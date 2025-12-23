function Invoke-ITFInMTA {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [hashtable]$Arguments,

        [Parameter(Mandatory)]
        [string]$ModuleManifestPath,

        [Parameter(Mandatory)]
        [string]$ResultPath
    )

    $argsJson = ($Arguments | ConvertTo-Json -Compress -Depth 6)

    $encodedArgs = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($argsJson))
    $encodedResultPath = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($ResultPath))
    $encodedManifestPath = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($ModuleManifestPath))

    $cmdTemplate = @'
$ErrorActionPreference = 'Stop'
$argsJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__ARGS__'))
$resultPath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__RESULT__'))
$manifestPath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__MANIFEST__'))
$params = ConvertFrom-Json -InputObject $argsJson
Import-Module $manifestPath -Force
$ht = @{}
foreach ($p in $params.psobject.Properties) { $ht[$p.Name] = $p.Value }
$r = & __CMD__ @ht -NoMtaRelaunch
$r | ConvertTo-Json -Depth 6 | Set-Content -Path $resultPath -Encoding UTF8 -Force
'@

    $cmd = $cmdTemplate.Replace('__ARGS__', $encodedArgs).Replace('__RESULT__', $encodedResultPath).Replace('__MANIFEST__', $encodedManifestPath).Replace('__CMD__', $CommandName)

    # Use -EncodedCommand to avoid quoting/escaping issues across shells.
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -MTA -EncodedCommand $encodedCommand"
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


