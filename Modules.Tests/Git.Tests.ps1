

Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Git -force

Function Script:Initialize-TestGitRepo {
    [CmdletBinding()]
    param ()
    $tempDirectory = Get-TempDirectory

    $currentLocation = Get-Location  # Save the current location.  Note, Pop-Location don't work from inside the Dispose Script.
    Push-Location $tempDirectory

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




Describe 'Get-GitObjectProperty' {
    It 'Return all properties' {
        'refname','parent','authorname' | ForEach-Object {
            (Get-GitObjectProperty) -contains $_ | Should Be $true
        }
    }
    It 'Return a specific property' {
        'refname','parent','authorname' | ForEach-Object {
            Get-GitObjectProperty -Name "$_" | Should Be "$_"
        }
    }
    It 'Return propery based on wildcard (*) suffix' {
        'object*' | ForEach-Object {
            Get-GitObjectProperty -Name "$_" | Should Be 'objecttype','objectsize','objectname','object'
        }
    }
    It 'Return propery based on wildcard (*) prefix' {
        '*parent' | ForEach-Object {
            Get-GitObjectProperty -Name "$_" | Should Be 'parent','numparent'
        }
    }
    # It 'Return properties as Json format string.' {
    #     'refname','refname:short','authorname' | ForEach-Object {
    #         Get-GitObjectProperty -Name "$_" -Format 'Json' | Should Be "`"$_`":`"%($_)`""
    #     }
    # }
    # It 'Return properties as git format strings.' {
    #     'refname','refname:short','authorname' | ForEach-Object {
    #         Get-GitObjectProperty -Name "$_" -Format 'GitFormat' | Should Be "%($_)"
    #     }
    # }
    It 'Given a collection of names/wildcards, return only those' {
            Get-GitObjectProperty -Name 'object*','authorname' | Should Be 'objecttype','objectsize','objectname','object','authorname'
    }
}