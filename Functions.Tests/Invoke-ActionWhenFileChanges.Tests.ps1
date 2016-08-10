$here = $PSScriptRoot
$sut = $PSCommandPath.Replace('.Tests', '')
. $sut

<# TO DO
    1. Test file needs to be clean up.
    2. Currently tests fail because they are not asynchronous.
#>

Function Set-FileTime

{

 Param (

    [Parameter(mandatory=$true)]

    [string[]]$path,

    [datetime]$date = (Get-Date))

    Get-ChildItem -Path $path |

    ForEach-Object {

     $_.LastAccessTime = $date

     $_.LastWriteTime = $date }

}

Describe 'Invoke-ActionWhenFileChanges' {
    It 'Touch file fires event' {
        $sampleFile = [System.IO.Path]::GetTempFileName();
        $isCalled = $false
        $block = $MyInvocation.MyCommand.Module.NewBoundScriptBlock( { $isCalled = $true } )
        Invoke-ActionWhenFileChanges $sampleFile { $block }

        Start-Sleep -Seconds 1
        Set-FileTime $sampleFile
        $isCalled | Should Be $true 
    }
}
