[CmdletBinding(
    SupportsShouldProcess=$true #Tells the shell that your function supports both -confirm and -whatif.
    ,ConfirmImpact="High" #Causes Confirm prompt when $ConfirmPreference is "High"
)]
param ()

#Install Chocolatey
If(!($ENV:ChocolateyInstall)) {
    if ($pscmdlet.ShouldProcess("Install Chocolatey (http:\\Chocolatey.org)")) {
        Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

#Install Pester
If(!(Get-ChildItem "$ENV:ChocolateyInstall\lib\Pester*" Pester.psm1 -Recurse)) {
    If ($pscmdlet.ShouldProcess("Install Pester (https://github.com/pester/Pester)")) {
        CINST Pester
    }
}
Get-ChildItem "$ENV:ChocolateyInstall\lib\Pester*" Pester.psm1 -Recurse | Select-Object -Last 1 | Import-Module -Verbose

Function Checkin {
    TF.exe "Checkin" $pwd -recursive
}