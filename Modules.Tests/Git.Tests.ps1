

Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common -Force
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Git -Force

Function Script:Initialize-TestGitRepo {
    [CmdletBinding()]
    param (
        [switch]$IsBare
    )
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
    Invoke-GitCommand -ActionMessage "Initialize a temporary repository in '$tempDirectory'." `
        -Command "git init $(if($IsBare){'--bare '})",`
        'git config user.name "Inigo.Montoya"','git config user.email "Inigo.Montoya@PrincessBride.com"' | Where-Object{ $_ -ne $null } | Write-Verbose
    return $tempDirectory
}

$script:TestGitRepo = $null;

Describe 'Get-GitRepo' {
    It 'Returns a repo object where IsBare==false' { 
        (Script:Initialize-TestGitRepo) | Register-AutoDispose -ScriptBlock {
            (Get-GitRepo).IsBare | Should -Be $false
        }
    }
    It 'Returns a bare repo object where IsBare==true' { 
        (Script:Initialize-TestGitRepo -IsBare) | Register-AutoDispose -ScriptBlock {
            (Get-GitRepo).IsBare | Should -Be $true
        }
    }
}



Describe 'Initialize-TestGitRepo' {
    It 'Cleans up temp repo when complete' {
        $currentLocation = Get-Location
        $tempGitDirectory = (Script:Initialize-TestGitRepo)
        $tempGitDirectory | Register-AutoDispose -ScriptBlock {
        }
        Test-Path $tempGitDirectory.FullName | Should -Be $false
        Get-Location | Should -Be "$currentLocation"
    }
}

Describe "Get-GitItemStatus" {
    It "Determine status in brand new repo" {
        (Script:Initialize-TestGitRepo) | Register-AutoDispose -ScriptBlock {
           Get-GitItemStatus| Should -Be $null # Initially, there are no modification git status --porcelain returns nothing.
           $randomFileName = [System.IO.Path]::GetRandomFileName()
           New-Item $randomFileName -ItemType File
           $actual = Get-GitItemStatus
           # TODO 'GitAction enum is not successfully getting imported from IntelliTect.Git module'
           # $actual.Action | Should -Be [GitAction]::Untracked
           $actual.Action | Should -Be 'Untracked'
           $actual.FileName | Should -Be $randomFileName
           Invoke-GitCommand -ActionMessage 'Staging an item' -Command "git add $randomFileName"
           $actual = Get-GitItemStatus
           $actual.Action | Should -Be 'Added'
           $actual.FileName | Should -Be $randomFileName
           Invoke-GitCommand -ActionMessage 'Commit' -Command "git commit -m 'Add $randomFileName'"
           $actual = Get-GitItemStatus| Should -Be $null
        }
    }
}




Describe 'Get-GitItemProperty' {
    It 'Return all properties' {
        'refname','parent','authorname' | ForEach-Object {
            (Get-GitItemProperty) -contains $_ | Should -Be $true
        }
    }
    It 'Return a specific property' {
        'refname','parent','authorname' | ForEach-Object {
            Get-GitItemProperty -Name "$_" | Should -Be "$_"
        }
    }
    It 'Return propery based on wildcard (*) suffix' {
        'object*' | ForEach-Object {
            Get-GitItemProperty -Name "$_" | Should -Be 'objecttype','objectsize','objectname','object'
        }
    }
    It 'Return propery based on wildcard (*) prefix' {
        '*parent' | ForEach-Object {
            Get-GitItemProperty -Name "$_" | Should -Be 'parent','numparent'
        }
    }
    # It 'Return properties as Json format string.' {
    #     'refname','refname:short','authorname' | ForEach-Object {
    #         Get-GitItemProperty -Name "$_" -Format 'Json' | Should -Be "`"$_`":`"%($_)`""
    #     }
    # }
    # It 'Return properties as git format strings.' {
    #     'refname','refname:short','authorname' | ForEach-Object {
    #         Get-GitItemProperty -Name "$_" -Format 'GitFormat' | Should -Be "%($_)"
    #     }
    # }
    It 'Given a collection of names/wildcards, return only those' {
            Get-GitItemProperty -Name 'object*','authorname' | Should -Be 'objecttype','objectsize','objectname','object','authorname'
    }
}

$script:tempFile = $null
$script:ignoreFile = $null

