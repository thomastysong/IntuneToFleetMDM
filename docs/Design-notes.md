## Design notes (validated behavior)

### Why we do not “set Fleet URLs in the registry”
The correct approach is to call the supported Windows MDM registration APIs. Windows then creates the enrollment artifacts (including discovery URL and OMADM management address) under:

- `HKLM\SOFTWARE\Microsoft\Enrollments\{GUID}`
- `HKLM\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\{GUID}`

### Where Windows stores the management address
We observed the Fleet management endpoint at:

- `HKLM\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\{EnrollmentId}\Protected\AddrInfo\Addr`

and sync health at:

- `HKLM\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\{EnrollmentId}\Protected\ConnInfo\LastSessionResult`

### Non-zero HRESULT can still be “success”
`RegisterDeviceWithManagement` can return a non-zero HRESULT even when the enrollment is created and syncing. The module treats enrollment as successful when verification succeeds (Enrollments + OMADM).


