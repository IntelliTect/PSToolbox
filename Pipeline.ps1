$moduleFolders = Get-ChildItem .\ChangedModules

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

    $BuiltPath = "$(System.DefaultWorkingDirectory)" + "\Modules\" +($manifest.PSChildName).Substring(0, $manifest.PSChildName.length - 5 ) +  "\"+ ($manifest.PSChildName)
    $BuiltPath

        Update-ModuleManifest -Path $BuiltPath -ModuleVersion $updatedVersion

        $tempManifest = $content | ForEach-Object{
        if ($_ -match "ModuleVersion"){
            "ModuleVersion = '$($updatedVersion.ToString())'\"
        }
        else {
            $_
        }
    }

    Write-Host "$moduleName's version was updated from $version to $updatedVersion"
}


$moduleFolders = Get-ChildItem .\ChangedModules

if(!$moduleFolders) {
    throw "No modules to update."
}

foreach ($item in $moduleFolders){
    Publish-Module -Path $item.FullName -Repository localPSRepo -NuGetApiKey password -Force
}
