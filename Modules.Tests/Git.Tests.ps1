

Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Git

Function Script:Initialize-TestGitRepo {
    [CmdletBinding()]
    param ()
    $tempDirectory = Get-TempDirectory
    try {
        Push-Location $tempDirectory
        Invoke-GitCommand -ActionMessage "Initialize a temporary repository in '$tempDirectory'." -Command 'git' -  
    }
    finally {
        Pop-Location
    }
    return $tempDirectory
}


Describe "Get-GitStatusObject" {
    (Script:Initialize-TestGitRepo) | Register-AutoDispose -ScriptBlock {
        It "Determine status in brand new repo" {
           Get-GitStatusObject | should be ""
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