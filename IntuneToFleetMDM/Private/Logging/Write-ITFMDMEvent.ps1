function Write-ITFMDMEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Information','Warning','Error')]
        [string]$EntryType,

        [Parameter(Mandatory)]
        [int]$EventId,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $script:ITFMDM_Logging -or -not $script:ITFMDM_Logging.Initialized) {
        return
    }

    $logName = $script:ITFMDM_Logging.EffectiveEventLogName
    $source = $script:ITFMDM_Logging.EffectiveEventLogSource

    try {
        Write-EventLog -LogName $logName -Source $source -EventId $EventId -EntryType $EntryType -Message $Message -ErrorAction Stop
    }
    catch {
        # Best effort only; file log should still capture everything.
        return
    }
}


