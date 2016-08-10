
$sut = $PSCommandPath.Replace('.Tests', '')
. (Join-Path (Split-Path $sut -Parent) "Common.ps1")
. $sut

<# TO DO
    1. Test file needs to be clean up.
    2. Currently tests fail because they are not asynchronous.
#>

# TODO: Move this into File.ps1 and include (dot-source) into Common.ps1
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
        $sampleFile = Get-TempFile
            
            $script:isCalled = $false
            $aScript = { $script:isCalled = $true }
            & $aScript

            $ev = Invoke-ActionWhenFileChanges $sampleFile { $block }

            Start-Sleep -Seconds 1
            Set-FileTime $sampleFile
            $script:isCalled | Should Be $true 

            $sampleFile.Dispose()
            $ev.StopJob()
    }
}
