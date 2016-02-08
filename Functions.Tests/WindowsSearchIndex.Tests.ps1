$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

Describe "Get-WindowsSearchIndexDirectory" {
    It "List all items" {
        $results = Get-WindowsSearchIndexDirectory | Select -ExpandProperty PatternOrURL
        $results -contains "file:///C:\Users\" | Should Be $true
    }
    It "List file:///C:\Users\ item" {
        $results = Get-WindowsSearchIndexDirectory "file:///C:\Users\" | Select -ExpandProperty PatternOrURL
        $results.Count | Should Be 1
    }
    It "List where path is `"C:\Users\`" item" {
        $results = Get-WindowsSearchIndexDirectory "C:\Users\" | Select -ExpandProperty PatternOrURL
        $results.Count | Should Be 1
    }
    It "List where path is `"C:\Windows*\`" item" {
        $results = Get-WindowsSearchIndexDirectory "C:\Windows*\" | Select -ExpandProperty PatternOrURL
        $results.Count | Should Be 2
    }
}

Describe "New-WindowsSearchIndexDirectory and Remove-WindowsSearchIndexDirectory" {
    It "Add Item C:\PerfLogs" {
        New-WindowsSearchIndexDirectory "C:\Perflogs\"
        try {
        $results = Get-WindowsSearchIndexDirectory | Select -ExpandProperty PatternOrURL
        $results -contains "file:///C:\Perflogs\" | Should Be $true
        }
        finally {
            Remove-WindowsSearchIndexDirectory "C:\Perflogs\"
        }
        # Verify remove succeeded.
        $results = Get-WindowsSearchIndexDirectory | Select -ExpandProperty PatternOrURL
        $results -contains "file:///C:\Perflogs\" | Should Be $false
    }
}