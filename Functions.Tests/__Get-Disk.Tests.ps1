$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

Describe "Get-Disk" {
    It "has a FormatStartData" {
        $target = Get-Disk
        $target[0].GetType().Name | Should Be "FormatStartData"
    }

    It "has a GroupStartData" {
        $target = Get-Disk
        $target[1].GetType().Name | Should Be "GroupStartData"
    }

    It "has a FormatEntryData" {
        $target = Get-Disk
        $target[2].GetType().Name | Should Be "FormatEntryData"
    }

    It "has a GroupEndData" {
        $target = Get-Disk
        $target[($target.Count -2)].GetType().Name | Should Be "GroupEndData"
    }

    It "has a FormatEndData" {
        $target = Get-Disk
        $target[($target.Count -1)].GetType().Name | Should Be "FormatEndData"
    }
}