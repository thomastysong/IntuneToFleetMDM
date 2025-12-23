function Get-ITFMDMEnrollments {
    [CmdletBinding()]
    param()

    $enrollRoot = 'HKLM:\SOFTWARE\Microsoft\Enrollments'
    $rows = @()
    if (-not (Test-Path $enrollRoot)) { return $rows }

    foreach ($k in (Get-ChildItem $enrollRoot -ErrorAction SilentlyContinue)) {
        $p = $k.PSPath
        $prov  = (Get-ItemProperty -Path $p -Name ProviderID -ErrorAction SilentlyContinue).ProviderID
        $state = (Get-ItemProperty -Path $p -Name EnrollmentState -ErrorAction SilentlyContinue).EnrollmentState
        $disco = (Get-ItemProperty -Path $p -Name DiscoveryServiceFullURL -ErrorAction SilentlyContinue).DiscoveryServiceFullURL

        if ($null -ne $prov -and $prov -ne '') {
            $e = [ITFMDMEnrollmentEntry]::new()
            $e.EnrollmentId = $k.PSChildName
            $e.ProviderId = [string]$prov
            if ($null -ne $state) { $e.EnrollmentState = [int]$state }
            $e.DiscoveryServiceFullURL = [string]$disco
            $rows += $e
        }
    }

    return $rows
}