Describe 'Undo-Git' {
    BeforeAll {
        $script:TestGitRepo = (Script:Initialize-TestGitRepo)
        $initialFile = Get-TempFile -path .\
        Invoke-GitCommand -ActionMessage 'Staging an item' -Command "git add $initialFile"
        Invoke-GitCommand -ActionMessage 'Commit item' -Command "git commit -m 'Adding $initialFile'"
    }

    It "Undo when there is nothing to do does nothing" {
        Undo-git | Should -Be $null
    }
    It "Undo-git for single untracked file" {
        $script:tempFile = Get-TempFile -path .\
        Get-GitItemStatus | Select-Object -ExpandProperty FileName | Should -Be $tempFile.Name
        Undo-git -RemoveUntrackedItems
        Get-GitItemStatus | Should -Be $null
    }
    It "Undo-git for single tracked file" {
        $script:tempFile = Get-TempFile -path .\
        Invoke-GitCommand -ActionMessage 'Staging an item' -Command "git add $tempFile"
        Undo-git -RestoreTrackedFiles
        Get-GitItemStatus | Should -Be $null
    }
    Context "Undo-git with -RemoveIgnoredFilesToo" {
        It ' but not -RemoveUntrackedFiles' {
            # Setup
            $script:ignoreFile = Get-TempFile -path .\
            $script:ignoreFile.Name | Out-File -FilePath (Join-Path '.\' '.gitignore') -Encoding ascii
            Invoke-GitCommand -ActionMessage 'Staging an item' -Command "git add .gitignore"
            Invoke-GitCommand -ActionMessage 'Commit item' -Command "git commit -m 'Adding .gitignore'"
            $script:tempFile = Get-TempFile -path .\

            $status = Get-GitItemStatus
            $status.Action | Should -Be 'Untracked'
            $script:tempFile.Name | Should -BeIn $status.FileName
            @($status.FileName) -notcontains $script:ignoreFile.Name | Should -Be $true

            {Undo-git -RemoveIgnoredFilesToo -ErrorAction Stop } | Should -Throw
        }
        It "Undo-git for ignored files" {
            # NOTE: Continue with files from previous test.

            Undo-git -RemoveIgnoredFilesToo -RemoveUntrackedItems
            Get-GitItemStatus  | Should -Be $null
            Test-Path -Path $script:tempFile.FullName -PathType Leaf | Should -Be $false
            Test-Path -Path $script:ignoreFile.FullName -PathType Leaf | Should -Be $false
        }
    }
    AfterAll {
        $script:TestGitRepo.Dispose()
    }

}


Describe 'Get-GitBranch' {
    It 'Default branch is main (or master)' {
        (Script:Initialize-TestGitRepo) | Register-AutoDispose -ScriptBlock {
            (Get-GitBranch) -in 'master','main' | Should -Be $true
        }
    }
}

# Describe 'Push-GitBranch' {
#     $localRepo = Script:Initialize-TestGitRepo
#     $mockRemoteRepo = Script:Initialize-TestGitRepo -IsBare

#     Register-AutoDispose -InputObject $localRepo,$mockRemoteRepo -ScriptBlock {
#         Push-Location
#         try {
#             Set-Location $localRepo
#             Invoke-GitCommand -ActionMessage 'Set remote pointing to file system "remote"' -Command "git remote add origin $($mockRemoteRepo.FullName)"
#             Invoke-GitCommand -ActionMessage 'Creaete a new branch called ''Temp''' -Command 'git checkout -b Temp'
#             New-Item -ItemType file 'dummy.txt'
#             Invoke-GitCommand -ActionMessage 'Commit initial file.' -Command 'git add .'
#             Invoke-GitCommand -ActionMessage 'Commit initial file.' -Command 'git commit -m ''Initial commit'''
#             It 'Push branch that doesn''t exist remotely' {
#                 Push-GitBranch -SetUpstream | Should -Be "Branch 'Temp' set up to track remote branch 'Temp' from 'origin'."
#             }
#             It 'Push branch that exists remotely' {
#                 Invoke-GitCommand -ActionMessage 'Remove file' -Command 'git rm dummy.txt'
#                 Invoke-GitCommand -ActionMessage 'Commit dummy.txt file remove.' -Command 'git commit -m ''Remove dummy.txt'''
#                 Push-GitBranch | Should -BeLike 'To * Temp -> Temp'
#             }
#         }
#         catch {
#             Pop-Location
#         }
#     }
# }