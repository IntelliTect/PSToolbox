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
                string accessTokenName = DropboxDriveInfo.GetDropboxAccessTokenName(Name);
                bool accessTokenResult = CredentialManager.DeleteCredential(accessTokenName);
                string refreshTokenName = DropboxDriveInfo.GetDropboxRefreshTokenName(Name);
                bool refreshTokenResult = CredentialManager.DeleteCredential(refreshTokenName);
                WriteObject(accessTokenResult && refreshTokenResult
                        ? "Credentials removed. You may wish to also revoke access in your Dropbox user profile."
                        : "No credential found.");
                Settings.Default.Reset();
            }
            catch ( Exception e )
            {
                WriteObject( "Error: " + e );
            }
        }
    }
}