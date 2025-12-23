function Invoke-ITFInMTA {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [hashtable]$Arguments,

        [Parameter(Mandatory)]
        [string]$ResultPath
    )

    $argsJson = ($Arguments | ConvertTo-Json -Compress -Depth 6)

    $encodedArgs = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($argsJson))
    $encodedResultPath = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($ResultPath))

    $cmd = @"
\$ErrorActionPreference = 'Stop'
\$argsJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedArgs'))
\$resultPath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedResultPath'))
\$params = ConvertFrom-Json -InputObject \$argsJson
Import-Module IntuneToFleetMDM -Force
\$ht = @{}
foreach (\$p in \$params.psobject.Properties) { \$ht[\$p.Name] = \$p.Value }
\$r = & $CommandName @ht -NoMtaRelaunch
\$r | ConvertTo-Json -Depth 6 | Set-Content -Path \$resultPath -Encoding UTF8 -Force
"@

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -MTA -Command `"$cmd`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $p = [System.Diagnostics.Process]::Start($psi)
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    return [pscustomobject]@{
        ExitCode = $p.ExitCode
        StdOut   = $stdout
        StdErr   = $stderr
        ResultPath = $ResultPath
    }
}


