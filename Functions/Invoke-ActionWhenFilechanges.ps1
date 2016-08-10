#TODO: Add escape (Cancel) from while (likely using CancellationTokenSource).
#TODO: Document that return value is a PSEventJob
Function Invoke-ActionWhenFileChanges {
    [CmdletBinding()]
    param(
        [string]$path = (Get-Location), 
        [ScriptBlock] $script, 
        [switch]$ignoreSubdirectories
    )

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = Split-Path $path -Parent
    $watcher.Filter = Split-Path $path -Leaf
    $watcher.IncludeSubdirectories = !$ignoreSubdirectories
    $watcher.EnableRaisingEvents = $true

    Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $script
}

