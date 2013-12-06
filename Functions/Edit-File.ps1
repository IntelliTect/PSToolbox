Function Edit-File([Parameter(Mandatory)][ValidateNotNull()][string]$fileName) {
    If(!(Test-Path $fileName)) {
        New-Item -ItemType File $fileName;
    }
    Open-File (Resolve-Path $fileName)
}
Set-Alias Edit Edit-File;