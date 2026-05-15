# IntelliTect.PSToolbox

[![Pull Request](https://github.com/IntelliTect/PSToolbox/actions/workflows/PullRequest.yml/badge.svg)](https://github.com/IntelliTect/PSToolbox/actions/workflows/PullRequest.yml)

A small, curated set of PowerShell modules published to the
[PowerShell Gallery](https://www.powershellgallery.com/packages?q=Intellitect).

Requires **PowerShell 7.2 or later**. Runs on Windows, Linux, and macOS
(individual cmdlets that rely on Windows-only APIs degrade gracefully).

## Maintained modules

| Module | Description |
|---|---|
| [`IntelliTect.Common`](https://www.powershellgallery.com/packages/IntelliTect.Common/) | Generic utility functions: `Wait-ForCondition`, `Register-AutoDispose` / `Using`, `Add-DisposeScript`, `Get-TempFile`, `Get-TempDirectory`, `Add-PathToEnvironmentVariable`, `Highlight` (ANSI), etc. |
| [`IntelliTect.File`](https://www.powershellgallery.com/packages/IntelliTect.File/) | File-system helpers: `Edit-File`, `Test-FileIsLocked`, `Get-FileEncoding`, `Set-FileEncoding`, `Remove-FileToRecycleBin` (Windows), `Remove-FileSystemItemForcibly` (Windows). |
| [`IntelliTect.Git`](https://www.powershellgallery.com/packages/IntelliTect.Git/) | Git wrappers: `Invoke-GitCommand`, `Get-GitItemStatus`, `Get-GitBranch`, `Push-GitBranch`, `Remove-GitBranch`, `Find-GitBranch`, `New-GitIgnore`, `Undo-Git`, `Invoke-GitDiff`. |
| [`IntelliTect.CredentialManager`](https://www.powershellgallery.com/packages/IntelliTect.CredentialManager/) | Thin wrapper over the Windows Credential Manager. |
| [`IntelliTect.PSToolbox`](https://www.powershellgallery.com/packages/IntelliTect.PSToolbox/) | Umbrella module that pulls in all of the above. |

## Installation

```powershell
Install-Module IntelliTect.PSToolbox
```

(or, for a single module: `Install-Module IntelliTect.Common`)

## What happened to the other modules?

Version **2.0.0** removed several modules that had been superseded by
mature, out-of-the-box solutions. Use these replacements instead:

| Removed module | Recommended replacement |
|---|---|
| `AzureManagement`                  | [`Az`](https://learn.microsoft.com/powershell/azure/) |
| `IntelliTect.PSDbxCli`             | [`dbxcli`](https://github.com/dropbox/dbxcli) directly |
| `IntelliTect.PSDropbin`            | [Dropbox.Api SDK](https://www.nuget.org/packages/Dropbox.Api) |
| `IntelliTect.PSRestore`            | Built-in Windows Recycle Bin / [`Recycle`](https://www.powershellgallery.com/packages/Recycle) |
| `IntelliTect.ResharperNugetSearch` | `Find-Package` / `nuget.exe search` |
| `IntelliTect.MicrosoftWord`        | Word COM or [Open XML SDK](https://www.nuget.org/packages/DocumentFormat.OpenXml) |
| `IntelliTect.Google`               | [GShell / Google APIs PowerShell module](https://www.powershellgallery.com/packages?q=google) |
| `IntelliTect.ChatGpt`              | [`PowerShellAI`](https://www.powershellgallery.com/packages/PowerShellAI) |
| `DotNetCore`                       | `dotnet` CLI directly |
| `Functions/` loose scripts         | Module the bits you need yourself; most are now obsolete (ISE, TFS, etc.) |

The complete **1.x** history is preserved in this repository at
the tag [`v1.0-legacy`](https://github.com/IntelliTect/PSToolbox/releases/tag/v1.0-legacy)
and the branch [`legacy/v1`](https://github.com/IntelliTect/PSToolbox/tree/legacy/v1).
See [`PROJECT_OVERVIEW.md`](PROJECT_OVERVIEW.md) for the in-depth review that motivated this trim.

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md).
