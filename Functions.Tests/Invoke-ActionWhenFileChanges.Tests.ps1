$here = $PSScriptRoot
$sut = $PSCommandPath.Replace('.Tests', '')
. $sut



Describe 'Invoke-ActionWhenFileChanges' {
    It 'Touch file fires event' {
        $sampleFile = [System.IO.Path]::GetTempFileName();
        $isCalled = $false
        Invoke-ActionWhenFileChanges $sampleFile { $isCalled = $true }
        Set-FileTime $sampleFile
        $isCalled | Should Be $true 
    }
}