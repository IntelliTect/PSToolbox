using System.Management.Automation;
using System.Net;
using DropNet;
using IntelliTect.Security;

namespace IntelliTect.PSDropbin
{
    public class DropboxDriveInfo : PSDriveInfo
    {
        private const string DropboxCredentialNameBase = "DropboxUserToken";

        public static string GetDropboxCredentialName(string driveName)
        {
            return $"{DropboxCredentialNameBase}-{driveName}";
        }

        public DropboxDriveInfo( PSDriveInfo driveInfo )
                : base( driveInfo )
        {
            NetworkCredential userToken;
            if ( driveInfo.Credential?.UserName == null ||
                 driveInfo.Credential.Password == null )
            {
                string credentialName = GetDropboxCredentialName(driveInfo.Name);
                userToken = CredentialManager.ReadCredential(credentialName);
            }
            else
            {
                userToken = new NetworkCredential(
                        driveInfo.Credential.UserName,
                        driveInfo.Credential.GetNetworkCredential().Password );
            }

            Client = new DropNetClient(
                    Settings.Default.ApiKey,
                    Settings.Default.AppSecret,
                    userToken.UserName,
                    userToken.Password );
        }

        public DropNetClient Client { get; private set; }
    }
}