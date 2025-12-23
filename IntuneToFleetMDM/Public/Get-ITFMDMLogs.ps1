function Get-ITFMDMLogs {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Last = 200
    )

    $cfg = Get-ITFMDMConfig
    $logPath = $cfg.LogPath

    $file = Join-Path $logPath ("IntuneToFleetMDM_{0}.log" -f (Get-Date).ToString('yyyyMMdd'))
    $tail = $null
    if (Test-Path $file) {
        try { $tail = Get-Content -Path $file -Tail $Last -ErrorAction Stop } catch { }
    }

    $ev = $null
    try {
        # Best-effort: look for our prefix in Application/WSH fallback and in the dedicated log if configured.
        $ev = Get-WinEvent -FilterHashtable @{ LogName = 'Application' } -MaxEvents ($Last * 5) -ErrorAction SilentlyContinue |
            Where-Object { param($e) $e.Message -match '\[IntuneToFleetMDM\]' } |
            Select-Object -First $Last
    }
    catch { }

    return [pscustomobject]@{
        LogFile = $file
        FileTail = $tail
        EventLogEvents = $ev
    }
}


