
$wordAssemblyPath = "./Lib/WordInteropNugetPackage/lib/netstandard2.0/Microsoft.Office.Interop.Word.dll"

if (Test-Path $wordAssemblyPath -eq $false) {
    # this file despite running from the ./tools folder has a working dir of the root of the module 
    # get the latest word interop package and place the dll in the lib folder
    $wordInteropNugetDownloadUrl = "https://www.nuget.org/api/v2/package/Microsoft.Office.Interop.Word"

    $ZipFile = "./Lib/" + $(Split-Path -Path $wordInteropNugetDownloadUrl -Leaf) + ".zip"

    $ExtractPath = "./Lib/WordInteropNugetPackage"

    Invoke-WebRequest -Uri $wordInteropNugetDownloadUrl -OutFile $ZipFile 

    Expand-Archive -Path $ZipFile -DestinationPath $ExtractPath -Force

    Remove-Item $ZipFile
}

# ensure word is installed.

try {
    add-type -AssemblyName 'Microsoft.Office.Interop.Word'
}
catch {
    try {
        if ($wordAssemblyPath -and (Test-Path $wordAssemblyPath)) {
            add-type -Path $wordAssemblyPath
            Write-Output "Microsoft.Office.Interop.Word.dll installed for module."
        }
        else {
            throw;
        }
    }
    catch {
        throw  'Error with install script. Unable to find Microsoft.Office.Interop.Word package (see https://www.nuget.org/packages/Microsoft.Office.Interop.Word)'
    }
}

try {
    # check if word is installed
    Write-Output "Checking for Microsoft Word installation. (Module requires existing Word Installation)"
    $Word = New-Object -ComObject word.application
    $Word.Quit([Microsoft.Office.Interop.Word.WdSaveOptions]::wdDoNotSaveChanges)
    Write-Output "Microsoft Word is installed. ✔"
}
catch {
    throw  'Unable to find Microsoft Word. You must have an install of Microsoft Word in order to use this module.'
}
