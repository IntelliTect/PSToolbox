[CmdletBinding(
    SupportsShouldProcess=$true #Tells the shell that your function supports both -confirm and -whatif.
    ,ConfirmImpact="High" #Causes Confirm prompt when $ConfirmPreference is "High"
)]
param ()

#Install PsGet
If(!(get-module PsGet -ListAvailable)) {
    If ($pscmdlet.ShouldProcess("Install PsGet (http://psget.net)")) {
        (new-object Net.WebClient).DownloadString("http://psget.net/GetPsGet.ps1") | Invoke-Expression
    }
}

If(!($ENV:ChocolateyInstall)) {
    if ($pscmdlet.ShouldProcess("Install Chocolatey (http:\\Chocolatey.org)")) {
        Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
        $ENV:ChocolateyInstall="$ENV:Systemdrive\chocolatey\bin"
        $ENV:PATH="$ENV:PATH;$ENV:ChocolateyInstall"
    }
}

#Install PowerShell
If($PSVersionTable.PSVersion -lt "3.0") {
    if ($pscmdlet.ShouldProcess("Install later version of PowerShell using Chocolatey")) {
        CINST PowerShell
    }
}



If(get-module PsGet -ListAvailable) {
    #ToDo: Refactor into Install-ModuleFromChocolatey
    If(!(get-module Pscx -ListAvailable)) {
        If ($pscmdlet.ShouldProcess("Install PSCX (http:\\pscx.codeplex.com)")) {
            Install-Module PSCX -verbose
        }
    }

    #Install Pester
    If(!(get-module Pester -ListAvailable)) {
        If ($pscmdlet.ShouldProcess("Install PSCX (http:\\pscx.codeplex.com)")) {
            Install-Module Pester -verbose
        }
    }

    #TODO: Install TFS PowerTools but the chocolatey pacakage appears to be out of date -http://chocolatey.org/packages/tfpt
}

If(!(Test-Path ENV:VSINSTALLDIR)) {
    . $PSScriptRoot\Functions\Import-VisualStudioVars.ps1
    Import-VisualStudioVars
}

Function Submit-Scc ([string]$Comment, $Filter = (Get-Location), [switch]$Recursive=$true ) {
    Invoke-Expression "TF.EXE Status $Filter $(if($Recursive){"/Recursive"})"
    if(!$comment) {  $comment = (Read-Host "Enter comments")}
    Invoke-Expression "TF.exe Checkin $Filter /comment:`"$comment`" $(if($Recursive){"-Recursive"})"
}
Set-Alias TfCheckin Submit-Scc


Function Get-Scc ($Filter = (Get-Location), [switch]$Recursive=$true ) {
    Invoke-Expression "TF.exe Get $Filter $(if($Recursive){"-Recursive"})"
}
Set-Alias TfGet Get-Scc

If(Test-Path variable:\psise) {
    Function Test-CurrentFile {
        Invoke-Pester $psISE.CurrentFile.FullPath.Replace(".Tests","").Replace(".ps1",".Tests.ps1");
    }
    Set-Alias Test Test-CurrentFile
}
#dir .\,.\Functions,.\Functions.Tests *.ps1 | ?{ $_.Name -notlike "*disk*" -AND $_.Name -notlike "__*" } | %{ edit $_.FullName }
#$psISE.CurrentPowerShellTab.DisplayName = "PSIdeation"

Set-Alias Nuget "$ENV:ChocolateyInstall\chocolateyInstall\NuGet.exe" -Scope Global


import-module (Join-Path $PSScriptRoot "PSIdeation.psm1") -Verbose