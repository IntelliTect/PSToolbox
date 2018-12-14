Set-StrictMode -Version "Latest"

function Set-CredentialManagerCredential {
    <#
        .SYNOPSIS
        Sets a PowerShell Credential (PSCredential) from the Windows Credential Manager

        .DESCRIPTION
        Adapted from: http://social.technet.microsoft.com/Forums/scriptcenter/en-US/e91769eb-dbce-4e77-8b61-d3e55690b511/addedit-saved-password-in-credential-manager-windows-7?forum=ITCG

        .PARAMETER TargetName
        The name of the target login informations in the Windows Credential Manager

        .PARAMETER $Credential
        The credentials to be stored in Windows Credential Manager

        .EXAMPLE
        .\Set-Credential TargetName (Get-Credential)

        .LINK
        Get-Credential
    #>
    [CmdletBinding(DefaultParametersetName="SplitCredentialValues")] 
    param(
        [Parameter(Mandatory=$true, Position=0)]
            [string]$TargetName
        ,[Parameter(ParameterSetName="PSCredentialObject", Position=1)]
            [PSCredential]$credential = $null # Removed Get-Credential default value because otherwise you get prompted even when using the SplitCredentialValues parameter set.
        ,[Parameter(ParameterSetName="SplitCredentialValues", Mandatory=$true, Position=1)]
            [string]$userName
    )

    if (-not $IsWindows){
        throw "This cmdlet is not supported on non-Windows operating systems."
    }

    switch ($PsCmdlet.ParameterSetName) 
    { 
        "PSCredentialObject"  { 
            if($credential -eq $null) {
                $credential = Get-Credential;
            }
            break;
        } 
        "SplitCredentialValues"  {
            $password = (Read-Host -AsSecureString -Prompt "Enter the password")

            $credential=new-object -typename System.Management.Automation.PSCredential $userName,$password; 
            break;
        } 
    } 

    $output = cmdkey /generic:$TargetName /user:$($credential.UserName) /pass:$($credential.GetNetworkCredential().password)

    if("$output".Trim() -notlike "*successfully*") {
        throw $output;
    }

    Return;

    #TODO: Switch to native PowerShell
    $sig = @"
    [DllImport("Advapi32.dll", SetLastError=true, EntryPoint="CredWriteW", CharSet=CharSet.Unicode)]
    public static extern bool CredWrite([In] ref Credential userCredential, [In] UInt32 flags);

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct Credential
    {
       public UInt32 flags;
       public UInt32 type;
       public IntPtr targetName;
       public IntPtr comment;
       public System.Runtime.InteropServices.ComTypes.FILETIME lastWritten;
       public UInt32 credentialBlobSize;
       public IntPtr credentialBlob;
       public UInt32 persist;
       public UInt32 attributeCount;
       public IntPtr Attributes;
       public IntPtr targetAlias;
       public IntPtr userName;
    }

"@
    Add-Type -MemberDefinition $sig -Namespace "ADVAPI32" -Name 'Util'

    $cred = New-Object ADVAPI32.Util+Credential
    $cred.flags = 0
    $cred.type = 2
    $cred.targetName = [System.Runtime.InteropServices.Marshal]::StringToCoTaskMemUni('server2')
    $cred.userName = [System.Runtime.InteropServices.Marshal]::StringToCoTaskMemUni('home\tome')
    $cred.attributeCount = 0
    $cred.persist = 2
    $password = "password"
    $cred.credentialBlobSize = [System.Text.Encoding]::Unicode.GetBytes($password).length
    $cred.credentialBlob = [System.Runtime.InteropServices.Marshal]::StringToCoTaskMemUni($password)
    [ADVAPI32.Util]::CredWrite([ref]$cred,0)
}


