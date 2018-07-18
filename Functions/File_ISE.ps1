If(!(Test-Path variable:\psise)) { Return; }

. $PSScriptRoot\Program.ps1

Function Close-File ([Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][string] $fileName) {
    PROCESS {
            $ISEFileToRemove = $psISE.CurrentPowerShellTab.Files | ?{$_.FullPath -eq (Resolve-Path $fileName)}
            $psISE.CurrentPowerShellTab.Files.Remove( $ISEFileToRemove ); 
    }
}
Set-Alias Close Close-File -Scope Global

Function Open-File([Parameter(ValueFromPipeline=$true,Mandatory)][ValidateNotNull()][string[]]$path) {
PROCESS {
    foreach($item in $path) {
        #Support wildcards
        $files = Get-Item $item
        foreach($file in $files) {
            try {
                $extension = [IO.Path]::GetExtension($file)
                $fileType = Get-FileAssociation $extension -ErrorAction Ignore;
            }
            catch [System.Management.Automation.RuntimeException] { <# Ignore #> }
            if( $fileType -and ($fileType.FileType -match "Microsoft\.PowerShell.*|txtfile|batfile") -or ($extension -in ".tmp",".nuspec") -or ($fileType -eq $null <# extension unknown #>) ) {
                #ISE $file;
                Start-Process (get-command powershell_ise.exe).Path -ArgumentList "-File `"$file`"" -Wait #Use start to ensure it is synchronous for testing purposes.
            }
            else {
                & $file
            }
        }
    }
}}
Set-Alias Open Open-File -Scope Global
 