# [string]$yes = "IntelliTect.PSToolbox.psd1"
# $yes = $yes.Substring(0, $yes.length - 5)
# $yes

$logs = git log --pretty=format:"%s"
$commitNum = 1
foreach ($log in $logs) {
    if($log.Contains("[skip ci]")){
        break
    }
    $commitNum++
}
$commitNum