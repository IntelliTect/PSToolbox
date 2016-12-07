[CmdletBinding(
    SupportsShouldProcess=$true #Tells the shell that your function supports both -confirm and -whatif.
    ,ConfirmImpact="High" #Causes Confirm prompt when $ConfirmPreference is "High"
)]
param ()


if (!([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544"))){
    # http://superuser.com/questions/749243/detect-if-powershell-is-running-as-administrator
    throw "Setup.ps1 requires administrative privelages."
}


#Install Pester
If(!(get-module Pester -ListAvailable)) {
    If ($pscmdlet.ShouldProcess("Install Pester (https://github.com/pester/Pester)")) {
        Install-Module Pester -verbose
    }
}

$PSToolboxPath = Join-path $PSScriptRoot Modules
if(!($env:PSModulePath -like "*$PSToolboxPath*")) {
    [System.Environment]::SetEnvironmentVariable( "PSModulePath", "$PSToolboxPath;$env:PSModulePath", [EnvironmentVariableTarget]::User );
    $PSToolboxPath="$PSToolboxPath;$env:PSModulePath"
    if(!($env:PSModulePath -like "*$PSToolboxPath*")) {
        throw "PSModulePath not set with $PSToolboxPath"  #NOTE: This does not test the change from [System.Environment]::SetEnvironmentVariable is permanent.
    }
}



If(Test-Path variable:\psise) {
    Function Test-CurrentFile {
        Invoke-Pester $psISE.CurrentFile.FullPath.Replace(".Tests","").Replace(".ps1",".Tests.ps1");
    }
    Set-Alias Test Test-CurrentFile
}
