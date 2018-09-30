

<#
.SYNOPSIS
Open the file specified, creating a new file if it doesn't exist.
.EXAMPLE
PS C:\> Open-File $env:Temp\temp.txt
Create the temp.txt file in the temp directory (if it doesn't exist) and then open the file using the default editor for a txt file.
#>
Function Open-File() {
    [CmdletBinding()] param(
        # The path to the file to edit.
        [Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][string[]]$path
    )
    PROCESS {
        foreach($item in $path) {
            #Support wildcards
            $files = Get-Item $item
            foreach($file in $files) {
                & $file
            }
        }
    }
}
Set-Alias Open Open-File -Scope Global

# TODO: Publish the fact that a string path implicitly converts to a FileInfo/DirectoryInfo so functions needing files should use [IO.FileInfo]/[IO.DirectoryInfo]

<#TODO: Resolve name clash with PSCX
    Add support so that PSCX create the file if it doesn't exist
    Set PSCX to use ISE as the editor when running inside ISE (This can be done
        by setting the $Pscx:Preferences['TextEditor'] variable.)
    Consider dynamically editing the PSCX:Edit-File and replacing the definition
        of EditFileImpl with the Edit-File function below.
#>
if(Test-Path Function:Edit-File) {
    if ( (Test-Path Function:Edit-File) -and ((Get-Item Function:Edit-File).ModuleName -eq "PSCX") -and (!(Test-Path Function:Edit-File_PSCX)) ) {
        #dir function: | ?{$_.ModuleName -eq "pscx" }
        Rename-Item Function:Edit-File Edit-File_PSCX
    }
    else {
        Remove-Item Function:Edit-File -Force
    }
}


<#
.SYNOPSIS
Open the file specified, creating a new file if it doesn't exist.
.EXAMPLE
PS C:\> Edit-File $env:Temp\temp.txt
Create the temp.txt file in the temp directory (if it doesn't exist) and then open the file using the default editor for a txt file.
#>
Function Edit-File() {
    [CmdletBinding()] param(
        # The path to the file to edit.
        [Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][IO.FileInfo]$path
    )
    PROCESS {
        If(!(Test-Path $path)) {
            New-Item -ItemType File $path;
        }
        Open-File (Resolve-Path $path)
    }
}
Set-Alias Edit Edit-File -Scope Global
Set-Item "Function:Edit-File" -Options "ReadOnly" #Used to prevent the PSCX module from overriding
                                                  # this function but causes an error to occur when
                                                  # PSCX loads.  Use remove-item with -force to remove
                                                  # the function.

Function Test-FileIsLocked {
    [CmdletBinding()]
    ## Attempts to open a file and trap the resulting error if the file is already open/locked
    param ([string]$filePath )
    $filelocked = $false
    try {
        $fileInfo = New-Object System.IO.FileInfo $filePath
        $fileStream = $fileInfo.Open( [System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None )
    }
    catch {
        $filelocked = $true
    }
    finally {
        if ($fileStream) {
            $fileStream.Close()
        }
    }

    return $filelocked
}

<#
.SYNOPSIS
Converts files to the given encoding.
Matches the include pattern recursively under the given path.

.EXAMPLE
Convert-FileEncoding -Include *.js -Path scripts -Encoding UTF8
#>
Function Set-FileEncoding {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string[]]$Path,
    [ValidateSet("Unknown","String","Unicode","Byte","BigEndianUnicode","UTF8","UTF7","ASCII")][Parameter(Mandatory)]$Encoding="UTF8",
    [switch]$Force
  )

    $Path | Get-Item | Where-Object{
        $currentEncoding = $(Get-FileEncoding $_.FullName)
        if(!$Force -and ($currentEncoding -eq $Encoding)) {
            Write-Warning "The endocing for '$($_.Fullname)' is already '$Encoding'"
            Write-Output $false
        } else {
            $message = "Converting $($_.Fullname) from '$currentEncoding' to '$Encoding'"
            Write-Output $PSCmdlet.ShouldProcess($message, $message, "Set-FileEndocing")
        }
    } | ForEach-Object {
        $item = $_.FullName
        (Get-Content -Path $item) |  Set-Content -Encoding $Encoding -Path $item
  }
}

# http://franckrichard.blogspot.com/2010/08/powershell-get-encoding-file-type.html
<#
.SYNOPSIS
Gets file encoding.

.DESCRIPTION
The Get-FileEncoding function determines encoding by looking at Byte Order Mark (BOM).
Based on port of C# code from http://www.west-wind.com/Weblog/posts/197245.aspx

.EXAMPLE
Get-ChildItem  *.ps1 | select FullName, @{n='Encoding';e={Get-FileEncoding $_.FullName}} | where {$_.Encoding -ne 'ASCII'}
This command gets ps1 files in current directory where encoding is not ASCII

.EXAMPLE
Get-ChildItem  *.ps1 | select FullName, @{n='Encoding';e={Get-FileEncoding $_.FullName}} | where {$_.Encoding -ne 'ASCII'} | foreach {(get-content $_.FullName) | set-content $_.FullName -Encoding ASCII}
Same as previous example but fixes encoding using set-content


# Modified by F.RICHARD August 2010
# add comment + more BOM
# http://unicode.org/faq/utf_bom.html
# http://en.wikipedia.org/wiki/Byte_order_mark
#
# Do this next line before or add function in Profile.ps1
# Import-Module .\Get-FileEncoding.ps1
#>
Function Get-FileEncoding
{
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
    [string]$Path
  )

  [byte[]]$byte = Get-Content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path
  #Write-Host Bytes: $byte[0] $byte[1] $byte[2] $byte[3]

  # EF BB BF (UTF8)
  if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf )
  { Write-Output 'UTF8' }

  # FE FF  (UTF-16 Big-Endian)
  elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff)
  { Write-Output 'Unicode UTF-16 Big-Endian' }

  # FF FE  (UTF-16 Little-Endian)
  elseif ($byte[0] -eq 0xff -and $byte[1] -eq 0xfe)
  { Write-Output 'Unicode UTF-16 Little-Endian' }

  # 00 00 FE FF (UTF32 Big-Endian)
  elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff)
  { Write-Output 'UTF32 Big-Endian' }

  # FE FF 00 00 (UTF32 Little-Endian)
  elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff -and $byte[2] -eq 0 -and $byte[3] -eq 0)
  { Write-Output 'UTF32 Little-Endian' }

  # 2B 2F 76 (38 | 38 | 2B | 2F)
  elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76 -and ($byte[3] -eq 0x38 -or $byte[3] -eq 0x39 -or $byte[3] -eq 0x2b -or $byte[3] -eq 0x2f) )
  { Write-Output 'UTF7'}

  # F7 64 4C (UTF-1)
  elseif ( $byte[0] -eq 0xf7 -and $byte[1] -eq 0x64 -and $byte[2] -eq 0x4c )
  { Write-Output 'UTF-1' }

  # DD 73 66 73 (UTF-EBCDIC)
  elseif ($byte[0] -eq 0xdd -and $byte[1] -eq 0x73 -and $byte[2] -eq 0x66 -and $byte[3] -eq 0x73)
  { Write-Output 'UTF-EBCDIC' }

  # 0E FE FF (SCSU)
  elseif ( $byte[0] -eq 0x0e -and $byte[1] -eq 0xfe -and $byte[2] -eq 0xff )
  {Write-Output 'SCSU' }

  # FB EE 28  (BOCU-1)
  elseif ( $byte[0] -eq 0xfb -and $byte[1] -eq 0xee -and $byte[2] -eq 0x28 )
  { Write-Output 'BOCU-1' }

  # 84 31 95 33 (GB-18030)
  elseif ($byte[0] -eq 0x84 -and $byte[1] -eq 0x31 -and $byte[2] -eq 0x95 -and $byte[3] -eq 0x33)
  { Write-Output 'GB-18030' }

  else
  { Write-Output 'ASCII' }
}

