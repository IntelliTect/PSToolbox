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

        private static string GetDropboxCredentialName(string driveName)
        {
            return $"{DropboxCredentialNameBase}-{driveName}";
        }

        public static string GetDropboxAccessTokenName(string driveName)
        {
            return $"{GetDropboxCredentialName(driveName)}-AccessToken";
        }

        public static string GetDropboxRefreshTokenName(string driveName)
        {
            return $"{GetDropboxCredentialName(driveName)}-RefreshToken";
        }

        public DropboxDriveInfo(PSDriveInfo driveInfo) 
            : base(driveInfo)
        {
            string accessToken;
            if (driveInfo.Credential?.Password == null)
            {
                string credentialName = GetDropboxAccessTokenName(driveInfo.Name);
                accessToken = CredentialManager.ReadCredential(credentialName);
            }
            else
            {
                accessToken = driveInfo.Credential.GetNetworkCredential().Password;
            }

            string refreshToken = CredentialManager.ReadCredential(GetDropboxRefreshTokenName(driveInfo.Name));

            Client = new DropboxClient(accessToken, refreshToken, Settings.Default.AccessTokenExpiration, Settings.Default.ApiKey);
        }

        public DropboxClient Client { get; private set; }
    }
}