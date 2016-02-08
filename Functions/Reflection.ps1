[CmdletBinding()]param(

)


Function Get-Type([Parameter(ValueFromPipeline=$true)]$value) {
    PROCESS {
        Write-Output $value.GetType();
    }
}


Function Test-IsStaticType {
    [CmdletBinding()]param(
        [Parameter(Mandatory, ValueFromPipeline)][Type]$Type,
        [bool]$IsPublic = $true  #ToDo: Add pipe and mandetory
    )
    return ($Type.IsSealed -and $Type.IsAbstract) -and ($IsPublic -and $Type.IsPublic) # -and (!$Type.IsValueType) -and $Type.IsPublic 
}


#ToDo: Convert to support Get-Member output of type Microsoft.PowerShell.Commands.MemberDefinition (possibly in addition to MethodInfo support)
Function Test-IsExtensionMethod {
   [CmdletBinding()]param(
        [Parameter(Mandatory, ValueFromPipeline)][System.Reflection.MethodInfo]$Method
    )
    return $Method.IsStatic -and ($Method.CustomAttributes.Count -gt 0) -and
        ($Method.CustomAttributes.AttributeType -contains [System.Runtime.CompilerServices.ExtensionAttribute] )
}


Function Get-ReflectionExtensionMemebers {
   [CmdletBinding()]param(
        [Parameter(Mandatory, ValueFromPipeline)][Type]$Type
    )
    
    $Type.GetMethods() | ?{ Test-IsExtensionMethod $_  }
}

<#
[reflection.assembly]::GetAssembly([system.console]).GetTypes() | ?{ Test-IsStaticType $_ } |  %{ 
    $methods = $_.GetMethods() | ?{ -not (Test-IsExtensionMethod $_) } | ?{ $_.IsStatic }
    $properties = $null;
    if($_.GetProperties().Length -gt 0) {
        $properties = $_ | Get-Member -Static -MemberType Property
    }
    if( ($methods -ne $null) -and ($properties -ne $null) ) {
        Write-OUtput $_.FullName # -ForegroundColor Green
        $methods | select -ExpandProperty name | select -unique | ?{
            ($_ -notlike "get_*") } | ?{ ($_ -notlike "set_*") 
        } | %{
            #Write-Host "`t$($_)" -ForegroundColor White
        }
    }
}
#>