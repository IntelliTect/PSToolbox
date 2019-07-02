$PSGalleryApiKey = "SomeKey-Make this a param"
$priority = @("IntelliTect.Common", "IntelliTect.File", "IntelliTect.MicrosoftWord", "IntelliTect.CredentialManager",
                "IntelliTect.DotNet", "IntelliTect.Git", "IntelliTect.Google", "IntelliTect.PSToolbox")

$projectUrl = [System.Uri]"https://github.com/IntelliTect/PSToolbox"
$ConfirmPreference = "None"
$modules = (Get-ChildItem $PSScriptRoot\ChangedModules) | Sort-Object { $priority.IndexOf($_.Name) }

if(!$modules) {
    throw "No modules to publish."
}


foreach($module in $modules){
    $moduleName = $module.Name
    $manifestPath = "$($module.FullName)\$moduleName.psd1"

    Write-Output "Importing $($module.Name)"
    Import-Module $manifestPath

    Write-Host "Publshing $moduleName to PSGallery"
    Publish-Module -Path $module.FullName -NuGetApiKey $PSGalleryApiKey -ProjectUri $projectUrl
}