function Get-CredentialManagerCredential {
    <#
        .SYNOPSIS
        Gets a PowerShell Credential (PSCredential) from the Windows Credential Manager

        .DESCRIPTION
        Adapted from: http://stackoverflow.com/questions/7162604/get-cached-credentials-in-powershell-from-windows-7-credential-manager

        .PARAMETER TargetName
        The name of the target login informations in the Windows Credential Manager

        .EXAMPLE
        .\Get-CredentialFromWindowsCredentialManager.ps1 tfs.codeplex.com

        UserName                             Password
        --------                             --------
        codeplexuser                         System.Security.SecureString

        .LINK
        Get-Credential
    #>

    # We have to supress this warning because we are taking the 
    # credential directly from native code - we have no choice but to use ConvertTo-SecureString
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$TargetName)
    
    if (-not $IsWindows){
        throw "This cmdlet is not supported on non-Windows operating systems."
    }

    $sig = @"

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct NativeCredential
    {
        public UInt32 Flags;
        public CRED_TYPE Type;
        public IntPtr TargetName;
        public IntPtr Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize;
        public IntPtr CredentialBlob;
        public UInt32 Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        public IntPtr TargetAlias;
        public IntPtr UserName;

        internal static NativeCredential GetNativeCredential(Credential cred)
        {
            NativeCredential ncred = new NativeCredential();
            ncred.AttributeCount = 0;
            ncred.Attributes = IntPtr.Zero;
            ncred.Comment = IntPtr.Zero;
            ncred.TargetAlias = IntPtr.Zero;
            ncred.Type = CRED_TYPE.GENERIC;
            ncred.Persist = (UInt32)1;
            ncred.CredentialBlobSize = (UInt32)cred.CredentialBlobSize;
            ncred.TargetName = Marshal.StringToCoTaskMemUni(cred.TargetName);
            ncred.CredentialBlob = Marshal.StringToCoTaskMemUni(cred.CredentialBlob);
            ncred.UserName = Marshal.StringToCoTaskMemUni(System.Environment.UserName);
            return ncred;
        }
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct Credential
    {
        public UInt32 Flags;
        public CRED_TYPE Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize;
        public string CredentialBlob;
        public UInt32 Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    public enum CRED_TYPE : uint
        {
            GENERIC = 1,
            DOMAIN_PASSWORD = 2,
            DOMAIN_CERTIFICATE = 3,
            DOMAIN_VISIBLE_PASSWORD = 4,
            GENERIC_CERTIFICATE = 5,
            DOMAIN_EXTENDED = 6,
            MAXIMUM = 7,      // Maximum supported cred type
            MAXIMUM_EX = (MAXIMUM + 1000),  // Allow new applications to run on old OSes
        }

    public class CriticalCredentialHandle : Microsoft.Win32.SafeHandles.CriticalHandleZeroOrMinusOneIsInvalid
    {
        public CriticalCredentialHandle(IntPtr preexistingHandle)
        {
            SetHandle(preexistingHandle);
        }

        public Credential GetCredential()
        {
            if (!IsInvalid)
            {
                NativeCredential ncred = (NativeCredential)Marshal.PtrToStructure(handle,
                      typeof(NativeCredential));
                Credential cred = new Credential();
                cred.CredentialBlobSize = ncred.CredentialBlobSize;
                cred.CredentialBlob = Marshal.PtrToStringUni(ncred.CredentialBlob,
                      (int)ncred.CredentialBlobSize / 2);
                cred.UserName = Marshal.PtrToStringUni(ncred.UserName);
                cred.TargetName = Marshal.PtrToStringUni(ncred.TargetName);
                cred.TargetAlias = Marshal.PtrToStringUni(ncred.TargetAlias);
                cred.Type = ncred.Type;
                cred.Flags = ncred.Flags;
                cred.Persist = ncred.Persist;
                return cred;
            }
            else
            {
                throw new InvalidOperationException("Invalid CriticalHandle!");
            }
        }

        override protected bool ReleaseHandle()
        {
            if (!IsInvalid)
            {
                CredFree(handle);
                SetHandleAsInvalid();
                return true;
            }
            return false;
        }
    }

    [DllImport("Advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredRead(string target, CRED_TYPE type, int reservedFlag, out IntPtr CredentialPtr);

    [DllImport("Advapi32.dll", EntryPoint = "CredFree", SetLastError = true)]
    public static extern bool CredFree([In] IntPtr cred);


"@
    Add-Type -MemberDefinition $sig -Namespace "ADVAPI32" -Name 'Util'

    $nCredPtr= New-Object IntPtr

    $success = [ADVAPI32.Util]::CredRead($TargetName,1,0,[ref] $nCredPtr)

    if ($success) {
        $critCred = New-Object ADVAPI32.Util+CriticalCredentialHandle $nCredPtr
        $cred = $critCred.GetCredential()
        $username = $cred.UserName
        $securePassword = $cred.CredentialBlob | ConvertTo-SecureString -AsPlainText -Force
        $cred.CredentialBlob = ""
        $cred = $null
        return new-object System.Management.Automation.PSCredential $username, $securePassword
    } else {
        #TODO: Determine if it is better to Error or return $null?
        Write-Error "No credentials were found in Windows Credential Manager for TargetName: $TargetName"
    }

}

Function Get-CredentialPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCredential]$credential
    )

    return $credential.GetNetworkCredential().password
}