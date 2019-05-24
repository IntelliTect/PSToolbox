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

if(-not (Test-Path Function:Set-EnvironmentVariable)) {
Function Set-EnvironmentVariable {
     [CmdletBinding(SupportsShouldProcess)]
     param(
          [ValidateScript({-not [string]::IsNullOrWhiteSpace($_)})][Parameter(Mandatory)][string]$Name,
          [Parameter(Mandatory)][string]$Value,
          [ValidateSet('User','Machine')][string]$Scope='User'
     )

     [string]$scopeArgs = $null
     if($Scope -eq 'Machine') {
         $scopeArgs = '/M'
     }
     setx.exe $Name $Value $scopeArgs | Out-Null
     Set-Item -Path Env:$Name -Value $Value
 }
}

 $PSToolboxPath=Join-Path $PSScriptRoot Modules
if(!($env:PSModulePath -like "*$PSToolboxPath*")) {
    Set-EnvironmentVariable -Name PSModulePath -Value "$PSToolboxPath;$env:PSModulePath" 
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
