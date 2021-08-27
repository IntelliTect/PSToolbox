using Dropbox.Api.Files;
using System;
using System.Linq;
using System.Management.Automation;
using System.Runtime.ExceptionServices;

namespace IntelliTect.PSDropbin
{
    [Cmdlet(VerbsCommon.Set, Noun, SupportsShouldProcess = true)]
    public class SetRevision : PSCmdlet
    {
        private const string Noun = "Revision";


        [Parameter(
                Position = 0,
                Mandatory = true,
                ValueFromPipeline = true,
                ValueFromPipelineByPropertyName = true)
        ]
        [ValidateNotNullOrEmpty]
        public string Path { get; set; }

        [Parameter(
                Position = 1,
                Mandatory = true,
                ValueFromPipeline = true,
                ValueFromPipelineByPropertyName = true)
        ]
        [ValidateNotNullOrEmpty]
        public string Revision { get; set; }

        protected override void ProcessRecord()
        {
            ProviderInfo dropboxProvider;
            string resolvedPath = GetResolvedProviderPathFromPSPath(Path, out dropboxProvider).First();
            string dropBoxPath = DropboxFileHelper.NormalizePath(resolvedPath);
            DropboxDriveInfo primaryDrive = dropboxProvider.Drives.Cast<DropboxDriveInfo>().First();

            RestoreArg restoreArg = new RestoreArg(dropBoxPath, Revision);

            base.WriteVerbose(string.Format("Restoring {0}, to version: {1}", dropBoxPath, Revision));

            
            if (ShouldProcess(resolvedPath, "Set-Revision"))
            {
                try
                {
                    FileMetadata fileMetadata = primaryDrive.Client.Files.RestoreAsync(restoreArg).Result;
                    base.WriteVerbose(string.Format("Succesfully restored {0}, to version: {1}", dropBoxPath, Revision));
                    base.WriteObject(fileMetadata);
                }
                catch (AggregateException exception)
                {
                    exception = exception.Flatten();
                    ExceptionDispatchInfo.Capture(
                    exception.InnerException).Throw();
                }
            }
        }
 
    }
}