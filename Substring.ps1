# # [string]$yes = "IntelliTect.PSToolbox.psd1"
# # $yes = $yes.Substring(0, $yes.length - 5)
# # $yes

# $logs = git log --pretty=format:"%s"
# $commitNum = 0
# foreach ($log in $logs) {
#     if($log.Contains("[skip ci]")){
#         break
#     }
#     if(!($log.Contains("Merge Branch") -or $log.Contains("of https://github.com/IntelliTect/PSToolbox"))){
#         $commitNum++
#     }
# }
# git diff HEAD HEAD~$commitNum --name-only

Write-Host "Determining modules that have changed since last run of pipeline"

$logs = git log --pretty=format:"%s"
$mergeCommit = 1
$finalCommit = 0
foreach ($log in $logs) {
    if($log.Contains("[skip ci]")){
        break
    }
    if($log.Contains("Merge Branch") -and $log.Contains("of https://github.com/IntelliTect/PSToolbox")){
        $mergeCommit = $finalCommit
    } else{
        $finalCommit++
    }
}
$beforeMerge = $mergeCommit - 1
#$changedFiles = $(git diff HEAD HEAD~$beforeMerge)
$changedFiles = @()
$changedFiles += $(git diff HEAD HEAD~$beforeMerge --name-only)
$changedFiles += $(git diff HEAD~$mergeCommit HEAD~$finalCommit --name-only)
$files = $changedFiles -split ' ' | ForEach-Object{[System.IO.FileInfo] $_}
$modules = @()

#Write-Host "Changed files ($($files.Count)):"
foreach ($file in $files) 
{
    $file.FullName
    if((Test-Path $file.FullName)){
        $fileDirectoryParent = $file.Directory.Parent
        #Write-Host "`t$($file.Name)"

        #$fileDirectoryParent
        $fileDirectoryParent.Name

        if ($fileDirectoryParent -and $fileDirectoryParent.Name -eq "Modules") {
            $modules += $file.Directory
        }
    }
    else {
        #Write-Host "$($file.Name) was deleted"
    }
}

#Write-Host "##vso[task.setvariable variable=CHANGED_MODULES_COUNT]$modules.Count"

if($modules.Count -eq 0){
    Write-Host "There are no modules that are changed"
    exit 0
}
else{
    foreach ($item in $modules) {
        "Changed:"
        $item.Name
    }
}