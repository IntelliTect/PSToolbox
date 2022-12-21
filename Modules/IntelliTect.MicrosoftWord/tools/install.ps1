
# ensure Microsoft.Office.Interop.Word.dll is installed.
$moduleRoot = (Split-Path $PSScriptRoot -Parent )

$wordAssemblyPath = "$($moduleRoot)/Lib/WordInteropNugetPackage/lib/netstandard2.0/Microsoft.Office.Interop.Word.dll"

$ExtractPath = "$($moduleRoot)/Lib/WordInteropNugetPackage"

if ((Test-Path $wordAssemblyPath) -eq $false) {
    if ((Test-Path $ExtractPath) -eq $false) {
        New-Item -ItemType Directory -Force -Path $ExtractPath
    }
    # this file despite running from the ./tools folder has a working dir of the root of the module 
    # get the latest word interop package and place the dll in the lib folder
    $wordInteropNugetDownloadUrl = "https://www.nuget.org/api/v2/package/Microsoft.Office.Interop.Word"

    $ZipFile = "$($moduleRoot)/Lib/" + $(Split-Path -Path $wordInteropNugetDownloadUrl -Leaf) + ".zip"

    Invoke-WebRequest -Uri $wordInteropNugetDownloadUrl -OutFile $ZipFile 

    Expand-Archive -Path $ZipFile -DestinationPath $ExtractPath -Force

    Remove-Item $ZipFile
}