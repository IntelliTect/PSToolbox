<#Header#>
Set-StrictMode -Version "Latest"

# Import IntelliTect.Commonn for suppot of Get-Temp stuff.
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common

Get-Module IntelliTect.PSDbxCli | Remove-Module
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.PSDbxCli -Force
#EndHeader#>

Describe 'Get-DbxItem' {
    It 'Verify you can see the root' {
        $items = Get-DbxItem
        $items.Count | Should -BeGreaterOrEqual 0
        $items | Select-Object -ExpandProperty Path | Should -BeLike '/*'
    }
    It 'Verify you can see a single file' {
        $items = Get-DbxItem | Where-Object {
            $_.GetType().Name -eq 'DbxFile'} # Use name as type may not always be yet.
        $path = ($items[(Get-Random -Maximum ($items.Count-1))]).Path
        $item = Get-DbxItem $path
        $item.Path | Should -Be $path
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


