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
#ToDo: Add support for piping Get-Program to Uninstall-Program (without selecting the name specicially)
#ToDo: Although using Function Get-ProgramUsingWmi is significantly slower, the object returns supports an Uninstall() method.
Function Uninstall-Program([Parameter(Mandatory, ValueFromPipeline=$True)]$Program) {
    if($Program -is [string]) {
        $Program = Get-Program $Program;  # Note: This converts program from a string to a PSCustomObject
        if(!$Program) {
            Throw "Cannot find path '$program' because it does not exist."
        }
    }
    elseif ($Program -isnot [PSCustomObject] -or (!($Program | Get-Member "UninstallString"))){
        throw "`$Program is not a valid type and doesn't support an UninstallString property"
    }
    
    $uninstallString = $Program.UninstallString
    Invoke-Uninstall $uninstallString
}

#REG QUERY HKLM\SOFTWARE /f Uninstall /k /S /e