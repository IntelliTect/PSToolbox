using System.Management.Automation;
using System.Net;
using IntelliTect.Security;
using Dropbox.Api;
using System.Management.Automation.Provider;

namespace IntelliTect.PSDropbin
{
    public class DropboxDriveInfo : PSDriveInfo
    {
        private const string DropboxCredentialNameBase = "DropboxUserToken";

        public static string GetDropboxCredentialName(string driveName)
        {
            return $"{DropboxCredentialNameBase}-{driveName}";
        }

        public DropboxDriveInfo(PSDriveInfo driveInfo) 
            : base(driveInfo)
        {
            string userToken;
            if (driveInfo.Credential?.Password == null)
            {
                string credentialName = GetDropboxCredentialName(driveInfo.Name);
                userToken = CredentialManager.ReadCredential(credentialName);
            }
            else
            {
                userToken = driveInfo.Credential.GetNetworkCredential().Password;
            }

            Client = new DropboxClient(userToken);
        }

        public DropboxClient Client { get; private set; }
    }
}