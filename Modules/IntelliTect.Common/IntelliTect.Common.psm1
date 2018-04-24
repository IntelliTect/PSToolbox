
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

#TODO: Add Intelligent $PSISE.ShouldProcess wrapper
<#
Function Invoke-ShouldProcess?????{
    $command = "git mv $oldFileName $newFileName $(if($PSBoundParameters['Verbose']) {`"-v`"})" # The following is not needed as it is handled by "$PSCmdlet.ShouldProcess": -What $(if($PSBoundParameters['WhatIf']) {`"--dry-run`"})"
    if ($PSCmdlet.ShouldProcess("`tExecuting: $command", "`tExecute git.exe Rename: $command", "Executing Git.exe mv")) {
        Invoke-Expression "$command" -ErrorAction Stop  #Change error handling to use throw instead.
    }
}
Set-Alias ShouldProcess Invoke-ShouldProcess
#>

<#
TODO: Create Set-Alias Wrapper that allows the passing of parameters

#>