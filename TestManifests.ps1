$moduleFolders = Get-ChildItem $PSScriptRoot\ChangedModules

if(!$moduleFolders) {
    throw "No modules to test."
}

foreach($moduleFolder in $moduleFolders){
    $moduleName = $moduleFolder.Name
    $moduleStatus = ""
    $manifestPath = "$($moduleFolder.FullName)\$moduleName.psd1"

    Write-Host "Testing $moduleName"

    if (!(Test-Path $manifestPath)) {
            throw "$($moduleName): Manifest was not found."
    }
    else{
        $testModuleFailed = $null
        $manifest = Test-ModuleManifest $manifestPath -ErrorVariable testModuleFailed -ErrorAction SilentlyContinue

        #Ignore errors that are caused by required modules not being installed
        $testModuleFailed = $testModuleFailed | ? { $_.ToString() -notmatch '\bRequiredModules\b' }

        if($testModuleFailed){
            Write-Error "Manifest Test Failed: `n$testModuleFailed$"
        }


        if (!$manifest.Description){
            $moduleStatus += "`n`t-Missing required description."
        }
        if (!$manifest.Author){
            $moduleStatus += "`n`t-Missing required author(s)."
        }
        if (!$manifest.CompanyName){
            $moduleStatus += "`n`t-Missing required company name."
        }
        if (!$manifest.Copyright){
            $moduleStatus += "`n`t-Missing required copyright."
        }
        if ($manifest.ExportedCommands.Count -eq 0 -and $moduleName -ne $omniModule -and -not $IgnoreNoExportedCommands){
            $moduleStatus += "`n`t-No exported commands."
        }

        if($moduleStatus -ne "") {
            Write-Error "$($moduleName): $moduleStatus"
        }
        Write-Host "$moduleName has a valid manifest"
    }
}