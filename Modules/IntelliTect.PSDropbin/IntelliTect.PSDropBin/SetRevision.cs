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

            Console.WriteLine(string.Format("Restoring {0}, to version: {1}", dropBoxPath, Revision));

            
            if (ShouldProcess(resolvedPath, "Set-Revision"))
            {
                try
                {   
                    FileMetadata fileMetadata = primaryDrive.Client.Files.RestoreAsync(restoreArg).Result;
                    Console.WriteLine(string.Format("Succesfully restored {0}, to version: {1}", dropBoxPath, Revision));
                    Console.WriteLine(string.Format("Current File Info:"));
                    var entry = new GetRevisions.RevisionEntry();
                    entry.Revision = fileMetadata.Rev;
                    entry.ServerModified = fileMetadata.ServerModified;
                    entry.ClientModified = fileMetadata.ClientModified;
                    //print new entry;
                    base.WriteObject(entry);
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