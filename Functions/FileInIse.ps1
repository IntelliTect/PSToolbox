If(!(Test-Path variable:\psise)) { Return; }

Function Close-File ([Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][string] $fileName) {
    PROCESS {
            $ISEFileToRemove = $psISE.CurrentPowerShellTab.Files | ?{$_.FullPath -eq (Resolve-Path $fileName)}
            $psISE.CurrentPowerShellTab.Files.Remove( $ISEFileToRemove ); 
    }
}

Function Open-File([Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][string]$fileName) {
    PROCESS {
        Start-Process (get-command powershell_ise.exe).Path -ArgumentList "-File `"$filename`"" -Wait #Use start to ensure it is synchronous for testing purposes.
    }
}

 