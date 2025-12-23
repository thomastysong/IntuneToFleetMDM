#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ApiKey = $env:NUGET_API_KEY,

    [Parameter()]
    [string]$Repository = 'PSGallery'
)

$ErrorActionPreference = 'Stop'

if (-not $ApiKey) {
    throw 'Missing API key. Set $env:NUGET_API_KEY or pass -ApiKey.'
}

$moduleRoot = Join-Path $PSScriptRoot '..\IntuneToFleetMDM'
$manifest = Join-Path $moduleRoot 'IntuneToFleetMDM.psd1'

if (-not (Test-Path $manifest)) {
    throw "Manifest not found: $manifest"
}

Publish-Module -Path $moduleRoot -NuGetApiKey $ApiKey -Repository $Repository -Verbose


