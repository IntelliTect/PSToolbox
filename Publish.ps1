[CmdletBinding(SupportsShouldProcess=$True)]
param (
    [string]$Filter = "",
    [bool]$IgnoreNoExportedCommands = $false
)

$moduleFolders = ls .\Modules\IntelliTect.* -Directory -Filter $filter
$modulesToPublish = @()

Write-Host "Searching for manifests ready to publish"
foreach ($item in $moduleFolders){
    $moduleName = $item.Name
    $moduleStatus = ""

    $manifest = Test-ModuleManifest -Path "$($item.FullName)\$moduleName.psd1"

    if (!$manifest.Description){
        $moduleStatus = "Missing required description. $($moduleStatus)"
    }
    if (!$manifest.Author){
        $moduleStatus = "Missing required author(s). $($moduleStatus)"
    }
    if ($manifest.ExportedCommands.Count -eq 0 -and -not $IgnoreNoExportedCommands){
        $moduleStatus = "No exported commands. $($moduleStatus)"
    }

    # This cmdlet doesn't report errors properly.
    # We can't use -ErrorVariable, and can't use try/catch. So, we use a slient continue and check the result for null instead.
    $moduleInfo = Find-Module $moduleName -ErrorAction SilentlyContinue -RequiredVersion $manifest.Version

    if ($moduleInfo -ne $null) {
        $moduleStatus = "Current version is already published. $($moduleStatus)"
    }

    if ($moduleStatus -eq "") {
        Write-Host "$($moduleName): Ready to publish." -ForegroundColor Green
        $modulesToPublish += $item
    } else {
        Write-Host "$($moduleName): $moduleStatus" -ForegroundColor Red
    }
}

if ($PSCmdlet.ShouldProcess($modulesToPublish)) {
    $apiKey = Read-Host "Enter your PS Gallery API Key"
    foreach ($item in $modulesToPublish) {    
        Publish-Module -Path $item.FullName -NuGetApiKey $apiKey
    }
}
