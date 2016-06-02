
Function script:Invoke-Tests {
    param($Paths)

    Get-childItem $Paths | Sort-object -property {$_.Fullname -like "*_ISE.ps1"} | ?{
            $_.Name -notlike "__*.ps1" -AND 
                ($_.Fullname -notlike "*_ISE.ps1" -OR (Test-Path variable:\psise)) 
    } | %{ . $_.FullName }
}


# Commented out the Functions tests for now. A spectacular number of them fail, and they eventually crash PSISE.
# Invoke-Tests (Join-Path $PSScriptRoot Functions.Tests) *.ps1


Invoke-Tests (Join-Path $PSScriptRoot Modules.Tests) *.ps1