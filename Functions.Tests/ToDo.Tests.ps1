

Describe "Assignment of specific type and cast create different results" {
    $hashTable = @{ A = "a"; B = "b" }
    It "Assignment without cast to a specific type is different from cast to a non-specific type" {
        [PSCustomObject]$first = $hashTable
        $second = [PSCustomObject]$hashTable
        $first | Should Be $second
    }
    It "Assignment with cast to a specific type is different from cast to a non-specific type" {
        [PSCustomObject]$first = [PSCustomObject]$hashTable
        $second = [PSCustomObject]$hashTable
        $first | should be $second
    }
}