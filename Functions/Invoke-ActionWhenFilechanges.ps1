#TODO: Add escape (Cancel) from while (likely using CancellationTokenSource).
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
    $watcher.EnableRaisingEvents = $false
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName
 
    while($true){
	    $result = $watcher.WaitForChanged(
            [System.IO.WatcherChangeTypes]::Changed -bor [System.IO.WatcherChangeTypes]::Renamed -bor [System.IO.WatcherChangeTypes]::Created, 1000);
	    if($result.TimedOut){
		    continue;
	    }
	    Write-host "Change in " + $result.Name
	    Invoke-Command $script
    }
}

