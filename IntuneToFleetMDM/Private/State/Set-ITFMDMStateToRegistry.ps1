function Set-ITFMDMStateToRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StateRegistryKey,

        [Parameter(Mandatory)]
        [hashtable]$Values
    )

    try {
        if (-not (Test-Path $StateRegistryKey)) {
            New-Item -Path $StateRegistryKey -Force | Out-Null
        }

        foreach ($k in $Values.Keys) {
            $v = $Values[$k]
            if ($null -eq $v) { continue }
            New-ItemProperty -Path $StateRegistryKey -Name $k -Value $v -PropertyType String -Force | Out-Null
        }
        return $true
    }
    catch {
        return $false
    }
}


