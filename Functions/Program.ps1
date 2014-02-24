#[CmdletBinding]
<#Private#> Function Get-ProgramRegistryKeys {
    return [string] "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                  "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                  "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                  "Microsoft.PowerShell.Core\Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Uninstall"
}

Function Get-Program([string] $Filter = "*") {
    Get-ChildItem (Get-ProgramRegistryKeys) | Get-ItemProperty | 
            Select-Object  *,@{Name="Name"; Expression = { 
                if( ($_ | Get-Member "DisplayName") -and $_.DisplayName) { #Consider $_.PSObject.Properties.Match("DisplayName") as it may be faster
                    $_.DisplayName
                } 
                else { 
                    $_.PSChildName 
                } 
            }} | 
            ?{ ($_.Name -Like $Filter) -or ($_.PSChildName -Like $Filter)  } 
}

Function Get-ProgramUsingWmi ([string] $Filter = "*") {
    Write-Progress -Activity "Get Program List using WMI"
    Get-WmiObject -Class Win32_Product | 
            Where-Object -Property Name -Like $Filter
    Write-Progress -Activity "Get Program List using WMI" -Completed
}

<#Private#> Function Invoke-Uninstall([string] $uninstallString) {
    Write-Verbose "Invoke-Expression $uninstallString"
    if ($uninstallString.Trim()[0] -eq '"') { 
        Invoke-Expression "& $uninstallString" 
    }
    else { 
        Invoke-Expression $uninstallString
    }
}

#[CmdletBinding]
Function Uninstall-Program([Parameter(Mandatory)][String] $Name) {
    $program = Get-Program $Name;
    
    $uninstallString = $program.UninstallString
    Invoke-Uninstall $uninstallString
}

#REG QUERY HKLM\SOFTWARE /f Uninstall /k /S /e