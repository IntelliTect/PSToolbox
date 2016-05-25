[CmdletBinding(
    SupportsShouldProcess=$true #Tells the shell that your function supports both -confirm and -whatif.
    ,ConfirmImpact="High" #Causes Confirm prompt when $ConfirmPreference is "High"
)]
param ()


if (!([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544"))){
    # http://superuser.com/questions/749243/detect-if-powershell-is-running-as-administrator
    throw "Setup.ps1 requires administrative privelages."
}

Function Install-Chocolatey {
    If(!($ENV:ChocolateyInstall)) {
        if ($pscmdlet.ShouldProcess("Install Chocolatey (http://Chocolatey.org)")) {
            Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
            $ENV:ChocolateyInstall="$ENV:Systemdrive\chocolatey\bin"
            $ENV:PATH="$ENV:PATH;$ENV:ChocolateyInstall"

            Set-Alias Nuget "$ENV:ChocolateyInstall\chocolateyInstall\NuGet.exe" -Scope Global
        }
    }
}

#Install PowerShell
If($PSVersionTable.PSVersion -lt "3.0") {
    if ($pscmdlet.ShouldProcess("Install later version of PowerShell using Chocolatey")) {
        Install-Chocolatey
        CINST PowerShell
    }
}

if (!(Get-Module PowerShellGet -ListAvailable)) {
    Write-Host "PowerShellGet is not installed. It can be installed via Chocolatey."
    
    If ($pscmdlet.ShouldProcess("Install PowerShellGet? (https://chocolatey.org/packages/powershell-packagemanagement)")) {
        Install-Chocolatey
        CINST powershell-packagemanagement
    }
}

If(get-module PowerShellGet -ListAvailable) {
    #Install Pester
    If(!(get-module Pester -ListAvailable)) {
        If ($pscmdlet.ShouldProcess("Install Pester (https://github.com/pester/Pester)")) {
            Install-Module Pester -verbose
        }
    }
}
else {
    Write-Error "PowerShellGet was not successfully installed"
}


If(Test-Path variable:\psise) {
    Function Test-CurrentFile {
        Invoke-Pester $psISE.CurrentFile.FullPath.Replace(".Tests","").Replace(".ps1",".Tests.ps1");
    }
    Set-Alias Test Test-CurrentFile
}
