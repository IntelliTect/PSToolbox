using ExposedObject;
using Microsoft.PowerShell.Commands;
using Microsoft.QualityTools.Testing.Fakes;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Fakes;
using System.Management.Automation.Host;
using System.Management.Automation.Provider;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Linq;
using System.Diagnostics;
using IntelliTect.Management.Automiation.UnitTesting;
using Microsoft.Samples.PowerShell.Providers;

namespace IntelliTect.PSDropbin.Tests
{
    [TestClass]
    public class AccessDBProviderTests : PSProviderTestBase<AccessDBProvider, AccessDBPSDriveInfo>
    {
        [ClassInitialize]
        public static void ClassInitialize(TestContext testContext)
        {
            if (PowerShell == null || PowerShell.HadErrors)
            {
                ClassCleanup();
                PowerShell = PowerShell.Create();
            }
            Provider = ImportModule(testContext);
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
        static public void ClassCleanup()
        {
            if (PowerShell != null)
            {
                PowerShell.Dispose();
            }
        }

        public TestContext TestContext { get; set; }

 
        [TestMethod]
        public void Constructor()
        {
            NavigationCmdletProvider providerBase = Provider;
            Assert.IsNotNull(Provider);
        }

        [TestMethod]
        public void CreateProvider_MultipleTimes_Succeeds()
        {
            Assert.IsNotNull(ImportModule(TestContext));
            Assert.IsNotNull(ImportModule(TestContext));
        }
        // TODO: Undo ignore and use Stub/Fakes to fake the call to Provider.WriteError
        [TestMethod][ExpectedException(typeof(System.Management.Automation.ProviderInvocationException))]
        public void NewDrive_PSDriveInfoIsNull_WritesErrorAndReturnsNull()
        {
            dynamic exposedObject = ExposedObject.Exposed.From(Provider);
            try
            {
                Assert.IsNull(exposedObject.NewDrive((PSDriveInfo)null));
            }
            catch
            {
                // TODO: Determine why no records are written to Error stream.
                //Assert.AreEqual<int>(1, PowerShell.Streams.Error.Count);
                throw;
            }
        }

        [TestMethod]
        public void ImportModule_SuccessfullyImports()
        {
            ICollection<PSObject> results = PowerShellInvoke(
                "Get-PSProvider " + ProviderName, TestContext);
            Assert.IsNotNull(results);
            ProviderInfo providerInfo = (ProviderInfo)results.First().ImmediateBaseObject;
            //Assert.AreEqual<string>(typeof(ProviderInfo).FullName, results.First().TypeNames[0]);
            Assert.AreEqual<string>(typeof(DropboxPSProvider).Assembly.GetName().Name, providerInfo.ModuleName);
            Assert.IsNotNull(Provider);
        }

        [TestMethod]
        public void ImportModule_SuccessfullyImports_CreatesDefaultDrive()
        {
            DropboxPSDriveInfo driveInfo = (DropboxPSDriveInfo)PowerShellInvoke(
                "Get-PSDrive " + DropboxPSProvider.DefaultDriveName).First().ImmediateBaseObject;
            Assert.AreEqual<string>(DropboxPSProvider.DefaultDriveName,driveInfo.Name);
        }

        [TestMethod]
        public void IsValid_GivenInvalidFileNames_ReturnsFalse()
        {
            dynamic exposedProvider = Exposed.From(Provider);
            Assert.IsFalse(exposedProvider.IsValidPath((string)null));
            Assert.IsFalse(exposedProvider.IsValidPath(""));
            Assert.IsFalse(exposedProvider.IsValidPath(string.Format("te{0}st\test.txt", Path.GetInvalidPathChars()[1])));
            Assert.IsFalse(exposedProvider.IsValidPath(string.Format("test\te{0}st.txt", Path.GetInvalidPathChars()[0])));
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


        [TestMethod]
        public void ItemExists_GivenNonExistentItem_ReturnsFalse()
        {
            dynamic exposedProvider = Exposed.From(Provider);
            Assert.IsFalse(exposedProvider.ItemExists(@"\Test\Test.txt"));
            Assert.IsFalse(exposedProvider.ItemExists(@"/Test/Test.txt"));
        }

        [TestMethod]
        public void NewItem_CreateItem_Success()
        {
            AccessDBPSDriveInfo drive = NewDrive("NewItem_CreateItem_Success");
            PowerShellInvoke("New-Item NewItem_CreateItem_Success:Junk.Junk -ItemType Directory", TestContext);
        }

        [TestMethod]
        public void TestPath_ValidPaths_ReturnsTrue()
        {
            NewDrive();
            ICollection<PSObject> results = PowerShellInvoke(
                @"Test-Path Drpbx:\;
                  Test-Path Drpbx:\Public");
            Assert.IsNotNull(results);
            Assert.AreEqual<int>(2, results.Count);
            results.Select(item => item.ImmediateBaseObject).Cast<bool>();
        }

        [TestMethod]
        public void RemoveItem_ExistingItem_Success()
        {
            string path = string.Format(@"{0}:\IntelliTect.PSDropbin.Testing.delete", DropboxPSProvider.DefaultDriveName);
            NewItem(path, TestContext);
            Assert.IsTrue(ItemExists(path));
            RemoveItem(path, TestContext);
            Assert.IsFalse(ItemExists(path));
        }

        [TestMethod]
        public void TestPath_InvalidPaths_ReturnsFalse()
        {
            NewDrive();
            ICollection<PSObject> results = PowerShellInvoke(
                @"Test-Path ""Drpbx:\Does not Exist""");
            Assert.IsNotNull(results);
            Assert.AreEqual<int>(1, results.Count);
            Assert.IsFalse((bool)results.First().ImmediateBaseObject);
        }

        [TestMethod]
        public void SetLocation_InvalidPaths_ReturnsFalse()
        {
            NewDrive();
            ICollection<PSObject> results = PowerShellInvoke(
                @"Set-Location ""Drpbx:\Public"";
                 Get-Location");
            Assert.IsNotNull(results);
            Assert.AreEqual<int>(1, results.Count);
            Assert.AreEqual<string>(@"Drpbx:\Public", (string)results.First().ImmediateBaseObject.ToString());
        }
    }
}
