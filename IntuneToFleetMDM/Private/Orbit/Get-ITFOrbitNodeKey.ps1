function Get-ITFOrbitNodeKey {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$OrbitNodeKeyPath
    )

    $candidates = @()
    if ($OrbitNodeKeyPath) { $candidates += $OrbitNodeKeyPath }

    # Observed on systems using Orbit update root directory (ProgramFiles\Orbit)
    if ($env:ProgramFiles) {
        $candidates += (Join-Path (Join-Path $env:ProgramFiles 'Orbit') 'secret-orbit-node-key.txt')
    }

    # Fallbacks (best-effort)
    if ($env:ProgramData) {
        $candidates += (Join-Path (Join-Path $env:ProgramData 'Orbit') 'secret-orbit-node-key.txt')
    }
    $candidates += 'C:\Program Files\Orbit\secret-orbit-node-key.txt'
    $candidates += 'C:\ProgramData\Orbit\secret-orbit-node-key.txt'

    foreach ($p in ($candidates | Select-Object -Unique)) {
        try {
            if (-not (Test-Path $p)) { continue }
            $k = (Get-Content -Path $p -Raw -ErrorAction Stop).Trim()
            if ($k) {
                return [pscustomobject]@{
                    Path = $p
                    OrbitNodeKey = $k
                }
            }
        }
        catch { }
    }

    return $null
}


