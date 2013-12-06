$here = $PSScriptRoot

Get-childItem (Join-Path $here Functions) *.ps1 | ?{
    $_.Name -notlike "__*.ps1" } | %{ . $_.FullName }