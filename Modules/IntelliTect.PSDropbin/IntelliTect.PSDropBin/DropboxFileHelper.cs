using Dropbox.Api;
using Dropbox.Api.Files;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation.Provider;
using System.Net;
using System.Text.RegularExpressions;

namespace IntelliTect.PSDropbin
{
    public static class DropboxFileHelper
    {
        public static Action<string> Writer = null;


        private const int _refreshSeconds = 300;

        static DropboxFileHelper()
        {
            _lastRefresh = DateTime.Now;
            _fileCache = new Dictionary<string, MetaData>();
        }

        private static DateTime _lastRefresh = DateTime.MinValue;
        private static Dictionary<string, MetaData> _fileCache = new Dictionary<string, MetaData>();
        private static Dictionary<string, List<MetaData>> _folderCache = new Dictionary<string, List<MetaData>>();

        /// <summary>
        /// Allow for resetting the cache when known changes are made to the file system
        /// </summary>
        public static void ResetCache()
        {
            RevitalizeCache(true);
        }

        /// <summary>
        /// Returns the metadata for a specific path.  Will return from the cache if available or Dropbox.
        /// </summary>
        /// <param name="normalizedPath"></param>
        /// <returns></returns>
        public static MetaData GetItem(string normalizedPath, DropboxClient client)
        {
            RevitalizeCache();

            Writer($"Invoking Helper.GetItem({normalizedPath})");

            try
            {
                if (!_fileCache.ContainsKey(normalizedPath))
                {
                    var metaData = new MetaData(client.Files.GetMetadataAsync(normalizedPath).Result);
                    _fileCache[normalizedPath] = metaData;
                }

                return _fileCache[normalizedPath];
            }
            catch (HttpException he) when (he.StatusCode == (int)HttpStatusCode.NotFound)
            {
                return null;
            }
            catch
            {
                throw;
            }
        }

        public static List<MetaData> GetChildItems(string normalizedPath, DropboxClient client)
        {
            RevitalizeCache();

            try
            {
                if (!_folderCache.ContainsKey(normalizedPath))
                {
                    var folders = client.Files.ListFolderAsync(normalizedPath).Result.Entries.ToList().ConvertAll(md =>
                    {
                        var metaData = new MetaData(md);

                        var normalizedChildPath = NormalizePath(metaData.Path);
                        if (!_fileCache.ContainsKey(normalizedChildPath)) _fileCache.Add(normalizedChildPath, metaData);

                        return metaData;
                    });
                    _folderCache[normalizedPath] = folders;
                }

                return _folderCache[normalizedPath];
            }
            catch (HttpException he) when (he.StatusCode == (int)HttpStatusCode.NotFound)
            {
                return null;
            }
            catch
            {
                throw;
            }
        }

        /// <summary>
        ///     Splits an arbitrary path into its directory and filename.
        /// </summary>
        /// <param name="path">A path string</param>
        /// <returns>A <see cref="PathInfo" /> containing directory and filename information</returns>
        public static Tuple<string, string> GetPathInfo(string normalizedPath)
        {
            var allButLastEntry = "";
            var lastEntry = "";

            var pathParts = normalizedPath.Split(new char[] { '/' }).ToList();

            if (pathParts.Count() > 0) lastEntry = pathParts.Last();
            if (pathParts.Count() > 1)
            {
                pathParts.Reverse();
                pathParts = pathParts.Skip(1).ToList();
                pathParts.Reverse();
                allButLastEntry = string.Join("/", pathParts);
            }

            return new Tuple<string, string>(allButLastEntry, lastEntry);
        }

        // ensures that the cache is updated as necessary
        private static void RevitalizeCache(bool overrideTimeout = false)
        {
            if (overrideTimeout || (DateTime.Now - _lastRefresh).TotalSeconds > _refreshSeconds)
            {
                _fileCache.Clear();
                _lastRefresh = DateTime.Now;
            }
        }

        public static string NormalizePath(string path)
        {
            string result = path.Trim('\\', '/');

            if (!string.IsNullOrEmpty(result))
            {
                result = result.Replace("\\", "/");
            }

            if (!string.IsNullOrEmpty(result)) return $"/{result}";
            return "";
        }
    }
}