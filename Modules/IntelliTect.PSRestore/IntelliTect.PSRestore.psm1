

function script:Get-HistoryCsvHeader() {
    $historyHeader = @()
    $historyHeader += '#TYPE Microsoft.PowerShell.Commands.HistoryInfo'
    $historyHeader += '"Id","CommandLine","ExecutionStatus","StartExecutionTime","EndExecutionTime"'
    return $historyHeader.Clone();
}

function script:Get-PowerShellHistoryFileName {
    $currentTabTitle = $null; 
    if(Test-path variable:psise) {
        $currentTabTitle = ".$($psise.CurrentPowerShellTab.DisplayName)"
    }
    return ([io.path]::ChangeExtension( $profile , "$currentTabTitle.CommandHistory.csv"))
}


function Import-PowerShellHistory {
<#
    .SYNOPSIS
        Imports PowerShell history from the given .csv file into the current session.
    .EXAMPLE
        Import-PowerShellHistory
    .PARAMETER HistoryLogFile
        The file to import history from. This file is generated with Export-PowerShellLastCommand. Defaults to a file named after the current tab (ISE) or window name (PowerShell)
    .NOTES
        In PowerShell ISE, this does not import commands to the buffer accessed with the up-arrow key. To access these imported commands, type # and press tab, or run Get-History
#>

    [CmdletBinding()]
    param(
        [string] $historyLogFile = (Get-PowerShellHistoryFileName),
        [switch] $passthru
    )
    # See http://jamesone111.wordpress.com/2012/01/28/adding-persistent-history-to-powershell/ to save history across sessions
    # For more history stuff check out http://orsontyrell.blogspot.ca/2013/11/true-powershell-command-history.html
    Write-Host "PowerShellRestore: Restoring history: $historyLogFile"
    $MaximumHistoryCount = 2048;
    $truncateLogLines = 1000
    if (Test-Path $historyLogFile) {
        #TODO: Change so that Select -Unique excludes the ID number and DateTime stamps which currently makes all items unique.
        $csvImport = Import-Csv $historyLogFile
        if($csvImport -and $csvImport.Count -gt 0) {
            $history = $csvImport[-([math]::Min($csvImport.Length, $truncateLogLines))..-1]
            # $history += $historyLogFileContents[-([math]::Min($historyLogFileContents.Length, $truncateLogLines))..-1] | where {$_ -match '^"\d+"'} | select -Unique
            $history | Add-History -Passthru:$passthru # -errorAction SilentlyContinue 
        }
    }
}

Function Export-PowerShellLastCommand {
<#
    .SYNOPSIS
        Appends the last run command in the current session to the given .csv file.
    .EXAMPLE
        Export-PowerShellLastCommand
    .PARAMETER HistoryLogFile
        The file to export history to. This file is consumed by Import-PowerShellHistory. Defaults to a file named after the current tab (ISE) or window name (PowerShell)
#>

    [CmdletBinding()]
    param(
        [string] $historyLogFile = (Get-PowerShellHistoryFileName)
    )

    [int] $id = 0;
    $history = @(get-history -count 2);
    if($history)
    {
        if($history.Count -eq 2) {
            if($history[0].CommandLine -ne $history[1].CommandLine) {
                #Save the last command if it was different from the previous one.
                $history[1] | Export-Csv $historyLogFile -append -confirm:$false
                $id = $history[1].Id+1
            }
        }
        elseif($history.Count -eq 1) {
            $history[0] | Export-Csv $historyLogFile -append -confirm:$false
            $id = $history[0].Id+1
        }
    }
    return $id
}




Function script:Get-WorkingDirectoryLogFileName {
    return ([io.path]::ChangeExtension( $profile , "$($psise.CurrentPowerShellTab.DisplayName).WorkingDirectory.txt"))
}

