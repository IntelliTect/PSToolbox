$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut
 
function DebugBreak{}
function Debug{
    Set-PSBreakpoint -command DebugBreak
    DebugBreak
}

Describe "New-NugetPackage" {
    It "Create Nuget package using the defaults" {
        $tempPath = Join-Path ([IO.Path]::GetTempPath()) "NewNugetPackage.Tests";
        If(Test-Path $tempPath) {
            Get-ChildItem $tempPath -Recurse | Remove-Item
        }
        else {
            New-Item $tempPath -ItemType Directory
        }

        #Setup for Nuget
        Nuget spec -verbosity detailed
        [xml] $nugetSpecContent = [XML] (Get-Content ".\package.nuspec")
        $extractedPath = (Join-Path $tempPath "extracted")
        $nugetSpecContent.package.metadata.dependencies.InnerText = ""
        Set-Content -Value $nugetSpecContent.InnerXml -Path ".\package.nuspec"

        # Debug
        Move-Item ".\package.nuspec" $tempPath
        Copy-Item $PSCommandPath $tempPath

        New-NugetPackage -inputDirectory $tempPath -outputDirectory $tempPath
        try {
            nuget install Package -outputdirectory $extractedPath -source $tempPath -noninteractive
            [IO.FileInfo[]]$extractedFiles = Get-ChildItem $tempPath -Recurse -File
            $extractedFiles.Count | should Be 5
            $extractedPath = Join-Path $extractedPath ("{0}.{1}" -f $nugetSpecContent.package.metadata.id,$nugetSpecContent.package.metadata.version)
            $extractedFiles.FullName -contains (Join-Path $extractedPath "temp.ps1") | Should Be True
        }
        finally {
            Remove-item "$tempPath" -recurse
        }
    }
}