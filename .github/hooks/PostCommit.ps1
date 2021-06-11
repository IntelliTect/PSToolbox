$changedModules = $(git diff HEAD HEAD~ --name-only)
$files = $changedModules -split ' ' | ForEach-Object{[System.IO.FileInfo] $_}
$modules = @()
foreach ($file in $files) 
{
    if((Test-Path $file.FullName)){
        $fileDirectoryParent = $file.Directory.Parent
        if ($fileDirectoryParent -and $fileDirectoryParent.Name -eq "Modules") {
            $modules += $file.Directory
        }
    }
}
$changedModulesPath = mkdir -Name "ChangedModules" -Force
For ($i=0; $i -lt $modules.Length; $i++)
{
    $module = $modules[$i]
    Copy-Item -Path $module.FullName -Destination $changedModulesPath -Recurse -Force
}
git add .
git commit -m "[skip ci] Githook ChangedModules Generation"