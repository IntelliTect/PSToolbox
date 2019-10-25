

Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common -Force
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Git -Force

Function Script:Initialize-TestGitRepo {
    [CmdletBinding()]
    param (
        [switch]$IsBare
    )
    $tempDirectory = Get-TempDirectory -Name ([System.IO.Path]::GetRandomFileName().Replace('.','_'))

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

Describe 'Get-GitRepo' {
    (Script:Initialize-TestGitRepo) | Register-AutoDispose -ScriptBlock {
        It 'Returns a repo object where IsBare==false' { 
            (Get-GitRepo).IsBare | Should Be $false
        }
    }
    (Script:Initialize-TestGitRepo -IsBare) | Register-AutoDispose -ScriptBlock {
        It 'Returns a bare repo object where IsBare==true' { 
            (Get-GitRepo).IsBare | Should Be $true
        }
    }
}


Describe 'Initialize-TestGitRepo' {
    $currentLocation = Get-Location
    $tempGitDirectory = (Script:Initialize-TestGitRepo)
    $tempGitDirectory | Register-AutoDispose -ScriptBlock {
    }
    Test-Path $tempGitDirectory.FullName | Should be $false
    Get-Location | Should Be "$currentLocation"
}

Describe "Get-GitItemStatus" {
    (Script:Initialize-TestGitRepo) | Register-AutoDispose -ScriptBlock {
        It "Determine status in brand new repo" {
           Get-GitItemStatus| should be $null # Initially, there are no modification git status --porcelain returns nothing.
           $randomFileName = [System.IO.Path]::GetRandomFileName()
           New-Item $randomFileName -ItemType File
           $actual = Get-GitItemStatus
           # TODO 'GitAction enum is not successfully getting imported from IntelliTect.Git module'
           # $actual.Action | Should be [GitAction]::Untracked
           $actual.Action | Should be 'Untracked'
           $actual.FileName | Should be $randomFileName
           Invoke-GitCommand -ActionMessage 'Staging an item' -Command "git add $randomFileName"
           $actual = Get-GitItemStatus
           $actual.Action | Should be 'Added'
           $actual.FileName | Should be $randomFileName
           Invoke-GitCommand -ActionMessage 'Commit' -Command "git commit -m 'Add $randomFileName'"
           $actual = Get-GitItemStatus| Should Be $null
        }
    }
}




Describe 'Get-GitItemProperty' {
    It 'Return all properties' {
        'refname','parent','authorname' | ForEach-Object {
            (Get-GitItemProperty) -contains $_ | Should Be $true
        }
    }
    It 'Return a specific property' {
        'refname','parent','authorname' | ForEach-Object {
            Get-GitItemProperty -Name "$_" | Should Be "$_"
        }
    }
    It 'Return propery based on wildcard (*) suffix' {
        'object*' | ForEach-Object {
            Get-GitItemProperty -Name "$_" | Should Be 'objecttype','objectsize','objectname','object'
        }
    }
    It 'Return propery based on wildcard (*) prefix' {
        '*parent' | ForEach-Object {
            Get-GitItemProperty -Name "$_" | Should Be 'parent','numparent'
        }
    }
    # It 'Return properties as Json format string.' {
    #     'refname','refname:short','authorname' | ForEach-Object {
    #         Get-GitItemProperty -Name "$_" -Format 'Json' | Should Be "`"$_`":`"%($_)`""
    #     }
    # }
    # It 'Return properties as git format strings.' {
    #     'refname','refname:short','authorname' | ForEach-Object {
    #         Get-GitItemProperty -Name "$_" -Format 'GitFormat' | Should Be "%($_)"
    #     }
    # }
    It 'Given a collection of names/wildcards, return only those' {
            Get-GitItemProperty -Name 'object*','authorname' | Should Be 'objecttype','objectsize','objectname','object','authorname'
    }
}



Describe 'Undo-Git' {
    (Script:Initialize-TestGitRepo) | Register-AutoDispose -ScriptBlock {
        $initialFile = Get-TempFile -path .\
        Invoke-GitCommand -ActionMessage 'Staging an item' -Command "git add $initialFile"
        Invoke-GitCommand -ActionMessage 'Commit item' -Command "git commit -m 'Adding $initialFile'"
        
        It "Undo when there is nothing to do does nothing" {
            Undo-git | Should Be $null
        }
        It "Undo-git for single untracked file" {
            New-TemporaryFile 
            Undo-git -RemoveUntrackedItems
            Get-GitItemStatus | Should Be $null
        } 
        It "Undo-git for single tracked file" {
            $tempFile = Get-TempFile -path .\
            Invoke-GitCommand -ActionMessage 'Staging an item' -Command "git add $tempFile"
            Undo-git -RestoreTrackedFiles
            Get-GitItemStatus | Should Be $null
        } 
        Context "Undo-git with -RemoveIgnoredFilesToo" {
            $ignoreFile = Get-TempFile -path .\
            $ignoreFile.Name | Out-File -FilePath (Join-Path '.\' '.gitignore') -Encoding ascii
            Invoke-GitCommand -ActionMessage 'Staging an item' -Command "git add .gitignore"
            Invoke-GitCommand -ActionMessage 'Commit item' -Command "git commit -m 'Adding .gitignore'"            
            $tempFile = Get-TempFile -path .\

            It ' but not -RemoveUntrackedFiles' {
                $status = Get-GitItemStatus 
                $status.Action | Should Be 'Untracked'
                $tempFile.Name | Should BeIn $status.FileName
                @($status.FileName) -notcontains $ignoreFile.Name | Should Be $true

                {Undo-git -RemoveIgnoredFilesToo -ErrorAction Stop } | Should Throw
            }
            It "Undo-git for ignored files" {
                # NOTE: Continue with files from previous test.

                Undo-git -RemoveIgnoredFilesToo -RemoveUntrackedItems
                $status = Get-GitItemStatus  | Should Be $null
                Test-Path -Path $tempFile.FullName -PathType Leaf | Should Be $false
                Test-Path -Path $ignoreFile.FullName -PathType Leaf | Should Be $false
            }  
        }
    }
}


Describe 'Get-GitBranch' {
    (Script:Initialize-TestGitRepo) | Register-AutoDispose -ScriptBlock {
        Get-GitBranch | should be 'master'
    }
}

Describe 'Push-GitBranch' {
    $localRepo = Script:Initialize-TestGitRepo
    $mockRemoteRepo = Script:Initialize-TestGitRepo -IsBare

    Register-AutoDispose -InputObject $localRepo,$mockRemoteRepo -ScriptBlock {
        Push-Location
        try {
            Set-Location $localRepo
            Invoke-GitCommand -ActionMessage 'Set remote pointing to file system "remote"' -Command "git remote add origin $($mockRemoteRepo.FullName)"
            Invoke-GitCommand -ActionMessage 'Creaete a new branch called ''Temp''' -Command 'git checkout -b Temp' -ErrorAction Ignore
            New-Item -ItemType file 'dummy.txt'
            Invoke-GitCommand -ActionMessage 'Commit initial file.' -Command 'git add .'
            Invoke-GitCommand -ActionMessage 'Commit initial file.' -Command 'git commit -m ''Initial commit'''
            It 'Push branch that doesn''t exist remotely' {
                Push-GitBranch -SetUpstream | Should Be "Branch 'Temp' set up to track remote branch 'Temp' from 'origin'."
            }
            It 'Push branch that exists remotely' {
                Invoke-GitCommand -ActionMessage 'Remove file' -Command 'git rm dummy.txt'
                Invoke-GitCommand -ActionMessage 'Commit dummy.txt file remove.' -Command 'git commit -m ''Remove dummy.txt'''
                Push-GitBranch | Should BeLike 'To * Temp -> Temp'
            }
        }
        catch {
            Pop-Location
        }
    }
}