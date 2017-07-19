[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact="High")]
param (
    [string]$Filter = "",
    [bool]$IgnoreNoExportedCommands = $false,
    [string]$PowerShellGalleryAPIKey,
    [switch]$SaveAPIKey
)


$omniModule = "IntelliTect.PSToolbox"
$moduleFolders = Get-ChildItem $PSScriptRoot\Modules\IntelliTect.* -Directory -Filter $filter
$modulesToPublish = @()

Write-Progress -Activity "Publish IntelliTect Module" -Status "Searching for manifests ready to publish"

if(!$moduleFolders) {
    throw "Nothing matches the filter, '$Filter'"
}

foreach ($item in $moduleFolders){
    $moduleName = $item.Name


    $manifestPath = "$($item.FullName)\$moduleName.psd1"

    if (!(Test-Path $manifestPath)) {
            Write-Error "$($moduleName): Manifest was not found."
            $submodules = git config --file (Join-Path $PSScriptRoot .gitmodules) --get-regexp path
            if ($submodules | ?{$_ -match $moduleName}) {
                Write-Error "$moduleName looks like a git submodule. Did you forget to run 'git submodule update --init --recursive'?" 
            }
    }
    else {
        $moduleStatus = ""
        $testModuleFailed = $null
        $manifest = Test-ModuleManifest -Path $manifestPath -ErrorVariable testModuleFailed
        if (!$manifest.Description){
            $moduleStatus += "`n`tMissing required description."
        }
        if (!$manifest.Author){
            $moduleStatus += "`n`tMissing required author(s)."
        }
        if ($manifest.ExportedCommands.Count -eq 0 -and $moduleName -ne $omniModule -and -not $IgnoreNoExportedCommands){
            $moduleStatus += "`n`tNo exported commands."
        }


        # This cmdlet doesn't report errors properly.
        # We can't use -ErrorVariable, and can't use try/catch. So, we use a slient continue and check the result for null instead.
        Write-Progress -Activity "Publish IntelliTect Module" -Status "Checking if module has ever been published."
        $moduleInfo = Find-Module $moduleName -ErrorAction SilentlyContinue

        if ($moduleInfo) {
            if($moduleInfo.Version -eq $manifest.Version) {
            $moduleStatus = "Current version is already published. $($moduleInfo.Version) $($moduleStatus)"
            }
            elseif ($moduleInfo.Version -gt $manifest.Version) {
                $moduleStatus = "Newer version is already published. $($moduleStatus)"
            }
            Write-Progress -Activity "Publish IntelliTect Module" -Status "$($moduleName): Ready to publish. $($moduleInfo.Version) -> $($manifest.Version)"
        }
        else {
            Write-Progress -Activity "Publish IntelliTect Module" -Status "$($moduleName): Ready to publish new module version $($manifest.Version)"
        }

        if($testModuleFailed) {}
        elseif($moduleStatus -ne "") {-and !$testModuleFailed
            Write-Warning "$($moduleName): $moduleStatus" testModuleFailed
        }
        else {
            $modulesToPublish += $item
        } 
    }
}

if ($modulesToPublish.Count -gt 0){

    Import-Module (Join-Path $PSScriptRoot /Modules/IntelliTect.CredentialManager)
    $credential = Get-CredentialManagerCredential "pstoolbox" -ErrorAction SilentlyContinue
    
    if (!$PowerShellGalleryAPIKey) {
        $PowerShellGalleryAPIKey = ([PSCredential]$credential).GetNetworkCredential().Password       
    }

    if(!$PowerShellGalleryAPIKey) {
        $PowerShellGalleryAPIKey = Read-Host "Enter your PS Gallery API Key"
    }

    if (!$PowerShellGalleryAPIKey) {
        throw "No API key was given. Stopping"
    }

    if ($SaveAPIKey) {
        if ($PowerShellGalleryAPIKey -and $SaveAPIKey) {
            $cred = New-Object System.Management.Automation.PSCredential "intellitect", ($PowerShellGalleryAPIKey | ConvertTo-SecureString -AsPlainText -Force)
            Set-CredentialManagerCredential -TargetName "pstoolbox" -Credential $cred
        }
    }
        
    foreach ($item in $modulesToPublish) {    
        Publish-Module -Path $item.FullName -NuGetApiKey $PowerShellGalleryAPIKey
    }
    Write-Progress -Activity "Publish IntelliTect Module" -Completed
}

