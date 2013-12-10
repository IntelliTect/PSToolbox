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

#Install Chocolatey
#If(!($ENV:ChocolateyInstall)) {
#    if ($pscmdlet.ShouldProcess("Install Chocolatey (http:\\Chocolatey.org)")) {
#        Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
#        $ENV:ChocolateyInstall="$ENV:Systemdrive\chocolatey\bin"
#        $ENV:PATH="$ENV:PATH;$ENV:ChocolateyInstall"
#    }
#}

If(!(get-module PsGet -ListAvailable)) {
    #ToDo: Refactor into Install-ModuleFromChocolatey
    If(!(get-module Pscx -ListAvailable)) {
        If ($pscmdlet.ShouldProcess("Install PSCX (http:\\pscx.codeplex.com)")) {
            Install-Module PSCX
        }
    }

    #Install Pester
    If(!(get-module Pester -ListAvailable)) {
        If ($pscmdlet.ShouldProcess("Install PSCX (http:\\pscx.codeplex.com)")) {
            Install-Module Pester
        }
    }

    #TODO: Install TFS PowerTools but the chocolatey pacakage appears to be out of date -http://chocolatey.org/packages/tfpt
}

#TODO: Move into a function file.
#If(!(Test-Path Function:Import-VsCommandLine)) {
#    function Get-Batchfile ($file) {
#        $cmd = "`"$file`" & set"
#        cmd /c $cmd | Foreach-Object {
#            $p, $v = $_.split('=')
#            Set-Item -path env:$p -value $v
#        }
#    }
#    function Import-VsCommandLine()
#    {
#        $VSCOMNTOOLS = (Get-Item "env:vs*comntools" | select -last 1).Value
#        $batchFile = Join-Path $VSCOMNTOOLS "vsvars32.bat"
#        Get-Batchfile $BatchFile
#    }
#    Import-VsCommandLine
#}



Function TfCheckin ([string]$comment = (Read-Host "Enter comments")) {
    TF.exe Checkin (Get-Location) /comment:"$comment" /recursive
}


Function TfGet {
    TF.exe Get (Get-Location) -recursive
}