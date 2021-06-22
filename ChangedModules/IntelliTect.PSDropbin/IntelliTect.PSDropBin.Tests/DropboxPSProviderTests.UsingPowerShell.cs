using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Management.Automation;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace IntelliTect.PSDropbin.Tests
{
    [TestClass]
    public class DropboxPSProviderTestsUsingPowerShell
    {
        //static public PowerShellHost<DropboxPSProvider> PowerShellHost { get; set; }

        private static PowerShell _PowerShell;
        public TestContext TestContext { get; set; }

        public static PowerShell PowerShell
        {
            get { return _PowerShell; }
            set
            {
                if (_PowerShell != null)
                {
                    PowerShell.Dispose();
                }
                _PowerShell = value;
            }
        }

        [ClassInitialize]
        public static void ClassInitialize(TestContext testContext)
        {
            PowerShell = PowerShell.Create();
            string psProviderPath = typeof(DropboxPSProvider).Assembly.Location;
            RunPowerShellUsingPowerShellApi(testContext,
                    string.Format("Import-Module {0}", psProviderPath));
        }

        [ClassCleanup]
        public static void ClassCleanup()
        {
            PowerShell.Dispose();
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

        private ICollection<PSObject> RunPowerShellUsingPowerShellApi(string command)
        {
            return RunPowerShellUsingPowerShellApi(TestContext, command);
        }

        private static ICollection<PSObject> RunPowerShellUsingPowerShellApi(TestContext testContext, string command)
        {
            PowerShell.AddScript(command);
            ICollection<PSObject> results = PowerShell.Invoke();
            PowerShell.Commands.Clear();
            foreach (PSObject item in results)
            {
                testContext.WriteLine(item.ToString());
            }
            foreach (ErrorRecord error in PowerShell.Streams.Error.ReadAll())
            {
                testContext.WriteLine("ERROR: {0}", error);
            }
            Assert.IsFalse(PowerShell.HadErrors);
            return results;
        }

        private Process RunPowerShellUsingStartProcess(string command)
        {
            ProcessStartInfo startInfo =
                    new ProcessStartInfo("PowerShell.exe",
                            string.Format(
                                    "-windowStyle Hidden -NonInteractive -noprofile -nologo -Command \"& {{0}}\"",
                                    command));
            startInfo.CreateNoWindow = false;
            startInfo.UseShellExecute = false;
            startInfo.RedirectStandardError = true;
            startInfo.RedirectStandardOutput = true;
            Process powerShellProcess = Process.Start(startInfo);
            powerShellProcess.WaitForExit(5000);
            string outputText = powerShellProcess.StandardOutput.ReadToEnd();
            if (outputText.Trim().Length > 0)
            {
                TestContext.WriteLine("OUTPUT: {0}", outputText);
            }
            string errorText = powerShellProcess.StandardError.ReadToEnd();
            if (errorText.Trim().Length > 0)
            {
                TestContext.WriteLine("ERROR: {0}", errorText);
                Assert.Fail(errorText);
            }
            Assert.AreEqual(0, powerShellProcess.ExitCode);
            return powerShellProcess;
        }

        // TODO: Currently not capturing a failure!!!
        [Ignore]
        [TestMethod]
        [ExpectedException(typeof(AssertFailedException))]
        public void InvokePester()
        {
            Process powershell = RunPowerShellUsingStartProcess(
                    string.Format("INVALID COMMAND; CD {0}; Invoke-Pester", TestContext.TestRunDirectory));
        }


        //[TestMethod]
        //public void ImportProviderModule_SuccessfullyImports()
        //{
        //    Assert.AreEqual<int>(0, RunPowerShellUsingStartProcess("Get-History").ExitCode);
        //}


        private DropboxPSDriveInfo NewDrive()
        {
            return DropboxPSProviderTests.NewDrive(DropboxPSProvider.DefaultDriveName, TestContext);
        }

        [TestMethod]
        public void NewPSDrive_SuccessfullyCreatesDrive()
        {
            string psProviderPath = typeof(DropboxPSProvider).Assembly.Location;
            ICollection<PSObject> results = RunPowerShellUsingPowerShellApi(
                    @"New-PSDrive -PSProvider Dropbox -Name NewPSDrive_SuccessfullyCreatesDrive -Root ""/""");
            Assert.IsNotNull(results);
            Assert.AreEqual(1, results.Count);
            Assert.AreEqual(typeof(IntelliTect.PSDropbin.DropboxPSDriveInfo),
                    results.First().ImmediateBaseObject.GetType());
        }
    }
}