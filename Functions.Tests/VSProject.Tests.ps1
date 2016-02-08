$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

$solutionText = @"
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio 14
VisualStudioVersion = 14.0.22609.0
MinimumVisualStudioVersion = 10.0.40219.1
Project("{2150E333-8FDC-42A3-9474-1A3956D46DE8}") = "Solution Items", "Solution Items", "{061EA5FD-627D-419B-8ECC-65964F44F6BD}"
	ProjectSection(SolutionItems) = preProject
		global.json = global.json
		NuGet.config = NuGet.config
	EndProjectSection
EndProject
Project("{8BB2217D-0F2D-49D1-97BC-3654ED321F3B}") = "SampleProject", "SampleProject\SampleProject.kproj", "{BFBD99B3-00A2-4592-BBE2-CCE9A210F449}"
EndProject
Project("{8BB2217D-0F2D-49D1-97BC-3654ED321F3B}") = "SampleProject.Tests", "SampleProject.Tests\SampleProject.Tests.kproj", "{2C083CB4-B524-49CA-B04C-4B28D18DFA83}"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Debug|Any CPU = Debug|Any CPU
		Release|Any CPU = Release|Any CPU
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
		{BFBD99B3-00A2-4592-BBE2-CCE9A210F449}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		{BFBD99B3-00A2-4592-BBE2-CCE9A210F449}.Debug|Any CPU.Build.0 = Debug|Any CPU
		{BFBD99B3-00A2-4592-BBE2-CCE9A210F449}.Release|Any CPU.ActiveCfg = Release|Any CPU
		{BFBD99B3-00A2-4592-BBE2-CCE9A210F449}.Release|Any CPU.Build.0 = Release|Any CPU
		{2C083CB4-B524-49CA-B04C-4B28D18DFA83}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		{2C083CB4-B524-49CA-B04C-4B28D18DFA83}.Debug|Any CPU.Build.0 = Debug|Any CPU
		{2C083CB4-B524-49CA-B04C-4B28D18DFA83}.Release|Any CPU.ActiveCfg = Release|Any CPU
		{2C083CB4-B524-49CA-B04C-4B28D18DFA83}.Release|Any CPU.Build.0 = Release|Any CPU
	EndGlobalSection
	GlobalSection(SolutionProperties) = preSolution
		HideSolutionNode = FALSE
	EndGlobalSection
EndGlobal
"@

Function New-TempProjectFile() {
    $tempProjectFile = [IO.Path]::GetTempFileName()
    Remove-Item $tempProjectFile
    $tempProjectFile = $tempProjectFile -replace "-","" -replace [IO.Path]::GetExtension($tempProjectFile),""
    New-Item -ItemType Directory $tempProjectFile > $null
    $result = New-Item -ItemType File "$tempProjectFile\$([IO.Path]::GetFileNameWithoutExtension($tempProjectFile)).Proj"
    return [IO.FileInfo]$result
}


Describe "Rename-Project" {
    It "Rename a project file" {
        [IO.FileInfo]$tempProjectFile = $null
        [IO.FileInfo]$newProjectFile = $null
        try {
             $tempProjectFile = New-TempProjectFile
             $newProjectFile = Rename-VSProject $tempProjectFile.FullName "New$($tempProjectFile.BaseName)"
             (Test-Path $tempProjectFile) | should be $false
             (Test-Path $newProjectFile) | should be $true
        }
        finally {
            Remove-Item (split-path $tempProjectfile -Parent) -Recurse -ErrorAction Ignore 
            Remove-Item (split-path $newProjectfile -Parent) -Recurse # -ErrorAction Ignore
        }
    }

    Context "Get-Content Mock" {
        Mock "Get-Content" {
            return $solutionText
        }
        Mock "Set-Content" {
            [Paramater(Mandatory, ValueFromPipeline)][string]$line,
            [switch]$PassThru
            return $line
        }
        It "Update solution file" {
            [IO.FileInfo]$tempProjectFile = $tempProjectFile = New-TempProjectFile
            [string]$solutionFilePath = "somepath"

            $newSolutionText = Update-VSSolution $solutionFilePath $tempProjectFile.FullName "UpdatedProjectName"
            $oldProjectName = $tempProjectFile.BaseName
            $newSolutionText | should be $solutionText -replace "`"$oldProjectName`"",'"UpdatedProjectName"' `
                -replace "$oldProjectName\\$oldProjectName",'UpdatedProjectName\UpdatedProjectName'
            $newSolutionText.Contains('"UpdatedProjectName"') | should be $true
            $newSolutionText.Contains("UpdatedProjectName\UpdatedProjectName") | should be $true
            $newSolutionText.Contains("`"$oldProjectName`"") | should be $false
            $newSolutionText.Contains("$oldProjectName.Tests") | should be $true
            $newSolutionText.Contains("$oldProjectName.Tests\$oldProjectName.Tests") | should be $true
        }
    }
}

Function Create-SolutionFile {
    Set-Content -Path $

}