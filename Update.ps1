$changedFiles = $(git diff HEAD HEAD~ --name-only)
$files = $changedFiles -split ' ' | ForEach-Object{[System.IO.FileInfo] $_}
$modules = @()

Write-Host "Changed files ($($file.Length)):"
foreach ($file in $files) 
{
    if((Test-Path $file.FullName)){
        $fileDirectoryParent = $file.Directory.Parent
        Write-Host "`t$($file.Name)"

        if ($fileDirectoryParent -and $fileDirectoryParent.Name -eq "Modules") {
            $modules += $file.Directory
        }
    }
    else {
        Write-Host "$($file.Name) was deleted"
    }
}