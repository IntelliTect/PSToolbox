$here = $PSScriptRoot
$sut = (Split-Path -Leaf $PSCommandPath).Replace(".Tests", "")
. $sut


Remove-Item alias:dir
Remove-Item alias:ls
Set-Alias dir Get-DirWithSize
Set-Alias ls Get-DirWithSize



