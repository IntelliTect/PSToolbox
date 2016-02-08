Function Rename-VSProject {
    [CmdletBinding()] param(
        [ValidateScript({Test-Path $_ -PathType Leaf})][Parameter(Mandatory)][string] $projFile, 
        [Parameter(Mandatory)][string] $newProjectName
    )

    $newProjectFile = $projFile -replace ([IO.Path]::GetFileNameWithoutExtension($projFile)),$newProjectName # Use GetFileNameWithoutExtension as Split-Path doesn't do this.
    Move-Item (Split-Path $projFile -Parent) (Split-Path $newProjectFile -Parent) #Rename the directory
    Move-Item (Join-Path (Split-Path $newProjectFile -Parent) (split-path $projFile -Leaf)) $newProjectFile # Rename the project file
    return Get-Item $newProjectFile
}

Function Update-VSSolution {
    [CmdletBinding()] param(
        [string] $solutionFilePath,
        [string] $projFile, 
        [string] $newProjectName
    )
    $oldProjectName = [IO.Path]::GetFileNameWithoutExtension($projFile)
    $oldFileName = Split-Path $projFile -leaf

    (Get-Content $solutionFilePath) |%{ 
        $_ -replace [System.Text.RegularExpressions.Regex]::Escape("$oldProjectName\$oldFileName"),"$newProjectName\$newProjectName$([IO.Path]::GetExtension($oldFileName))" `
            -replace "`"oldProjectName`"","`"$newProjectName`"" } | Set-Content -Path $solutionFilePath
                
}


