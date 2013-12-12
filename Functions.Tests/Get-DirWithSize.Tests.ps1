$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

Describe "Get-DirWithSize" {
    It "is an array of FileInfo" {
        $target = Get-DirWithSize "TestDrive:"
        $target | %{ $_.GetType().Name | Should Be "FileInfo"}
    }




}