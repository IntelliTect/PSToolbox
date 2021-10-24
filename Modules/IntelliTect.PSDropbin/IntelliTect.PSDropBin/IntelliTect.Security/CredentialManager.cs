using System;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;
using System.Management.Automation.Provider;

namespace IntelliTect.Security
{
    public static class CredentialManager
    {
        public static int WriteCredential(string key, string secret)
        {
            // Validations.

            byte[] byteArray = Encoding.Unicode.GetBytes(secret);
            if (byteArray.Length > 512)
            {
                throw new ArgumentOutOfRangeException("The secret message has exceeded 512 bytes.");
            }

            // Go ahead with what we have are stuff it into the CredMan structures.
            Credential cred = new Credential
            {
                TargetName = key,
                UserName = "psdropbin",
                CredentialBlob = secret,
                CredentialBlobSize = (UInt32)Encoding.Unicode.GetBytes(secret).Length,
                AttributeCount = 0,
                Attributes = IntPtr.Zero,
                Comment = null,
                TargetAlias = null,
                Type = CRED_TYPE.GENERIC,
                Persist = CRED_PERSIST.ENTERPRISE
            };

            NativeCredential ncred = NativeCredential.GetNativeCredential(cred);
            // Write the info into the CredMan storage.
            bool written = NativeMethods.CredWrite(ref ncred, 0);
            int lastError = Marshal.GetLastWin32Error();
            if (written)
            {
                return 0;
            }
            string message = $"CredWrite failed with the error code {lastError}.";
            throw new Exception(message);
        }

        public static string ReadCredential(string key)
        {
            IntPtr nCredPtr;
            string result;

            // Make the API call using the P/Invoke signature
            bool read = NativeMethods.CredRead(key, CRED_TYPE.GENERIC, 0, out nCredPtr);
            int lastError = Marshal.GetLastWin32Error();

            // If the API was successful then...
            if (read)
            {
                using (CriticalCredentialHandle critCred = new CriticalCredentialHandle(nCredPtr))
                {
                    Credential cred = critCred.GetCredential();
                    result = cred.CredentialBlob;
                }
                
            }
            else
            {
                //1168 is "element not found" -- ignore that one and return empty string:
                if (lastError != 1168)
                {
                    string message = $"ReadCred failed with the error code {lastError}.";
                    throw new Exception(message);
                }
                result = null;
            }
            return result;
        }

        public static bool DeleteCredential(string key)
        {
            // Make the API call using the P/Invoke signature
            bool read = NativeMethods.CredDelete(key, CRED_TYPE.GENERIC, 0);
            int lastError = Marshal.GetLastWin32Error();

            // If the API was successful then...
            if (!read)
            {
                if (lastError != 1168)
                {
                    string message = $"DeleteCred failed with the error code {lastError}.";
                    throw new Exception(message);
                }
                return false;
            }
            return true;
        }

        private enum CRED_PERSIST : uint
        {
            SESSION = 1,
            LOCAL_MACHINE = 2,
            ENTERPRISE = 3
        }

