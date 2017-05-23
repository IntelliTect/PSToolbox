[CmdletBinding()]
param(
  [string]$version
)

$globalJsonPath = Join-Path $pwd 'global.json'
$globalJsonContent = Get-Content $globalJsonPath -raw | ConvertFrom-Json
$globalJsonContent.sdk | % {$_.version=$version}
$globalJsonContent | ConvertTo-Json  | Set-Content $globalJsonPath 