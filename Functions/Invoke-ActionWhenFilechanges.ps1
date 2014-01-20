#TODO: Add escape (Cancel) from while (likely using CancellationTokenSource).
Function Invoke-ActionWhenFileChanges([string]$path = (Get-Location), [ScriptBlock] $script, [switch]$includeSubdirectories = $true) {

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $path
    $watcher.IncludeSubdirectories = $includeSubdirectories
    $watcher.EnableRaisingEvents = $false
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName
 
    while($TRUE){
	    $result = $watcher.WaitForChanged(
            [System.IO.WatcherChangeTypes]::Changed -bor [System.IO.WatcherChangeTypes]::Renamed -bOr [System.IO.WatcherChangeTypes]::Created, 1000);
	    if($result.TimedOut){
		    continue;
	    }
	    Write-host "Change in " + $result.Name
	    Invoke-Command $script
    }

}