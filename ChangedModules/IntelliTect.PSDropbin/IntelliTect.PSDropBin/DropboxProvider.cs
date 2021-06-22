using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Provider;
using System.Net;
using System.Reflection;
using System.Security;
using System.Text.RegularExpressions;
using IntelliTect.Management.Automation;
using IntelliTect.Security;
using Newtonsoft.Json;
using Dropbox.Api.Files;
using Dropbox.Api;
using System.Threading;

namespace IntelliTect.PSDropbin
{
    [CmdletProvider(_providerName, ProviderCapabilities.Credentials | ProviderCapabilities.ExpandWildcards)]
    public class DropboxProvider : NavigationCmdletProvider
    {
        public DropboxProvider()
        {
            ProviderEventArgs<DropboxProvider>.PublishNewProviderInstance(this,
                    new ProviderEventArgs<DropboxProvider>(this));

            DropboxFileHelper.Writer = Warn;
        }

        #region Data
        private const string _providerName = "Dropbox";

        private DropboxClient _client => ((DropboxDriveInfo)PSDriveInfo).Client;
        #endregion

        #region Drive Management

        protected override bool IsValidPath(string path)
        {
            WriteDebugMessage("Invoking IsValidPath({0})", path);

            return !string.IsNullOrEmpty(path) && Path.GetInvalidPathChars().All(c => !path.Contains(c));
        }

        protected override PSDriveInfo RemoveDrive(PSDriveInfo drive)
        {
            if (drive == null)
            {
                throw new ArgumentNullException(nameof(drive));
            }

            return base.RemoveDrive(drive);
        }

