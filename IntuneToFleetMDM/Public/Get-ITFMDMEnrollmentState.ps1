function Get-ITFMDMEnrollmentState {
    [CmdletBinding()]
    param()

    $state = [ITFMDMEnrollmentState]::new()
    $state.ComputerName = $env:COMPUTERNAME

    try {
        $state.InstallationType = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name InstallationType -ErrorAction Stop).InstallationType
    }
    catch { $state.InstallationType = $null }

    $state.Enrollments = @(Get-ITFMDMEnrollments)
    $omadm = @()
    foreach ($e in $state.Enrollments) {
        $ci = Get-ITFOMADMConnInfo -EnrollmentId $e.EnrollmentId
        if ($ci) { $omadm += $ci }
    }
    $state.OMADM = $omadm

    $providers = @($state.Enrollments | Select-Object -ExpandProperty ProviderId -ErrorAction SilentlyContinue)
    if ($providers -contains 'Fleet') {
        $state.Detected = 'Fleet'
    } elseif ($providers -contains 'MS DM Server' -or $providers -contains 'Microsoft Device Management') {
        $state.Detected = 'Intune'
    } elseif ($providers.Count -eq 0) {
        $state.Detected = 'None'
    } else {
        $state.Detected = 'Other'
    }

    return $state
}


