function Get-ITFDeviceNotificationContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FleetHost,

        [Parameter(Mandatory)]
        [string]$DiscoveryUrl,

        [Parameter(Mandatory)]
        [string]$CorrelationId
    )

    $username = $null
    $serial = $null
    $model = $null
    $osDisplay = $null

    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($cs.UserName) { $username = [string]$cs.UserName }
        if ($cs.Model) { $model = [string]$cs.Model }
    } catch { }

    if (-not $username) {
        try {
            if ($env:USERDOMAIN -and $env:USERNAME) {
                $username = ('{0}\{1}' -f $env:USERDOMAIN, $env:USERNAME)
            } elseif ($env:USERNAME) {
                $username = [string]$env:USERNAME
            }
        } catch { }
    }

    try {
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
        if ($bios.SerialNumber) { $serial = [string]$bios.SerialNumber }
    } catch { }

    try {
        $cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $product = [string]$cv.ProductName
        $displayVersion = $null
        if ($cv.PSObject.Properties.Name -contains 'DisplayVersion') { $displayVersion = [string]$cv.DisplayVersion }
        if (-not $displayVersion -and $cv.PSObject.Properties.Name -contains 'ReleaseId') { $displayVersion = [string]$cv.ReleaseId }
        $build = [string]$cv.CurrentBuildNumber
        $ubr = $null
        if ($cv.PSObject.Properties.Name -contains 'UBR') { $ubr = [string]$cv.UBR }

        $buildFull = $build
        if ($ubr) { $buildFull = ('{0}.{1}' -f $build, $ubr) }

        if ($product -and $displayVersion -and $buildFull) {
            $osDisplay = ('{0} {1} ({2})' -f $product, $displayVersion, $buildFull)
        } elseif ($product -and $buildFull) {
            $osDisplay = ('{0} ({1})' -f $product, $buildFull)
        }
    } catch { }

    return [pscustomobject]@{
        FleetHost      = $FleetHost
        DiscoveryUrl   = $DiscoveryUrl
        CorrelationId  = $CorrelationId
        Username       = $username
        SerialNumber   = $serial
        DeviceModel    = $model
        OSVersionBuild = $osDisplay
        ComputerName   = $env:COMPUTERNAME
    }
}


