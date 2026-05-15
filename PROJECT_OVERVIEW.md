# IntelliTect.PSToolbox — Project Overview & Modernization Review

> A deep review of every module, function, and supporting file in this repository, with current-state assessment and modern-replacement guidance.
>
> **Repository state at time of review:** last commit on `main` is `3db40cf` (2022-12-16). Tests already use Pester 5 syntax (`Should -Be`), but CI invocation, manifests, and many functions are pre‑PowerShell‑7 era.
>
> **Target runtime considered "modern":** PowerShell 7.4 LTS / 7.6 (current LTS), running on Windows, Linux, and macOS.

---

## 1. Repository layout

| Path | Purpose | Status |
|---|---|---|
| `Modules/` | Active modules published to PowerShell Gallery | Mixed — see §2 |
| `Functions/` | Loose `.ps1` scripts dot-sourced by `Main.ps1`; not a module | Mostly obsolete — see §3 |
| `Archived Modules/` | Retired modules left in source tree | Should be deleted — see §4 |
| `Modules.Tests/` | Pester tests for modules | Pester 5 syntax already; runs OK |
| `Functions.Tests/` | Pester tests for loose scripts; also contains 31 MB of `.CR2` + `.tcx` fixtures | Fixtures shouldn't be in git |
| `submodules/RamblingCookieMonster/PowerShell` | Third-party submodule | Unused; SSH-only URL breaks anonymous clones |
| `Lib/`, `Content/`, `temp/` | Miscellaneous binaries / scratch | Investigate before deleting |
| `Main.ps1`, `Main.Tests.ps1` | Dot-source-everything entry point | Obsolete; modules should be imported individually |
| `Setup.ps1` | Admin-required bootstrap, adds ISE alias | ISE is dead; rewrite or delete |
| `Publish.ps1` | PSGallery publisher using `Publish-Module` | Migrate to `Publish-PSResource` |
| `PSScriptAnalyzerSettings.psd1` | Empty rule set (`ExcludeRules = @()`) | Analyzer effectively disabled |
| `.github/workflows/PullRequest.yml` | Pester + dotnet build/test on PR | Uses `actions/checkout@v2` (deprecated) and Pester 4 `-OutputFormat NUnitXML` |
| `.github/workflows/Deploy.yml` | Discovers changed module folders and publishes | Uses `actions/checkout@v2`; relies on PowerShellGet v2 `Publish-Module` |

---

## 2. Modules — inventory & modernization verdict

Legend: 🟢 keep · 🟡 keep with rewrite · 🔴 deprecate · ⚫ already obsolete

### 2.1 `IntelliTect.Common` — 🟢 **keep (with fixes)**

Version `0.2.0.7` · Author: Mark Michaelis · No external dependencies.

