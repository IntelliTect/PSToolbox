<#Header#>
using module "IntelliTect.PSDbxCli"
Set-StrictMode -Version "Latest"

# Import IntelliTect.Commonn for suppot of Get-Temp stuff.
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common
# Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.File

Get-Module IntelliTect.PSDbxCli | Remove-Module
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.PSDbxCli -Force
#EndHeader#>

# Using BeforeDiscovery rather than BeforAll because variables are used in the It Name.
BeforeDiscovery {
    $rootFiles = Get-DbxItem -File
    if(-not $rootFiles) { throw 'There are no sample files at the root folder to test with.' }
    $rootDirectories = Get-DbxItem -Directory
    if(-not $rootFiles) { throw 'There are no exisint sample directories at the root folder to test with.' }
    $script:sampleFileAtRootPath = $rootFiles[(Get-Random -Maximum ($rootFiles.Count-1))].Path
    $script:sampleDirectoryAtRootPath = $rootDirectories[(Get-Random -Maximum ($rootDirectories.Count-1))].Path
}
Describe 'Test-DbxPath' {
    It "Verify item (a file called '$script:sampleFileAtRootPath') exists" {
        Test-DbxPath $script:sampleFileAtRootPath | Should -BeTrue
    }
    It "Verify item (a directory called '$script:sampleDirectoryAtRootPath') exists" {
        Test-DbxPath $script:sampleDirectoryAtRootPath | Should -BeTrue
    }
    It "Verify a file (-File) called '$script:sampleFileAtRootPath' exists" {
        Test-DbxPath -PathType Leaf $script:sampleFileAtRootPath | Should -BeTrue
    }
    It "Verify a directory (-Container) called '$script:sampleDirectoryAtRootPath' exists" {
        Test-DbxPath -PathType Container $script:sampleDirectoryAtRootPath | Should -BeTrue
    }
    It "Verify a directory called '$($script:sampleDirectoryAtRootPath.TrimEnd('/')) (without trailing slash) exists" {
        # Verify trailing slash is allowed
        Test-DbxPath -PathType Container $script:sampleDirectoryAtRootPath.TrimEnd('/') | Should -BeTrue
    }
    It 'Verify slash prefix will be assumed.' {
        Test-DbxPath -PathType Container $script:sampleDirectoryAtRootPath.TrimStart('/') | Should -BeTrue
    }
    It "Verify folder (called 'Bogus-Bogus-Bogus.bogus') does not exists" {
        Test-DbxPath -PathType Container 'Bogus-Bogus-Bogus.bogus' | Should -BeFalse
    }
    It 'Verify searching for a file with a trailing ''/'' will throw an error' {
        { Test-DbxPath -PathType Leaf '/Folder/' } | Should -Throw
    }
}

Describe 'Get-DbxItem' {
    It 'Verify you can see the root' {
        $items = Get-DbxItem
        $items.Count | Should -BeGreaterOrEqual 0
        $items | Select-Object -ExpandProperty Path | Should -BeLike '/*'
    }
    It 'Verify you can see a single file' {
        $items = Get-DbxItem -File
        $path = ($items[(Get-Random -Maximum ($items.Count-1))]).Path
        $item = Get-DbxItem $path
        $item.Path | Should -Be $path
        $converter=@{
            B=1;
            KiB=1000;
            MiB=1000000;
            GiB=1000000000;
        }
        $item.DisplaySize -match '(?<Unit>GiB|KiB|MiB|B)' | Should -BeTrue
        $item.Size | Should -BeGreaterThan ($converter.($Matches.Unit))
    }
    It 'Return only files' {
        $items = Get-DbxItem -File
        $items | ForEach-Object{
            $_.GetType().Name | Should -Be 'DbxFile' }
    }
    It 'Return only directories' {
        $items = Get-DbxItem -Directory
        $items | ForEach-Object{
            $_.GetType().Name | Should -Be 'DbxDirectory' }
    }
    It 'Retrieve a single directory by name' {
        $items = Get-DbxItem -Directory
        $items | Select-Object -First 1 | ForEach-Object{
            $path = $_.Path
            Get-DbxItem $_.Path | Select-Object -ExpandProperty Path | Should -BeLike "$path*"
        }
    }
}

Describe 'DbxDirectory' {
    It 'Retrieve childe items using DbxDirectory.GetChildItems()' {
        $items = Get-DbxItem -Directory
        $items | Select-Object -First 2 | ForEach-Object{
            $expectedPath = $_.Path
            $childItems = $_.GetChildItems()
            $childItems | Select-Object -ExpandProperty 'Path' | Should -BeLike "$expectedPath*"
        }
    }
}

