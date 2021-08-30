using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Provider;
using System.Text.RegularExpressions;
using IntelliTect.Management.Automation;
using IntelliTect.Security;
using Dropbox.Api.Files;
using Dropbox.Api;
using System.Runtime.ExceptionServices;

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
            if (drive == null)
            {
                throw new ArgumentNullException(nameof(drive));
            }

            WriteDebugMessage("Invoking NewDrive({0}) ... {0}", drive.DisplayRoot);

            PKCEHelper helper = new PKCEHelper();
            string accessToken = string.Empty;
            try
            {
                accessToken = helper.GetOAuthTokensAsync(null, IncludeGrantedScopes.None).Result;
            }
            catch (AggregateException exception)
            {
                exception = exception.Flatten();
                ExceptionDispatchInfo.Capture(
                exception.InnerException).Throw();
            }
            if (string.IsNullOrEmpty(accessToken))
            {
                return null;
            }

            CredentialManager.WriteCredential(
                DropboxDriveInfo.GetDropboxCredentialName(drive.Name),
                accessToken
            );

            return new DropboxDriveInfo(drive);
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
                return new MetaData(_client.Files.CopyV2Async(normalizedPath, normalizedCopyPath).Result.Metadata);
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
                return new MetaData(_client.Files.MoveV2Async(normalizedFromPath, normalizedToPath).Result.Metadata);
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
                return new MetaData(_client.Files.DeleteV2Async(normalizedPath).Result.Metadata);
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
                           var result = new MetaData(_client.Files.CreateFolderV2Async(normalizedPath).Result.Metadata);
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
                catch (AggregateException exception)
                {
                    exception = exception.Flatten();
                    ExceptionDispatchInfo.Capture(
                    exception.InnerException).Throw();
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
