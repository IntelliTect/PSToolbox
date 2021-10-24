using Dropbox.Api.Files;
using System;

namespace IntelliTect.PSDropbin
{
    public class MetaData
    {
        public MetaData(Metadata metaData)
        {
            IsDeleted = metaData.IsDeleted;
            IsFolder = metaData.IsFolder;
            Name = metaData.Name;
            Path = metaData.PathDisplay;
            Root = "dropbox";
            if (metaData.IsFile)
            {
                Size = (int)metaData.AsFile.Size;
                ServerModified = metaData.AsFile.ServerModified;
            }
        }

        public bool IsDeleted { get; set; }
        public bool IsFolder { get; set; }
        public string Name { get; set; }
        public int? Size { get; set; } = null;
        public DateTime? ServerModified { get; set; } = null;
        public string Path { get; set; }
        public string Root { get; set; }
    }
}
