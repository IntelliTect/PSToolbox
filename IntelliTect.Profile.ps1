$here = $PSScriptRoot

$ProfileISE = (Join-Path $here Profile_ISE.ps1)
if(Test-Path $ProfileISE) { . $ProfileISE }

Get-childItem (Join-Path $here Functions) *.ps1 | ?{
    $_.Name -notlike "__*.ps1" } | %{ . $_.FullName }