        private enum CRED_TYPE : uint
        {
            GENERIC = 1,
            DOMAIN_PASSWORD = 2,
            DOMAIN_CERTIFICATE = 3,
            DOMAIN_VISIBLE_PASSWORD = 4,
            GENERIC_CERTIFICATE = 5,
            DOMAIN_EXTENDED = 6,
            MAXIMUM = 7, // Maximum supported cred type
            MAXIMUM_EX = (MAXIMUM + 1000) // Allow new applications to run on old OSes
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct Credential
        {
            public UInt32 Flags;
            public CRED_TYPE Type;
            public string TargetName;
            public string Comment;
            public readonly System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
            public UInt32 CredentialBlobSize;
            public string CredentialBlob;
            public CRED_PERSIST Persist;
            public UInt32 AttributeCount;
            public IntPtr Attributes;
            public string TargetAlias;
            public string UserName;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct NativeCredential : IDisposable
        {
            public readonly UInt32 Flags;
            public CRED_TYPE Type;
            public IntPtr TargetName;
            public IntPtr Comment;
            public readonly System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
            public UInt32 CredentialBlobSize;
            public IntPtr CredentialBlob;
            public UInt32 Persist;
            public UInt32 AttributeCount;
            public IntPtr Attributes;
            public IntPtr TargetAlias;
            public IntPtr UserName;

            /// <summary>
            ///     This method derives a NativeCredential instance from a given Credential instance.
            /// </summary>
            /// <param name="credential">The managed Credential counterpart containing data to be stored.</param>
            /// <returns>
            ///     A NativeCredential instance that is derived from the given Credential
            ///     instance.
            /// </returns>
            internal static NativeCredential GetNativeCredential(Credential credential)
            {
                NativeCredential nativeCredential = new NativeCredential();
                nativeCredential.AttributeCount = 0;
                nativeCredential.Attributes = IntPtr.Zero;
                nativeCredential.Comment = IntPtr.Zero;
                nativeCredential.TargetAlias = IntPtr.Zero;
                nativeCredential.Type = credential.Type;
                nativeCredential.Persist = (UInt32)credential.Persist;
                nativeCredential.CredentialBlobSize = credential.CredentialBlobSize;
                nativeCredential.TargetName = Marshal.StringToCoTaskMemUni(credential.TargetName);
                nativeCredential.CredentialBlob = Marshal.StringToCoTaskMemUni(credential.CredentialBlob);
                nativeCredential.UserName = Marshal.StringToCoTaskMemUni(credential.UserName);
                return nativeCredential;
            }

            public void Dispose()
            {
                Dispose(true);
                GC.SuppressFinalize(this);
            }

            public void Dispose(bool disposing)
            {
                if (disposing)
                {
                    // Release managed resources.
                }

                // Free the unmanaged resource ...

                Attributes = IntPtr.Zero;
                Comment = IntPtr.Zero;
                CredentialBlob = IntPtr.Zero;
                TargetAlias = IntPtr.Zero;
                TargetName = IntPtr.Zero;
                UserName = IntPtr.Zero;
            }

            //~NativeCredential()
            //{
            //    Dispose(false);
            //}
        }

        private static class NativeMethods
        {
            [DllImport("Advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
            public static extern bool CredRead(string target,
                    CRED_TYPE type,
                    int reservedFlag,
                    out IntPtr CredentialPtr);

            [DllImport("Advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
            public static extern bool CredWrite([In] ref NativeCredential userCredential, [In] UInt32 flags);

            [DllImport("Advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
            public static extern bool CredDelete([In] string target, [In] CRED_TYPE type, [In] UInt32 flags);

            [DllImport("Advapi32.dll", EntryPoint = "CredFree", SetLastError = true)]
            public static extern bool CredFree([In] IntPtr cred);
        }

        #region Critical Handle Type definition

        private sealed class CriticalCredentialHandle : CriticalHandleZeroOrMinusOneIsInvalid
        {
            // Set the handle.
            internal CriticalCredentialHandle(IntPtr preexistingHandle)
            {
                SetHandle(preexistingHandle);
            }

            internal Credential GetCredential()
            {
                if (!IsInvalid)
                {
                    // Get the Credential from the mem location
                    NativeCredential ncred = (NativeCredential)Marshal.PtrToStructure(handle,
                            typeof(NativeCredential));

                    // Create a managed Credential type and fill it with data from the native counterpart.
                    Credential cred = new Credential
                    {
                        CredentialBlobSize = ncred.CredentialBlobSize,
                        CredentialBlob = Marshal.PtrToStringUni(ncred.CredentialBlob,
                                (int)ncred.CredentialBlobSize / 2),
                        UserName = Marshal.PtrToStringUni(ncred.UserName),
                        TargetName = Marshal.PtrToStringUni(ncred.TargetName),
                        TargetAlias = Marshal.PtrToStringUni(ncred.TargetAlias),
                        Type = ncred.Type,
                        Flags = ncred.Flags,
                        Persist = (CRED_PERSIST)ncred.Persist
                    };
                    return cred;
                }
                throw new InvalidOperationException("Invalid CriticalHandle!");
            }

            // Perform any specific actions to release the handle in the ReleaseHandle method.
            // Often, you need to use Pinvoke to make a call into the Win32 API to release the 
            // handle. In this case, however, we can use the Marshal class to release the unmanaged memory.

            protected override bool ReleaseHandle()
            {
                // If the handle was set, free it. Return success.
                if (!IsInvalid)
                {
                    // NOTE: We should also ZERO out the memory allocated to the handle, before free'ing it
                    // so there are no traces of the sensitive data left in memory.
                    NativeMethods.CredFree(handle);
                    // Mark the handle as invalid for future users.
                    SetHandleAsInvalid();
                    return true;
                }
                // Return false. 
                return false;
            }
        }

        #endregion
    }
}