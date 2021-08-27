using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation;
using IntelliTect.Management.Automation.UnitTesting;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using ExposedObject;

namespace IntelliTect.PSDropbin.Tests
{
    [TestClass]
    public class DropboxPSProviderTests : PSProviderTestBase<DropboxProvider, DropboxDriveInfo>
    {
        public const string TestDriveName = "DropboxTestDrive";

        [ClassInitialize]
        public static void ClassInitialize(TestContext testContext)
        {
            if (PowerShell == null ||
                 PowerShell.HadErrors)
            {
                ClassCleanup();
                PowerShell = PowerShell.Create();
            }
            Provider = ImportModule(testContext);
            NewDrive(driveName: TestDriveName, testContext: testContext);
        }

        [TestInitialize]
        public void TestInitialize()
        {
            if (PowerShell.HadErrors)
            {
                PowerShell.Dispose();
                ClassInitialize(TestContext);
            }
        }

        [ClassCleanup]
        public static void ClassCleanup()
        {
            if (PowerShell != null)
            {
                PowerShell.Dispose();
            }
        }

        [TestMethod]
        public void Constructor()
        {
            Assert.IsNotNull(Provider);
        }

        // TODO: Undo ignore and use Stub/Fakes to fake the call to Provider.WriteError
        [TestMethod]
        //      [ExpectedException( typeof(ProviderInvocationException) )]
        // TODO: figure out why we were originally getting a ProviderInvocationException instead
        [ExpectedException(typeof(ArgumentNullException))]
        public void NewDrive_PSDriveInfoIsNull_WritesErrorAndReturnsNull()
        {
            dynamic exposedObject = Exposed.From(Provider);
            try
            {
                Assert.IsNull(exposedObject.NewDrive((PSDriveInfo)null));
            }
            catch
            {
                // TODO: Determine why no records are written to Error stream.
                //                Assert.AreEqual<int>(1, PowerShell.Streams.Error.Count);
                throw;
            }
        }

        [TestMethod]
        public void ImportModule_SuccessfullyImports()
        {
            ICollection<PSObject> results = PowerShellInvoke("Get-PSProvider " + ProviderName);
            Assert.IsNotNull(results);
            ProviderInfo providerInfo = (ProviderInfo)results.First().ImmediateBaseObject;
            //Assert.AreEqual<string>(typeof(ProviderInfo).FullName, results.First().TypeNames[0]);
            Assert.AreEqual(typeof(DropboxProvider).Assembly.GetName().Name, providerInfo.ModuleName);
            Assert.IsNotNull(Provider);
        }

        [TestMethod]
        public void IsValid_GivenInvalidFileNames_ReturnsFalse()
        {
            dynamic exposedProvider = Exposed.From(Provider);
            Assert.IsFalse(exposedProvider.IsValidPath((string)null));
            Assert.IsFalse(exposedProvider.IsValidPath(""));
            Assert.IsFalse(
                    exposedProvider.IsValidPath(string.Format("te{0}st\test.txt", Path.GetInvalidPathChars()[1])));
            Assert.IsFalse(
                    exposedProvider.IsValidPath(string.Format("test\te{0}st.txt", Path.GetInvalidPathChars()[0])));
        }

        [TestMethod]
        public void IsValid_GivenValidFileNames_ReturnsTrue()
        {
            dynamic exposedProvider = Exposed.From(Provider);
            Assert.IsTrue(exposedProvider.IsValidPath(@"Test\Test.txt"));
            Assert.IsTrue(exposedProvider.IsValidPath("Test/Test.txt"));
            Assert.IsTrue(exposedProvider.IsValidPath(@"\Test\Test.txt"));
            Assert.IsTrue(exposedProvider.IsValidPath(@"/Test/Test.txt"));
        }

        [Ignore]
        [TestMethod] // Not sure how to invoke a command using ImportModuleCommand type.
        public void ImportModule_UsingImportModuleCommand()
        {
            //PowerShell = PowerShell.Create();
            //string psProviderPath = typeof(DropboxPSProvider).Assembly.Location;
            //ImportModuleCommand command = new ImportModuleCommand();
            //command.Assembly = new[] { typeof(DropboxPSProvider).Assembly };
            //command.PassThru = SwitchParameter.Present;
            //command.Name = new[] { "Import-Module" };
            //CmdletInfo cmdletInfo = new CmdletInfo("Import-Module", typeof(ImportModuleCommand));
            //PSObject psObject;
            //PowerShell.AddCommand(cmdletInfo);
            //psObject = PowerShellInvoke(TestContext).First();
        }

        [TestMethod]
        public void ItemExists_GivenExistentItem_ReturnsTrue()
        {
            Assert.IsTrue((bool)PowerShellInvoke(
                    string.Format("Test-Path {0}:", TestDriveName))
                    .First()
                    .ImmediateBaseObject);
        }

