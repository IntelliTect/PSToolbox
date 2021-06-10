# [string]$yes = "IntelliTect.PSToolbox.psd1"
# $yes = $yes.Substring(0, $yes.length - 5)
# $yes

$logs = git log --pretty=format:"%s"
$commitNum = 0
foreach ($log in $logs) {
    if($log.Contains("[skip ci]")){
        break
    }
    if(!($log.Contains("Merge Branch") -or $log.Contains("of https://github.com/IntelliTect/PSToolbox"))){
        $commitNum++
    }
}
git diff HEAD HEAD~$commitNum --name-only