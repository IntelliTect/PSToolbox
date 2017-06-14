Function Set-DotNetSdkVersion {
  [CmdletBinding()]
  param(
    [string]$version,
    [string]$folder = $pwd
  )

  if(Test-Path "global.json") {
      $globalJsonPath = (Resolve-Path 'global.json').Path
      $globalJsonContent = Get-Content $globalJsonPath -raw | ConvertFrom-Json
  }
  else {
    $globalJsonPath = Join-Path $pwd 'global.json'
    Write-Output (New-Item -ItemType File $globalJsonPath)
    $globalJsonContent = "{
    `"sdk`":  {
                `"version`":  `"2.0.0`"
            }
      }" | ConvertFrom-Json
  }
  
  $globalJsonContent.sdk | % {$_.version=$version}
  $globalJsonContent | ConvertTo-Json  | Set-Content $globalJsonPath
  Write-Output $globalJsonContent
}