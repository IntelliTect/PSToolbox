
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common

Function Set-FileTime
{
 Param (
    [Parameter(mandatory=$true)]
    [string[]]$path,
    [datetime]$date = (Get-Date))

    Get-ChildItem -Path $path |
    ForEach-Object {
     $_.LastAccessTime = $date
     $_.LastWriteTime = $date
    }
}

Describe 'Invoke-ActionWhenFileChanges' {
    It 'Touch file fires event' {
        $sampleFile = Get-TempFile
        Register-AutoDispose $sampleFile {

            $script:isCalled = $false
            $aScript = { $script:isCalled = $true }
            & $aScript

            $ev = Invoke-ActionWhenFileChanges $sampleFile { $block }

            Start-Sleep -Seconds 1
            Set-FileTime $sampleFile
            $script:isCalled | Should Be $true
            $ev.StopJob()
        }
    }
}
