

Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Git -force

Function Script:Initialize-TestGitRepo {
    [CmdletBinding()]
    param ()
    $tempDirectory = Get-TempDirectory

    $currentLocation = Get-Location  # Save the current location.  Note, Pop-Location don't work from inside the Dispose Script.

    # Take the existing dispose script and add Pop-Location at the beginning.
    [ScriptBlock]$DisposeScript = [scriptblock]::Create(
        "
            Set-Location $currentLocation  # Move out of the location before deleting it. (Pop-Location doesn't work.
            $($tempDirectory.Dispose.Script);
        "
    )
    $tempDirectory | Add-DisposeScript -DisposeScript $DisposeScript -Force
    Invoke-GitCommand -ActionMessage "Initialize a temporary repository in '$tempDirectory'." -Command 'git init' | Write-Verbose
    return $tempDirectory
}

Describe 'Initialize-TestGitRepo' {
    $currentLocation = Get-Location
    $tempGitDirectory = (Script:Initialize-TestGitRepo)
    $tempGitDirectory | Register-AutoDispose -ScriptBlock {
    }
    Test-Path $tempGitDirectory.FullName | Should be $false
    Get-Location | Should Be "$currentLocation"
}

Describe "Get-GitStatusObject" {
    (Script:Initialize-TestGitRepo) | Register-AutoDispose -ScriptBlock {
        It "Determine status in brand new repo" {
           Get-GitStatusObject | should be $null # Initially, there are no modification git status --porcelain returns nothing.
           $randomFileName = [System.IO.Path]::GetRandomFileName()
           New-Item $randomFileName -ItemType File
           $actual = Get-GitStatusObject
           $actual.Action | Should be 'Untracked'
           $actual.FileName | Should be $randomFileName
           Invoke-GitCommand -ActionMessage 'Staging an item' -Command "git add $randomFileName"
           $actual = Get-GitStatusObject
           $actual.Action | Should be 'Added'
           $actual.FileName | Should be $randomFileName
           Invoke-GitCommand -ActionMessage 'Commit' -Command "git commit -m 'Add $randomFileName'"
           $actual = Get-GitStatusObject | Should Be $null
        }
    }
}



