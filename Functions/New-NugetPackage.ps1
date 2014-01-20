Function New-NugetPackage(
    [string] $inputDirectory=(Get-Location).Path, 
    [string] $outputDirectory=(Get-Location).Path, 
    [string] $tempDirectory=([IO.Path]::GetTempPath()) ) {
    
    #TODO: Handle if 0 or more than 1 file is returned
    [string]$nuspecFile = (Get-ChildItem $inputDirectory "*.nuspec")[0].FullName

    [XML]$nuspecXML = [XML] (Get-content $nuspecFile)

    $tempDirectory = Join-Path $tempDirectory NewNugetPackage
    $tempDirectory = Join-Path $tempDirectory ($nuspecXML.package.metadata.id + "(" + $nuspecXML.package.metadata.version + ")")
    $tempDirectory = Join-Path $tempDirectory "Tools"

    If(!(Test-Path $tempDirectory)) {
        New-Item $tempDirectory -ItemType Directory
    }
    If(!(Test-Path $outputDirectory)) {
        New-Item $outputDirectory -ItemType Directory
    }
    $outputDirectory = Resolve-Path $outputDirectory
        
 
    #Remove-Item (Join-Path $PSScriptRoot "\..\Tools") -Recurse
    #Copy-Item $PSScriptRoot $PSScriptRoot\..\Tools -Exclude "Tools" -Recurse -Force
    #Move-Item $PSScriptRoot\..\Tools $PSScriptRoot\Tools -WhatIf
    #TODO: Switcc to use Copy-Item rather than Robocopy (good luck). :)


    
    #TODO Replace Robocopy with Raw Powershell commands
    #   Copy/upadate (copy if newer or missing) files in the $PSScriptRoot directory into $PSScriptRoot\bin\Tools
    Robocopy $inputDirectory $tempDirectory * /S /XC /MIR /XD bin
#    if(!(Test-Path $PSScriptRoot\bin)) {
#        New-Item "$PSScriptRoot\bin" -ItemType Directory
#    }
#    If(Test-Path $PSScriptRoot\bin\Tools) {
#        Remove-Item $PSScriptRoot\bin\Tools -Recurse
#    }
#    Copy $PSScriptRoot\..\Tools $PSScriptRoot\bin\Tools -Recurse
    
    If(!(Get-Command Nuget)) {
        #TODO: This needs to check other locations to avoid the dependency on Nuget
        #      or to dynamically install it if necessary.
        Set-Alias Nuget "$ENV:ChocolateyInstall\chocolateyInstall\NuGet.exe"
    }

    $currentDirectory = Get-Location;
    try {
        Set-Location $tempDirectory
        Nuget Pack $nuspecFile -OutputDirectory $outputDirectory
    }
    Finally {
        Set-Location $currentDirectory;
    }

    Remove-Item $tempDirectory -Recurse
}
