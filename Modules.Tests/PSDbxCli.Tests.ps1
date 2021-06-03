<#Header#>
Set-StrictMode -Version "Latest"

# Import IntelliTect.Commonn for suppot of Get-Temp stuff.
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common

Get-Module IntelliTect.PSDbxCli | Remove-Module
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.PSDbxCli -Force
#EndHeader#>

Describe 'Test-DbxPath' {
    BeforeAll {
        $rootFiles = Get-DbxItem -File
        if(-not $rootFiles) { throw 'There are no exisint sample files at the root folder to test with.' }
        $rootDirectories = Get-DbxItem -Directory
        if(-not $rootFiles) { throw 'There are no exisint sample directories at the root folder to test with.' }
        $script:sampleFileAtRootPath = $rootFiles[(Get-Random -Maximum ($rootFiles.Count-1))].Path
        $script:sampleDirectoryAtRootPath = $rootDirectories[(Get-Random -Maximum ($rootDirectories.Count-1))].Path
    }
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
    It "Verify a directory called '$($sampleDirectoryAtRootPath.TrimEnd('/')) (without trailing slash) exists" {
        # Verify trailing slash is allowed
        Test-DbxPath -PathType Container $sampleDirectoryAtRootPath.TrimEnd('/') | Should -BeTrue
    }
    It 'Verify slash prefix will be assumed.' {
        Test-DbxPath -PathType Container $sampleDirectoryAtRootPath.TrimStart('/') | Should -BeTrue
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

Describe 'Get-DbxRevision' {
    It 'Retrieve a simple revision' {
        $items = Get-DbxItem -File
        $items | Select-Object -First 2 | ForEach-Object{
            $expectedPath = $_.Path
            $revisions = @($_ | Get-DbxRevision)
            $revisions.Count | Should -BeGreaterOrEqual 1
            $revisions | Select-Object -ExpandProperty 'Path' | Should -Be $expectedPath
        }
    }
}

Describe 'DbxFile' {
    It 'Retrieve using DbxFile.GetRevisions()' {
        $items = Get-DbxItem -File
        $items | Select-Object -First 2 | ForEach-Object{
            $expectedPath = $_.Path
            $revisions = $_.GetRevisions()
            $revisions.Count | Should -BeGreaterOrEqual 1
            $revisions | Select-Object -ExpandProperty 'Path' | Should -Be $expectedPath
        }
    }
}


Describe 'Save-DbxFile' {
    It 'Save a file locally defaulting the target name to the name of the file' {
        $items = Get-DbxItem -File
        # ToDO: Size is still a string
        $items = $items | Where-Object { $_.Size -like '* B*'} | Select-Object -First 2
        if(@($items).Count -eq 0) {
            Set-ItResult -Inconclusive -Because 'There were not items measured in bytes'
        }
        $items | ForEach-Object{
            [string]$fileName = $null
            [string]$currentDirectory = Get-Location
            try {
                Push-Location
                Set-Location $env:Temp
                $fileName = Join-Path $env:Temp $(Split-Path -Leaf $_.Path)
                if(!(Test-Path $fileName)) {
                    try {
                        Save-DbxFile $_.Path # | Select-Object -ExpandProperty Path | Should -Be $fileName
                        Test-Path $fileName | Should -BeTrue
                    }
                    finally {
                        Get-Item $fileName -ErrorAction Ignore | Remove-Item -Force
                    }
                }
                else {
                    Set-ItResult -Inconclusive -Because "The file ('$fileName') already existed"
                }
            }
            finally {
                Pop-Location
            }
            Test-Path $fileName | Should -BeFalse
            Get-Location | Should -Be $currentDirectory
        }
    }
}
