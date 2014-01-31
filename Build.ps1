Import-Module (Join-Path $PSScriptRoot "PSIdeation.psm1") -Verbose -Scope Local
New-NugetPackage -inputDirectory $PSScriptRoot -outputDirectory (Join-Path $PSScriptRoot bin)