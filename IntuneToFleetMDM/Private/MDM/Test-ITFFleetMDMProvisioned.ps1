function Test-ITFFleetMDMProvisioned {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ExpectedFleetHost
    )

    $enrollments = Get-ITFMDMEnrollments | Where-Object { $_.ProviderId -eq 'Fleet' }
    foreach ($e in $enrollments) {
        $conn = Get-ITFOMADMConnInfo -EnrollmentId $e.EnrollmentId
        if ($null -eq $conn) { continue }

        if ($ExpectedFleetHost) {
            if ($conn.Addr -and ($conn.Addr -notmatch [Regex]::Escape($ExpectedFleetHost))) {
                continue
            }
        }

        if ($conn.LastSessionResult -eq 0) {
            return [pscustomobject]@{
                EnrollmentId          = $e.EnrollmentId
                ProviderId            = $e.ProviderId
                DiscoveryServiceFullURL = $e.DiscoveryServiceFullURL
                Addr                  = $conn.Addr
                LastSessionResult     = $conn.LastSessionResult
                ServerLastSuccessTime = $conn.ServerLastSuccessTime
                ServerLastAccessTime  = $conn.ServerLastAccessTime
            }
        }
    }
    return $null
}


