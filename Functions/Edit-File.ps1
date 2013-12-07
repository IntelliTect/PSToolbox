
Function Open-File([Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][string]$fileName) {
    PROCESS {
        . $fileName
    }
}

#TODO: Resolve name clash with PSCX
Function Edit-File([Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][string]$fileName) {
    PROCESS {
        If(!(Test-Path $fileName)) {
            New-Item -ItemType File $fileName;
        }
        Open-File (Resolve-Path $fileName)
    }
}
Set-Alias Edit Edit-File;