using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Provider;
using System.Management.Automation.Runspaces;
using System.Net;
using System.Reflection;
using System.Security;
using System.Text.RegularExpressions;
using System.Threading;
using DropNet;
using DropNet.Exceptions;
using DropNet.Models;
using IntelliTect.Management.Automation;
using IntelliTect.Security;
using Newtonsoft.Json;

namespace IntelliTect.PSDropbin
{
    [CmdletProvider( ProviderName, ProviderCapabilities.Credentials | ProviderCapabilities.ExpandWildcards )]
    public class DropboxProvider : NavigationCmdletProvider
    {
        public DropboxProvider()
        {
            ProviderEventArgs<DropboxProvider>.PublishNewProviderInstance( this,
                    new ProviderEventArgs<DropboxProvider>( this ) );
        }

        #region Data

        private const string ProviderName = "Dropbox";

        private DropNetClient Client => ( (DropboxDriveInfo) PSDriveInfo ).Client;

        #endregion

        #region Drive Management

        protected override bool IsValidPath( string path )
        {
            return !string.IsNullOrEmpty( path ) && Path.GetInvalidPathChars().All( c => !path.Contains( c ) );
        }

        protected override PSDriveInfo RemoveDrive(PSDriveInfo drive)
        {
            if (drive == null)
            {
                throw new ArgumentNullException(nameof(drive));
            }

            return base.RemoveDrive(drive);
        }

        protected override PSDriveInfo NewDrive( PSDriveInfo drive)
        {
            if ( drive == null )
            {
                throw new ArgumentNullException( nameof( drive ) );
            }

            string credentialName = DropboxDriveInfo.GetDropboxCredentialName(drive.Name);

            // If the credential doesn't already exist, prompt for it.
            if (CredentialManager.ReadCredential(credentialName) == null)
            {
                WriteWarning($"Couldn't find Dropbox Credentials for drive {drive.Name}.");

                if (!PromptForCredential(drive))
                {
                    WriteWarning("Couldn't get Dropbox Credentials. Run New-PSDrive again when ready.");

                    return null;
                }
            }

            return new DropboxDriveInfo(drive);
        }

        private bool PromptForCredential(PSDriveInfo driveInfo)
        {
            var client = new DropNetClient(
                    Settings.Default.ApiKey,
                    Settings.Default.AppSecret);

            var token = client.GetToken();
            var url = client.BuildAuthorizeUrl();
            WriteObject("Opening URL: " + url);

            // open browser for authentication
            try
            {
                Process.Start(url);
            }
            catch (Exception)
            {
                WriteWarning("An unexpected error occured while opening the browser.");
            }

            WriteObject("Waiting for authentication...");

            // poll for authentication until it either occurs or you give up in frustration
            int counter = 15;
            while (counter > 0)
            {
                try
                {
                    // if we make it through this segment, a token is successfully generated and saved
                    var accessToken = client.GetAccessToken();
                    CredentialManager.WriteCredential(
                            DropboxDriveInfo.GetDropboxCredentialName(driveInfo.Name),
                            accessToken.Token,
                            accessToken.Secret);
                    break;
                }
                catch (Exception)
                {
                    Thread.Sleep(5000);
                    counter--;
                }
            }

            if (counter <= 0)
            {
                WriteWarning("Authentication failed.");
                return false;
            }
            else
            {
                WriteObject("Authentication successful. Run Remove-DropboxCredential to remove stored credentials.");
                return true;
            }
        }

        protected override Collection<PSDriveInfo> InitializeDefaultDrives()
        {
            Collection<PSDriveInfo> drives = base.InitializeDefaultDrives();

            // We used to always initialized a single, default drive here, and that's all this supported.
            // Now, we require the user to call New-PSDrive (alias mount, ndr) to add their drives.
            // Normal usage of this module would be to add calls to New-PSDrive to your powershell profile.

            // We will now use this method to remove the old credential which may still be stored on the system without the user's knowledge.
            CredentialManager.ReadCredential("DropboxUserToken");

            return drives;
        }

        #endregion

        #region Boolean Methods

        protected override bool ItemExists( string path )
        {
            WriteDebug( "Invoking ItemExists({0})", path );
            path = DropboxFileHelper.NormalizePath( path );

            if ( IsRoot( path ) )
            {
                return true;
            }

            return DropboxFileHelper.ItemExists( path, GetExistingChildItems );
        }

