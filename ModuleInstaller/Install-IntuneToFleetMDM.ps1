#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$AllUsers = $true
)

$ErrorActionPreference = 'Stop'

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue } catch {}
try { Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue | Out-Null } catch {}

$scope = if ($AllUsers) { 'AllUsers' } else { 'CurrentUser' }

if ($Force) {
    Install-Module IntuneToFleetMDM -Force -AllowClobber -Scope $scope -ErrorAction Stop
} else {
    if (-not (Get-Module -ListAvailable -Name IntuneToFleetMDM)) {
        Install-Module IntuneToFleetMDM -Force -AllowClobber -Scope $scope -ErrorAction Stop
    } else {
        try { Update-Module IntuneToFleetMDM -Force -ErrorAction Stop } catch { }
    }
}

Write-Host "Installed/updated IntuneToFleetMDM ($scope)." -ForegroundColor Green


