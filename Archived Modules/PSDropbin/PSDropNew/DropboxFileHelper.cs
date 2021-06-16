using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using DropNet.Models;

namespace IntelliTect.PSDropbin
{
    public static class DropboxFileHelper
    {
        private const int RefreshSeconds = 2;

        static DropboxFileHelper()
        {
            LastRefresh = DateTime.Now;
            Cache = new Dictionary<string, List<string>>();
        }

        private static DateTime LastRefresh { get; set; }
        private static Dictionary<string, List<string>> Cache { get; }
        // returns whether an item exists or not, but also caches files in the same directory to decrease API calls
        public static bool ItemExists( string path, Func<string, IEnumerable<MetaData>> getItems )
        {
            RevitalizeCache();
            var info = GetPathInfo( path );

            if ( !Cache.ContainsKey( info.Directory ) )
            {
                Cache[info.Directory] = new List<string>( getItems( info.Directory ).Select( x => x.Name ) );
            }

            return Cache[info.Directory].Any( x => x.Equals( info.Name, StringComparison.InvariantCultureIgnoreCase ) );
        }

        /// <summary>
        ///     Splits an arbitrary path into its directory and filename.
        /// </summary>
        /// <param name="path">A path string</param>
        /// <returns>A <see cref="PathInfo" /> containing directory and filename information</returns>
        public static PathInfo GetPathInfo( string path )
        {
            path = NormalizePath( path );

            PathInfo info = new PathInfo();
            Match match = Regex.Match( path, @"((?:[^\/]+\/)+)(.+)" );

            info.Directory = match.Groups[1].Value.TrimEnd( '/' );
            info.Name = match.Groups[2].Value;

            // if we are perusing the root the regex will be useless
            if ( string.IsNullOrEmpty( info.Directory ) &&
                 string.IsNullOrEmpty( info.Name ) )
            {
                info.Name = path.Trim( '/', '\\' );
            }

            return info;
        }

        // ensures that the cache is updated as necessary
        private static void RevitalizeCache()
        {
            if ( ( DateTime.Now - LastRefresh ).TotalSeconds > RefreshSeconds )
            {
                Cache.Clear();
                LastRefresh = DateTime.Now;
            }
        }

        public static string NormalizePath( string path )
        {
            string result = path.TrimStart( '\\', '/' );

            if ( !string.IsNullOrEmpty( result ) )
            {
                result = result.Replace( "\\", "/" );
            }

            return result;
        }
    }

    public struct PathInfo
    {
        public string Directory;
        public string Name;
    }
}