        protected override PSDriveInfo NewDrive(PSDriveInfo drive)
        {
            WriteDebugMessage("Invoking NewDrive({0}) ... {0}", drive.DisplayRoot);

            if (drive == null)
            {
                throw new ArgumentNullException(nameof(drive));
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
            Uri authUri = DropboxOAuth2Helper.GetAuthorizeUri(Settings.Default.ApiKey);

            Warn("Opening URL: " + authUri);

            // open browser for authentication
            try
            {
                Process.Start(authUri.ToString());
            }
            catch (Exception)
            {
                WriteWarning("An unexpected error occured while opening the browser.");
            }

            Warn("Waiting for authentication...");

            Host.UI.WriteLine("Please enter your authorization code provided by DropBox");
            Host.UI.Write(">>> ");
            var authCode = Host.UI.ReadLine();

            OAuth2Response response = null;
            try
            {
                response = DropboxOAuth2Helper.ProcessCodeFlowAsync(authCode, Settings.Default.ApiKey, Settings.Default.AppSecret).Result;
            }
            catch (OAuth2Exception)
            {
                Warn("Authentication failed.");
                return false;
            }

            CredentialManager.WriteCredential(
                DropboxDriveInfo.GetDropboxCredentialName(driveInfo.Name),
                response.AccessToken
            );

            Warn("Authentication successful. Run Remove-DropboxCredential to remove stored credentials.");
            return true;
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

        protected override bool ItemExists(string path)
        {
            var normalizedPath = DropboxFileHelper.NormalizePath(path);
            WriteDebugMessage("Invoking ItemExists({0})", normalizedPath);

            return Invoke(() =>
            {
                if (IsRoot(normalizedPath)) return true;

                if (normalizedPath.EndsWith("*")) return false;

                return DropboxFileHelper.GetItem(normalizedPath, _client) != null;
            });
        }

        protected override bool IsItemContainer(string path)
        {
            var normalizedPath = DropboxFileHelper.NormalizePath(path);
            WriteDebugMessage("Invoking IsItemContainer({0})", normalizedPath);

            return Invoke(() =>
            {
                if (IsRoot(normalizedPath))
                {
                    return true;
                }

                var item = DropboxFileHelper.GetItem(normalizedPath, _client);

                return item != null && item.IsFolder;                
            });
        }
        #endregion

        #region Item Methods
        protected override bool HasChildItems(string path)
        {
            var normalizedPath = DropboxFileHelper.NormalizePath(path);
            WriteDebugMessage("Invoking HasChildItems({0})", normalizedPath);

            return Invoke(() =>
            {
                var item = DropboxFileHelper.GetItem(normalizedPath, _client);
                if (item != null && item.IsFolder)
                {
                    var children = DropboxFileHelper.GetChildItems(normalizedPath, _client);
                    return children != null && children.Count() > 0;
                }
                return false;
            });
        }

        protected override void GetChildItems(string path, bool recurse)
        {
            var normalizedPath = DropboxFileHelper.NormalizePath(path);
            WriteDebugMessage("Invoking GetChildItems({0}, {1})", normalizedPath, recurse);

            List<MetaData> childItems = Invoke(() =>
            {
                Func<string, List<MetaData>> getChildren = null;
                getChildren = p =>
                {
                    var currentLevelItems = DropboxFileHelper.GetChildItems(p, _client);
                    if (recurse)
                    {
                        var currentLevelCount = currentLevelItems.Count();
                        for (var idx = 0; idx < currentLevelCount; idx++)
                        {
                            currentLevelItems.AddRange(getChildren(DropboxFileHelper.NormalizePath(currentLevelItems[idx].Path)));
                        }
                    }

                    return currentLevelItems;
                };
                return getChildren(normalizedPath);
            });

            childItems.OrderBy(item => !item.IsFolder).ThenBy(item => item.Name).ToList().ForEach(item => WriteMetaData(item));
        }

        protected override void GetItem(string path)
        {
            var normalizedPath = DropboxFileHelper.NormalizePath(path);
            WriteDebugMessage("Invoking GetItem({0})", normalizedPath);

            if (string.IsNullOrEmpty(normalizedPath)) return;

            MetaData item = Invoke(() => 
            {
                return DropboxFileHelper.GetItem(normalizedPath, _client);
            });

            WriteMetaData(item);
        }


        protected override void CopyItem(string path, string copyPath, bool recurse)
        {
            DropboxFileHelper.ResetCache();

            var normalizedPath = DropboxFileHelper.NormalizePath(path);
            var normalizedCopyPath = DropboxFileHelper.NormalizePath(copyPath);
            WriteDebugMessage("Invoking CopyItem({0}, {1}, {2})", normalizedPath, normalizedCopyPath, recurse);

            MetaData result = Invoke(() =>
            {
                return new MetaData(_client.Files.CopyAsync(normalizedPath, normalizedCopyPath).Result);
            });

            WriteMetaData(result, normalizedCopyPath, IsItemContainer(copyPath));
        }

        protected override void MoveItem(string fromPath, string toPath)
        {
            DropboxFileHelper.ResetCache();

            var normalizedFromPath = DropboxFileHelper.NormalizePath(fromPath);
            var normalizedToPath = DropboxFileHelper.NormalizePath(toPath);
            WriteDebugMessage("Invoking MoveItem({0}, {1})", normalizedFromPath, normalizedToPath);

            MetaData result = Invoke(() =>
            {
                return new MetaData(_client.Files.MoveAsync(normalizedFromPath, normalizedToPath).Result);
            });

            WriteMetaData(result, normalizedToPath, IsItemContainer(toPath));
        }

        protected override void RemoveItem(string path, bool recurse)
        {
            DropboxFileHelper.ResetCache();

            var normalizedPath = DropboxFileHelper.NormalizePath(path);
            WriteDebugMessage("Invoking RemoveItem({0}, {1})", normalizedPath, recurse);

            MetaData result = Invoke(() =>
            {
                return new MetaData(_client.Files.DeleteAsync(normalizedPath).Result);
            });

            WriteMetaData(result);
        }

        protected override void NewItem(string path, string itemTypeName, object newItemValue)
        {
            UploadFile(path, itemTypeName, newItemValue);
        }

        private void UploadFile(string path, string itemTypeName, object newItemValue)
        {
            DropboxFileHelper.ResetCache();

            var normalizedPath = DropboxFileHelper.NormalizePath(path);
            WriteDebugMessage("Invoking NewItem({0}, {1}, {2})", normalizedPath, itemTypeName, newItemValue);

            Action throwUnknownType = () => ThrowTerminatingError(new ArgumentException(
                    @"The type is not a known type for the file system. Only ""file"" and ""directory"" can be specified.",
                    nameof(itemTypeName)),
                    ErrorId.ItemTypeNotValid);

            if (itemTypeName == null)
            {
                throwUnknownType();
            }

            // TODO: Verify that dropbox already checked the item doesn't exist and the path is valid.
            switch (itemTypeName.ToLower())
            {
                case "directory":
                    if (ShouldProcess(normalizedPath, $"New-Item: {itemTypeName}"))
                    {
                        Invoke(() =>
                       {
                           var result = new MetaData(_client.Files.CreateFolderAsync(normalizedPath).Result);
                           WriteMetaData(result, normalizedPath, false);
                       });
                    }
                    break;
                case "file":
                    if (ShouldProcess(normalizedPath, $"New-Item: {itemTypeName}"))
                    {
                        string localFilePath = Path.GetTempFileName();
                        try
                        {
                            Invoke(() =>
                           {
                               using (FileStream stream = File.Open(localFilePath, FileMode.Open))
                               {
                                   Debug.Assert(stream != null, "stream != null");
                                   CommitInfo info = new CommitInfo(normalizedPath, WriteMode.Add.Instance, true);
                                   var result = new MetaData(_client.Files.UploadAsync(info, stream).Result);
                                   WriteMetaData(result, normalizedPath, false);
                               }
                           });
                        }
                        finally
                        {
                            File.Delete(localFilePath);
                        }
                    }
                    break;
                default:
                    throwUnknownType();
                    break;
            }
        }

        protected override string[] ExpandPath(string path)
        {
            var normalizedPath = DropboxFileHelper.NormalizePath(path);
            var pathParts = DropboxFileHelper.GetPathInfo(normalizedPath);

            var childItems = DropboxFileHelper.GetChildItems(pathParts.Item1, _client);
            if (childItems == null || childItems.Count() == 0)
            {
                return null;
            }

            var regexString = Regex.Escape(pathParts.Item2).Replace("\\*", ".*");
            var regex = new Regex("^" + regexString + "$", RegexOptions.IgnoreCase);

            var matchingItems = (from item in childItems
                                 where regex.IsMatch(item.Name)
                                 select pathParts.Item1 + "/" + item.Name).ToList();

            return matchingItems.Any() ? matchingItems.ToArray() : null;
        }
        #endregion

        #region Helper Methods 

        private void WriteMetaData(MetaData metaData)
        {
            WriteMetaData(metaData, metaData.Path, metaData.IsFolder);
        }

        private void WriteMetaData(MetaData metaData, string path, bool isFolder)
        {
            WriteItemObject(metaData, path, isFolder);
        }

        private void WriteDebugMessage(string format, params object[] args)
        {
            string message = string.Format(format, args);
            Warn(message);
        }

        private void Warn(string obj)
        {
            //WriteWarning(obj);
        }

        private static bool IsRoot(string path)
        {
            return String.IsNullOrEmpty(path);
        }

        #endregion

        #region Error Handling

        private void ThrowTerminatingError(Exception exception,
                ErrorId errorId,
                ErrorCategory errorCategory,
                object targetObject = null)
        {
            ErrorRecord errorRecord = new ErrorRecord(exception, errorId.ToString(), errorCategory, targetObject);
            ThrowTerminatingError(errorRecord);
        }

        private void ThrowTerminatingError(ArgumentException exception, ErrorId errorId, object targetObject = null)
        {
            ErrorRecord errorRecord = new ErrorRecord(exception,
                    errorId.ToString(),
                    ErrorCategory.InvalidArgument,
                    targetObject);
            ThrowTerminatingError(errorRecord);
        }

        protected void ThrowTerminatingError(Exception exception)
        {
            ThrowTerminatingError(new ErrorRecord(exception, null, ErrorCategory.FromStdErr, null));
        }

        private enum ErrorId
        {
            NoDriveAssociatedWithProvider,
            PSDriveInfoCannotBeNull,
            ItemTypeNotValid
        }

        #endregion Error Handling

        #region Invocation

        private void Invoke(Action func)
        {
            Invoke(() =>
            {
                func();
                return true;
            });
        }

        private T Invoke<T>(Func<T> func)
        {
            T result = default(T);

            if (PSDriveInfo == null)
            {
                ThrowTerminatingError(
                        new InvalidOperationException("There are currently no PSDrives created for this provider."),
                        ErrorId.NoDriveAssociatedWithProvider,
                        ErrorCategory.InvalidOperation);
            }
            else
            {
                try
                {
                    result = func();
                }
                catch (Exception exception)
                {
                    ThrowTerminatingError(exception);
                }
            }

            return result;
        }

        #endregion
    }
}
