Function Get-WindowsSpecialFolders([string] $filter="*") {
    [System.Enum]::GetValues([System.Environment+SpecialFolder]) | ?{ $_ -like $filter } | %{
        [PSCustomObject] @{ Name=($_.ToString().Trim()); Path=([Environment]::GetFolderPath($_)) } 
    }
}