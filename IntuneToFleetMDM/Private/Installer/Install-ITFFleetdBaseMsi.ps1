function Install-ITFFleetdBaseMsi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FleetHost,

        [Parameter(Mandatory)]
        [string]$EnrollSecret,

        [Parameter()]
        [string]$InstallerUrl = 'https://download.fleetdm.com/stable/fleetd-base.msi',

        [Parameter()]
        [string]$MsiPath,

        [Parameter()]
        [int]$TimeoutSeconds = 300,

        [Parameter()]
        [int]$PollIntervalSeconds = 5
    )

    $ErrorActionPreference = 'Stop'

    try {
        $msi = $null
        if ($MsiPath) {
            if (-not (Test-Path $MsiPath)) {
                throw ("MSI path not found: {0}" -f $MsiPath)
            }
            $msi = $MsiPath
        } else {
            try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

            $tempBase = $env:TEMP
            if (-not $tempBase) { $tempBase = $env:TMP }
            if (-not $tempBase) { $tempBase = 'C:\Windows\Temp' }

            $dest = Join-Path $tempBase ("fleetd-base_{0}.msi" -f ([guid]::NewGuid().ToString()))
            $msi = $dest

            $oldProgressPreference = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            try {
                Write-ITFMDMLog -Level Info -EventId 2101 -Message 'Downloading Fleet agent installer (fleetd-base.msi)' -Data @{
                    installer_url = $InstallerUrl
                    destination   = $dest
                }

                Invoke-WebRequest -Uri $InstallerUrl -OutFile $dest -UseBasicParsing -ErrorAction Stop | Out-Null

                $len = $null
                try { $len = (Get-Item -Path $dest -ErrorAction Stop).Length } catch { }

                Write-ITFMDMLog -Level Info -EventId 2102 -Message 'Downloaded Fleet agent installer (fleetd-base.msi)' -Data @{
                    destination = $dest
                    bytes       = $len
                }
            }
            finally {
                $ProgressPreference = $oldProgressPreference
            }
        }

        $msiexec = Join-Path $env:WINDIR 'System32\msiexec.exe'
        if (-not (Test-Path $msiexec)) {
            $msiexec = 'msiexec.exe'
        }

        $fleetUrl = "https://$FleetHost"

        # Important: do NOT log EnrollSecret or the full msiexec command line.
        Write-ITFMDMLog -Level Warn -EventId 2103 -Message 'Running msiexec to install Fleet agent (silent)' -Data @{
            msi_path  = $msi
            fleet_url = $fleetUrl
            properties = @('ENABLE_SCRIPTS=true','FLEET_DESKTOP=true','FLEET_URL=<redacted>','FLEET_SECRET=<redacted>')
        }

        $argList = @(
            '/i'
            "`"$msi`""
            '/qn'
            'ENABLE_SCRIPTS=true'
            'FLEET_DESKTOP=true'
            ("FLEET_URL=`"{0}`"" -f $fleetUrl)
            ("FLEET_SECRET=`"{0}`"" -f $EnrollSecret)
        )

        $p = Start-Process -FilePath $msiexec -ArgumentList $argList -Wait -PassThru -WindowStyle Hidden
        $exit = $p.ExitCode

        $rebootRequired = ($exit -in 3010, 1641)
        $ok = ($exit -in 0, 3010, 1641)

        Write-ITFMDMLog -Level Info -EventId 2104 -Message 'msiexec completed for Fleet agent install' -Data @{
            exit_code       = $exit
            success         = $ok
            reboot_required = $rebootRequired
        }

        if (-not $ok) {
            throw ("Fleet agent install failed (msiexec exit code: {0})." -f $exit)
        }

        # Best-effort: check service exists and is running
        $svc = $null
        try { $svc = Get-Service -Name 'Fleet osquery' -ErrorAction SilentlyContinue } catch { }
        if ($svc) {
            Write-ITFMDMLog -Level Info -EventId 2106 -Message 'Fleet osquery service detected after install (best-effort)' -Data @{
                service_name = $svc.Name
                status       = [string]$svc.Status
            }
            if ($svc.Status -ne 'Running') {
                try {
                    Start-Service -Name $svc.Name -ErrorAction Stop
                    $svc = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
                    if ($svc) {
                        Write-ITFMDMLog -Level Info -EventId 2107 -Message 'Started Fleet osquery service (best-effort)' -Data @{
                            service_name = $svc.Name
                            status       = [string]$svc.Status
                        }
                    }
                }
                catch { }
            }
        } else {
            Write-ITFMDMLog -Level Warn -EventId 2108 -Message 'Fleet osquery service not detected yet after install (best-effort)' -Data @{
                service_name = 'Fleet osquery'
            }
        }

        # Wait for Orbit node key to appear on disk.
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        do {
            $orbit = Get-ITFOrbitNodeKey
            if ($orbit -and $orbit.OrbitNodeKey) {
                Write-ITFMDMLog -Level Info -EventId 2105 -Message 'Orbit node key discovered after Fleet agent install' -Data @{
                    node_key_path = $orbit.Path
                }

                return [pscustomobject]@{
                    Success        = $true
                    OrbitNodeKeyPath = $orbit.Path
                    MsiexecExitCode  = $exit
                    RebootRequired = $rebootRequired
                }
            }
            Start-Sleep -Seconds $PollIntervalSeconds
        } while ((Get-Date) -lt $deadline)

        throw ("Timed out waiting for Orbit node key after Fleet agent install (timeout={0}s)." -f $TimeoutSeconds)
    }
    catch {
        $msg = $null
        try { $msg = $_.Exception.Message } catch { $msg = 'Unknown error' }
        Write-ITFMDMLog -Level Error -EventId 3101 -Message 'Fleet agent install failed' -Data @{
            error = $msg
        }
        throw
    }
}


