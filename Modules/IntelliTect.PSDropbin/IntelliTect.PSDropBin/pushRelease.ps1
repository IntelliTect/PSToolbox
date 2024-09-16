param(
    [string]$version = "v1.0",
    #[string]$prerelease = "false",
    #[string]$draft= "false",
    [string]$info = ""
)

#Paths & FileNames
[string]$choco = "Chocolatey\"
[string]$tools = "tools\"
[string]$installFile = "ChocolateyInstall.ps1"
[string]$uninstallFile = "ChocolateyUninstall.ps1"
[string]$nuspecFile = "project.nuspec"

#Git Command Strings
[string]$addCommand = "git add bin\Release -f"
[string]$tagCommand = "git tag"
[string]$pushCommand = "git push origin master --follow-tags"

#Chocolatey related Strings  & Command Strings
[string]$packageName = "`$packageName = 'PSDropBin'"
[string]$url = "`$url = 'https://github.com/IntelliTect/PSDropbin/PSDropNew/archives/"
[string]$unzipLocation = "`$unzipLocation = '`${env:ProgramFiles}\PSDropBin'" 
[string]$installCommand = "Install-ChocolateyZipPackage `$packageName `$url `$unzipLocation"
[string]$postInstallMessage = "Write-Host 'Run setup.ps1 located at `$unzipLocation to finish setup.' -foregroundcolor White -backgroundcolor Red"
[string]$uninstallCommand = "Uninstall-ChocolateyZipPackage `$packageName '"
Function Build-Chocolatey() {
    If (-not (Test-Path ($choco + $tools)))
    {
        md ($choco + $tools) | Out-Null
    }
    Build-Install
    Build-Uninstall
    #Build-NuSpec
}

Function Build-Install()  {
$fullPath = $choco + $tools + $installFile
$packageName > $fullPath
$urlFull = $url + $version + ".zip'"
$urlFull >> $fullPath
$unzipLocation >> $fullPath
$installCommand >> $fullPath
$postInstallMessage >> $fullPath
}
Function Build-Uninstall() {
$fullPath = $choco + $tools + $uninstallFile
$packageName > $fullPath
$uninstallCommandFull = $uninstallCommand + $version + ".zip'"
$uninstallCommandFull >> $fullPath
}
Function Build-NuSpec() {

}
#Build-Chocolatey

Invoke-Expression $addCommand
If(-not $info) {
    $tagLightWeight = $version + "-lw"
    $tagCommandFull = $tagCommand + " " + $tagLightWeight
}
Else {
    $tag = " -a " + $version
    $tagAnnotation = " -m " + $info
    $tagCommandFull = $tagCommand + $tag + $tagAnnotation
}

Invoke-Expression $tagCommandFull
Invoke-Expression $pushCommand
<#
Build Full Release
    

[string]$uri = "https://api.github.com/repos/IntelliTect/PSDropbin/releases?access_token=:"
[string]$personalAccessCode = "f2b803e867daf53349fed934452ff1920f8262c0"
$body = @{
    tag_name = $version
    target_commitish = "master"
    name = $version
    body = "Description"
    draft = $draft
    prerelease = $prerelease
}
Invoke-RestMethod -Method Post -Uri ($uri + $personalAccessCode) -Body $body
#>
