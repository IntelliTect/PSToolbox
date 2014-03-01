Function Get-WindowsSpecialFolders([string] $filter) {
    [System.Enum]::GetValues([System.Environment+SpecialFolder]) | %{
        [PSCustomObject] @{ Name=($_.ToString().Trim()); Path=([Environment]::GetFolderPath($_)) }
    }
}