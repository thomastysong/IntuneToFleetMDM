function Invoke-ITFMDMMigration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$FleetHost,

        [Parameter()]
        [string]$DiscoveryUrl,

        [Parameter()]
        [bool]$Install = $false,

        [Parameter()]
        [string]$EnrollSecret,

        [Parameter()]
        [string]$InstallerUrl = 'https://download.fleetdm.com/stable/fleetd-base.msi',

        [Parameter()]
        [string]$MsiPath,

        [Parameter()]
        [int]$InstallTimeoutSeconds = 300,

        [Parameter()]
        [int]$InstallPollIntervalSeconds = 5,

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
        [string]$SlackWebhook,

        [Parameter()]
        [switch]$NoMtaRelaunch
    )

    if (-not $DiscoveryUrl) {
        $DiscoveryUrl = ("https://{0}/api/mdm/microsoft/discovery" -f $FleetHost)
    }

    $cfg = Get-ITFMDMConfig
    $corr = $script:ITFMDM_Logging.CorrelationId

    # Relaunch in MTA if needed (common when called from STA hosts).
    # Note: Slack notifications are emitted from the inner MTA process to avoid duplicates.
    $aptState = [System.Threading.Thread]::CurrentThread.ApartmentState
    if (-not $NoMtaRelaunch -and $aptState -ne [System.Threading.ApartmentState]::MTA) {
        $tempBase = $env:TEMP
        if (-not $tempBase) { $tempBase = $env:TMP }
        if (-not $tempBase) { $tempBase = 'C:\Windows\Temp' }

        $tmp = Join-Path $tempBase ("itfmdm_result_{0}.json" -f ([guid]::NewGuid().ToString()))
        $args = @{
            FleetHost        = $FleetHost
            DiscoveryUrl     = $DiscoveryUrl
            Install          = [bool]$Install
            EnrollSecret     = $EnrollSecret
            InstallerUrl     = $InstallerUrl
            MsiPath          = $MsiPath
            InstallTimeoutSeconds      = [int]$InstallTimeoutSeconds
            InstallPollIntervalSeconds = [int]$InstallPollIntervalSeconds
            SkipUnenroll     = [bool]$SkipUnenroll
            UnenrollOnly     = [bool]$UnenrollOnly
            EnrollOnly       = [bool]$EnrollOnly
            Force            = [bool]$Force
            OrbitNodeKeyPath = $OrbitNodeKeyPath
            SlackWebhook     = $SlackWebhook
        }

        Write-ITFMDMLog -Level Warn -EventId 2001 -Message 'Relaunching in MTA for MDM registration reliability' -Data @{
            current_apartment_state = [string]$aptState
            result_path = $tmp
        }

        $moduleRoot = Split-Path $PSScriptRoot -Parent
        $manifestPath = Join-Path $moduleRoot 'IntuneToFleetMDM.psd1'
        $r = Invoke-ITFInMTA -CommandName 'Invoke-ITFMDMMigration' -Arguments $args -ModuleManifestPath $manifestPath -ResultPath $tmp
        if (Test-Path $tmp) {
            try { return (Get-Content -Path $tmp -Raw | ConvertFrom-Json) } catch { }
        }
        throw ("MTA relaunch failed (exit={0}). StdErr={1}" -f $r.ExitCode, $r.StdErr)
    }

    $notifyCtx = $null
    if ($SlackWebhook) {
        $notifyCtx = Get-ITFDeviceNotificationContext -FleetHost $FleetHost -DiscoveryUrl $DiscoveryUrl -CorrelationId $corr
    }

    $changesMade = $false
    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            throw 'Must run elevated (Administrator/SYSTEM).'
        }

        $installType = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name InstallationType -ErrorAction Stop).InstallationType
        if ($installType -and $installType.ToLowerInvariant() -eq 'server') {
            throw "Windows Server detected (InstallationType=$installType). Windows MDM enrollment is not supported."
        }

        $existingState = Get-ITFMDMStateFromRegistry -StateRegistryKey $cfg.StateRegistryKey

        $already = Test-ITFFleetMDMProvisioned -ExpectedFleetHost $FleetHost
        if ($already -and -not $Force) {
            Write-ITFMDMLog -Level Info -EventId 1002 -Message 'Already Fleet MDM enrolled and syncing; skipping' -Data $already

            # If we were previously "InProgress", mark completion and optionally post Slack Success on this verification run.
            $wasVerified = $false
            try {
                if ($existingState -and $existingState.PSObject.Properties.Name -contains 'Status' -and $existingState.Status -eq 'Verified') {
                    $wasVerified = $true
                }
            } catch { }

            if (-not $wasVerified) {
                Set-ITFMDMStateToRegistry -StateRegistryKey $cfg.StateRegistryKey -Values @{
                    CorrelationId = $corr
                    FleetHost     = $FleetHost
                    DiscoveryUrl  = $DiscoveryUrl
                    Status        = 'Verified'
                    EnrollmentId  = $already.EnrollmentId
                    VerifiedTime  = (Get-Date).ToString('o')
                } | Out-Null

                if ($SlackWebhook -and $notifyCtx) {
                    Send-ITFSlackNotification -SlackWebhook $SlackWebhook -Type 'Success' -Context $notifyCtx | Out-Null
                }
            }

            $res = [ITFMDMMigrationResult]::new()
            $res.Status = 'Verified'
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

        # If Fleet enrollment artifacts exist but are not yet healthy (OMADM not confirmed), treat this as "in progress"
        # rather than a hard failure. In practice, Windows can take a long time to fully provision/sync the OMADM account.
        if (-not $Force -and $null -eq $already) {
            $legacyEnrollments = @($stateBefore.Enrollments | Where-Object { $_.ProviderId -eq 'MS DM Server' -or $_.ProviderId -eq 'Microsoft Device Management' })
            $fleetEnrollments = @($stateBefore.Enrollments | Where-Object { $_.ProviderId -eq 'Fleet' })

            if ($FleetHost) {
                $fleetEnrollments = @($fleetEnrollments | Where-Object {
                    $_.DiscoveryServiceFullURL -and ($_.DiscoveryServiceFullURL -match [Regex]::Escape($FleetHost))
                })
            }

            if ($legacyEnrollments.Count -eq 0 -and $fleetEnrollments.Count -gt 0) {
                $inProgressId = $fleetEnrollments[0].EnrollmentId

                Write-ITFMDMLog -Level Warn -EventId 2005 -Message 'Fleet MDM enrollment artifacts detected but OMADM is not yet verified healthy; returning InProgress (retry later)' -Data @{
                    enrollment_id = $inProgressId
                    discovery_url = $fleetEnrollments[0].DiscoveryServiceFullURL
                    suggested_retry_after_minutes = 30
                }

                Set-ITFMDMStateToRegistry -StateRegistryKey $cfg.StateRegistryKey -Values @{
                    CorrelationId  = $corr
                    FleetHost      = $FleetHost
                    DiscoveryUrl   = $DiscoveryUrl
                    Status         = 'InProgress'
                    EnrollmentId   = $inProgressId
                    InProgressTime = (Get-Date).ToString('o')
                    NextRetryAfter = (Get-Date).AddMinutes(30).ToString('o')
                } | Out-Null

                $res = [ITFMDMMigrationResult]::new()
                $res.Status = 'InProgress'
                $res.FleetHost = $FleetHost
                $res.DiscoveryUrl = $DiscoveryUrl
                $res.EnrollmentId = $inProgressId
                $res.CorrelationId = $corr
                return $res
            }
        }

        Set-ITFMDMStateToRegistry -StateRegistryKey $cfg.StateRegistryKey -Values @{
            CorrelationId = $corr
            FleetHost     = $FleetHost
            DiscoveryUrl  = $DiscoveryUrl
            Status        = 'Attempted'
            AttemptTime   = (Get-Date).ToString('o')
        } | Out-Null

        # Preflight: avoid unenrolling legacy MDM unless we can proceed with Fleet enrollment.
        $orbit = $null
        if (-not $UnenrollOnly) {
            $orbit = Get-ITFOrbitNodeKey -OrbitNodeKeyPath $OrbitNodeKeyPath
            if (-not $orbit -or -not $orbit.OrbitNodeKey) {
                if ($Install) {
                    if (-not $EnrollSecret) {
                        throw 'EnrollSecret is required when -Install is true.'
                    }

                    Write-ITFMDMLog -Level Warn -EventId 2100 -Message 'Orbit node key missing; -Install is enabled so Fleet agent install will be attempted' -Data @{
                        installer_url = if ($MsiPath) { $null } else { $InstallerUrl }
                        msi_path      = $MsiPath
                        install_timeout_seconds = $InstallTimeoutSeconds
                        install_poll_interval_seconds = $InstallPollIntervalSeconds
                        enroll_secret_provided = $true
                    }

                    Install-ITFFleetdBaseMsi -FleetHost $FleetHost -EnrollSecret $EnrollSecret -InstallerUrl $InstallerUrl -MsiPath $MsiPath -TimeoutSeconds $InstallTimeoutSeconds -PollIntervalSeconds $InstallPollIntervalSeconds | Out-Null

                    $orbit = Get-ITFOrbitNodeKey -OrbitNodeKeyPath $OrbitNodeKeyPath
                    if (-not $orbit -or -not $orbit.OrbitNodeKey) {
                        throw 'Orbit node key still not found after Fleet agent install attempt. Retry later or pass -OrbitNodeKeyPath if using a non-standard install location.'
                    }
                } else {
                    throw 'Orbit node key not found on disk. Install Fleet agent (Orbit/fleetd) or run with -Install true -EnrollSecret <value>, or pass -OrbitNodeKeyPath.'
                }
            }

            # Best-effort reachability check. If the discovery endpoint cannot be reached (no HTTP response),
            # do not unenroll. Note: We treat non-2xx responses as "reachable".
            try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
            try {
                $req = [System.Net.HttpWebRequest]::Create($DiscoveryUrl)
                $req.Method = 'GET'
                $req.Timeout = 10000
                $req.ReadWriteTimeout = 10000
                $req.AllowAutoRedirect = $true
                $resp = $req.GetResponse()
                try { $resp.Close() } catch { }
            }
            catch [System.Net.WebException] {
                # If we got an HTTP response (even error), the endpoint is reachable.
                if ($_.Exception -and $_.Exception.Response) {
                    try { $_.Exception.Response.Close() } catch { }
                } else {
                    throw ("Discovery URL is not reachable: {0}" -f $DiscoveryUrl)
                }
            }
        }

        Initialize-ITFMDMInterop

        $didUnenroll = $false
        $unenrollRc = $null
        if (-not $SkipUnenroll -and -not $EnrollOnly) {
            if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'UnregisterDeviceWithManagement(0)')) {
                $changesMade = $true
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
                $didUnenroll = $true

                # Poll until legacy enrollment artifacts are gone to reduce unenroll→enroll race conditions.
                $legacyGone = Wait-ITFLegacyMdmUnenrolled -TimeoutSeconds 180 -PollIntervalSeconds 5
                if (-not $legacyGone) {
                    throw 'Timed out waiting for legacy MDM unenroll confirmation.'
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

        if ($SlackWebhook -and $didUnenroll -and $notifyCtx) {
            Send-ITFSlackNotification -SlackWebhook $SlackWebhook -Type 'Started' -Context $notifyCtx | Out-Null
        }

        $token = New-ITFProgrammaticEnrollmentToken -OrbitNodeKey $orbit.OrbitNodeKey

        $enrollRc = $null
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "RegisterDeviceWithManagement('', '$DiscoveryUrl', <token>)")) {
            $changesMade = $true
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
        $proof = Wait-ITFFleetMdmProvisioned -ExpectedFleetHost $FleetHost -TimeoutSeconds 300 -PollIntervalSeconds 5
        if ($null -eq $proof) {
            # If Fleet enrollment artifacts exist but OMADM is not yet healthy, treat this as in-progress.
            # This prevents Fleet/Intune/SCCM orchestrators from interpreting a transient "not yet synced" state as a failure.
            $fleetEnrollments = @(Get-ITFMDMEnrollments | Where-Object { $_.ProviderId -eq 'Fleet' })
            if ($FleetHost) {
                $fleetEnrollments = @($fleetEnrollments | Where-Object {
                    $_.DiscoveryServiceFullURL -and ($_.DiscoveryServiceFullURL -match [Regex]::Escape($FleetHost))
                })
            }

            if ($fleetEnrollments.Count -gt 0) {
                $inProgressId = $fleetEnrollments[0].EnrollmentId

                Write-ITFMDMLog -Level Warn -EventId 2006 -Message 'Fleet MDM enrollment not yet verified; returning InProgress (retry later)' -Data @{
                    enrollment_id = $inProgressId
                    enroll_hresult_hex = if ($null -ne $enrollRc) { ('0x{0:X8}' -f $enrollRc) } else { $null }
                    suggested_retry_after_minutes = 30
                }

                Set-ITFMDMStateToRegistry -StateRegistryKey $cfg.StateRegistryKey -Values @{
                    Status         = 'InProgress'
                    EnrollmentId   = $inProgressId
                    InProgressTime = (Get-Date).ToString('o')
                    NextRetryAfter = (Get-Date).AddMinutes(30).ToString('o')
                } | Out-Null

                $res = [ITFMDMMigrationResult]::new()
                $res.Status = 'InProgress'
                $res.FleetHost = $FleetHost
                $res.DiscoveryUrl = $DiscoveryUrl
                $res.EnrollmentId = $inProgressId
                $res.CorrelationId = $corr
                return $res
            }

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

        if ($SlackWebhook -and $notifyCtx) {
            Send-ITFSlackNotification -SlackWebhook $SlackWebhook -Type 'Success' -Context $notifyCtx | Out-Null
        }

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
    catch {
        $reason = $null
        try { $reason = $_.Exception.Message } catch { }

        if (-not $changesMade) {
            # Preflight failure: no unenroll/enroll calls were made.
            Set-ITFMDMStateToRegistry -StateRegistryKey $cfg.StateRegistryKey -Values @{
                Status = 'PreflightFailed'
                PreflightFailureReason = $reason
                PreflightFailureTime = (Get-Date).ToString('o')
            } | Out-Null

            if ($SlackWebhook -and $notifyCtx) {
                Send-ITFSlackNotification -SlackWebhook $SlackWebhook -Type 'PreflightFailed' -Context $notifyCtx -FailureReason $reason | Out-Null
            }
        } else {
            if ($SlackWebhook -and $notifyCtx) {
                Send-ITFSlackNotification -SlackWebhook $SlackWebhook -Type 'Failure' -Context $notifyCtx -FailureReason $reason | Out-Null
            }
        }
        throw
    }
}


