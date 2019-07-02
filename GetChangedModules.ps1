Write-Host "Determining modules that have changed in last commit"

$changedFiles = $(git diff HEAD HEAD~ --name-only)
$filesSplit = $changedFiles -split ' '
$files = $changedFiles -split ' ' | ForEach-Object{[System.IO.FileInfo] $_}
$modules = @()

Write-Host "Changed files ($($files.Count)):"
For ($i=0; $i -lt $files.Count; $i++)
{
    $file = $files[$i]
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

# used for conditional artifact publishing
# Write-Host "##vso[task.setvariable variable=CHANGED_MODULES_COUNT]$modules.Count"

if($modules.Count -eq 0){
    Write-Host "There are no modules that are changed"
    exit 0
}

$changedModulesPath = mkdir -Path $PSScriptRoot\ -Name "ChangedModules" -Force
Write-Host $changedModulesPath

Write-Host "Copying changed modules: "
For ($i=0; $i -lt $modules.Length; $i++)
{
    $module = $modules[$i]
    Write-Host "`t$($module.Name)"
    Copy-Item -Path $module.FullName -Destination $changedModulesPath -Recurse -Force
}