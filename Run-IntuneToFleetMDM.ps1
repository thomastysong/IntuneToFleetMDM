#Requires -Version 5.1
<#
.SYNOPSIS
  Bootstrapper: install/update IntuneToFleetMDM and run migration.
.DESCRIPTION
  - Prompts for UAC (admin) if needed
  - Installs/updates IntuneToFleetMDM from PowerShell Gallery
  - Runs Invoke-ITFMDMMigration (non-interactive)
.EXAMPLE
  irm https://raw.githubusercontent.com/thomastysong/IntuneToFleetMDM/main/Run-IntuneToFleetMDM.ps1 | iex
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$FleetHost,

  [Parameter()]
  [switch]$SkipUnenroll,

  [Parameter()]
  [switch]$EnrollOnly,

  [Parameter()]
  [switch]$UnenrollOnly,

  [Parameter()]
  [switch]$Force,

  [Parameter()]
  [switch]$NoElevate,

  [Parameter()]
  [string]$SelfUrl = 'https://raw.githubusercontent.com/thomastysong/IntuneToFleetMDM/main/Run-IntuneToFleetMDM.ps1'
)

function Test-IsAdmin {
  try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = [Security.Principal.WindowsPrincipal]::new($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

if (-not $NoElevate -and -not (Test-IsAdmin)) {
  Write-Host "Admin rights are required. A UAC prompt will appear..." -ForegroundColor Yellow
  $cmd = "irm '$SelfUrl' | iex"
  Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-Command", $cmd,
    "-FleetHost", $FleetHost
  ) | Out-Null
  return
}

try {
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
  try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue } catch {}
  try { Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue | Out-Null } catch {}

  if (-not (Get-Module -ListAvailable -Name IntuneToFleetMDM)) {
    Install-Module IntuneToFleetMDM -Force -AllowClobber -Scope AllUsers -ErrorAction Stop
  } else {
    try { Update-Module IntuneToFleetMDM -Force -ErrorAction Stop } catch { }
  }

  Import-Module IntuneToFleetMDM -Force -ErrorAction Stop

  $params = @{
    FleetHost = $FleetHost
  }
  if ($SkipUnenroll) { $params.SkipUnenroll = $true }
  if ($EnrollOnly) { $params.EnrollOnly = $true }
  if ($UnenrollOnly) { $params.UnenrollOnly = $true }
  if ($Force) { $params.Force = $true }

  Invoke-ITFMDMMigration @params
}
catch {
  Write-Host ("Failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
  throw
}


