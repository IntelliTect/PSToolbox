using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Provider;
using System.Threading;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace IntelliTect.Management.Automation.UnitTesting
{
    public abstract partial class PSProviderTestBase<TProvider, TDriveInfo>
            where TProvider : CmdletProvider
    {
        private static PowerShell _PowerShell;

        public static PowerShell PowerShell
        {
            get { return _PowerShell; }
            set
            {
                if ( _PowerShell != null )
                {
                    _PowerShell.Dispose();
                }
                _PowerShell = value;
            }
        }

        public virtual TestContext TestContext { get; set; }
        public static TProvider Provider { get; set; }

        public static string ProviderName
        {
            get
            {
                CmdletProviderAttribute cmdletProviderAttribute =
                        (CmdletProviderAttribute) typeof(TProvider).GetCustomAttributes(
                                typeof(CmdletProviderAttribute),
                                false ).First();
                return cmdletProviderAttribute.ProviderName;
            }
        }

        /// <summary>
        ///     Invokes the command within the PowerShell session.
        /// </summary>
        /// <param name="commandFormat">
        ///     A command expressed as a composite format string
        ///     (see http://msdn.microsoft.com/en-us/library/txafckwd(v=vs.110).aspx) into which the args
        ///     can be embedded (e.d. New-Item {0}"
        /// </param>
        /// <param name="args">An object array that contains zero or more objects to format.</param>
        /// <returns></returns>
        public ICollection<PSObject> PowerShellInvoke( string commandFormat, params object[] args )
        {
            commandFormat = string.Format( commandFormat, args );
            return PowerShellInvoke( commandFormat, false, TestContext );
        }

        /// <summary>
        ///     Invokes the command within the PowerShell session.
        /// </summary>
        /// <param name="ignoreErrors">set to true to ignore errors</param>
        /// <param name="commandFormat">
        ///     A command expressed as a composite format string
        ///     (see http://msdn.microsoft.com/en-us/library/txafckwd(v=vs.110).aspx) into which the args
        ///     can be embedded (e.d. New-Item {0}"
        /// </param>
        /// <param name="args">An object array that contains zero or more objects to format.</param>
        /// <returns></returns>
        public ICollection<PSObject> PowerShellInvoke( bool ignoreErrors, string commandFormat, params object[] args )
        {
            commandFormat = string.Format( commandFormat, args );
            return PowerShellInvoke( commandFormat, ignoreErrors, TestContext );
        }

        public static ICollection<PSObject> PowerShellInvoke( string command,
                bool ignoreErrors,
                TestContext testContext = null )
        {
            TestContextWriteLine( testContext, command );
            PowerShell.AddScript( command );
            string errorText = null;
            ICollection<PSObject> results = PowerShell.Invoke();
            //TestContextWriteLine(testContext, "HistoryString: " + PowerShell.HistoryString);
            PowerShell.Commands.Clear();
            foreach ( PSObject item in results )
            {
                TestContextWriteLine( testContext, "{0}", item );
            }
            foreach ( DebugRecord record in PowerShell.Streams.Debug.ReadAll() )
            {
                TestContextWriteLine( testContext, "DEBUG: {0}", record );
            }
            foreach ( VerboseRecord record in PowerShell.Streams.Verbose.ReadAll() )
            {
                TestContextWriteLine( testContext, "VERBOSE: {0}", record );
            }
            foreach ( WarningRecord record in PowerShell.Streams.Warning.ReadAll() )
            {
                TestContextWriteLine( testContext, "WARNING: {0}", record );
            }
            if ( !ignoreErrors )
            {
                // Used to allow caller to read the errors.
                IEnumerable<ErrorRecord> errors = PowerShell.Streams.Error.ReadAll();
                errorText = string.Join( Environment.NewLine, errors );
                foreach ( ErrorRecord record in errors )
                {
                    TestContextWriteLine( testContext, "ERROR: {0}", record );
                }
                Assert.IsFalse( PowerShell.HadErrors, errorText );
            }

            return results;
        }

        private static void TestContextWriteLine( TestContext testContext, string commandFormat, params object[] args )
        {
            string command;
            if ( args == null ||
                 !args.Any() )
            {
                command = commandFormat;
            }
            else
            {
                command = string.Format( commandFormat, args );
            }
            if ( testContext != null )
            {
                testContext.WriteLine( "Command: {0}", command );
            }
            else
            {
                Console.WriteLine( "Command: {0}", command );
            }
        }

        public static TProvider ImportModule( TestContext testContext )
        {
            TProvider provider = null;
            ProviderEventArgs<TProvider>.OnNewInstance += ( sender, eventArgs ) => provider = eventArgs.Provider;
            string psProviderPath = typeof(TProvider).Assembly.Location;

            PowerShell.AddCommand( "Set-ExecutionPolicy" )
                    .AddArgument( "Unrestricted" )
                    .AddParameter( "Scope", "Process" );
            PowerShell.Invoke();

            string command = @"if(test-path variable:module) {{
                        remove-module $module -Verbose;
                    }};
                    
                    $module=(import-module '{0}' -PassThru -Verbose);
                    #Write-Output $module";

            command = string.Format( command, new FileInfo(psProviderPath).Directory.Parent.Parent.Parent.FullName + "\\IntelliTect.PSDropbin.psd1" );
            PowerShellInvoke( command, false, testContext );

            Assert.IsNotNull( provider );
            return provider;
        }

        public static TDriveInfo NewDrive( string driveName = "DropboxTestDrive", TestContext testContext = null )
        {
            // TODO: Change to dynamically determine New-PSDrive parameters.
            string command = @"if(!(Test-Path Variable:\{0})) {{
                    ${0} = New-PSDrive -PSProvider {1} -Name {0} -Root ""/"" -Verbose
                }}
                Get-PSDrive ${0}";
            command = string.Format( command, driveName, ProviderName );
            TDriveInfo driveInfo =
                    (TDriveInfo) PowerShellInvoke( command, false, testContext ).First().ImmediateBaseObject;
            return driveInfo;
        }

        public static bool TestPath( string path, TestContext testContext = null )
        {
            return
                    (bool)
                            PowerShellInvoke( string.Format( "Test-Path {0}", path ), false, testContext )
                                    .Single()
                                    .ImmediateBaseObject;
        }

        // TODO: Change to not use dynamic
        public static dynamic NewItem( string path, TestContext testContext = null )
        {
            string itemType = "File";
            if ( path.Trim().EndsWith( "\\" ) || path.Trim().EndsWith("/") ||
                 string.IsNullOrEmpty( Path.GetExtension( path ) ) )
            {
                itemType = "Directory";
            }
            return PowerShellInvoke(
                    string.Format("New-Item {0} -ItemType {1} -verbose -Force", path, itemType ),
                    false,
                    testContext ).First().ImmediateBaseObject;
        }

        public static void RemoveItem( string path, bool ignoreMissingItem = false, TestContext testContext = null )
        {
            //PowerShellInvoke(ignoreMissingItem, "Remove-Item {0} -verbose -recurse", path);
            PowerShellInvoke(
                    string.Format( "Remove-Item {0} -verbose -recurse", path ),
                    ignoreMissingItem,
                    testContext );
        }

        // TODO: Move to base class of TProvider

        protected virtual void CopyItem( string path, string destination )
        {
            PowerShellInvoke( "Copy-Item {0} {1};", path, destination );
        }

        protected virtual dynamic GetItem( string path )
        {
            return PowerShellInvoke( "Get-Item {0};", path );
        }

        protected virtual bool IsItemContainer( string path )
        {
            return
                    (bool)
                            PowerShellInvoke( "Get-Item {0} | %{{ $_.PsIsContainer }}", path )
                                    .Single()
                                    .ImmediateBaseObject;
        }

        protected virtual void CopyItemTest( string path, string destination )
        {
            using ( new PSTempItem( path ) )
            {
                using ( new PSTempItem( destination ) )
                {
                    // ReSharper disable PossibleMultipleEnumeration
                    RemoveItem( destination );
                    IEnumerable<string> fileNames = Enumerable.Range( 0, 3 ).Select( count => "Item" + count + ".item" );

                    if ( path.EndsWith( "\\" ) )
                    {
                        foreach ( string name in fileNames )
                        {
                            NewItem( Path.Combine( path, name ) );
                        }
                    }
                    CopyItem( path, destination );
                    AttemptAssertion( () => TestPath( destination ) );
                    if ( path.EndsWith( "\\" ) )
                    {
                        Assert.IsTrue( IsItemContainer( destination ) );
                        foreach ( string name in fileNames )
                        {
                            Assert.IsTrue( TestPath( Path.Combine( destination, name ) ) );
                        }
                    }
                    // ReSharper restore PossibleMultipleEnumeration
                }
            }
        }

        // for when the first attempt may or may not work due to latency

        protected virtual void MoveItem( string path, string destination )
        {
            PowerShellInvoke( "Move-Item {0} {1};", path, destination );
        }

        protected void AttemptAssertion( Func<bool> assertion, bool expected = true, int pulses = 6 )
        {
            // if we expect false, check for false
            Func<bool> modifiedAssertion = ( expected ) ? assertion : () => !assertion();
            int count = 0;

            while ( !modifiedAssertion() &&
                    count < pulses )
            {
                Thread.Sleep( 400 );
                count++;
            }

            if ( expected )
            {
                Assert.IsTrue( assertion() );
            }
            else
            {
                Assert.IsFalse( assertion() );
            }
        }

        protected virtual void MoveItemTest( string path, string destination )
        {
            using ( new PSTempItem( path ) )
            {
                using ( new PSTempItem( destination ) )
                {
                    // ReSharper disable PossibleMultipleEnumeration
                    RemoveItem( destination );
                    IEnumerable<string> fileNames = Enumerable.Range( 0, 3 ).Select( count => "Item" + count + ".item" );
                    if ( path.EndsWith( "\\" ) )
                    {
                        foreach ( string name in fileNames )
                        {
                            NewItem( Path.Combine( path, name ) );
                        }
                    }

                    MoveItem( path, destination );
                    AttemptAssertion( () => TestPath( path ), false );
                    AttemptAssertion( () => TestPath( destination ) );
                    if ( path.EndsWith( "\\" ) )
                    {
                        Assert.IsTrue( IsItemContainer( destination ) );
                        foreach ( string name in fileNames )
                        {
                            Assert.IsFalse( TestPath( Path.Combine( path, name ) ) );
                            Assert.IsTrue( TestPath( Path.Combine( destination, name ) ) );
                        }
                    }
                    // ReSharper restore PossibleMultipleEnumeration
                }
            }
        }
    }
}