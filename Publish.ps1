
$moduleFolders = ls .\Modules\IntelliTect.* -Directory

Write-Host "Testing the manifest files for any defects..."
foreach ($item in $moduleFolders){
    $moduleName = $item.Name

    $manifest = Test-ModuleManifest -Path "$($item.FullName)\$moduleName.psd1"
    $manifest

    # This cmdlet doesn't report errors properly.
    # We can't use -ErrorVariable, and can't use try/catch. So, we use a slient continue and check the result for null instead.
    $moduleInfo = Find-Module $moduleName -ErrorAction SilentlyContinue

    if ($moduleInfo -eq $null) {
        Write-Host "No previous version found - this must be a new module. Congratulations!"
        Write-Host
    }
    elseif ($moduleInfo.Version -ge $manifest.Version){
        throw "A newer or identical version of $moduleName already exists on PSGallery. LocalVersion: $($manifest.Version), RemoteVersion: $($moduleInfo.Version)"
    }
    
    if (!$manifest.Description){
        throw "The module $($item.name) is missing a Description in its manifest. PowerShell Gallery requires this to be present."
    }
    if (!$manifest.Author){
        throw "The module $($item.name) is missing Author(s) from its manifest. PowerShell Gallery requires this to be present."
    }
    if ($manifest.ExportedCommands.Count -eq 0){
        throw "The module $($item.name) does not have any exported commands. Please remove the module, or export some commands from it."
    }

}


Write-Host "We aren't ready for publishing yet. Ending now before we actually perform the publish. Remove this part of the script once we're ready." -ForegroundColor Green
return;

$apiKey = Read-Host "Enter your PS Gallery API Key"
foreach ($item in $moduleFolders){
    
    Publish-Module -Path $item.FullName -NuGetApiKey $apiKey
}