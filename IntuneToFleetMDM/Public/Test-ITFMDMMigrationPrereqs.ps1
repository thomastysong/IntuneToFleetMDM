function Test-ITFMDMMigrationPrereqs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FleetHost,

        [Parameter()]
        [string]$OrbitNodeKeyPath
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    $aptState = [System.Threading.Thread]::CurrentThread.ApartmentState

    $installType = $null
    try {
        $installType = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name InstallationType -ErrorAction Stop).InstallationType
    }
    catch { }

    $orbit = Get-ITFOrbitNodeKey -OrbitNodeKeyPath $OrbitNodeKeyPath
    $haveOrbitKey = ($null -ne $orbit -and $orbit.OrbitNodeKey)

    $already = Test-ITFFleetMDMProvisioned -ExpectedFleetHost $FleetHost

    return [pscustomobject]@{
        IsAdmin            = $isAdmin
        ApartmentState     = [string]$aptState
        InstallationType   = $installType
        IsWindowsServer    = ($installType -and $installType.ToLowerInvariant() -eq 'server')
        OrbitNodeKeyFound  = $haveOrbitKey
        OrbitNodeKeyPath   = if ($orbit) { $orbit.Path } else { $null }
        AlreadyFleetEnrolledAndHealthy = ($null -ne $already)
        DiscoveryUrl       = ("https://{0}/api/mdm/microsoft/discovery" -f $FleetHost)
    }
}


