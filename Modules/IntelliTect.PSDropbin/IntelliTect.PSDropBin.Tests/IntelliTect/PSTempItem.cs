using System;

namespace IntelliTect.Management.Automation.UnitTesting
{
    public abstract partial class PSProviderTestBase<TProvider, TDriveInfo>
    {
        protected class PSTempItem : IDisposable
        {
            public PSTempItem(string path)
            {
                Path = path;
                if (!TestPath(path))
                {
                    NewItem(path);
                }
            }

            public PSTempItem(string path, string parentPath) : this(path)
            {
                ParentPath = !string.IsNullOrWhiteSpace(parentPath) ? parentPath
                    : throw new ArgumentException($"'{nameof(parentPath)}' cannot be null or whitespace.", nameof(parentPath));
                HasParentTestDirectory = true;
            }

            public String Path { get; set; }

            public bool HasParentTestDirectory { get; } = false;

            public string ParentPath { get; }

            public void Dispose()
            {
                Dispose(true);
                GC.SuppressFinalize(this);
            }

            private void Dispose(bool disposing)
            {
                if (disposing)
                {
                    if (HasParentTestDirectory)
                    {
                        RemoveItem(ParentPath, true);
                    }
                    else
                    {
                        RemoveItem(Path, true);
                    }
                }
            }

            ~PSTempItem()
            {
                Dispose(false);
            }
        }
    }
}