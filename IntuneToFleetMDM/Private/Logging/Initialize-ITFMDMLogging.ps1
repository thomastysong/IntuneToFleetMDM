function Initialize-ITFMDMLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        [string]$CorrelationId
    )

    $script:ITFMDM_Logging = @{
        Initialized   = $false
        CorrelationId = $CorrelationId
        Config        = $Config
        EffectiveEventLogName   = $Config.EventLogName
        EffectiveEventLogSource = $Config.EventLogSource
    }

    try {
        if (-not (Test-Path $Config.LogPath)) {
            New-Item -Path $Config.LogPath -ItemType Directory -Force | Out-Null
        }
    }
    catch {
        # If ProgramData isn't writable, fall back to TEMP.
        $tempBase = $env:TEMP
        if (-not $tempBase) { $tempBase = $env:TMP }
        if (-not $tempBase) { $tempBase = 'C:\Windows\Temp' }

        $fallback = Join-Path $tempBase 'IntuneToFleetMDM\Logs'
        New-Item -Path $fallback -ItemType Directory -Force | Out-Null
        $script:ITFMDM_Logging.Config.LogPath = $fallback
    }

    # Prefer a dedicated log/source when possible; fall back to Application/WSH when not.
    try {
        $logName = $Config.EventLogName
        $source = $Config.EventLogSource

        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

            if ($isAdmin) {
                New-EventLog -LogName $logName -Source $source -ErrorAction Stop
            } else {
                throw "Not admin - cannot create Event Log source"
            }
        }

        $script:ITFMDM_Logging.EffectiveEventLogName = $logName
        $script:ITFMDM_Logging.EffectiveEventLogSource = $source
    }
    catch {
        # Safe fallback that works without admin: Application log + existing WSH source.
        $script:ITFMDM_Logging.EffectiveEventLogName = 'Application'
        $script:ITFMDM_Logging.EffectiveEventLogSource = 'WSH'
    }

    $script:ITFMDM_Logging.Initialized = $true
    Write-ITFMDMLog -Level Info -EventId 1000 -Message "Logging initialized" -Data @{
        effective_event_log_name   = $script:ITFMDM_Logging.EffectiveEventLogName
        effective_event_log_source = $script:ITFMDM_Logging.EffectiveEventLogSource
        log_path                   = $script:ITFMDM_Logging.Config.LogPath
        correlation_id             = $script:ITFMDM_Logging.CorrelationId
    }
}


