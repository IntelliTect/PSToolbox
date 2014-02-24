. (Join-Path $PSScriptRoot "ConvertFrom-LabelColonValue.ps1")

Function Get-TfInfo([string] $path) {
    [string] $output = Get-ChildItem $path 2> $null | %{tf info $_.FullName }
    If($output -like "tf : TF*") {
        If($output -match "No items match*") {
            Write-Verbose $output
            Throw "Cannot find item in TFS"
        } else {
            
        }
    }
    $result = ConvertFrom-LabelColonValue $output;
    return $result
}