if(($PSVersionTable.PSEdition -eq 'Desktop') -and ($PSVersionTable.Clrversion.Major -ge 4)) {
    <#
    The current implementation only works with Windows Recycle bin from Full Framework
    PowerShell (not PowerShell Core).  In the future, Core (MacOs/Linux) support can be
    added (checking for $home/.Trash directory for example)
    ($env:OS -like 'Windows*') is anothe potential test (which doesn't work with PowerShell Core)
    To avoid using the Microsfot.VisualBasic assembly, the recycle bin is located
    within c:\$Recycle.Bin but it is still necessary to determine the SSID of the user.
    #>
Function Remove-FileToRecycleBin {
[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='Path')]
        # The file(s) to be moved to the recyle bin. TODO: Add support for wild cards.
    param (
        [ValidateScript({ Test-Path $_ })]
        [Parameter(ParameterSetName='Path', Mandatory=$true, Position, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("FullName")]
        [string[]]
        $Path,

        [Parameter(ParameterSetName='LiteralPath', Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('PSPath')]
        [string[]]
        $LiteralPath
    )
    BEGIN {
        Add-Type -AssemblyName Microsoft.VisualBasic
        try {
            [System.Reflection.Assembly]::GetAssembly([Microsoft.VisualBasic.FileIO.FileSystem])
        }
        catch {
            throw 'Unable to load Microsoft.VisualBasic.FileIO.FileSystem. It is like due to lack of support by the OS/platform.'
        }
#        switch($pscmdlet.parametersetname) {
#            'filesysteminfo' {
#                $path = $fileinfo.fullname
#            }
#            'literalpath' {
#                $path = $literalpath
#            }
#        }
    }
    PROCESS {

            $item = Resolve-Path @PSBoundParameters
            $item | %{
            if ($PSCmdlet.ShouldProcess(
                    #TODO: Change to use ShouldProcess from IntelliTect.Common module
                    "Moving $item to the Recycle Bin'",
                    "Moving $item to the Recycle Bin'",
                    "Moving $item to the Recycle Bin'"
                )) {
                Write-Verbose "Moving '$item' to the Recycle Bin"
                if(Test-Path -LiteralPath $item -PathType Container) {
                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($item,'OnlyErrorDialogs','SendToRecycleBin')
                }
                else {
                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($item,'OnlyErrorDialogs','SendToRecycleBin')
                }
            }
        }
    }
}
}

#ToDo: Move to IntelliTect.Item module
Filter Test-ItemIsEmpty{
    [CmdletBinding()]
    param(
        [ValidateScript({Test-Path $_ -PathType Container})][Parameter(Mandatory,ValueFromPipeLine)]
        [string[]]$path
    )
    
    PROCESS {
        $path | Foreach-Object {
            Write-Output ((Get-ChildItem $path -Force | Measure | % Count) -eq 0)
        }
    }
}


if(($PSVersionTable.PSEdition -eq 'Desktop') -and ($PSVersionTable.Clrversion.Major -ge 4)) {
    # Using robocopy so execution is only supported on Windows
Function Remove-FileSystemItemForcibly {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
    param(
        # TODO: Add support for files by parsing the path into directory and filter.  If item is a file, then $filter should not be set
        [ValidateScript({ Test-Path $_ -PathType Container})][Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
            [Alias('FullName')][string[]]$path,
        [string[]]$filter='*'
    )
    PROCESS {
        $path | ForEach-Object{
            $deleteTarget = Resolve-Path $_.TrimEnd([System.IO.Path]::DirectorySeparatorChar).TrimEnd([System.IO.Path]::AltDirectorySeparatorChar)
            [string]$tempDirectory = "$env:temp\ForceDelete"
            $filter | ForEach-Object {
                [string]$eachFilter = $_
                [string]$activity = "'$(Join-Path $deleteTarget $eachFilter)'"
                if ($PSCmdlet.ShouldProcess($activity)) {
                    Write-Progress -Activity 'Enumerating items to be deleted...'
                    $totalItemCount = Get-ChildItem $deleteTarget $eachFilter -Force -Recurse -ErrorAction SilentlyContinue | measure | % Count
                    if($totalItemCount -gt 0) {
                        try {
                            New-Item -ItemType Directory $tempDirectory | Out-Null
                            [long]$removedItemCount=0
                            robocopy /MT /MIR /NS /NC $tempDirectory $deleteTarget $filter  | ForEach-Object {
                                if($_[-1] -in [System.IO.Path]::DirectorySeparatorChar,[System.IO.Path]::AltDirectorySeparatorChar) {
                                    # Use Math.Min() because Robocopy might find more items then Get-ChildItem -Recurse which
                                    # has ErrorAction of SilentlyContinue (so as not to show security/long file errors) so items might have been missed.
                                    Write-Progress  -Activity "Removing $activity ($totalItemCount items)" -Status  "Removing sub-directory '$($_.Trim())'... (item $removedItemCount)" -PercentComplete ([System.Math]::Min($removedItemCount,$totalItemCount)/$totalItemCount)
                                }
                                Write-Verbose "Deleting '$($_.Trim())'..."
                                ($removedItemCount++) | Out-Null
                            }
                        }
                        finally {
                            Get-Item $tempDirectory | Remove-Item -Force -Recurse
                        }
                    }
                    if(Test-ItemIsEmpty $deleteTarget) {
                        Remove-Item $deleteTarget -Force
                    }
                }
            }
        }
    }
}
}


# TODO: Add functions below
# See https://github.com/MarkMichaelis/Private/blob/InitialMachineSetup/Install-Dropbox.ps1 for
#   Function Set-ItemShortName 
#   Function Close-OpenFileHandle
#   Function Get-ShortName
#   Function Compare-Path
#   Function Move-ItemWithOpenHandles
#   Function Copy-Acl 
