$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut


Describe "Test-IsStaticType" {
    It "Test-IsStaticType" {
        Test-IsStaticType ([System.Console]) | Should Be $true
    }
}

Describe "Get-ReflectionExtensionMemebers" {
    It "For System.Linq.Enumerable" {
        $extensionMEmbers = Get-ReflectionExtensionMemebers ([System.Linq.Enumerable])
        ($extensionMEmbers | select -ExpandProperty Name) -contains "Where" | Should Be $true
    }
    It "For System.Console" {
        $extensionMEmbers = Get-ReflectionExtensionMemebers ([System.Console])
        $extensionMEmbers | Should Be $null
    }
}
