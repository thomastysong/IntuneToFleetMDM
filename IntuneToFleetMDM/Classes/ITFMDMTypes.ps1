class ITFMDMEnrollmentEntry {
    [string]$EnrollmentId
    [string]$ProviderId
    [Nullable[int]]$EnrollmentState
    [string]$DiscoveryServiceFullURL
}

class ITFOMADMConnInfo {
    [string]$EnrollmentId
    [string]$Addr
    [Nullable[int]]$LastSessionResult
    [Nullable[datetime]]$ServerLastSuccessTime
    [Nullable[datetime]]$ServerLastAccessTime
}

class ITFMDMEnrollmentState {
    [string]$ComputerName
    [string]$InstallationType
    [string]$Detected
    [ITFMDMEnrollmentEntry[]]$Enrollments
    [ITFOMADMConnInfo[]]$OMADM
}

class ITFMDMMigrationResult {
    [string]$Status
    [string]$FleetHost
    [string]$DiscoveryUrl
    [string]$EnrollmentId
    [Nullable[uint32]]$UnenrollHResult
    [Nullable[uint32]]$EnrollHResult
    [string]$CorrelationId
}