| Function | What it does | Modern equivalent | Verdict |
|---|---|---|---|
| `Add-PathToEnvironmentVariable` | Append a path to `$env:PATH` (or any env var) with dedup, at User/Machine/Process scope | None in PS 7 — `[Environment]::SetEnvironmentVariable` is the raw primitive but does not dedup | **Keep** |
| `Invoke-ShouldProcess` | Helper that wraps `$PSCmdlet.ShouldProcess` + scriptblock execution | None | **Keep** |
| `ConvertFrom-Hashtable` | Hashtable → `PSCustomObject` | `[PSCustomObject]$hashtable` (native in PS 5+) | **Replace inline** — one-liner suffices |
| `Highlight` (alias `HL`) | Print matching lines yellow via `Write-Host` | `Select-String` does not colorize; PS 7 ANSI escapes give cleaner result | **Keep but modernize** — use `"$([char]27)[33m$line$([char]27)[0m"` |
| `Initialize-Array` | Returns `$args` as an array | None — but trivial; `@($a, $b, $c)` is idiomatic | **Remove** |
| `Add-DisposeScript` | Bolts `Dispose()` + `IsDisposed` onto an arbitrary object | None — PS has no IDisposable-style `using` block | **Keep** |
| `Register-AutoDispose` (alias `Using`) | `try { … } finally { $obj.Dispose() }` wrapper | None | **Keep** |
| `Get-TempDirectory` | Create a `[DirectoryInfo]` in `$env:TEMP` with Dispose hook | No native temp-directory cmdlet ([PS#5009](https://github.com/PowerShell/PowerShell/issues/5009)) | **Keep** |
| `Get-TempFile` | Same as above for files | `New-TemporaryFile` (PS 5.1+) returns a `[FileInfo]` but has no Dispose | **Thin wrapper over `New-TemporaryFile`** |
| `Get-FileSystemTempItemPath` | Generates a non-existent path under `$env:TEMP` | `[IO.Path]::GetTempFileName()` / `GetRandomFileName()` | **Keep** (small) |
| `ConvertTo-Lines` | Split a string on newlines | `$s -split "`r?`n"` | **Remove** — too trivial |
| `Test-Command` | `Get-Command -ErrorAction Ignore` as a bool | None — but trivial | **Keep** |
| `Test-Property` | Check if a property name exists on an object | None | **Keep** |
| `Test-VariableExists` | `Test-Path Variable:\$Name` | None | **Keep** |
| `Get-IsWindowsPlatform` | Detect Windows | `$IsWindows` (automatic variable since PS 6) | **Remove** — and the function is **buggy** (returns `$true` on Linux/macOS PS 7, see §5) |
| `Set-IsWindowsVariable` | Sets a global `$IsWindows` if not present | Automatic in PS 6+ | **Remove** — runs on import as a side effect |
| `Wait-ForCondition` | Poll a predicate against a pipeline of items with timeout | None in `Microsoft.PowerShell.Utility` | **Keep** |

---

### 2.2 `IntelliTect.Git` — 🟢 **keep (with fixes)**

Version `1.0.0.0` · Depends on `IntelliTect.Common`. Exports `*`.

| Function | What it does | Modern equivalent | Verdict |
|---|---|---|---|
| `Invoke-GitCommand` | Runs git with `ShouldProcess`, color output, and optional JSON object output | None | **Keep** — fix `Start-Process`/`$LASTEXITCODE` TODO at line ~375 |
| `Get-GitRepo` | Returns `IsBare` | `git rev-parse --is-bare-repository` directly | **Optional** |
| `Get-GitItemStatus` | Parses `git status --porcelain` to objects | `git status --porcelain=v2` parser; no module covers this | **Keep** |
| `Update-GitAuthor` | Rewrites a single commit's author via `git replace` | Use `git rebase -i --exec` or `git filter-repo` (modern replacement for `filter-branch`) | **Keep but document** |
| `New-GitIgnore` | Fetches `.gitignore` from `gitignore.io` | `gitignore.io` now redirects to `toptal.com/developers/gitignore/api/<type>` — still works | **Keep but update URL** and drop the 1500-char fallback list |
| `Undo-Git` | `git reset --hard` + `git clean -f -d -X` | Direct git commands | **Keep** — useful one-stop wrapper |
| `Get-GitBranch` | Current branch name | `git branch --show-current` (Git 2.22+) | **Keep** (older-Git fallback retained) |
| `Remove-GitBranch` | Delete branches matching a pattern | None — `git branch -D` does not support wildcards | **Keep** |
| `Find-GitBranch` | List branches matching a pattern | `git branch --list <pattern>` | **Optional** |
| `Get-GitItemProperty` | Valid `git --format` field names | Static list; useful for tab-completion | **Keep** |
| `Push-GitBranch` | `git push` with optional `--set-upstream` | None — fills a niche | **Keep but fix:** bypasses its own `Invoke-GitCommand`, uses inline `git`, mishandles `$LASTEXITCODE` |
| `Invoke-GitDiff` | Colorized diff between two files | `git diff --color` directly | **Optional** |

---

### 2.3 `IntelliTect.File` — 🟡 **keep partial, replace recycle/encoding**

Version `0.5` · Depends on `IntelliTect.Common`. Exports `*`.

| Function | What it does | Modern equivalent | Verdict |
|---|---|---|---|
| `Edit-File` | `New-Item` if missing + `Invoke-Item` | None — but does what its name says | **Keep** |
| `Test-FileIsLocked` | Try-open with `FileShare.None` to detect locks | None | **Keep** |
| `Set-FileEncoding` | Convert files between encodings | `Get-Content -Encoding`/`Set-Content -Encoding` already work; this is a thin wrapper | **Optional** |
| `Get-FileEncoding` | Detect by BOM | **Broken in PS 6+** — uses `Get-Content -Encoding byte` (removed); needs `-AsByteStream`. Replace with `[IO.StreamReader]::new($p).CurrentEncoding` after a read. | **Rewrite** |
| `Remove-FileToRecycleBin` | Send to recycle bin via `Microsoft.VisualBasic.FileIO` | [`Recycle`](https://www.powershellgallery.com/packages/Recycle) — `Remove-ItemSafely` | **Replace with `Recycle`** |
| `Test-ItemIsEmpty` | Is a directory empty? | None | **Keep** |
| `Remove-FileSystemItemForcibly` | Robocopy-based force delete | None (clever Windows-only hack) | **Keep on Windows** |
| `Join-Path` | n-ary `Join-Path` wrapper | PS 7 `Join-Path` natively accepts `-AdditionalChildPath` | **Remove** |

---

### 2.4 `IntelliTect.CredentialManager` — 🔴 **deprecate** in favor of `CredentialManager` or `SecretManagement`

Version `1.1.1.1` · Depends on `IntelliTect.Common`. Windows-only.

Wraps `cmdkey.exe` (write) and P/Invokes `ADVAPI32.CredRead` (read). Contains ~35 lines of **dead code** after an unconditional `Return;` (psm1 lines 65–101). `Remove-CredentialManagerCredential` and `Get-CredentialPassword` are defined but **not exported**.

| Use case | Modern replacement |
|---|---|
| Windows-only drop-in | [`CredentialManager`](https://www.powershellgallery.com/packages/CredentialManager) v2.0 — `Get-StoredCredential` / `Set-StoredCredential` / `Remove-StoredCredential` |
| Cross-platform | [`Microsoft.PowerShell.SecretManagement`](https://www.powershellgallery.com/packages/Microsoft.PowerShell.SecretManagement) + [`Microsoft.PowerShell.SecretStore`](https://www.powershellgallery.com/packages/Microsoft.PowerShell.SecretStore) |
| Bridge — SecretManagement using Windows Credential Manager as backend | [`SecretManagement.JustinGrote.CredMan`](https://www.powershellgallery.com/packages/SecretManagement.JustinGrote.CredMan) |

**Verdict:** retire. Optionally republish as a thin shim that re-exports `CredentialManager`'s cmdlets under the IntelliTect names for back-compat.

---

### 2.5 `IntelliTect.PSRestore` — 🔴 **deprecate** — replaced by PSReadLine

Version `0.4.0.0` · Restores command history and ISE working directory across sessions. Heavily ISE‑specific.

PSReadLine ships with PowerShell 7 and provides cross-session history out of the box:

```powershell
Set-PSReadLineOption -HistorySavePath "$env:USERPROFILE\.ps_history"
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -MaximumHistoryCount 10000
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
```

All ISE-related code paths are dead in PS 6+ (ISE is not shipped). **Retire the module entirely.**

---

### 2.6 `AzureManagement` — ⚫ **already obsolete**

Version `1.0` · Wraps the AzureRM and Azure Service Management modules (`Install-Module AzureRM`, `Login-AzureRmAccount`, `New-AzureVM`, etc.). **AzureRM was retired by Microsoft on 2024-02-29**; the modules no longer install or authenticate against current Azure.

Replace with [`Az`](https://www.powershellgallery.com/packages/Az). The IntelliTect wrappers are not 1-to-1 with `Az` cmdlets and would need to be rewritten from scratch. Easiest path: **delete the module**; consumers use `Az` directly.

---

### 2.7 `IntelliTect.MicrosoftWord` — 🔴 **deprecate or rewrite**

Version `0.5.0.12` · 47 KB of `Word.Application` COM Interop. Requires Office installed on Windows. Functions: `Open-WordDocument`, `Get-WordDocumentComment`, `Update-WordDocumentAcceptAllChanges`, `Set-WordDocumentTrackChanges`, `Invoke-WordDocumentFindReplace`, `Compare-WordDocument`, etc.

Modern alternative: [`DocumentFormat.OpenXml`](https://www.nuget.org/packages/DocumentFormat.OpenXml) NuGet (cross-platform, no Word install) or [`PSWriteOffice`](https://www.powershellgallery.com/packages/PSWriteOffice). Not drop-in — different object model. Decide based on whether any consumers actually depend on this.

---

### 2.8 `IntelliTect.PSDbxCli` — 🔴 **deprecate**

Version `0.5` · Wraps `dbxcli.exe`. Functions: `Get-DbxItem`, `Write-DbxFile`, `Save-DbxFile`, `Get-DbxRevision`, etc.

[`dbxcli`](https://github.com/dropbox/dbxcli) was never officially supported by Dropbox (their README states this explicitly) and has had no meaningful changes since 2019–2020. Modern alternatives:

- [`rclone`](https://rclone.org) — actively maintained, supports Dropbox as a backend
- Dropbox API v2 via `Invoke-RestMethod` against `https://api.dropboxapi.com/2/`

**Delete.**

---

### 2.9 `IntelliTect.PSDropbin` — 🔴 **deprecate**

Version `0.7.1.0` · Binary module (`bin\IntelliTect.PSDropbin.dll`) implementing a PowerShell provider for Dropbox. The DLL is checked in. Same Dropbox-CLI-era concerns; no maintenance since the original commit.

**Delete unless someone is still using it.**

---

### 2.10 `IntelliTect.ResharperNugetSearch` — 🔴 **deprecate**

Version `1.0.0.1` · Calls `http://resharper-nugetsearch.jetbrains.com/api/v1/find-type` / `find-namespace`. The API is technically still alive but its index is frozen at ~2019 — it misses every package newer than that.

Modern replacement: NuGet's own v3 search API:

```powershell
Invoke-RestMethod 'https://azuresearch-usnc.nuget.org/query?q=IEnumerable&prerelease=false' |
  Select-Object -ExpandProperty data
```

Also note two bugs in the existing code: `Write-Verbose "Page size: $($result.pageSize)"` at lines ~73 and ~149 should be `$results.pageSize` (silently logs nothing today).

**Delete.**

---

### 2.11 `IntelliTect.Google` — 🔴 **deprecate**

Version `1.5.3.0` · Functions: `Search-Google` (opens a browser URL), `Get-GoogleSession` (scrapes the Google login flow), `Get-GoogleLocationHistoryKmlFile` (downloads Google Location History KML).

`Get-GoogleSession` does form-scraping of the Google login page — brittle and likely already broken given Google's auth-flow changes. Location History KML export is now done through [Google Takeout](https://takeout.google.com/). Google has also been migrating Location History from server-side to on-device.

**Delete.** If location-history processing is still valuable, replace with a script that consumes Takeout output.

---

### 2.12 `IntelliTect.PSToolbox` — 🟡 **keep as the umbrella manifest**

Version `1.4.2.4` · No `RootModule`; only a `RequiredModules` list. Acts purely as a meta‑package to install the others. After path B (slim-and-modernize) the `RequiredModules` should shrink to `IntelliTect.Common` and `IntelliTect.Git`. Bump to a new major version when published.

---

### 2.13 `DotNetCore` — 🟡 **keep**

Version `0.2` · Single exported function `Set-DotNetSdkVersion` that updates/creates `global.json`. No external dependencies. Useful and small. Note manifest does not enumerate `FunctionsToExport`. **Keep with a manifest cleanup.**

---

## 3. `Functions/` — loose scripts

`Main.ps1` dot-sources every `*.ps1` in this directory (excluding `__*.ps1`, and excluding `*_ISE.ps1` unless running under ISE). This is a 2014-era pattern; it is not a module and cannot be published.

| File | Purpose | Verdict |
|---|---|---|
| `Azure.ps1` (28 KB) | Misc Azure helpers, AzureRM-era | 🔴 Delete |
| `Clear-Temp.ps1` | Cleans `$env:TEMP` | 🟡 Move to `IntelliTect.File` |
| `Computer.ps1` | Tiny helper | 🔴 Delete |
| `ConvertFrom-LabelColonValue.ps1` | Parses `Label: Value` text blocks | 🟡 Move to `IntelliTect.Common` if used |
| `Device.ps1` | Tiny helper | 🔴 Delete |
| `Disable-IEEnhancedSecurity.ps1` | Turns off IE ESC | 🔴 Delete (IE is retired) |
| `DotNetCore.ps1` | Duplicates `DotNetCore` module | 🔴 Delete |
| `File_ISE.ps1` | ISE editor helpers | 🔴 Delete (ISE dead) |
| `GeoTrack.ps1` | GPS / geo-tracking | 🟡 Keep only if used; otherwise extract to a personal repo |
| `Get-PSToDo.ps1` | 109-byte helper | 🔴 Delete |
| `Get-TfInfo.ps1` | TFS helper | 🔴 Delete; use `TfsCmdlets` or `az devops` |
| `Get-WindowsSpecialFolders.ps1` | Wraps `[Environment]::GetFolderPath` | 🔴 Delete (one-liner) |
| `HostsFileEntry.ps1` | Edit `hosts` file | 🔴 Replace with [`PSHosts`](https://www.powershellgallery.com/packages/PSHosts) |
| `Import-VisualStudioVars.ps1` | Imports VS dev env | 🔴 Replace with `Enter-VsDevShell` from the `VSSetup` module |
| `Invoke-ActionWhenFilechanges.ps1` | `FileSystemWatcher` wrapper | 🟡 Move to `IntelliTect.File` if kept |
| `Member.ps1` | Reflection helpers | 🟡 Move to `IntelliTect.Common` if kept |
| `MicrosoftWindows.ps1` | Misc Windows helpers | 🔴 Delete |
| `New-CommentHelp.ps1` | Generates comment-based help scaffold | 🟡 Keep if used; otherwise [PlatyPS](https://github.com/PowerShell/platyPS) is better |
| `New-NugetPackage.ps1` | Wraps `nuget.exe pack` | 🔴 Replace with `dotnet pack` |
| `New-PSCustomObject.ps1` | Object construction helper | 🔴 Delete (use `[PSCustomObject]@{…}`) |
| `Photo.ps1` (23 KB) | Photo manipulation | 🟡 Personal-use; consider extraction |
| `PhotoLibrary.xml` (146 KB) | Reference data | 🔴 Should not be in repo |
| `PowerShellScripting.ps1` | **Empty file (0 bytes)** | 🔴 Delete |
| `Program.ps1` (27 KB) | Program/process helpers | 🟡 Review case-by-case |
| `PSScript.ps1`, `PSScript_ISE.ps1` | Script helpers | 🟡 Drop `_ISE`; review the rest |
| `PushBullet.ps1` | Send push notifications via Pushbullet | 🔴 Delete; service is effectively abandoned. Modern picks: [`ntfy`](https://ntfy.sh), Pushover, Telegram Bot API |
| `Reflection.ps1` | Reflection helpers | 🟡 Move to `IntelliTect.Common` if kept |
| `TCX.ps1` | TCX activity files | 🟡 Niche; extract |
| `TFS.ps1` | TFS commands | 🔴 Delete; use `TfsCmdlets` or `az devops` |
| `ToDo.ps1` | **Empty file (0 bytes)** | 🔴 Delete |
| `VSProject.ps1` | VS .csproj manipulation | 🟡 Consider replacing with `dotnet`/MSBuild |
| `WindowsSearchIndex.ps1` | Windows Search index | 🟡 Niche; review |
| `WindowsShortcut.ps1` | Create `.lnk` files | 🟡 Keep — no maintained module covers this |
| `__Colorizer.ps1.__`, `__Get-Disk.ps1.__` | Hidden backup artifacts | 🔴 Delete |

---

## 4. `Archived Modules/`

| Module | Status |
|---|---|
| `IntelliTect.AzureRm` | Already archived; AzureRM is retired. **Delete from repo.** |
| `IntelliTect.DropboxToGit` | Already archived. **Delete from repo.** |

Keeping archived modules in source confuses readers and adds search noise. They live in git history if needed.

---

## 5. Bugs & dead code (concrete, with citations)

| # | File:line | Issue |
|---|---|---|
| 1 | `Modules\IntelliTect.CredentialManager\IntelliTect.CredentialManager.psm1:65` | Unconditional `Return;` followed by ~35 lines of dead P/Invoke code |
| 2 | `Modules\IntelliTect.CredentialManager\IntelliTect.CredentialManager.psd1` | `Remove-CredentialManagerCredential` and `Get-CredentialPassword` defined in `.psm1` but **not** in `FunctionsToExport` |
| 3 | `Modules\IntelliTect.Common\IntelliTect.Common.psm1:381-386` | `Get-IsWindowsPlatform` is broken — returns `$true` on Linux/macOS under PS 7 Core because the second clause `($PSEdition -eq 'Core')` matches on every platform. Operator precedence treats this as `($IsWindows -or 'PSEdition' -in $keys) -and (Desktop OR Core)` |
| 4 | `Modules\IntelliTect.Common\IntelliTect.Common.psm1:398` | `Set-IsWindowsVariable` runs **on module import** as a side effect, polluting the global scope |
| 5 | `Modules\IntelliTect.File\IntelliTect.File.psm1:129` | `Get-FileEncoding` uses `Get-Content -Encoding byte` which was **removed in PowerShell 6**; needs `-AsByteStream` |
| 6 | `Modules\IntelliTect.Git\IntelliTect.Git.psm1:163-187` | `New-GitIgnore` URL is `gitignore.io` — now redirects to `toptal.com/developers/gitignore`; works but should be updated. Hard-coded 1500-char fallback list is unmaintainable. |
| 7 | `Modules\IntelliTect.Git\IntelliTect.Git.psm1:362-384` | `Push-GitBranch` bypasses its own `Invoke-GitCommand` wrapper, mishandles `$LASTEXITCODE`, and uses inline `git rev-parse` for upstream detection |
| 8 | `Modules\IntelliTect.ResharperNugetSearch\IntelliTect.ResharperNugetSearch.psm1:~73,~149` | `Write-Verbose "Page size: $($result.pageSize)"` — typo; should be `$results.pageSize` (verbose log shows nothing) |
| 9 | `Modules\IntelliTect.PSToolbox\IntelliTect.PSToolbox.psd1:12` | `RootModule` commented out; `FunctionsToExport = '*'` and `CmdletsToExport = '*'` defeat module-discovery performance |
| 10 | `Functions\ToDo.ps1`, `Functions\PowerShellScripting.ps1` | **Empty 0-byte files**, dot-sourced by `Main.ps1` |
| 11 | `Functions\__Colorizer.ps1.__`, `Functions\__Get-Disk.ps1.__` | Hidden backup artifacts left in source |
| 12 | `Functions.Tests\IMG_2452.CR2`, `IMG_2456.CR2`, `activity_521153787.tcx`, etc. | ~31 MB of binary fixtures committed to git; should be Git LFS or excluded |
| 13 | `.github\workflows\PullRequest.yml`, `.github\workflows\Deploy.yml` | `actions/checkout@v2` is deprecated; `Invoke-Pester -OutputFormat NUnitXML` is Pester v4 syntax (Pester 5 uses configuration objects) |
| 14 | `Publish.ps1` | Uses `Publish-Module` (PowerShellGet v2); preferred path is `Publish-PSResource` (PSResourceGet, bundled with PS 7.4+) |
| 15 | `Setup.ps1` | Requires admin rights to add an ISE alias — ISE is no longer shipped or supported |
| 16 | `.gitmodules` | Submodule URL is `git@github.com:RamblingCookieMonster/PowerShell.git` — SSH-only, breaks anonymous clones. The submodule does not appear to be used. |
| 17 | Several modules use `FunctionsToExport = '*'` | Defeats fast module auto-discovery in PS 7; should be explicit |

---

## 6. Replacement matrix (capability → modern)

| Capability | This repo | Modern replacement | Drop-in? |
|---|---|---|---|
| Windows Credential Manager | `IntelliTect.CredentialManager` | [`CredentialManager`](https://www.powershellgallery.com/packages/CredentialManager) v2.0 | Near drop-in (different verb-nouns) |
| Cross-platform secrets | — | [`Microsoft.PowerShell.SecretManagement`](https://www.powershellgallery.com/packages/Microsoft.PowerShell.SecretManagement) + [`SecretStore`](https://www.powershellgallery.com/packages/Microsoft.PowerShell.SecretStore) | No (new architecture) |
| Command history | `IntelliTect.PSRestore` | [`PSReadLine`](https://www.powershellgallery.com/packages/PSReadLine) (ships with PS 7) | Yes — superior |
| Azure | `AzureManagement`, `Functions/Azure.ps1` | [`Az`](https://www.powershellgallery.com/packages/Az) (AzureRM retired 2024-02-29) | No |
| Dropbox | `IntelliTect.PSDbxCli`, `IntelliTect.PSDropbin` | [`rclone`](https://rclone.org) or Dropbox API v2 REST | No |
| NuGet search | `IntelliTect.ResharperNugetSearch` | NuGet v3 search API directly | No (REST) |
| Word docs | `IntelliTect.MicrosoftWord` (COM) | [`DocumentFormat.OpenXml`](https://www.nuget.org/packages/DocumentFormat.OpenXml) NuGet or [`PSWriteOffice`](https://www.powershellgallery.com/packages/PSWriteOffice) | No |
| Recycle bin | `Remove-FileToRecycleBin` | [`Recycle`](https://www.powershellgallery.com/packages/Recycle) (`Remove-ItemSafely`) | Yes |
| Hosts file | `Functions/HostsFileEntry.ps1` | [`PSHosts`](https://www.powershellgallery.com/packages/PSHosts) | Yes |
| TFS / Azure DevOps | `Functions/TFS.ps1`, `Get-TfInfo.ps1` | [`TfsCmdlets`](https://www.powershellgallery.com/packages/TfsCmdlets) (active in 2026) or `az devops` | No |
| NuGet packaging | `Functions/New-NugetPackage.ps1` | `dotnet pack` (SDK-style) / `nuget.exe` v7+ (legacy `.nuspec`) | No (CLI) |
| File encoding (BOM) | `Get-FileEncoding` | `[IO.StreamReader]::new($p).CurrentEncoding` | Inline |
| `using` / Dispose | `Register-AutoDispose` | None — PS has `using namespace/module/assembly` only, not C#-style disposal | **Keep this** |
| Temp directory | `Get-TempDirectory` | None — no native cmdlet ([PS#5009](https://github.com/PowerShell/PowerShell/issues/5009)) | **Keep this** |
| Temp file | `Get-TempFile` | `New-TemporaryFile` (PS 5.1+) — but no Dispose | Partial |
| Wait for predicate | `Wait-ForCondition` | None | **Keep this** |
| Colorized grep | `Highlight` | `Select-String` is not colorized; PS 7 ANSI escapes work natively | **Keep, modernize** |
| Add path to env var | `Add-PathToEnvironmentVariable` | None | **Keep this** |
| Push notifications | `Functions/PushBullet.ps1` | [`ntfy.sh`](https://ntfy.sh), Pushover, Telegram Bot API | No |
| ISE helpers | `*_ISE.ps1`, ISE branches of PSRestore | VS Code `$psEditor` API + `ms-vscode.PowerShell` extension | No (full rewrite) |
| Comment-based help | `New-CommentHelp.ps1` | [PlatyPS](https://github.com/PowerShell/platyPS) for external help | Different model |
| Pester tests | `Modules.Tests/`, `Functions.Tests/` | Pester 5.7.1 (tests already use `Should -Be` syntax; only the CI runner needs updating) | Mostly yes |
| Publish to PSGallery | `Publish.ps1` (`Publish-Module`) | [`Publish-PSResource`](https://learn.microsoft.com/powershell/module/microsoft.powershell.psresourceget/publish-psresource) (PSResourceGet, bundled with PS 7.4+) | Near drop-in |

---

## 7. Recommendations going forward

Three paths are realistic.

### Path A — Archive

- Mark the repo read-only on GitHub.
- Add an `ARCHIVED.md` at the root that points users at the modern replacements in §6.
- Unlist the obsolete modules from PowerShell Gallery (`AzureManagement`, `IntelliTect.PSDbxCli`, `IntelliTect.PSDropbin`, `IntelliTect.PSRestore`, `IntelliTect.ResharperNugetSearch`, `IntelliTect.MicrosoftWord`, `IntelliTect.Google`).
- Stop here.

**When to choose A:** if download counts on PSGallery are low and no internal team depends on these modules. Lowest effort, lowest ongoing cost.

### Path B — Slim and modernize (**recommended**)

The vast majority of the genuinely useful code lives in `IntelliTect.Common` and `IntelliTect.Git`. Everything else is either superseded, abandoned upstream, or one-off scripts.

1. **Delete** these modules and their tests:
   - `AzureManagement`, `IntelliTect.PSDbxCli`, `IntelliTect.PSDropbin`, `IntelliTect.PSRestore`, `IntelliTect.ResharperNugetSearch`, `IntelliTect.MicrosoftWord`, `IntelliTect.Google`
2. **Delete** `Functions/`, `Functions.Tests/`, `Main.ps1`, `Main.Tests.ps1`, `Archived Modules/`, `submodules/`, `.gitmodules`, `Lib/`, `Content/`, `temp/` (after verifying contents aren't needed).
3. **Keep, fix, and modernize** two modules + the umbrella:
   - `IntelliTect.Common` — remove `Get-IsWindowsPlatform`/`Set-IsWindowsVariable`/`Initialize-Array`/`ConvertTo-Lines`/n-ary `Join-Path`; fix or remove broken helpers; ANSI-modernize `Highlight`; thin `Get-TempFile` over `New-TemporaryFile`.
   - `IntelliTect.Git` — fix `Push-GitBranch` exit-code handling; update `New-GitIgnore` URL; drop the hard-coded fallback list.
   - `IntelliTect.PSToolbox` (umbrella) — shrink `RequiredModules` to `IntelliTect.Common`, `IntelliTect.Git`.
   - Consider keeping `IntelliTect.File` (small, useful), replacing `Get-FileEncoding` and recommending `Recycle` for recycle-bin needs. Or merge its keepers into `IntelliTect.Common`.
4. **Modernize CI**:
   - `actions/checkout@v4`
   - Run Pester 5.x via a `PesterConfiguration` object instead of `-OutputFormat NUnitXML`.
   - Publish with `Publish-PSResource` (PSResourceGet) instead of `Publish-Module`.
   - Wire up PSScriptAnalyzer with a non-empty rule set (start with `PSGallery` profile, add exceptions explicitly).
   - Cross-platform CI matrix (Windows + Ubuntu) for `IntelliTect.Common` and `IntelliTect.Git`.
5. **Cut a new major version** (`2.0.0`) for `IntelliTect.PSToolbox` to signal breaking changes. README should explicitly document which modules were retired and which third-party modules to install instead.
6. Optionally publish a thin **`IntelliTect.CredentialManager` 2.0** that just re-exports `CredentialManager`'s cmdlets under the old IntelliTect names, for back-compat.

**When to choose B:** if the niche helpers (`Wait-ForCondition`, `Register-AutoDispose`, branch wrappers, `Add-PathToEnvironmentVariable`) provide real value and you're willing to publish maintained releases. Best long-term ratio of effort to value.

### Path C — Full rewrite

Start a new repo with modern conventions:
- One module per repo (or use a monorepo with [Microsoft.PowerShell.Crescendo](https://learn.microsoft.com/powershell/utility-modules/crescendo/overview) for CLI wrappers like git).
- [PlatyPS](https://github.com/PowerShell/platyPS) for external help.
- Reusable GitHub Actions workflows.
- Modern PSScriptAnalyzer config.
- 100 % Pester 5 from the start.

Same scope as B, just cleaner. More effort; defensible if you want to take the opportunity to start fresh.

---

## Final recommendation

**Take Path B.** It rescues the ~30 % of code that is genuinely valuable, retires the ~70 % that has been quietly superseded since 2018–2023, and reduces ongoing maintenance to two small modules. Path A is acceptable if no one actively uses these modules; Path C is preferable only if you want a green-field design exercise.

## Citations

- PowerShell support lifecycle: <https://learn.microsoft.com/powershell/scripting/install/powershell-support-lifecycle>
- PSResourceGet: <https://learn.microsoft.com/powershell/module/microsoft.powershell.psresourceget/>
- AzureRM retirement notice: <https://learn.microsoft.com/powershell/azure/migrate-from-azurerm-to-az>
- ISE deprecation: <https://learn.microsoft.com/powershell/scripting/windows-powershell/ise/introducing-the-windows-powershell-ise>
- Pester 5 migration: <https://pester.dev/docs/migrations/v4-to-v5>
- PSReadLine: <https://www.powershellgallery.com/packages/PSReadLine>
- `dbxcli` unofficial-support notice: <https://github.com/dropbox/dbxcli>
- Native temp-directory cmdlet request (still open): <https://github.com/PowerShell/PowerShell/issues/5009>
