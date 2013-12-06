if(!(Test-Path variable:\psise)) { return; }


Function Close-File ([Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][string] $fileName) {
    PROCESS {
            $ISEFileToRemove = $psISE.CurrentPowerShellTab.Files | ?{$_.FullPath -eq (Resolve-Path $fileName)}
            $psISE.CurrentPowerShellTab.Files.Remove( $ISEFileToRemove ); 
    }
}

Function Open-File([Parameter(Mandatory)][ValidateNotNull()][string]$fileName) {
    start (get-command powershell_ise.exe).Path -Wait $filename #Use start to ensure it is synchronous for testing purposes.
}

 