Describe 'Get-DbxRevision: ' {
    BeforeAll {
        $script:dropboxFile = Get-DbxItem -File | Select-Object -First 1
        $script:tempFile = $script:dropboxFile
    }
    It 'Find a DbxFile with multiple revisions' {
        # Rather than use Get-DbxRevisions in BeforeAll, use this test to
        # update $dropboxFile to contain a DbxFile that has more than
        # one revision.
        $dbxFileRevisions = Get-DbxItem -File | ` # Retrieve all the files in the root dropbox directory
            Where-Object {
                Write-Progress -Activity 'Get-DbxRevision tests: Finding file with multiple revisions' `
                    -Status "Examining'$($_.Path)'..."
                $tempRevisions = Get-DbxRevision $_
                @($tempRevisions).Count -gt 1
            } | ` # Select the dropbox files with more than one revision and save the revisions to $tempRevisions
            Select-Object -First 1 | ` # Select just the first file
            ## Tee-Object -Variable dropboxFile | ` # Update the $dropboxFile to be this item with more than one revision
            ForEach-Object {
                $script:dropboxFile = $_
                $tempRevisions
            } # Return the previously retrieved revisions
        $dbxFileRevisions | Should -Not -BeNullOrEmpty
        @($dbxFileRevisions).Count | Should -BeGreaterOrEqual 1
        $dbxFileRevisions | ForEach-Object {
            $_.Revision | Should -Not -BeNullOrEmpty
        }
        $dbxFileRevisions | ForEach-Object {
            $_.Path | Should -Be $dropboxFile.Path
        }
    }
    It 'Pipe Get-DbxItem -File to Get-DbxRevision' {
        $dbxFileRevisions = $dropboxFile  | Get-DbxRevision
        @($dbxFileRevisions).Count | Should -BeGreaterOrEqual 1
        $dbxFileRevisions | ForEach-Object {
            $_.Revision | Should -Not -BeNullOrEmpty
        }
        $dbxFileRevisions | ForEach-Object {
            $_.Path | Should -Be $dropboxFile.Path
        }
    }
    It 'Retrieve using DbxFile.GetRevisions()' {
        $dbxFileRevisions = $dropboxFile.GetRevisions()
        @($dbxFileRevisions).Count | Should -BeGreaterOrEqual 1
        $dbxFileRevisions | ForEach-Object {
            $_.Revision | Should -Not -BeNullOrEmpty
        }
        $dbxFileRevisions | ForEach-Object {
            $_.Path | Should -Be $dropboxFile.Path
        }
    }
}

Describe 'Save-DbxFile' {
    BeforeAll {
        [DbxFile]$script:dropboxFile = Get-DbxItem -File | `
            # Where-Object{ $_.DisplaySize -match '.+? (B|KiB)\s*'} | ` # Select the items measured in bytes or kb.
            Sort-Object -Property 'Size' | Select-Object -First 1
        [string]$script:currentDirectory = Get-Location
        $script:tempDirectory = Get-TempDirectory
        Push-Location
        Set-Location $tempDirectory
    }
    BeforeEach {
        $script:targetFileName = Get-TempFile -Path $tempDirectory -DoNotCreateFile
    }
    It 'Save a file locally defaulting the target name to the name of the file' {
        $targetFileName = Get-TempFile -Path $tempDirectory -Name $(Split-Path -Leaf $dropboxFile.Path) -DoNotCreateFile
        # TODO: Determine how to drop the explicit '-DropboxPath' parameter name
        Save-DbxFile -DropboxPath $dropboxFile.Path # | Select-Object -ExpandProperty Path | Should -Be $targetFileName
        Test-Path $targetFileName | Should -BeTrue
    }
    It 'Save a file locally with the specific target name' {
        # TODO: Determine how to drop the explicit '-DropboxPath' parameter name
        Save-DbxFile -DropboxPath $dropboxFile.Path -TargetPath $targetFileName.FullName
        Test-Path $targetFileName | Should -BeTrue
    }
    It 'Pipe Get-DbxFile -File into Save-DbxFile' {
        # Save off the expected target file name so that it can be disposed.
        $targetFileName = Get-TempFile -Path $tempDirectory -Name $(Split-Path -Leaf $dropboxFile.Path) -DoNotCreateFile
        $savedFileInfo = Get-DbxItem -File -Path $dropboxFile.Path | Save-DbxFile
        $savedFileInfo | Should -Not -BeNullOrEmpty
        Test-Path $savedFileInfo | Should -BeTrue
        $savedFileInfo.FullName | Should -Be $targetFileName.FullName -Because "$($savedFileInfo.FullName) -ne $targetFileName"
    }
    AfterEach {
        $targetFileName.Dispose()
        # Get-Item $targetFileName -ErrorAction Ignore | Remove-Item -Force
        Test-Path $targetFileName | Should -BeFalse
    }
    AfterAll {
        Pop-Location
        Get-Location | Should -Be $currentDirectory
        $tempDirectory.Dispose()
    }
}


Describe 'Save-DbxFile -Revision' {
    BeforeAll {
        [DbxFile]$script:dropboxFile = Get-DbxItem -File | `
            # Where-Object{ $_.DisplaySize -match '.+? (B|KiB)\s*'} | ` # Select the items measured in bytes or kb.
            Sort-Object -Property 'Size' | `
            Where-Object{ $_.GetRevisions().Count -gt 1} | `
            Select-Object -First 1
        [string]$script:currentDirectory = Get-Location
        $script:tempDirectory = Get-TempDirectory
        Push-Location
        Set-Location $tempDirectory
    }
    BeforeEach {
        $script:targetFileName = Get-TempFile -Path $tempDirectory -DoNotCreateFile
    }
    It 'Save a file locally defaulting the target name to the name of the file' {
        $targetFileName = Get-TempFile -Path $tempDirectory -Name $(Split-Path -Leaf $dropboxFile.Path) -DoNotCreateFile
        # TODO: Determine how to drop the explicit '-DropboxPath' parameter name
        Save-DbxFile -DropboxPath $dropboxFile.Path -Revision $dropboxFile.GetRevisions()[-1].Revision # | Select-Object -ExpandProperty Path | Should -Be $targetFileName
        Test-Path $targetFileName | Should -BeTrue
    }
    # It 'Save a file locally with the specific target name' {

    #     # TODO: Determine how to drop the explicit '-DropboxPath' parameter name
    #     Save-DbxFile -DropboxPath $dropboxFile.Path -TargetPath $targetFileName.FullName
    #     Test-Path $targetFileName | Should -BeTrue
    # }
    AfterEach {
        $targetFileName.Dispose()
        # Get-Item $targetFileName -ErrorAction Ignore | Remove-Item -Force
        Test-Path $targetFileName | Should -BeFalse
    }
    AfterAll {
        Pop-Location
        Get-Location | Should -Be $currentDirectory
        $tempDirectory.Dispose()
    }
}