Function Update-ProjectFile {
{
    # see http://dhickey.ie/post/2011/06/03/Rename-a-Visual-Studio-Project-using-PowerShell.aspx
    # designed to run from the sln folder
    [CmdletBinding()] param(
        [string]$projectName=$(throw "projectName required."),
        [string]$newProjectName=$(throw "newProjectName required.")
    )
     
    if(!(Test-Path $projectName)){
        Write-Error "No project folder '$projectName' found"
        return
    }
     
    if(!(Test-Path $projectName\$projectName.csproj)){
        Write-Error "No project '$projectName\$projectName.dll' found"
        return
    }
     
    if((Test-Path $newProjectName)){
        Write-Error "Project '$newProjectName' already exists"
        return
    }
     
    # project
    hg rename $projectName\$projectName.csproj $projectName\$newProjectName.csproj
     
    # folder
    hg rename $projectName $newProjectName
     
    # assembly title
    $assemblyInfoPath = "$newProjectName\Properties\AssemblyInfo.cs"
    (gc $assemblyInfoPath) -replace """$projectName""","""$newProjectName""" | sc $assemblyInfoPath
     
    # root namespace
    $projectFile = "$newProjectName\$newProjectName.csproj"
    (gc $projectFile) -replace "<RootNamespace>$projectName</RootNamespace>","<RootNamespace>$newProjectName</RootNamespace>" | sc $projectFile
     
    # assembly name
    (gc $projectFile) -replace "<AssemblyName>$projectName</AssemblyName>","<AssemblyName>$newProjectName</AssemblyName>" | sc $projectFile
     
    # other project references
    gci -Recurse -Include *.csproj |% { (gc $_) -replace "..\\$projectName\\$projectName.csproj", "..\$newProjectName\$newProjectName.csproj" | sc $_ }
    gci -Recurse -Include *.csproj |% { (gc $_) -replace "<Name>$projectName</Name>", "<Name>$newProjectName</Name>" | sc $_ }
     
    # solution 
    gci -Recurse -Include *.sln |% { (gc $_) -replace "\""$projectName\""", """$newProjectName""" | sc $_ }
    gci -Recurse -Include *.sln |% { (gc $_) -replace "\""$projectName\\$projectName.csproj\""", """$newProjectName\$newProjectName.csproj""" | sc $_ }
}

}

Function Set-VSProjectCodeAnalysis {
    [CmdletBinding()] param(
        [Parameter(Mandatory, ValueFromPipeline=$True)][string[]] $projectPaths,
        [bool] $value = $true) 
    
    PROCESS {
        foreach($projectPath in $projectPaths) {
            $projectPath = Resolve-Path $projectPath
            [XML]$projectXML = Get-Content $projectPath
            # TODO: Verify that the first one is the PropertyGroup without any conditionals.
            if($projectXml.Project.PropertyGroup[0]["RunCodeAnalysis"] -eq $null) {
                $runCodeAnalysisElement = $projectXMl.CreateElement("RunCodeAnalysis", $proj.Project.NamespaceURI )
                $projectXml.Project.PropertyGroup[0].AppendChild($runCodeAnalysisElement)
            }
            if($projectXml.Project.PropertyGroup[0].RunCodeAnalysis -ne $value.ToString()) {
                $projectXml.Project.PropertyGroup[0].RunCodeAnalysis = $value.ToString()
            }
            # TODO: Refactor to parameterize the added element and value.
            if($projectXml.Project.PropertyGroup[0]["CodeAnalysisRuleSet"] -eq $null) {
                $codeAnalysisRuleSetElement = $projectXMl.CreateElement("CodeAnalysisRuleSet", $proj.Project.NamespaceURI )
                $projectXml.Project.PropertyGroup[0].AppendChild($codeAnalysisRuleSetElement)
            }
            if($projectXml.Project.PropertyGroup[0].CodeAnalysisRuleSet -ne "..\Solution.ruleset") {
                $projectXml.Project.PropertyGroup[0].CodeAnalysisRuleSet = "..\Solution.ruleset"
            }
            # TODO: Move this to occur only if an element changes.
            $projectXML.Save( $projectPath )
        }
    }

}


Function Rename-CompileFile {
    [CmdletBinding(SupportsShouldProcess=$true)] param(
            [ValidateScript({Test-Path $_ -PathType Leaf})][Parameter(Mandatory)][string] $projFile, 
            [ValidateScript({Test-Path $_ -PathType Leaf})][Parameter(Mandatory)][string] $oldFileName,
            [Parameter(Mandatory)][string] $newFileName
    )

    #TODO: Verify that git is the SCC tool.
    #TODO: Add support for TFS.

    $command = "git.exe mv $oldFileName $newFileName $(if($PSBoundParameters['Verbose']) {`"-v`"})" # The following is not needed as it is handled by "$PSCmdlet.ShouldProcess": -What $(if($PSBoundParameters['WhatIf']) {`"--dry-run`"})"
    if ($PSCmdlet.ShouldProcess("`tExecuting: $command", "`tExecute git.exe Rename: $command", "Executing Git.exe mv")) {
        Invoke-Expression "$command" -ErrorAction Stop  #Change error handling to use throw instead.
    }
    $projFile = Resolve-Path $projFile
    $proj = [XML](Get-Content $projFile)
    #TODO Add support for subdirectories in the VS path.
    $proj.Project.ItemGroup.SelectNodes('//*[local-name()="Compile"]') | 
        ?{ $_.Include -eq [IO.Path]::GetFileName($oldFileName) }  | #TODO: Change to use XPath to find element as this makes no check that the element exists.
            %{ $_.Include = [IO.Path]::GetFileName($newFileName) }
    if ($PSCmdlet.ShouldProcess(
        "`tUpdating $projFile - Renaming compiled file '$([IO.Path]::GetFileName($oldFileName))' to '$([IO.Path]::GetFileName($newFileName))'",
        "`tUpdating $projFile - Renaming compiled file '$([IO.Path]::GetFileName($oldFileName))' to '$([IO.Path]::GetFileName($newFileName))'",
        "Updating $($projFile):"
        )) {
        $proj.Save($projFile) # Saving as each file is renamed rather than all at the end in case we error out in the middle.
    }
}