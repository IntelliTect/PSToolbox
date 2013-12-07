[CmdletBinding(
    SupportsShouldProcess=$true #Tells the shell that your function supports both -confirm and -whatif.
    ,ConfirmImpact="High" #Causes Confirm prompt when $ConfirmPreference is "High"
)]
param ()

#Install Chocolatey
If(!($ENV:ChocolateyInstall)) {
    if ($pscmdlet.ShouldProcess("Install Chocolatey (http:\\Chocolatey.org)")) {
        Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
        $ENV:ChocolateyInstall="$ENV:Systemdrive\chocolatey\bin"
        $ENV:PATH="$ENV:PATH;$ENV:ChocolateyInstall"
    }
}

If($ENV:ChocolateyInstall) {
    #ToDo: Refactor into Install-ModuleFromChocolatey
    If(!(get-module Pscx -ListAvailable)) {
        If ($pscmdlet.ShouldProcess("Install PSCX (http:\\pscx.codeplex.com)")) {
            CINST Pscx #Note: This runs the Pscx MSI which probably? executes Install-Module
        }
    }

    #Install Pester
    If(!(get-module Pester -ListAvailable)) {
        If(!(Get-ChildItem "$ENV:ChocolateyInstall\lib\Pester*" Pester.psm1 -Recurse)) {
            If ($pscmdlet.ShouldProcess("Install Pester (https://github.com/pester/Pester)")) {
                CINST Pester #Note: This probably comes from NuGet (not chocolatey) and probably? doesn't execute Install-Module
            }
        }
        #TODO: Make conditional on chocolatey install as user may have declined that install
        Get-ChildItem "$ENV:ChocolateyInstall\lib\Pester*" Pester.psm1 -Recurse | Select-Object -Last 1 | Install-Module -Verbose 
    }

    #TODO: Install TFS PowerTools but the chocolatey pacakage appears to be out of date -http://chocolatey.org/packages/tfpt
}

#TODO: Move into a function file.
If(!(Test-Path Function:Import-VsCommandLine)) {
    function Get-Batchfile ($file) {
        $cmd = "`"$file`" & set"
        cmd /c $cmd | Foreach-Object {
            $p, $v = $_.split('=')
            Set-Item -path env:$p -value $v
        }
    }
    function Import-VsCommandLine()
    {
        $VSCOMNTOOLS = (Get-Item "env:vs*comntools" | select -last 1).Value
        $batchFile = Join-Path $VSCOMNTOOLS "vsvars32.bat"
        Get-Batchfile $BatchFile
    }
    Import-VsCommandLine
}


Function Checkin {
    TF.exe "Checkin" $pwd -recursive
}

