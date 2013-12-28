
Function Open-File([Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][string]$fileName) {
    PROCESS {
        . $fileName
    }
}

# TODO: Publish the fact that a string path implicitly converts to a FileInfo/DirectoryInfo so functions needing files should use [IO.FileInfo]/[IO.DirectoryInfo]

<#TODO: Resolve name clash with PSCX
    Add support so that PSCX create the file if it doesn't exist
    Set PSCX to use ISE as the editor when running inside ISE (This can be done
        by setting the $Pscx:Preferences['TextEditor'] variable.)
    Consider dynamically editing the PSCX:Edit-File and replacing the definition
        of EditFileImpl with the Edit-File function below.
#>      
if( (Test-Path Function:Edit-File) -AND ((Get-Item Function:Edit-File).ModuleName -eq "PSCX")) {
    #dir function: | ?{$_.ModuleName -eq "pscx" }
    Rename-Item Function:Edit-File PSCX:Edit-File
}

#TODO: Dir .\ *.txt -recurse | Edit-File creates files rather than using the files in the sub directories

Function Edit-File([Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][IO.FileInfo]$fileName)  {
    PROCESS {
        If(!(Test-Path $fileName)) {
            New-Item -ItemType File $fileName;
        }
        Open-File (Resolve-Path $fileName)
    }
}
Set-Alias Edit Edit-File;
Set-Item "Function:Edit-File" -Options "ReadOnly" #Used to prevent the PSCX module from overriding 
                                                  # this function but causes an error to occur when 
                                                  # PSCX loads.  Use remove-item with -force to remove
                                                  # the function.
