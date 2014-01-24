
#TODO: Rename this and the tests file to not include the verb.

function FolderExcludeCopy([string]$sourceDir, [string]$destDir, [string[]]$excludeFilters, [string]$excludeDirs, [bool]$deleteExistedDestDir=$true) {
   if ($deleteExistedDestDir -and (Test-Path $destDir)) {
    Write-Host "clean destination folder $destdir" -ForegroundColor Cyan
    Remove-Item  $destDir -Recurse -Force
   }
   #join the excluded directories into a string
   $excludeDirs = $excludeDirs -join "|"
   Get-ChildItem $sourceDir -Recurse -Exclude $excludeFilters | ? {$_.FullName -inotMatch $excludeDirs } |  Copy-Item -Force -Destination {Join-Path $destDir $_.FullName.Substring($sourceDir.length)}   
}

Function New-NugetPackage(
    [string] $inputDirectory=(Get-Location).Path, 
    [string] $outputDirectory=(Join-Path (Get-Location).Path "bin"), 
    [string] $tempDirectory=([IO.Path]::GetTempPath()) ) {
    
    #TODO: Handle if 0 or more than 1 file is returned
    [string]$nuspecFile = (Get-ChildItem $inputDirectory "*.nuspec")[0].FullName

    [XML]$nuspecXML = [XML] (Get-content $nuspecFile)

    $tempDirectory = Join-Path $tempDirectory NewNugetPackage
    $tempDirectory = Join-Path $tempDirectory ($nuspecXML.package.metadata.id + "(" + $nuspecXML.package.metadata.version + ")")
    $tempDirectory = Join-Path $tempDirectory "Tools"

    If(!(Test-Path $tempDirectory)) {
        New-Item $tempDirectory -ItemType Directory | Write-Debug
    }
    If(!(Test-Path $outputDirectory)) {
        New-Item $outputDirectory -ItemType Directory | Write-Debug
    }
    $outputDirectory = Resolve-Path $outputDirectory
            
    #   Copy/upadate (copy if newer or missing) files in the $PSScriptRoot directory into $PSScriptRoot\bin\Tools
    #        What wasn't working:
    #             Remove-Item (Join-Path $PSScriptRoot "\..\Tools") -Recurse
    #             Copy-Item $PSScriptRoot $PSScriptRoot\..\Tools -Exclude "Tools" -Recurse -Force
    #             Move-Item $PSScriptRoot\..\Tools $PSScriptRoot\Tools -WhatIf
    #Robocopy $inputDirectory $tempDirectory * /S /XC /MIR /XD bin | Write-Debug
    #    if(!(Test-Path $PSScriptRoot\bin)) {
    #        New-Item "$PSScriptRoot\bin" -ItemType Directory
    #    }
    #    If(Test-Path $PSScriptRoot\bin\Tools) {
    #        Remove-Item $PSScriptRoot\bin\Tools -Recurse
    #    }
    #    Copy $PSScriptRoot\..\Tools $PSScriptRoot\bin\Tools -Recurse

    #Replace the above Robocopy command with Raw Powershell commands
    FolderExcludeCopy $inputDirectory $tempDirectory "" "bin" $false
    
    If(!(Get-Command Nuget)) {
        #TODO: This needs to check other locations to avoid the dependency on Nuget
        #      or to dynamically install it if necessary.
        Set-Alias Nuget "$ENV:ChocolateyInstall\chocolateyInstall\NuGet.exe"
    }

    $currentDirectory = Get-Location;
    try {
        Set-Location $tempDirectory
        Nuget Pack $nuspecFile -OutputDirectory $outputDirectory | %{
            Write-Debug $_
            if($_ -like "*Successfully created package*") { 
                Write-Host $_ 
                $packageName = $_ -replace "Successfully created package ", ""
                $packageName = $packageName.Trim(".").Trim("'")
                Write-host $packageName
                Get-Item $packageName;
            }
        }

    }
    Finally {
        Set-Location $currentDirectory;
    }

    Remove-Item $tempDirectory -Recurse
}
