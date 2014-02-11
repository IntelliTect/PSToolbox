
Function Install-NugetPSModule([string] $url) {
    #Change to nuget extension rather than zip.
    [string]$tempFilePath = [IO.Path]::GetTempFileName() + ".zip"
    Invoke-WebRequest -Uri $url -OutFile $tempFilePath
    
    [string]$tempDirectory = New-Item -ItemType Directory ($tempFilePath.TrimEnd(".zip"))
    #Consider refactoring into a zip function - though there are already a gazillion out there.

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempFilePath, $tempDirectory)
    
    [string]$nuspecFile = (Get-ChildItem $tempDirectory "*.nuspec")[0].FullName
    [XML]$nuspecXML = [XML] (Get-content $nuspecFile)
    $moduleName = $nuspecXML.package.metadata.id

    Move-Item $tempFilePath (Join-Path (Split-Path $tempFilePath) ($moduleName + ".nuget")) -Force
    Move-Item $tempDirectory (Join-Path (Split-Path $tempDirectory) $moduleName) -Force

    #TODO: Extract content to modules path.
}


#, 
#return $outputFile

Function Get-CurrentUserModuleDirectory() {
    [string[]]$ModulePaths = @($Env:PSModulePath -split ';')
    $ExpectedUserModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowerShell\Modules
    $Destination = $ModulePaths | %{$_.TrimEnd("\") } | Where-Object { $_ -eq $ExpectedUserModulePath}
    if (-not $Destination) {
        $Destination = $ModulePaths | Select-Object -Index 0
    }
    return $Destination
}


#Modified from PSGet - http://psget.net/GetPsGet.ps1
Function Install-Module([string] $moduleName, [string] $url) {
    $moduleDirectory = Get-CurrentUserModuleDirectory
    New-Item (Join-Path $moduleDirectory "moduleName") -ItemType Directory -Force | out-null
    
    Install-NugetPackageAsModule "https://www.dropbox.com/s/yw703um9iufg5ll/PSIdeation.4.0.20140113.nupkg?dl=1"


    $executionPolicy  = (Get-ExecutionPolicy)
    $executionRestricted = ($executionPolicy -eq "Restricted")
    if ($executionRestricted){
        Write-Warning @"
Your execution policy is $executionPolicy, this means you will not be able import or use any scripts including modules.
To fix this change your execution policy to something like RemoteSigned.

        PS> Set-ExecutionPolicy RemoteSigned

For more information execute:
        
        PS> Get-Help about_execution_policies

"@
    }

    if (!$executionRestricted){
        # ensure PsGet is imported from the location it was just installed to
        Import-Module -Name $Destination\PsGet
    }    
    Write-Host "PsGet is installed and ready to use" -Foreground Green
    Write-Host @"
USAGE:
    PS> import-module PsGet
    PS> install-module PsUrl

For more details:
    get-help install-module
Or visit http://psget.net
"@
}

Install-NugetPSModule "https://www.dropbox.com/s/yw703um9iufg5ll/PSIdeation.4.0.20140113.nupkg?dl=1"