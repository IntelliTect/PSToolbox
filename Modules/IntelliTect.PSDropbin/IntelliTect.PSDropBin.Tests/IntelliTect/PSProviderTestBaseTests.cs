using IntelliTect.Management.Automation.UnitTesting;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace IntelliTect.PSDropbin.Tests.IntelliTect
{
    [TestClass]
    public class PSProviderTestBaseTests
    {
        [TestMethod]
        public void ProviderName()
        {
            Assert.AreEqual("Dropbox", PSProviderTestBase<DropboxProvider, DropboxDriveInfo>.ProviderName);
        }
    }
}