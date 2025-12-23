function Initialize-ITFMDMInterop {
    [CmdletBinding()]
    param()

    if ($script:ITFMDM_InteropInitialized) { return }

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ITFMDMRegistration {
  [DllImport("mdmregistration.dll", CharSet=CharSet.Unicode)]
  public static extern UInt32 RegisterDeviceWithManagement(string upn, string discoveryUrl, string accessToken);

  [DllImport("mdmregistration.dll", CharSet=CharSet.Unicode)]
  public static extern UInt32 UnregisterDeviceWithManagement(UInt32 reserved);
}
"@ -ErrorAction Stop

    $script:ITFMDM_InteropInitialized = $true
}


