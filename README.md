# IntuneToFleetMDM

PowerShell module to migrate Windows devices from **Intune MDM → Fleet Windows MDM** using **supported Windows MDM registration APIs** (mdmregistration.dll) with **strong verification** and **Event Log + file logging**.

This module is intended to be delivered cohort-by-cohort via **Intune** (primary), **Chef/Cinc** (fallback/repair), or any orchestration system.

## What it does (validated in testing)

- **Unenroll Intune MDM**: calls `UnregisterDeviceWithManagement(0)` (mdmregistration.dll)
- **Enroll Fleet Windows MDM**: calls `RegisterDeviceWithManagement("", "https://<fleet-host>/api/mdm/microsoft/discovery", <token>)`
  - Token is a JSON payload backed by the **local Orbit node key**
- **Verify success** using OS state (not just return codes):
  - `HKLM\SOFTWARE\Microsoft\Enrollments\*` (`ProviderID=Fleet`, `DiscoveryServiceFullURL=.../api/mdm/microsoft/discovery`)
  - `HKLM\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\{EnrollmentID}\...` (management `Addr`, `LastSessionResult=0`)

## Installation

From PowerShell Gallery:

```powershell
Install-Module -Name IntuneToFleetMDM -Scope AllUsers
```

## Quick start

```powershell
Import-Module IntuneToFleetMDM

# Dry-run prereqs (recommended)
Test-ITFMDMMigrationPrereqs -FleetHost 'nv.cloud.fleetdm.com'

# Run full migration (SYSTEM/admin required)
Invoke-ITFMDMMigration -FleetHost 'nv.cloud.fleetdm.com'
```

## Orchestrator examples

### Intune Proactive Remediation (SYSTEM)

- **Detection** (example): fail if not Fleet-enrolled

```powershell
Import-Module IntuneToFleetMDM
$s = Get-ITFMDMEnrollmentState
if ($s.Detected -eq 'Fleet') { exit 0 } else { exit 1 }
```

- **Remediation** (example): cohort migration

```powershell
Import-Module IntuneToFleetMDM
Invoke-ITFMDMMigration -FleetHost 'nv.cloud.fleetdm.com'
```

### Chef/Cinc (fallback/repair)

Use Chef as a repair lane (retry enroll-only, re-run verification, emit logs/markers) if enrollment is stuck or Fleet/Orbit is degraded.

```ruby
powershell_script 'mdm_migrate_intune_to_fleet' do
  code "Import-Module IntuneToFleetMDM; Invoke-ITFMDMMigration -FleetHost 'nv.cloud.fleetdm.com'"
end
```

## Safety notes

- Must run as **SYSTEM** or **Administrator**.
- Some environments behave better when executed from an **MTA** PowerShell host; this module can self-relaunch in MTA when needed.
- Enrollment return codes can be misleading; this module relies on **post-verification** to determine success (Enrollments + OMADM).

## Logging

- **File logs**: `%ProgramData%\IntuneToFleetMDM\Logs\IntuneToFleetMDM_YYYYMMDD.log` (JSON lines, prefixed with `[IntuneToFleetMDM]`)\n
- **Event Viewer**:\n
  - Prefer: `Applications and Services Logs > IntuneToFleetMDM` (when admin can create source)\n
  - Fallback: `Windows Logs > Application` with Source `WSH`, filter messages containing `[IntuneToFleetMDM]`\n

## Publishing

Publishing uses `Publish-Module` with the NuGet API key in:

- `$env:NUGET_API_KEY` (recommended)

See `scripts/Publish.ps1` and `.github/workflows/publish.yml`.