$script:lastSavedPath = $null
Function Export-PowerShellISEWorkingDirectory {
<#
    .SYNOPSIS
        Saves the given path to the given file if it has changed since last save. Only works in PowerShell ISE.
    .EXAMPLE
        Export-PowerShellISEWorkingDirectory
    .PARAMETER WorkingDirectoryLogFile
        The file to export the working directory to. Defaults to a file named after the current tab.
    .PARAMETER Path
        The path to export to the file. Defaults to $pwd
#>

    [CmdletBinding()]
    param(
        [string] $workingDirectoryLogFile = $null,
        [string] $Path = $pwd.Path
    )
    
    if (Test-Path variable:psise) {
        if ($script:lastSavedPath -ne $Path){
            if (!$workingDirectoryLogFile){
                $workingDirectoryLogFile = Get-WorkingDirectoryLogFileName
            }
            $Path > $workingDirectoryLogFile
            $script:lastSavedPath = $Path
        }
    }
}

Function Import-PowerShellISEWorkingDirectory {
<#
    .SYNOPSIS
        Sets the working directory to the path contained in the given file. Only works in PowerShell ISE.
    .EXAMPLE
        Import-PowerShellISEWorkingDirectory
    .PARAMETER WorkingDirectoryLogFile
        The file to import the working directory from. Defaults to a file named after the current tab.
#>

    [CmdletBinding()]
    param(
        [string] $workingDirectoryLogFile
    )
    
    if (Test-Path variable:psise) {
        if (!$workingDirectoryLogFile){
            $workingDirectoryLogFile = Get-WorkingDirectoryLogFileName
        }
    
        if (Test-Path $workingDirectoryLogFile){
            $path = Get-Content $workingDirectoryLogFile
            Set-Location $path -ErrorAction Continue
            $script:lastSavedPath = $path
        }
    }
}


Function Install-PSRestore {
<#
    .SYNOPSIS
        Imports the last saved history and working directory, and injects commands into Prompt to automatically save these for future sessions.
    .DESCRIPTION
        Recommended usage of this function is to place it at the bottom of your PowerShell profile.
        
        To do this automatically to your CurrentUserAllHosts profile, call this cmdlet with the -Persist flag, and then restart your PowerShell session.
        
        If you have a custom Prompt function, make sure to invoke Install-PSRestore after it is defined. Install-PSRestore will inject commands into your custom prompt.

        If your Prompt function is defined in profiles other than the one that Install-PSRestore is called in, be aware of the order in which profiles are ran - you may accidentally overwrite Install-PSRestore's injections.
    .EXAMPLE
        Install-PSRestore
    .PARAMETER Persist
        If this flag is set, Install-PSRestore will be added to your CurrentUserAllHosts profile.
    .LINKS
        https://technet.microsoft.com/en-us/magazine/2008.10.windowspowershell.aspx
    .NOTES
        If you are running this command in your profile, and you have a custom prompt function, make sure to run this after your custom prompt has been defined.

        This function adds the following two lines to the top of your prompt:
        Export-PowerShellISEWorkingDirectory
        $historyId = Export-PowerShellLastCommand
#>

    [CmdletBinding()]
    param(
        [switch] $Persist
    )

    if ($Persist){
        $path = $PROFILE.CurrentUserAllHosts
        if (!(Test-Path $path)){
            New-Item $path -ItemType file -Force
        }
        if (Select-String -Path $path -Pattern "Install-PSRestore"){
            throw "CurrentUserAllHosts profile seems to already contain Install-PSRestore. You shouldn't put it there twice."
        } else {
            Add-Content -Path $path @"

# Autogenerated by 'Install-PSRestore -Persist':
Import-Module Intellitect.PSRestore -ErrorAction SilentlyContinue
if (Get-Module IntelliTect.PSRestore) {
    Install-PSRestore
} else {
    Write-Warning "Module Intellitect.PSRestore not found. Skipping Install-PSRestore from `$(`$PSCommandPath)"
}
"@
        }

    } else {


        try {
            Import-PowerShellHistory
            Import-PowerShellISEWorkingDirectory 
        }
        catch {
            Write-Error $_
            Write-Host "Error restoring state: $_"
        }


        Invoke-Expression -Command @"
Function global:Prompt {
    Export-PowerShellISEWorkingDirectory
    `$historyId = Export-PowerShellLastCommand

    $((Get-Command 'Prompt').Definition)
}
"@

    }
}
