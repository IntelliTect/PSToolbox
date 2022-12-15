
# get the latest word interop package and place the dll in the lib folder
$wordInteropNugetDownloadUrl = "https://www.nuget.org/api/v2/package/Microsoft.Office.Interop.Word"

$ZipFile = "./" + $(Split-Path -Path $wordInteropNugetDownloadUrl -Leaf) + ".zip"

$ExtractPath = "../Lib/WordInteropNugetPackage"

Invoke-WebRequest -Uri $wordInteropNugetDownloadUrl -OutFile $ZipFile 

Expand-Archive -Path $ZipFile -DestinationPath $ExtractPath -Force

Remove-Item $ZipFile

# ensure word is installed.

try {
    add-type -AssemblyName 'Microsoft.Office.Interop.Word'
    Write-Output "Microsoft.Office.Interop.Word installed for module."
}
catch {
    try {
        # the install location of the dll as per install.ps1
        $wordAssemblyPath = Resolve-Path "../Lib/WordInteropNugetPackage/lib/netstandard2.0/Microsoft.Office.Interop.Word.dll" | `
            Sort-Object -Descending | Select-Object -First 1 
        if ($wordAssemblyPath -and (Test-Path $wordAssemblyPath)) {
            add-type -Path $wordAssemblyPath
            Write-Output "Microsoft.Office.Interop.Word installed for module."
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
    $Word = New-Object -ComObject word.application
    $Word.Quit([Microsoft.Office.Interop.Word.WdSaveOptions]::wdDoNotSaveChanges)
    Write-Output "Microsoft Word is installed. (Module requires existing Word Installation)"
}
catch {
    throw  'Unable to find Microsoft Word. You must have an install of Microsoft Word in order to use this module.'
}
