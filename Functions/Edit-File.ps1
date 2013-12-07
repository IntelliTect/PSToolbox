
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
Set-Item "Function:Edit-File" -Options "ReadOnly" #Used to prevent the PSCX module from overriding 
                                                  # this function but causes an error to occur when 
                                                  # PSCX loads.  Use -force or remove-item to override
                                                  # the read only flag.