        protected override bool IsItemContainer( string path )
        {
            WriteDebug( "Invoking IsItemContainer({0})", path );
            path = DropboxFileHelper.NormalizePath( path );

            if ( IsRoot( path ) )
            {
                return true;
            }

            bool result = true;
            MetaData data = null;

            try
            {
                data = Client.GetMetaData( path );
            }
            catch ( DropboxException exception )
            {
                switch ( exception.StatusCode )
                {
                    case HttpStatusCode.NotFound:
                        result = false;
                        break;
                    default:
                        throw;
                }
            }
            return result && data.Is_Dir;
        }

        #endregion

        #region Item Methods

        protected override bool HasChildItems( string path )
        {
            WriteDebug( "Invoking HasChildItems({0})", path );

            bool hasChildItems = false;
            path = DropboxFileHelper.NormalizePath( path );

            Invoke( () =>
            {
                MetaData metaData = Client.GetMetaData( path );
                hasChildItems = metaData.Is_Dir && metaData.Contents != null && metaData.Contents.Count > 0;
            } );

            return hasChildItems;
        }

        protected override void GetChildItems( string path, bool recurse )
        {
            WriteDebug( "Invoking GetChildItems({0}, {1})", path, recurse );
            foreach ( MetaData item in GetExistingChildItems( path ).OrderBy( x => !x.Is_Dir ).ThenBy( x => x.Name ) )
            {
                WriteItemObject( item, item.Path, item.Is_Dir );
            }
        }

        protected override void GetItem( string path )
        {
            WriteDebug( "Invoking GetItem({0})", path );

            MetaData item = null;
            path = DropboxFileHelper.NormalizePath( path );
            Invoke( () => { item = Client.GetMetaData( path ); } );

            WriteItemObject( item, item.Path, item.Is_Dir );
        }


        protected override void CopyItem( string path, string copyPath, bool recurse )
        {
            WriteDebug( "Invoking CopyItem({0}, {1}, {2})", path, copyPath, recurse );

            path = DropboxFileHelper.NormalizePath( path );
            copyPath = DropboxFileHelper.NormalizePath( copyPath );
            MetaData result = Invoke( () => Client.Copy( path, copyPath ) );
            WriteItemObject( result, copyPath, IsItemContainer( copyPath ) );
        }

        protected override void MoveItem( string fromPath, string toPath )
        {
            WriteDebug( "Invoking MoveItem({0}, {1}, {2})", fromPath, toPath );

            fromPath = DropboxFileHelper.NormalizePath( fromPath );
            toPath = DropboxFileHelper.NormalizePath( toPath );
            MetaData result = Invoke( () => Client.Move( fromPath, toPath ) );
            WriteItemObject( result, toPath, IsItemContainer( toPath ) );
        }

        protected override void RemoveItem( string path, bool recurse )
        {
            WriteDebug( "Invoking RemoveItem({0}, {1})", path, recurse );

            MetaData result = null;
            path = DropboxFileHelper.NormalizePath( path );
            Invoke( () => result = Client.Delete( path ) );
            WriteItemObject( result, result.Path, result.Is_Dir );
        }

        protected override void NewItem( string path, string itemTypeName, object newItemValue )
        {
            UploadFile( path, itemTypeName, newItemValue );
        }

        private void UploadFile( string path,
                string itemTypeName,
                object newItemValue )
        {
            WriteDebug( "Invoking NewItem({0}, {1}, {2})", path, itemTypeName, newItemValue );
            path = DropboxFileHelper.NormalizePath( path );

            Action throwUnknownType = () => ThrowTerminatingError( new ArgumentException(
                    @"The type is not a known type for the file system. Only ""file"" and ""directory"" can be specified.",
                    nameof( itemTypeName ) ),
                    ErrorId.ItemTypeNotValid );

            if ( itemTypeName == null )
            {
                throwUnknownType();
            }

            // TODO: Verify that dropbox already checked the item doesn't exist and the path is valid.
            switch ( itemTypeName.ToLower() )
            {
                case "directory":
                    if ( ShouldProcess( path, $"New-Item: {itemTypeName}" ) )
                    {
                        Invoke( () =>
                        {
                            var result = Client.CreateFolder( path );
                            WriteItemObject( result, path, false );
                        } );
                    }
                    break;
                case "file":
                    if ( ShouldProcess( path, $"New-Item: {itemTypeName}" ) )
                    {
                        string localFilePath = Path.GetTempFileName();
                        try
                        {
                            Invoke( () =>
                            {
                                using ( FileStream stream = File.Open( localFilePath, FileMode.Open ) )
                                {
                                    Debug.Assert( stream != null, "stream != null" );
                                    var result = Client.UploadFile(
                                            Path.GetDirectoryName( path ),
                                            Path.GetFileName( path ),
                                            stream );
                                    WriteItemObject( result, path, false );
                                }
                            } );
                        }
                        finally
                        {
                            File.Delete( localFilePath );
                        }
                    }
                    break;
                default:
                    throwUnknownType();
                    break;
            }
        }

