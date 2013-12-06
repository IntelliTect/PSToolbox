$here = $PSScriptRoot
$sut = (Split-Path -Leaf $PSCommandPath).Replace(".Tests", "")
#Import-Module "$env:utils\Import-Script.psm1" -Scope Local -Force
#Import-Script "$here\$sut"
. $sut




