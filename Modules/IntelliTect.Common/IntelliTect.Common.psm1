
Function Add-PathToEnvironmentVariable {
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path,
    [string]$EnvironmentVariableName = "Path",
    [EnvironmentVariableTarget]$Scope=[EnvironmentVariableTarget]::User
)
    
    if( ! (([Environment]::GetEnvironmentVariable($EnvironmentVariableName, $Scope) -split ';') -contains $Path) ) {
        if($PSCmdlet.ShouldProcess("Add '$Path' to '`$env:$EnvironmentVariableName'.")) {
            $CurrentValue = [Environment]::GetEnvironmentVariable($EnvironmentVariableName, $Scope)
            [Environment]::SetEnvironmentVariable($EnvironmentVariableName, "$Path;$CurrentValue", $Scope)
            Set-Item "env:$EnvironmentVariableName"="$Path;$CurrentValue"
        }
    }
}
