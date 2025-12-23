function Write-ITFMDMLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Info','Warn','Error')]
        [string]$Level,

        [Parameter(Mandatory)]
        [int]$EventId,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [hashtable]$Data
    )

    $prefix = '[IntuneToFleetMDM]'
    $corr = $null
    $logPath = $null
    if ($script:ITFMDM_Logging -and $script:ITFMDM_Logging.Initialized) {
        $corr = $script:ITFMDM_Logging.CorrelationId
        $logPath = $script:ITFMDM_Logging.Config.LogPath
    }

    $payload = @{
        ts             = (Get-Date).ToString('o')
        level          = $Level
        event_id       = $EventId
        message        = $Message
        correlation_id = $corr
    }
    if ($Data) { $payload.data = $Data }

    $json = $payload | ConvertTo-Json -Compress -Depth 6
    $line = "$prefix $json"

    # File log (best-effort)
    try {
        if ($logPath) {
            $file = Join-Path $logPath ("IntuneToFleetMDM_{0}.log" -f (Get-Date).ToString('yyyyMMdd'))
            Add-Content -Path $file -Value $line -Encoding UTF8
        }
    }
    catch { }

    # Event log (best-effort)
    $entryType = switch ($Level) {
        'Info'  { 'Information' }
        'Warn'  { 'Warning' }
        'Error' { 'Error' }
    }
    Write-ITFMDMEvent -EntryType $entryType -EventId $EventId -Message $line
}


