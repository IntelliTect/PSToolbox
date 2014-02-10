. (Join-Path $PSScriptRoot "ConvertFrom-LabelColonValue.ps1")

Function Get-TfInfo([string] $path) {
    $output = tf info $path
    If($output -match "No items match*") {
        Write-Verbose $output
        Throw "Cannot find item in TFS"
    }
    $result = ConvertFrom-LabelColonValue $output;
    return $result



}