#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

# Module paths
$script:ModuleRoot = $PSScriptRoot

# Module-scoped configuration
$script:ModuleConfig = $null
$script:CorrelationId = $null

function Initialize-ITFMModuleConfiguration {
    [CmdletBinding()]
    param()

    $manifestPath = Join-Path $script:ModuleRoot 'IntuneToFleetMDM.psd1'
    $manifest = Import-PowerShellDataFile -Path $manifestPath

    $defaults = $manifest.PrivateData.ModuleConfig

    $programData = $env:ProgramData
    if (-not $programData) { $programData = 'C:\ProgramData' }

    $script:CorrelationId = [guid]::NewGuid().ToString()

    $logPath = [string]$defaults.LogPath
    # Support either PowerShell-style $env:ProgramData or Windows-style %ProgramData%
    if ($logPath -match '%ProgramData%') {
        $pd = $env:ProgramData
        if (-not $pd) { $pd = 'C:\ProgramData' }
        $logPath = $logPath.Replace('%ProgramData%', $pd)
    }
    $logPath = $ExecutionContext.InvokeCommand.ExpandString($logPath)

    $script:ModuleConfig = @{
        LogPath          = $logPath
        EventLogName     = $defaults.EventLogName
        EventLogSource   = $defaults.EventLogSource
        StateRegistryKey = $defaults.StateRegistryKey
        ModuleVersion    = $manifest.ModuleVersion
    }

    if ($env:ITFMDM_LOG_PATH) { $script:ModuleConfig.LogPath = $env:ITFMDM_LOG_PATH }
    if ($env:ITFMDM_EVENT_LOG_NAME) { $script:ModuleConfig.EventLogName = $env:ITFMDM_EVENT_LOG_NAME }
    if ($env:ITFMDM_EVENT_LOG_SOURCE) { $script:ModuleConfig.EventLogSource = $env:ITFMDM_EVENT_LOG_SOURCE }
    if ($env:ITFMDM_STATE_KEY) { $script:ModuleConfig.StateRegistryKey = $env:ITFMDM_STATE_KEY }
}

function Get-ITFMDMConfig {
    [CmdletBinding()]
    param()
    return $script:ModuleConfig.Clone()
}

# Dot-source all files: Classes -> Private -> Public
$classFiles = @(
    'Classes\ITFMDMTypes.ps1'
)

$privateFiles = @(
    'Private\Logging\Initialize-ITFMDMLogging.ps1'
    'Private\Logging\Write-ITFMDMLog.ps1'
    'Private\Logging\Write-ITFMDMEvent.ps1'
    'Private\State\Get-ITFMDMStateFromRegistry.ps1'
    'Private\State\Set-ITFMDMStateToRegistry.ps1'
    'Private\Interop\Initialize-ITFMDMInterop.ps1'
    'Private\Interop\Invoke-ITFInMTA.ps1'
    'Private\MDM\Get-ITFMDMEnrollments.ps1'
    'Private\MDM\Get-ITFOMADMConnInfo.ps1'
    'Private\MDM\Test-ITFFleetMDMProvisioned.ps1'
    'Private\Orbit\Get-ITFOrbitNodeKey.ps1'
    'Private\Token\New-ITFProgrammaticEnrollmentToken.ps1'
)

$publicFiles = @(
    'Public\Get-ITFMDMEnrollmentState.ps1'
    'Public\Test-ITFMDMMigrationPrereqs.ps1'
    'Public\Invoke-ITFMDMMigration.ps1'
    'Public\Get-ITFMDMLogs.ps1'
)

foreach ($file in ($classFiles + $privateFiles + $publicFiles)) {
    $filePath = Join-Path $script:ModuleRoot $file
    if (-not (Test-Path $filePath)) {
        Write-Warning "Module component not found: $file"
        continue
    }
    . $filePath
}

Initialize-ITFMModuleConfiguration
Initialize-ITFMDMLogging -Config $script:ModuleConfig -CorrelationId $script:CorrelationId

Export-ModuleMember -Function @(
    'Get-ITFMDMConfig'
    'Get-ITFMDMEnrollmentState'
    'Test-ITFMDMMigrationPrereqs'
    'Invoke-ITFMDMMigration'
    'Get-ITFMDMLogs'
)


