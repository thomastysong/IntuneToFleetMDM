@{
    RootModule        = 'IntuneToFleetMDM.psm1'
    ModuleVersion     = '0.3.0'
    GUID              = '7fdf3f2a-5b6f-4d5b-9bb4-4d1f8b0a5e4a'
    Author            = 'Thomas Tyson'
    CompanyName       = 'Community'
    Copyright         = '(c) 2025 Thomas Tyson. MIT License.'
    Description       = 'Migrate Windows devices from Intune MDM to Fleet Windows MDM using supported Windows MDM registration APIs, with strong verification and event/file logging.'

    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Get-ITFMDMConfig'
        'Get-ITFMDMEnrollmentState'
        'Test-ITFMDMMigrationPrereqs'
        'Invoke-ITFMDMMigration'
        'Get-ITFMDMLogs'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags       = @('FleetDM','Intune','MDM','Windows','Enrollment','Migration','Orbit')
            LicenseUri = 'https://github.com/thomastysong/IntuneToFleetMDM/blob/main/LICENSE'
            ProjectUri = 'https://github.com/thomastysong/IntuneToFleetMDM'
        }

        ModuleConfig = @{
            LogPath          = '%ProgramData%\IntuneToFleetMDM\Logs'
            EventLogName     = 'IntuneToFleetMDM'
            EventLogSource   = 'IntuneToFleetMDM'
            StateRegistryKey = 'HKLM:\SOFTWARE\IntuneToFleetMDM\Migration'
        }
    }
}


