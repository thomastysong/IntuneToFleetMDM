function Get-ITFOMADMConnInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnrollmentId
    )

    $connKey = "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$EnrollmentId\Protected\ConnInfo"
    $addrKey = "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$EnrollmentId\Protected\AddrInfo"
    if (-not (Test-Path $connKey)) { return $null }

    try {
        $p = Get-ItemProperty -Path $connKey -ErrorAction Stop
        $addr = $null
        if (Test-Path $addrKey) {
            try { $addr = (Get-ItemProperty -Path $addrKey -Name Addr -ErrorAction SilentlyContinue).Addr } catch { }
        }

        $ci = [ITFOMADMConnInfo]::new()
        $ci.EnrollmentId = $EnrollmentId
        $ci.Addr = if ($addr) { [string]$addr } else { $null }
        if ($null -ne $p.LastSessionResult) { $ci.LastSessionResult = [int]$p.LastSessionResult }

        function Parse-OmadmTime([object]$s) {
            if (-not $s) { return $null }
            $str = [string]$s
            # Examples observed: 20251223T072908Z
            try {
                return [datetime]::ParseExact($str, 'yyyyMMdd''T''HHmmss''Z''', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
            } catch {
                try { return [datetime]::Parse($str, [Globalization.CultureInfo]::InvariantCulture) } catch { return $null }
            }
        }

        if ($p.PSObject.Properties.Name -contains 'ServerLastSuccessTime') {
            $ci.ServerLastSuccessTime = Parse-OmadmTime $p.ServerLastSuccessTime
        }
        if ($p.PSObject.Properties.Name -contains 'ServerLastAccessTime') {
            $ci.ServerLastAccessTime = Parse-OmadmTime $p.ServerLastAccessTime
        }
        return $ci
    }
    catch {
        return $null
    }
}


