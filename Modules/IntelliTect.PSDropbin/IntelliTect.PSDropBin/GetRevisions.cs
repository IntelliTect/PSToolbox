using Dropbox.Api.Files;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Runtime.ExceptionServices;

namespace IntelliTect.PSDropbin
{
    [Cmdlet(VerbsCommon.Get, Noun, SupportsShouldProcess = false)]
    public class GetRevisions : PSCmdlet
    {
        private const string Noun = "Revisions";

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
                Mandatory = false,
                ValueFromPipeline = true,
                ValueFromPipelineByPropertyName = true)
        ]
        [ValidateNotNullOrEmpty]
        public ulong Limit { get; set; } = 0;
        private const ulong _DefaultLimit = 10;

        protected override void ProcessRecord()
        {
            ProviderInfo dropboxProvider;
            string resolvedPath = GetResolvedProviderPathFromPSPath(Path, out dropboxProvider).First();
            string dropBoxPath = DropboxFileHelper.NormalizePath(resolvedPath);
            DropboxDriveInfo primaryDrive = dropboxProvider.Drives.Cast<DropboxDriveInfo>().First();

            ulong numberOfEntriesToReturn = Limit > _DefaultLimit ? Limit : _DefaultLimit;
            try
            {


                IList<FileMetadata> revisionHistory = primaryDrive.Client.Files.ListRevisionsAsync(dropBoxPath, null, numberOfEntriesToReturn).Result.Entries;
                IOrderedEnumerable<FileMetadata> sortedHistory = revisionHistory.OrderBy(entry => entry.ServerModified);

                foreach (FileMetadata fileMetadata in sortedHistory)
                {
                    var entry = new RevisionEntry();
                    entry.ServerModified = fileMetadata.ServerModified;
                    entry.ClientModified = fileMetadata.ClientModified;
                    entry.Revision = fileMetadata.Rev;
                    base.WriteObject(entry);
                }
            }
            catch (AggregateException exception)
            {
                exception = exception.Flatten();
                ExceptionDispatchInfo.Capture(
                exception.InnerException).Throw();
            }

        }


        public class RevisionEntry
        {
            public System.DateTime ServerModified { get; set; }
            public System.DateTime ClientModified { get; set; }
            public string Revision { get; set; }


            public static PSObject Get()
            {

                var entry = new RevisionEntry();
                var pso = new PSObject(entry);
                var display = new PSPropertySet("DefaultDisplayPropertySet", new[] { nameof(ServerModified), nameof(Revision) });
                var standardMembers = new PSMemberSet("PSStandardMembers", new[] { display });
                pso.Members.Add(standardMembers);

                return pso;
            }
        }
    }
}