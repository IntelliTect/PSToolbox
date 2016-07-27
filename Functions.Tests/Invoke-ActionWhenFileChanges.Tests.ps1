$here = $PSScriptRoot
$sut = $PSCommandPath.Replace('.Tests', '')
. $sut

<# TO DO
    1. Test file needs to be clean up.
    2. Currently tests fail because they are not asynchronous.
#>

Describe 'Invoke-ActionWhenFileChanges' {
    It 'Touch file fires event' {
        $sampleFile = [System.IO.Path]::GetTempFileName();
        $isCalled = $false
        Invoke-ActionWhenFileChanges $sampleFile { $isCalled = $true }
        Set-FileTime $sampleFile
        $isCalled | Should Be $true 
    }
}