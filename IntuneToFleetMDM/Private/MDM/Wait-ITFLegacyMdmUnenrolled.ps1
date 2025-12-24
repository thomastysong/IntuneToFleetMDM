function Wait-ITFLegacyMdmUnenrolled {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$TimeoutSeconds = 120,

        [Parameter()]
        [int]$PollIntervalSeconds = 5
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $enrollments = @(Get-ITFMDMEnrollments)
        $legacy = @($enrollments | Where-Object { $_.ProviderId -in @('MS DM Server','Microsoft Device Management') })
        if ($legacy.Count -eq 0) {
            return $true
        }
        Start-Sleep -Seconds $PollIntervalSeconds
    } while ((Get-Date) -lt $deadline)

    return $false
}


