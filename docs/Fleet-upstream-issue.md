## Proposal: add first-class Orbit CLI for Windows MDM unenroll/enroll (Intune → Fleet)

### Summary
We validated a reliable Windows MDM migration flow using **supported Windows APIs** (mdmregistration.dll):

- `UnregisterDeviceWithManagement(0)` to remove current MDM (Intune)
- `RegisterDeviceWithManagement("", "<fleet>/api/mdm/microsoft/discovery", <programmatic token>)` to enroll into Fleet Windows MDM

Even when `RegisterDeviceWithManagement` returns a non-zero HRESULT in some cases, the device can still be fully enrolled and syncing; therefore success must be determined by **post-verification** (Enrollments + OMADM), not only return codes.

### Why Orbit should expose this
Orbit already performs programmatic enrollment as part of Fleet orchestration (Windows MDM discovery endpoint + programmatic enrollment payload containing Orbit node key). Exposing a supported CLI would:

- Give admins a safe, supported tool to **migrate cohort-by-cohort** without manual UI clicking
- Provide standardized **verification** and **logging**
- Reduce the need for one-off wrappers in enterprises

### Suggested commands
- `orbit windows mdm unenroll` (calls `UnregisterDeviceWithManagement(0)`)\n
- `orbit windows mdm enroll --discovery-url https://<fleet>/api/mdm/microsoft/discovery` (calls `RegisterDeviceWithManagement`)\n
- `orbit windows mdm status` (reads Enrollments + OMADM state)

### Verification logic (must-have)
Treat enrollment as successful if OS state indicates Fleet is provisioned and syncing:

- `HKLM\SOFTWARE\Microsoft\Enrollments\*\ProviderID == Fleet`
- `HKLM\SOFTWARE\Microsoft\Enrollments\*\DiscoveryServiceFullURL == https://<fleet>/api/mdm/microsoft/discovery`
- `HKLM\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\{id}\Protected\AddrInfo\Addr == https://<fleet>/api/mdm/microsoft/management`
- `HKLM\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\{id}\Protected\ConnInfo\LastSessionResult == 0`

### Relevant upstream code references
- Fleet server discovery/MDM endpoints and enrollment gating:
  - `server/service/orbit.go`
  - `server/service/microsoft_mdm.go`
  - `server/mdm/microsoft/microsoft_mdm.go`
- Existing Windows enrollment tooling (if still applicable):
  - `tools/windows-mdm-enroll/main.go`
- Orbit update/orchestration (where programmatic enrollment is triggered by notifications):
  - `orbit/pkg/update/...` (Windows MDM enrollment path uses mdmregistration.dll)

### Suggested logging
- Emit structured events (Info/Warn/Error) and include the HRESULT plus verification details.
- Log the discovery URL and the enrollment ID found in registry. Never log secrets (node key).


