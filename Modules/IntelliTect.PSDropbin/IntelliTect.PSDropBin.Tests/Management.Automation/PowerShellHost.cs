using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Provider;
using System.Text;
using System.Threading.Tasks;

namespace IntelliTect.Management.Automation.UnitTesting
{
    public class PowerShellHost<TProvider>
        where TProvider : NavigationCmdletProvider, new()
    {
        public PowerShellHost(TestContext testContext)
        {
            TestContext = testContext;
            PowerShell = PowerShell.Create();
            string psProviderPath = typeof(TProvider).Assembly.Location;
            string providerName = ((CmdletProviderAttribute)typeof(TProvider).GetCustomAttributes(typeof(CmdletProviderAttribute), false).First()).ProviderName;
            ICollection<PSObject> results = Invoke(string.Format("Import-Module {0}; Get-PSProvider {1}", psProviderPath, providerName));
            //Provider = new PSDropbin.DropboxPSProvider().(ProviderInfo)results.First().ImmediateBaseObject;
        }

        public PowerShell PowerShell { get; set; }

        public TProvider Provider { get; private set; }

        public TestContext TestContext { get; private set; }

        public ICollection<PSObject> Invoke(string command)
        {
            PowerShell.AddScript(command);
            ICollection<PSObject> results = PowerShell.Invoke();
            PowerShell.Commands.Clear();
            foreach (PSObject item in results)
            {
                TestContext.WriteLine(item.ToString());
            }
            foreach (ErrorRecord error in PowerShell.Streams.Error.ReadAll())
            {
                TestContext.WriteLine("ERROR: {0}", error);
            }
            Assert.IsFalse(PowerShell.HadErrors);
            return results;
        }
    }
}
