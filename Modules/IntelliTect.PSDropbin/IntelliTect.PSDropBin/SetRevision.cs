using Dropbox.Api.Files;
using System.Linq;
using System.Management.Automation;
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




        private const ulong _DefaultLimit = 10;

        protected override void ProcessRecord()
        {
            ProviderInfo dropboxProvider;
            string resolvedPath = GetResolvedProviderPathFromPSPath(Path, out dropboxProvider).First();
            string dropBoxPath = DropboxFileHelper.NormalizePath(resolvedPath);
            DropboxDriveInfo primaryDrive = dropboxProvider.Drives.Cast<DropboxDriveInfo>().First();

            RestoreArg restoreArg = new RestoreArg(Path, Revision);

            FileMetadata fileMetadata = primaryDrive.Client.Files.RestoreAsync(restoreArg).Result;

            var entry = new RevisionEntry();
            entry.ServerModified = fileMetadata.ServerModified;
            base.WriteObject(entry);


        }


        public class RevisionEntry
        {
            public System.DateTime ServerModified { get; set; }
            public System.DateTime ClientModified { get; set; }
            public string Three { get; set; }
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