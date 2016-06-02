[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact="High")]
param (
    [string]$Filter = "",
    [bool]$IgnoreNoExportedCommands = $false
)

$omniModule = "IntelliTect.PSToolbox"
$moduleFolders = $moduleFolders = Get-ChildItem $PSScriptRoot\Modules\IntelliTect.* -Directory -Filter $filter
$modulesToPublish = @()

Write-Host "Searching for manifests ready to publish"
foreach ($item in $moduleFolders){
    $moduleName = $item.Name
    $moduleStatus = ""

    $manifestPath = "$($item.FullName)\$moduleName.psd1"

    if (!(Test-Path $manifestPath)) {
            Write-Host "$($moduleName): Manifest was not found." -ForegroundColor Red
            $submodules = git config --file (Join-Path $PSScriptRoot .gitmodules) --get-regexp path
            if ($submodules | ?{$_ -match $moduleName}) {
                Write-Host "$moduleName looks like a git submodule. Did you forget to run 'git submodule update --init --recursive'?" -ForegroundColor Red
            }
    }
    else {
        $manifest = Test-ModuleManifest -Path $manifestPath
        if (!$manifest.Description){
            $moduleStatus = "Missing required description. $($moduleStatus)"
        }
        if (!$manifest.Author){
            $moduleStatus = "Missing required author(s). $($moduleStatus)"
        }
        if ($manifest.ExportedCommands.Count -eq 0 -and $moduleName -ne $omniModule -and -not $IgnoreNoExportedCommands){
            $moduleStatus = "No exported commands. $($moduleStatus)"
        }

        # This cmdlet doesn't report errors properly.
        # We can't use -ErrorVariable, and can't use try/catch. So, we use a slient continue and check the result for null instead.
        $moduleInfo = Find-Module $moduleName -ErrorAction SilentlyContinue

    
        $color = [System.ConsoleColor]::Red
        if ($moduleInfo.Version -eq $manifest.Version) {
            $color = [System.ConsoleColor]::Gray
            $moduleStatus = "Current version is already published. $($moduleInfo.Version) $($moduleStatus)"
        }
        elseif ($moduleInfo.Version -gt $manifest.Version) {
            $moduleStatus = "Newer version is already published. $($moduleStatus)"
        }

        if ($moduleStatus -eq "") {
            Write-Host "$($moduleName): Ready to publish. $($moduleInfo.Version) -> $($manifest.Version)" -ForegroundColor Green
            $modulesToPublish += $item
        } else {
            Write-Host "$($moduleName): $moduleStatus" -ForegroundColor $color
        }
    }
}

if ($modulesToPublish.Count -gt 0){
    $apiKey = $null

    if (Get-Module Intellitect.CredentialManager -ListAvailable) {
        Import-Module IntelliTect.CredentialManager
        $credential = Get-CredentialManagerCredential "psgallery" -ErrorAction SilentlyContinue
        if (!$credential) {
            Write-Host "No credentials were found for TargetName: psgallery"
        }
        else {
            $apiKey = ([PSCredential]$credential).GetNetworkCredential().Password
            Write-Host "Retrieved API key from credential manager."
        }
    } else {
        Write-Host "Couldn't find Intellitect.CredentialManager for automatic API key retrieval. Install it, and add a credential with TargetName psgallery"
    }
    
    if (!$apiKey) {
        $apiKey = Read-Host "Enter your PS Gallery API Key"
    }
    if (!$apiKey) {
        throw "No API key was given. Stopping"
    }
    
    foreach ($item in $modulesToPublish) {    
        if ($PSCmdlet.ShouldProcess($item.Name)) {
            Publish-Module -Path $item.FullName -NuGetApiKey $apiKey
        }
    }
}
