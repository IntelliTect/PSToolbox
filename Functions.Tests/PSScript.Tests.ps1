<#Header#>
Set-StrictMode -Version "Latest"
$sut = $PSCommandPath.ToLower().Replace(".tests", "")
. $sut
[string]$here=$PSScriptRoot;
<#EndHeader#>

Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common

