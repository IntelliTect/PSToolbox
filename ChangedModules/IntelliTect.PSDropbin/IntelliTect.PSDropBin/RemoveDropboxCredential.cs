using System;
using System.Management.Automation;
using IntelliTect.Security;

namespace IntelliTect.PSDropbin
{
    [Cmdlet( VerbsCommon.Remove, Noun )]
    public class RemoveDropboxCredential : PSCmdlet
    {
        private const string Noun = "DropboxCredential";

        [Parameter(Position = 0, Mandatory = true), Alias("DriveName", "Drive")]
        public string Name { get; set; }

        protected override void ProcessRecord()
        {
            try
            {
                string credentialName = DropboxDriveInfo.GetDropboxCredentialName(Name);
                bool result = CredentialManager.DeleteCredential(credentialName);
                WriteObject( result
                        ? "Credential removed. You may wish to also revoke access in your Dropbox user profile."
                        : "No credential found." );
            }
            catch ( Exception e )
            {
                WriteObject( "Error: " + e );
            }
        }
    }
}