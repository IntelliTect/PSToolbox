
#Import all script files - ISE files last
Get-childItem (Join-Path $PSScriptRoot Functions) *.ps1 |
    sort-object -property {$_.Fullname -like "*_ISE.ps1"} | ?{
            $_.Name -notlike "__*.ps1" -AND 
                ($_.Fullname -notlike "*_ISE.ps1" -OR (Test-Path variable:\psise)) 
    } | %{ . $_.FullName }
