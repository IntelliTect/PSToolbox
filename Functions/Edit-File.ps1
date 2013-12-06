
Function Open-File([Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][string]$fileName) {
    PROCESS {
        . $fileName
    }
}

Function Edit-File([Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][string]$fileName) {
    PROCESS {
        If(!(Test-Path $fileName)) {
            New-Item -ItemType File $fileName;
        }
        type function:\Open-File
        Open-File (Resolve-Path $fileName)
    }
}
Set-Alias Edit Edit-File;