        [TestMethod]
        public void ItemExists_GivenNonExistentItem_ReturnsFalse()
        {
            Assert.IsFalse(TestPath(string.Format("{0}:/DoesNotExist", TestDriveName)));
        }

        [TestMethod]
        public void TestPath_ValidDirectoryPaths_ReturnsTrue()
        {
            Assert.IsTrue(TestPath(PrependProviderDefaultDrive("\\")));
        }

        [TestMethod]
        public void TestPath_InvalidPaths_ReturnsFalse()
        {
            ICollection<PSObject> results = PowerShellInvoke(@"Test-Path ""DropboxTestDrive:\DoesNotExist""");
            Assert.IsNotNull(results);
            Assert.AreEqual(1, results.Count);
            Assert.IsFalse((bool)results.First().ImmediateBaseObject);
        }

        [TestMethod]
        public void SetLocation_RootPath_Successful()
        {
            ICollection<PSObject> results = PowerShellInvoke(@"Set-Location ""DropboxTestDrive:\"";
                 Get-Location");
            Assert.IsNotNull(results);
            Assert.AreEqual(1, results.Count);
            Assert.AreEqual(@"DropboxTestDrive:\", results.First().ImmediateBaseObject.ToString());
        }

        [TestMethod]
        public void SetLocation_ValidPaths_Successful()
        {
            ICollection<PSObject> results = PowerShellInvoke(@"Set-Location ""DropboxTestDrive:"";
                 Get-Location");
            Assert.IsNotNull(results);
            Assert.AreEqual(1, results.Count);
            Assert.AreEqual(@"DropboxTestDrive:", results.First().ImmediateBaseObject.ToString().TrimEnd('\\'));
        }

        [TestMethod]
        public void NewItem_CreateDirectoryItem_Success()
        {
            const string directoryName = "NewItem_CreateDirectoryItem_Success.delete";
            if (TestPath(directoryName))
            {
                PowerShellInvoke("Remove-Item {0}", directoryName);
            }
            PowerShellInvoke("New-Item {0} -ItemType Directory   ", directoryName);
            AttemptAssertion(() => TestPath(directoryName));
            Assert.IsTrue(IsItemContainer(directoryName));
            PowerShellInvoke("Remove-Item {0}", directoryName);
        }

        [TestMethod]
        public void NewItem_CreateFileItem_Success()
        {
            const string path = "NewItem_CreateFileItem_Success.delete";
            try
            {
                NewItem(path);
                Assert.IsTrue(TestPath(path));
                Assert.IsFalse(IsItemContainer(path));
            }
            finally
            {
                RemoveItem(path, true);
            }
        }

        protected string PrependProviderDefaultDrive(string path)
        {
            // TODO: Leverage Microsoft.PowerShell.Management.Activities.JoinPath rather than hard coding the '/'
            return string.Format("{0}:\\{1}", TestDriveName, path);
        }

        [TestMethod]
        public void CopyItem_GivenExistingItemInDropbox_Success()
        {
            string path = PrependProviderDefaultDrive("CopyItem_GivenExistingItemInDropbox_Success.delete");
            string destination = path + "-Copied";
            CopyItemTest(path, destination);
        }

        [TestMethod]
        public void CopyDirectory_GivenExistingDirectoryInDropbox_Success()
        {
            const string name = "CopyDirectory_GivenExistingDirectoryItemInDropbox_Success.delete";
            string path = PrependProviderDefaultDrive(name + "\\");
            string destination = PrependProviderDefaultDrive("Copied-" + name + "\\");
            CopyItemTest(path, destination);
        }

        [TestMethod]
        public void CopyDirectory_GivenExistingDirectoryOnLfs_CopyItemToDropbox()
        {
            const string name = "CopyDirectory_GivenExistingDirectoryOnLocalFileSystem_Success-delete";
            string path = Path.Combine(Path.GetTempPath(), name + "\\");
            string destination = PrependProviderDefaultDrive("Copied-" + name + "\\");
            CopyItemTest(path, destination);
        }

        [TestMethod]
        public void CopyDirectory_GivenMultilevelDirectoryOnLfs_CopyItemToDropbox()
        {
            const string parentDirectoryName = "CopyDirectory_GivenMultilevelDirectoryOnLfs_CopyItemToDropbox-delete\\";
            const string subDirectoryName = "Subdirectory";
            string parentPath = Path.Combine(Path.GetTempPath(), parentDirectoryName);
            string path = Path.Combine(parentPath, subDirectoryName + "\\");
            string parentDestination = PrependProviderDefaultDrive("Copied-" + parentDirectoryName);
            string destination = Path.Combine(parentDestination, subDirectoryName + "\\");
            CopyItemTest(path, parentPath, destination, parentDestination);
        }

        [TestMethod]
        public void CopyDirectory_GivenExistingDirectoryInDropbox_CopyItemToLfs()
        {
            const string name = "CopyDirectory_GivenExistingDirectoryInDropbox_CopyItemToLfs-delete";
            string path = PrependProviderDefaultDrive(name + "\\");
            string destination = Path.Combine(Path.GetTempPath(), name + "-Copied\\");
            CopyItemTest(path, destination);
        }

        [TestMethod]
        public void CopyItem_GivenExistingItemOnLocalFileSystem_CopyItemToDropbox()
        {
            const string fileName = "CopyItem_GivenExistingItemOnLocalFileSystem_CopyItemToDropbox.delete";
            string path = Path.Combine(Path.GetTempPath(), fileName);
            string destination = PrependProviderDefaultDrive(fileName + "-Copied");
            CopyItemTest(path, destination);
        }

        [TestMethod]
        public void CopyItem_GivenExistingItemInDropbox_CopyItemToLocalFileSystem()
        {
            const string name = "CopyItem_GivenExistingItemInDropbox_CopyItemToLocalFileSystem.delete";
            string path = PrependProviderDefaultDrive(name);
            string destination = Path.Combine(Path.GetTempPath(), name + "-Copied");
            CopyItemTest(path, destination);
        }

        [TestMethod]
        public void MoveItem_GivenExistingItemInDropbox_Success()
        {
            const string name = "MoveItem_GivenExistingItemInDropbox_Success.delete";
            string path = PrependProviderDefaultDrive(name + "\\");
            string destination = PrependProviderDefaultDrive("Moved-" + name + "\\");
            MoveItemTest(path, destination);
        }

        [TestMethod]
        [Ignore] // This functionality is not yet implemented. This test SHOULD fail.
        public void MoveItem_GivenExistingItemInDropbox_MoveItemToLocalFileSystem()
        {
            const string name = "MoveItem_GivenExistingItemInDropbox_Move";
            string path = PrependProviderDefaultDrive(name);
            string destination = Path.Combine(Path.GetTempPath(), name + "-Moved");
            MoveItemTest(path, destination);
        }

        [TestMethod]
        [Ignore] // This functionality is not yet implemented. This test SHOULD fail.
        public void MoveItem_GivenExistingItemInLocalFileSystem_MoveItemToDropbox()
        {
            const string name = "MoveItem_GivenExistingItemInDropbox_Move";
            string path = Path.Combine(Path.GetTempPath(), name);
            string destination = PrependProviderDefaultDrive(name + "-Moved");
            MoveItemTest(path, destination);
        }

        [TestMethod]
        public void RemoveItem_NonExistent_Fails()
        {
            const string itemName = "NonExistentItem.delete";
            string path = PrependProviderDefaultDrive(itemName);
            RemoveItem(path, true);
            Assert.IsTrue(PowerShell.HadErrors);
            IEnumerable<ErrorRecord> errors = PowerShell.Streams.Error.ReadAll();
            string errorText = string.Join(Environment.NewLine, errors);

            // Expected error text from Dropbox.Api.Files.DeleteError
            string expectedErrorText = "path_lookup/not_found/";
            Assert.AreEqual(expectedErrorText, errorText.TrimEnd('.'));
        }

        [TestMethod]
        public void GetRevisions_GivenFileWithNoRevisions_OneRevision()
        {
            var uniqueFileNameGuid = Guid.NewGuid();
            //Dropbox remembers files (Thats part of revisions). So we need to create a new file to test revision history
            string name = String.Format("newItem{0}.txt", uniqueFileNameGuid);
            string path = PrependProviderDefaultDrive("");
            //string destination = PrependProviderDefaultDrive("Copied-" + name + "\\");
            ItemRevisionsTest(path, name, 1);
        }

        [TestMethod]
        public void GetRevisions_GivenFileWithThreeRevisions_ThreeRevisions()
        {
            var uniqueFileNameGuid = Guid.NewGuid();
            //Dropbox remembers files (Thats part of revisions). So we need to create a new file to test revision history
            string name = String.Format("newItem{0}.txt", uniqueFileNameGuid);
            string path = PrependProviderDefaultDrive("");
            //string destination = PrependProviderDefaultDrive("Copied-" + name + "\\");
            ItemRevisionsTest(path, name, 3);
        }


        [TestMethod]
        public void RemoveItem_ExistingItem_Success()
        {
            string path = PrependProviderDefaultDrive("IntelliTect.PSDropbin.Testing.delete");
            NewItem(path);
            AttemptAssertion(() => TestPath(path));
            RemoveItem(path);
            AttemptAssertion(() => TestPath(path), false);
        }
    }
}