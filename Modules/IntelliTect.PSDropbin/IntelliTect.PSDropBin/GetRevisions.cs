using Dropbox.Api.Files;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management.Automation;
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
            
            IList<FileMetadata> revisionHistory = primaryDrive.Client.Files.ListRevisionsAsync(dropBoxPath,numberOfEntriesToReturn).Result.Entries;

            foreach(FileMetadata fileMetadata in revisionHistory)
            {
            var entry = new RevisionEntry();
                entry.ServerModified = fileMetadata.ServerModified;
                entry.RevisionId = fileMetadata.Id;
            base.WriteObject(entry);

            }


        }


        public class RevisionEntry
        {
            public System.DateTime ServerModified { get; set; }
            public System.DateTime ClientModified { get; set; }
            public string RevisionId { get; set; }
            public string Four { get; set; }

            public static PSObject Get()
            {

                var w = new RevisionEntry();
                var pso = new PSObject(w);
                var display = new PSPropertySet("DefaultDisplayPropertySet", new[] { "One", "Two" });
                var mi = new PSMemberSet("PSStandardMembers", new[] { display });
                pso.Members.Add(mi);

                return pso;
            }
        }
    }
}