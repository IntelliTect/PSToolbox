#Copy
$commitOne = "4bd918851257ba18f3339bb459836fcda9ad61f3"
$commitTwo = "f36875c6f7e4be9e4b6792914352a391d4cefc51"

$changedFiles = $(git diff $commitOne $commitTwo --name-only)
$changedFiles
$files = $changedFiles -split ' ' | ForEach-Object{[System.IO.FileInfo] $_}
$modules = @()

Write-Host "Changed files ($($files.Count)):"
foreach ($file in $files) 
{
    if((Test-Path $file.FullName)){
        $fileDirectoryParent = $file.Directory.Parent
        Write-Host "`t$($file.Name)"

        if ($fileDirectoryParent -and $fileDirectoryParent.Name -eq "Modules") {
            $modules += $file.Directory
        }
    }
    else {
        Write-Host "$($file.Name) was deleted"
    }
}

Write-Host "##vso[task.setvariable variable=CHANGED_MODULES_COUNT]$modules.Count"

if($modules.Count -eq 0){
    Write-Host "There are no modules that are changed"
    exit 0
}

#$changedModulesPath = mkdir -Path $(Build.ArtifactStagingDirectory) -Name "ChangedModules" -Force
$changedModulesPath = mkdir -Path C:\Users\TylerJones\Testing\PipeLine -Name "ChangedModules" -Force
Write-Host $changedModulesPath

Write-Host "Copying changed modules: "
For ($i=0; $i -lt $modules.Length; $i++)
{
    $module = $modules[$i]
    Write-Host "`t$($module.Name)"
    Copy-Item -Path $module.FullName -Destination $changedModulesPath -Recurse -Force
}
#Update

$moduleFolders = Get-ChildItem C:\Users\TylerJones\Testing\PipeLine\ChangedModules

if(!$moduleFolders) {
    throw "No modules to update."
}
foreach ($item in $moduleFolders){
    $moduleName = $item.Name
    $manifest = Get-ChildItem $item.PSPath | Where-Object{$_.Name -like "*psd1"}

    if(!$manifest){
        Write-Error "The manifest for $moduleName was not found"
    }

    $content = Get-Content $manifest.PSPath | ForEach-Object{
        $_
        if ($_ -match "ModuleVersion"){
            $version = [System.Version]($_ -split "'")[1]
        }
    }

$major = 0
    $minor = 0
    $build = 0
    $minorRev = 1

    if($version.Major -gt 0){$major = $version.Major}
    if($version.Minor -gt 0){$minor = $version.Minor}
    if($version.Build -gt 0){$build = $version.Build}
    if($version.MinorRevision -gt 0){$minorRev = $version.MinorRevision + 1}

    $updatedVersion = New-Object -TypeName system.Version -ArgumentList $major, $minor, $build, $minorRev

    # $tempManifest = $content | ForEach-Object{
    #     if ($_ -match "ModuleVersion"){
    #         "ModuleVersion = '$($updatedVersion.ToString())'"
    #     }
    #     else {
    #         $_
    #     }
    # }

    # $tempManifest | Set-Content $manifest.PSPath
    Update-ModuleManifest -Path "C:\Users\TylerJones\source\repos\Main PSToolBox\PSToolbox\Modules\IntelliTect.PSToolbox\IntelliTect.PSToolbox.psd1" -ModuleVersion $updatedVersion


    Write-Host "$moduleName's version was updated from $version to $updatedVersion"
}
git pull origin Testing-Publishing
# git add Modules/\*.psd1
git add .
git commit -m "[skip ci] Commit from build agent"
git merge Testing-Publishing -m "[skip ci] Merge from build agent"

#Publish
$moduleFolders = Get-ChildItem C:\Users\TylerJones\Testing\PipeLine\ChangedModules

if(!$moduleFolders) {
    throw "No modules to update."
}

foreach ($item in $moduleFolders){
    Publish-Module -Path $item.FullName -Repository localPsRepo -NuGetApiKey password
}
