

Function ConvertFrom-LabelColonValue([string]$labelColonValue) {
    $result = @{}
    
    $labelColonValue -split "`n"  | %{ 
        $label,$value=($_ -split ": ", 2, "Singleline")
        $result[$label.Trim()]=$value
    }

    return $result

}