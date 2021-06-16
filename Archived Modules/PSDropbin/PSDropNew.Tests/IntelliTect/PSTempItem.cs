using System;

namespace IntelliTect.Management.Automation.UnitTesting
{
    public abstract partial class PSProviderTestBase<TProvider, TDriveInfo>
    {
        protected class PSTempItem : IDisposable
        {
            public PSTempItem( string path )
            {
                Path = path;
                if ( !TestPath( path ) )
                {
                    NewItem( path );
                }
            }

            public String Path { get; set; }

            public void Dispose()
            {
                Dispose( true );
                GC.SuppressFinalize( this );
            }

            private void Dispose( bool disposing )
            {
                if ( disposing )
                {
                    RemoveItem( Path, true );
                }
            }

            ~PSTempItem()
            {
                Dispose( false );
            }
        }
    }
}