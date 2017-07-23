

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
Removes a directory including one with a path exceeding 260 characters.
.EXAMPLE
PS C:\> Remove-Item $env:Temp\SampleDirectory
Deletes the $env:Temp\SampleDirectory directory.
#>
Function Remove-Directory {
    param(
        [ValidateScript({Test-Path $_ -PathType �Container�})] 
        $directory
    )

    $tempDir = [System.IO.Path]::GetTempPath()
    New-Item $tempDir -ItemType Directory

    robocopy $tempDir $directory /MIR;
    Remove-Item $directory -Recurse -Force
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
