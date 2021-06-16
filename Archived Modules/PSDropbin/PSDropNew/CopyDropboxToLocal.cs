using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation;
using DropNet.Exceptions;
using DropNet.Models;

namespace IntelliTect.PSDropbin
{
    [Cmdlet( VerbsCommon.Copy, Noun, SupportsShouldProcess = true )]
    public class CopyDropboxToLocal : PSCmdlet
    {
        private const string Noun = "DropboxToLocal";

        [Parameter(
                Position = 0,
                Mandatory = true,
                ValueFromPipeline = true,
                ValueFromPipelineByPropertyName = true )
        ]
        [ValidateNotNullOrEmpty]
        public string Path { get; set; }

        [Parameter(
                Position = 1,
                Mandatory = true,
                ValueFromPipeline = true,
                ValueFromPipelineByPropertyName = true )
        ]
        [ValidateNotNullOrEmpty]
        public string[] Destination { get; set; }

        // TODO: implement support for multiple files
        protected override void ProcessRecord()
        {
            ProviderInfo dropboxProvider;
            string sourceFile = GetResolvedProviderPathFromPSPath( Path, out dropboxProvider ).First();
            string destination = GetUnresolvedProviderPathFromPSPath( Destination[0] );
            DropboxDriveInfo primaryDrive = dropboxProvider.Drives.Cast<DropboxDriveInfo>().First();

            if ( !ShouldProcess( sourceFile, "Copy-Item" ) )
            {
                return;
            }

            try
            {
                var dropboxPath = DropboxFileHelper.NormalizePath( sourceFile );
                var meta = primaryDrive.Client.GetMetaData( dropboxPath );

                if ( meta.Is_Dir )
                {
                    // We append slashes so that our call to System.IO.Path.GetDirectoryName later works properly.
                    dropboxPath += "\\";
                    var directories = new Stack<MetaData>();
                    directories.Push( meta );

                    while ( directories.Count > 0 )
                    {
                        MetaData dir = primaryDrive.Client.GetMetaData( directories.Pop().Path );
                        if ( dir.Contents == null )
                        {
                            continue;
                        }
                        foreach ( MetaData item in dir.Contents.Where( item => !item.Is_Deleted ) )
                        {
                            if ( item.Is_Dir )
                            {
                                directories.Push( item );
                            }
                            else
                            {
                                item.Path = DropboxFileHelper.NormalizePath( item.Path );

                                var finalDest = destination + "\\" + item.Path.Remove( 0,
                                        System.IO.Path.GetDirectoryName( dropboxPath ).Length )
                                        .Replace( '/', '\\' );

                                DownloadFile( item.Path, finalDest, primaryDrive );
                            }
                        }
                    }
                }
                else
                {
                    DownloadFile( dropboxPath, destination, primaryDrive );
                }
            }
            catch ( DropboxException e )
            {
                ErrorRecord errorRecord = new ErrorRecord(
                        new ArgumentException( "Unable to read Dropbox file '" + sourceFile + "'", e ),
                        "FileReadError",
                        ErrorCategory.InvalidArgument,
                        null );
                ThrowTerminatingError( errorRecord );
            }
        }

        private void DownloadFile( string source, string destination, DropboxDriveInfo drive )
        {
            var fileData = drive.Client.GetFile( source );
            var parentDir = System.IO.Path.GetDirectoryName( destination );

            if ( Directory.Exists( destination ) )
            {
                destination += $"\\{System.IO.Path.GetFileName( source )}";
            }

            if ( !Directory.Exists( parentDir ) )
            {
                Directory.CreateDirectory( parentDir );
            }

            using ( FileStream fs = new FileStream( destination, FileMode.Create ) )
            {
                foreach ( byte t in fileData )
                {
                    fs.WriteByte( t );
                }

                fs.Seek( 0, SeekOrigin.Begin );

                // mismatched values
                if ( fileData.Any( t => t != fs.ReadByte() ) )
                {
                    ErrorRecord errorRecord = new ErrorRecord( new Exception( "Error writing file" ),
                            "Error writing file",
                            ErrorCategory.InvalidOperation,
                            null );

                    ThrowTerminatingError( errorRecord );
                }
            }
        }
    }
}