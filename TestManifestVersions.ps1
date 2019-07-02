$moduleFolders = Get-ChildItem $PSScriptRoot\ChangedModules

if(!$moduleFolders) {
    throw "No modules to test."
}

foreach($moduleFolder in $moduleFolders){
    $moduleName = $moduleFolder.Name
    $moduleStatus = ""
    $manifestPath = "$($moduleFolder.FullName)\$moduleName.psd1"

    Write-Host "Testing $moduleName"

    if (!(Test-Path $manifestPath)) {
            throw "$($moduleName): Manifest was not found."
    }
    else{
        $manifest = Test-ModuleManifest $manifestPath -ErrorAction SilentlyContinue

        Write-Host "Checking published version of $moduleName"

        # check if published versions are newer or equal
        $moduleInfo = Find-Module $moduleName -ErrorAction SilentlyContinue

        if ($moduleInfo) {
            if($manifest.Version -eq $moduleInfo.Version) {
                Write-Error "$($moduleName): Current version ($($moduleInfo.Version)) is already published."
            }
            elseif ($manifest.Version -lt $moduleInfo.Version) {
                Write-Error "$($moduleName): Published version ($($moduleInfo.Version)) is newer than current version ($($manifest.Version))."
            }
            else {
                Write-Host "Current $($moduleName) version ($($manifest.Version)) is newer than published version ($($moduleInfo.Version))."
            }
        }
        else {
            Write-Host "$($moduleName) has never been published."
        }

        Write-Host "$($moduleName) is ready to be published."
    }
}
