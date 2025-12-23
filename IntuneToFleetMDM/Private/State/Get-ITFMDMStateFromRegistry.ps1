function Get-ITFMDMStateFromRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StateRegistryKey
    )

    try {
        if (-not (Test-Path $StateRegistryKey)) { return $null }
        return Get-ItemProperty -Path $StateRegistryKey -ErrorAction Stop
    }
    catch {
        return $null
    }
}


