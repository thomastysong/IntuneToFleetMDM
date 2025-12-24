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
Test-ITFMDMMigrationPrereqs -FleetHost '<fleet-host>'

# Run full migration (SYSTEM/admin required)
Invoke-ITFMDMMigration -FleetHost '<fleet-host>'
```

## Slack notifications (optional)

If you pass `-SlackWebhook`, the module will send **standardized notifications** (best-effort):

- Started (after successful unenroll, before enroll)
- Success (after verification)
- Failure (on any error)
- PreflightFailed (on prereq failure before any enrollment changes are made)

Webhook values are treated as secrets and are **not logged**.

## Preflight + race condition handling

To reduce “unenroll then fail” outcomes and timing issues, `Invoke-ITFMDMMigration`:

- Runs **preflight checks before unenroll** (e.g., Orbit node key present, Fleet discovery URL reachable). If preflight fails, it aborts without calling Windows MDM unenroll/enroll APIs.
- Uses **polling with timeouts** (instead of fixed sleeps) to confirm:
  - Legacy MDM unenroll is reflected in OS state
  - Fleet OMADM account is provisioned and syncing

Examples:

```powershell
# Path-only form (recommended for readability)
Invoke-ITFMDMMigration -FleetHost '<fleet-host>' -SlackWebhook '<TEAM_ID>/<CHANNEL_ID>/<WEBHOOK_TOKEN>'

# Full URL form
Invoke-ITFMDMMigration -FleetHost '<fleet-host>' -SlackWebhook 'https://hooks.slack.com/services/<TEAM_ID>/<CHANNEL_ID>/<WEBHOOK_TOKEN>'
```

## Prerequisites

- Windows 10/11 **client** (Windows Server is not supported for Windows MDM enrollment)
- PowerShell 5.1+
- Must run as **SYSTEM** or **Administrator**
- **Orbit already installed** on the target device(s) (device is Fleet-enrolled but not MDM-enrolled)
  - The module reads the local Orbit node key from disk to build the programmatic enrollment token.
  - The node key is **never printed/logged**.
- Fleet server has **Windows MDM fully configured and enabled** (including WSTEP identity cert/key) and the device can reach:
  - `https://<fleet-host>/api/mdm/microsoft/discovery`

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
Invoke-ITFMDMMigration -FleetHost '<fleet-host>'
```

### Chef/Cinc (fallback/repair)

Use Chef as a repair lane (retry enroll-only, re-run verification, emit logs/markers) if enrollment is stuck or Fleet/Orbit is degraded.

```ruby
powershell_script 'mdm_migrate_intune_to_fleet' do
  code "Import-Module IntuneToFleetMDM; Invoke-ITFMDMMigration -FleetHost '<fleet-host>'"
end
```

## Safety notes

- Must run as **SYSTEM** or **Administrator**.
- Some environments behave better when executed from an **MTA** PowerShell host; this module can self-relaunch in MTA when needed.
- Enrollment return codes can be misleading; this module relies on **post-verification** to determine success (Enrollments + OMADM).

## Intune tenant considerations (common edge case)

If your tenant/device configuration enforces automatic MDM enrollment to Intune, devices may re-enroll back into Intune unless you **scope/disable that behavior for the migration cohort**. The recommended approach is cohort-by-cohort targeting (Entra groups/rings) for both unenroll and enroll phases.

## Logging

- **File logs**: `%ProgramData%\IntuneToFleetMDM\Logs\IntuneToFleetMDM_YYYYMMDD.log` (JSON lines, prefixed with `[IntuneToFleetMDM]`)
- **Event Viewer**:
  - Prefer: `Applications and Services Logs > IntuneToFleetMDM` (when admin can create source)
  - Fallback: `Windows Logs > Application` with Source `WSH`, filter messages containing `[IntuneToFleetMDM]`

## Notes on secrets

This module does **not** require Fleet API tokens or enrollment secrets.
It uses the **local Orbit node key** (already present on devices with Orbit installed) to build the programmatic enrollment token and does **not** print/log the key.

## Publishing

Publishing uses `Publish-Module` with the NuGet API key in:

- `$env:NUGET_API_KEY` (recommended)

See `scripts/Publish.ps1` and `.github/workflows/publish.yml`.


