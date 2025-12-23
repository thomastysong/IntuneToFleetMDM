function Invoke-ITFMDMMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$FleetHost,

        [Parameter()]
        [string]$DiscoveryUrl,

        [Parameter()]
        [switch]$SkipUnenroll,

        [Parameter()]
        [switch]$UnenrollOnly,

        [Parameter()]
        [switch]$EnrollOnly,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [string]$OrbitNodeKeyPath,

        [Parameter()]
        [switch]$NoMtaRelaunch
    )

    if (-not $DiscoveryUrl) {
        $DiscoveryUrl = ("https://{0}/api/mdm/microsoft/discovery" -f $FleetHost)
    }

    $cfg = Get-ITFMDMConfig
    $corr = $script:ITFMDM_Logging.CorrelationId

    # Relaunch in MTA if needed (common when called from STA hosts).
    $aptState = [System.Threading.Thread]::CurrentThread.ApartmentState
    if (-not $NoMtaRelaunch -and $aptState -ne [System.Threading.ApartmentState]::MTA) {
        $tempBase = $env:TEMP
        if (-not $tempBase) { $tempBase = $env:TMP }
        if (-not $tempBase) { $tempBase = 'C:\Windows\Temp' }

        $tmp = Join-Path $tempBase ("itfmdm_result_{0}.json" -f ([guid]::NewGuid().ToString()))
        $args = @{
            FleetHost        = $FleetHost
            DiscoveryUrl     = $DiscoveryUrl
            SkipUnenroll     = [bool]$SkipUnenroll
            UnenrollOnly     = [bool]$UnenrollOnly
            EnrollOnly       = [bool]$EnrollOnly
            Force            = [bool]$Force
            OrbitNodeKeyPath = $OrbitNodeKeyPath
        }

        Write-ITFMDMLog -Level Warn -EventId 2001 -Message 'Relaunching in MTA for MDM registration reliability' -Data @{
            current_apartment_state = [string]$aptState
            result_path = $tmp
        }

        $r = Invoke-ITFInMTA -CommandName 'Invoke-ITFMDMMigration' -Arguments $args -ResultPath $tmp
        if (Test-Path $tmp) {
            try { return (Get-Content -Path $tmp -Raw | ConvertFrom-Json) } catch { }
        }
        throw ("MTA relaunch failed (exit={0}). StdErr={1}" -f $r.ExitCode, $r.StdErr)
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw 'Must run elevated (Administrator/SYSTEM).'
    }

    $installType = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name InstallationType -ErrorAction Stop).InstallationType
    if ($installType -and $installType.ToLowerInvariant() -eq 'server') {
        throw "Windows Server detected (InstallationType=$installType). Windows MDM enrollment is not supported."
    }

    $already = Test-ITFFleetMDMProvisioned -ExpectedFleetHost $FleetHost
    if ($already -and -not $Force) {
        Write-ITFMDMLog -Level Info -EventId 1002 -Message 'Already Fleet MDM enrolled and syncing; skipping' -Data $already
        $res = [ITFMDMMigrationResult]::new()
        $res.Status = 'AlreadyEnrolled'
        $res.FleetHost = $FleetHost
        $res.DiscoveryUrl = $DiscoveryUrl
        $res.EnrollmentId = $already.EnrollmentId
        $res.CorrelationId = $corr
        return $res
    }

    $stateBefore = Get-ITFMDMEnrollmentState
    if (-not $Force -and $stateBefore.Detected -eq 'Intune' -and $EnrollOnly) {
        throw 'EnrollOnly requested but Intune enrollment is still present (detected). Unenroll first or use -Force.'
    }

    Set-ITFMDMStateToRegistry -StateRegistryKey $cfg.StateRegistryKey -Values @{
        CorrelationId = $corr
        FleetHost     = $FleetHost
        DiscoveryUrl  = $DiscoveryUrl
        Status        = 'Attempted'
        AttemptTime   = (Get-Date).ToString('o')
    } | Out-Null

    Initialize-ITFMDMInterop

    $unenrollRc = $null
    if (-not $SkipUnenroll -and -not $EnrollOnly) {
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'UnregisterDeviceWithManagement(0)')) {
            Write-ITFMDMLog -Level Warn -EventId 2002 -Message 'Calling UnregisterDeviceWithManagement(0) to remove current MDM enrollment' -Data @{
                detected_before = $stateBefore.Detected
            }
            $unenrollRc = [ITFMDMRegistration]::UnregisterDeviceWithManagement(0)
            Write-ITFMDMLog -Level Info -EventId 1003 -Message 'UnregisterDeviceWithManagement returned' -Data @{
                hresult_hex = ('0x{0:X8}' -f $unenrollRc)
                hresult     = [uint32]$unenrollRc
            }
            if ($unenrollRc -ne 0) {
                Set-ITFMDMStateToRegistry -StateRegistryKey $cfg.StateRegistryKey -Values @{ Status = 'FailedUnenroll' } | Out-Null
                throw ("Unenroll failed (HRESULT=0x{0:X8})." -f $unenrollRc)
            }
        }
    }

    if ($UnenrollOnly) {
        Set-ITFMDMStateToRegistry -StateRegistryKey $cfg.StateRegistryKey -Values @{ Status = 'Unenrolled' } | Out-Null
        $res = [ITFMDMMigrationResult]::new()
        $res.Status = 'Unenrolled'
        $res.FleetHost = $FleetHost
        $res.DiscoveryUrl = $DiscoveryUrl
        $res.UnenrollHResult = if ($null -ne $unenrollRc) { [uint32]$unenrollRc } else { $null }
        $res.CorrelationId = $corr
        return $res
    }

    $orbit = Get-ITFOrbitNodeKey -OrbitNodeKeyPath $OrbitNodeKeyPath
    if (-not $orbit -or -not $orbit.OrbitNodeKey) {
        throw 'Orbit node key not found on disk. Install Orbit and ensure the node key file is present, or pass -OrbitNodeKeyPath.'
    }

    $token = New-ITFProgrammaticEnrollmentToken -OrbitNodeKey $orbit.OrbitNodeKey

    $enrollRc = $null
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "RegisterDeviceWithManagement('', '$DiscoveryUrl', <token>)")) {
        Write-ITFMDMLog -Level Warn -EventId 2003 -Message 'Calling RegisterDeviceWithManagement for Fleet discovery URL' -Data @{
            discovery_url = $DiscoveryUrl
            orbit_node_key_path = $orbit.Path
        }
        $enrollRc = [ITFMDMRegistration]::RegisterDeviceWithManagement('', $DiscoveryUrl, $token)
        Write-ITFMDMLog -Level Info -EventId 1004 -Message 'RegisterDeviceWithManagement returned' -Data @{
            hresult_hex = ('0x{0:X8}' -f $enrollRc)
            hresult     = [uint32]$enrollRc
        }
    }

    # Verification is authoritative; some environments return non-zero even with a healthy OMADM account.
    Start-Sleep -Seconds 5
    $proof = Test-ITFFleetMDMProvisioned -ExpectedFleetHost $FleetHost
    if ($null -eq $proof) {
        Set-ITFMDMStateToRegistry -StateRegistryKey $cfg.StateRegistryKey -Values @{ Status = 'FailedEnroll' } | Out-Null
        if ($null -ne $enrollRc -and $enrollRc -ne 0) {
            throw ("Enroll failed (HRESULT=0x{0:X8}) and verification did not find a healthy Fleet OMADM account." -f $enrollRc)
        }
        throw 'Enroll verification failed: no healthy Fleet OMADM account found.'
    }

    Set-ITFMDMStateToRegistry -StateRegistryKey $cfg.StateRegistryKey -Values @{
        Status = 'Verified'
        EnrollmentId = $proof.EnrollmentId
        VerifiedTime = (Get-Date).ToString('o')
    } | Out-Null

    if ($null -ne $enrollRc -and $enrollRc -ne 0) {
        Write-ITFMDMLog -Level Warn -EventId 2004 -Message 'Enroll returned non-zero, but verification shows Fleet MDM is provisioned and syncing' -Data @{
            hresult_hex = ('0x{0:X8}' -f $enrollRc)
            enrollment_id = $proof.EnrollmentId
            addr = $proof.Addr
            last_success = $proof.ServerLastSuccessTime
        }
    } else {
        Write-ITFMDMLog -Level Info -EventId 1005 -Message 'Fleet MDM provisioned and syncing (verified)' -Data $proof
    }

    $res = [ITFMDMMigrationResult]::new()
    $res.Status = 'Verified'
    $res.FleetHost = $FleetHost
    $res.DiscoveryUrl = $DiscoveryUrl
    $res.EnrollmentId = $proof.EnrollmentId
    $res.UnenrollHResult = if ($null -ne $unenrollRc) { [uint32]$unenrollRc } else { $null }
    $res.EnrollHResult = if ($null -ne $enrollRc) { [uint32]$enrollRc } else { $null }
    $res.CorrelationId = $corr
    return $res
}