        #endregion

        #region Helper Methods 

        protected override string[] ExpandPath( string path )
        {
            var pathInfo = DropboxFileHelper.GetPathInfo( path );
            var items = GetExistingChildItems( pathInfo.Directory );

            if ( items == null )
            {
                return null;
            }

            var regexString = Regex.Escape( pathInfo.Name ).Replace( "\\*", ".*" );
            var regex = new Regex( "^" + regexString + "$", RegexOptions.IgnoreCase );

            var matchingItems = ( from item in items
                where regex.IsMatch( item.Name )
                select pathInfo.Directory + "/" + item.Name ).ToArray();

            return matchingItems.Any() ? matchingItems : null;
        }

        private IEnumerable<MetaData> GetExistingChildItems( string path )
        {
            path = DropboxFileHelper.NormalizePath( path );
            List<MetaData> results = null;
            Invoke( () => results = Client.GetMetaData( path ).Contents );
            return results?.Where( item => !item.Is_Deleted );
        }

        private void WriteDebug( string format, params object[] args )
        {
            // string message = string.Format( format, args );
            // base.WriteDebug( message );
        }

        private void WriteObject(string obj)
        {
            WriteWarning(obj);
        }

        private static bool IsRoot( string path )
        {
            return String.IsNullOrEmpty( path );
        }

        #endregion

        #region Error Handling

        private void ThrowTerminatingError( Exception exception,
                ErrorId errorId,
                ErrorCategory errorCategory,
                object targetObject = null )
        {
            ErrorRecord errorRecord = new ErrorRecord( exception, errorId.ToString(), errorCategory, targetObject );
            ThrowTerminatingError( errorRecord );
        }

        private void ThrowTerminatingError( ArgumentException exception, ErrorId errorId, object targetObject = null )
        {
            ErrorRecord errorRecord = new ErrorRecord( exception,
                    errorId.ToString(),
                    ErrorCategory.InvalidArgument,
                    targetObject );
            ThrowTerminatingError( errorRecord );
        }

        private void ThrowTerminatingError( DropboxException dropboxException, object targetObject = null )
        {
            // TODO: Map exception.StatusCode to ErrorCategories
            if ( dropboxException.Response != null )
            {
                try
                {
                    dynamic errorData = JsonConvert.DeserializeObject( dropboxException.Response.Content );
                    string message;
                    if ( errorData.error != null )
                    {
                        // TODO: Figure out how to discover the properties on a JSON object.
                        if ( errorData.Keys != null &&
                             errorData.error.path != null )
                        {
                            message = errorData.error.path.Value;
                        }
                        else
                        {
                            message = errorData.error.ToString();
                        }
                    }
                    else
                    {
                        message = dropboxException.Response.Content;
                    }
                    // Attempt to enhance the message.
                    FieldInfo fieldInfo = dropboxException.GetType().GetField(
                            "_message",
                            BindingFlags.NonPublic | BindingFlags.FlattenHierarchy | BindingFlags.Instance );

                    Debug.Assert( fieldInfo != null, "fieldInfo != null" );
                    fieldInfo.SetValue( dropboxException, message );
                }
                catch ( SecurityException )
                {
                    /*Ignore if unsuccessful */
                }
            }
            ErrorRecord errorRecord = new ErrorRecord( dropboxException,
                    dropboxException.StatusCode.ToString(),
                    ErrorCategory.InvalidOperation,
                    targetObject );
            ThrowTerminatingError( errorRecord );
        }

        protected void WriteError( Exception exception,
                string errorId,
                ErrorCategory category,
                object targetObject = null )
        {
            WriteError( new ErrorRecord( exception, errorId, category, "test" ) );
        }

        private enum ErrorId
        {
            NoDriveAssociatedWithProvider,
            PSDriveInfoCannotBeNull,
            ItemTypeNotValid
        }

        #endregion Error Handling

        #region Invocation

        private void Invoke( Action func )
        {
            Invoke( () =>
            {
                func();
                return true;
            } );
        }

        private T Invoke<T>( Func<T> func )
        {
            T result = default(T);

            if ( PSDriveInfo == null )
            {
                ThrowTerminatingError(
                        new InvalidOperationException( "There are currently no PSDrives created for this provider." ),
                        ErrorId.NoDriveAssociatedWithProvider,
                        ErrorCategory.InvalidOperation );
            }
            else
            {
                try
                {
                    result = func();
                }
                catch ( DropboxException exception )
                {
                    ThrowTerminatingError( exception );
                }
            }

            return result;
        }

        #endregion
    }
}