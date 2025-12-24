function Wait-ITFFleetMdmProvisioned {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ExpectedFleetHost,

        [Parameter()]
        [int]$TimeoutSeconds = 180,

        [Parameter()]
        [int]$PollIntervalSeconds = 5
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $proof = Test-ITFFleetMDMProvisioned -ExpectedFleetHost $ExpectedFleetHost
        if ($null -ne $proof) {
            return $proof
        }
        Start-Sleep -Seconds $PollIntervalSeconds
    } while ((Get-Date) -lt $deadline)

    return $null
}


