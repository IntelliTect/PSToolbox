

Function Add-PathToEnvironmentVariable {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path,
        [string]$EnvironmentVariableName = "Path",
        [EnvironmentVariableTarget]$Scope = [EnvironmentVariableTarget]::User
    )

    if ( ! (([Environment]::GetEnvironmentVariable($EnvironmentVariableName, $Scope) -split ';') -contains $Path) ) {
        if ($PSCmdlet.ShouldProcess("Add '$Path' to '`$env:$EnvironmentVariableName'.")) {
            $CurrentValue = [Environment]::GetEnvironmentVariable($EnvironmentVariableName, $Scope)
            [Environment]::SetEnvironmentVariable($EnvironmentVariableName, "$Path;$CurrentValue", $Scope)
            Set-Item "env:$EnvironmentVariableName"="$Path;$CurrentValue"
        }
    }
}

<#
.SYNOPSIS
Invokes $PSCmdlet.ShouldProcess

.PARAMETER ContinueMessage
Textual description of the action to be performed. This is what will be displayed to the user for ActionPreference.Continue.

.PARAMETER InquireMessage
Textual query of whether the action should be performed, usually in the form of a question. This is what will be displayed to the user for ActionPreference.Inquire.

.PARAMETER Caption
Caption of the window which may be displayed if the user is prompted whether or not to perform the action. (Caption may be displayed by some hosts, but not all.)

.PARAMETER ShouldProcessReason
Indicates the reason(s) why ShouldProcess returned what it returned. Only the reasons enumerated in System.Management.Automation.ShouldProcessReason are returned.

.PARAMETER script
The script executed if the $PSCmdlet.ShouldProcess returns true.

#>
Function Invoke-ShouldProcess{
    [CmdletBinding()]
    param(
        [string]$ContinueMessage,
        [string]$InquireMessage,
        [string]$Caption,
        [ScriptBlock]$Script
    )

    if ($PSCmdlet.ShouldProcess($ContinueMessage, $InquireMessage, $Caption)) {
        Write-Debug 'Executing script...'
        Invoke-Command $Script
        Write-Debug 'Finished executing script.'
    }
}
Set-Alias ShouldProcess Invoke-ShouldProcess

<#
    TODO: Create Set-Alias Wrapper that allows the passing of parameters

    #>

#See http://blogs.technet.com/b/heyscriptingguy/archive/2013/03/25/learn-about-using-powershell-value-binding-by-property-name.aspx
Function New-ObjectFromHashtable {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
        [Hashtable] $Hashtable
    )
    begin { }
    process {
        $r = new-object System.Management.Automation.PSObject
        $Hashtable.Keys | % {
            $key = $_
            $value = $Hashtable[$key]
            $r | Add-Member -MemberType NoteProperty -Name $key -Value $value -Force
        }
        $r
    }
    end { }
}



#TODO: Outputs ane extra NewLine: $definition = (get-command edit-file).Definition ; $definition | hl name
#TODO: Select only the 10 lines around the item found
#TODO: Consider renaming $pattern as it indicates the wild card characters (*) are already embedded.
Function Highlight([string]$pattern, [Int32]$Context = 10, [Parameter(ValueFromPipeline = $true)][string[]]$item) {
    PROCESS {
        $items = $item.Split([Environment]::NewLine)
        foreach ($line in $items) {
            if ( $line -like "*$pattern*") {
                write-host  $line -foregroundcolor Yellow
            }
            else {
                write-host  $line -foregroundcolor white
            }
        }
    }
}
set-alias HL highlight

function New-Array {
    [CmdletBinding()][OutputType('System.Array')]
    $args
}

Function Add-DisposeScript {
    [CmdletBinding()]
    param(
        [ValidateNotNull()][Parameter(Mandatory,ValueFromPipeline)][object[]]$InputObject,
        [ValidateNotNull()][Parameter(Mandatory)][ScriptBlock]$DisposeScript
    )

    $InputObject | Add-Member -MemberType NoteProperty -Name IsDisposed -Value $false
    # Set the IsDisposed property to true when Dispose() is called.
    [ScriptBlock]$DisposeScript = [scriptblock]::Create(
        "$DisposeScript; `n`$this.IsDisposed = `$true; "
    )
    $InputObject | Add-Member -MemberType ScriptMethod -Name Dispose -Value $DisposeScript
}

Function Register-AutoDispose {
    [CmdletBinding()] param(
        [ValidateScript( {
                $_.PSobject.Members.Name -contains "Dispose"})]
        [ValidateNotNull()][Parameter(Mandatory,ValueFromPipeline)]
        [Object[]]$inputObject,

        [Parameter(Mandatory)]
        [ScriptBlock]$ScriptBlock
    )

    try {
        Invoke-Command -ScriptBlock $ScriptBlock
    }
    finally {
        $inputObject | ForEach-Object {
            try {
                $_.Dispose()
            }
            catch {
                Write-Error $_
            }
        }
    }
}
Set-Alias Using Register-AutoDispose


Function Get-TempDirectory {
    [CmdletBinding(DefaultParameterSetName = 'pathSet')][OutputType('System.IO.DirectoryInfo')]
    param (
        [Parameter(ParameterSetName = 'nameSet', Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Parameter(ParameterSetName = 'pathSet', Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string[]]
        ${Path},

        [Parameter(ParameterSetName = 'nameSet', Position = 1, Mandatory, ValueFromPipelineByPropertyName = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        ${Name}
    )
    if ($PSCmdlet.ParameterSetName -eq 'nameSet') {
        if (!$path) {$path = [System.IO.Path]::GetTempPath() }
        $path = Join-Path $path $name
    }
    if (!$path) {
        $path = Get-Item ([IO.Path]::GetTempFileName())
        Remove-Item $path -Force
    }

    $directory = New-Item -Path $path -ItemType Directory
    $directory | Add-Member -MemberType ScriptMethod -Name Dispose -Value {
        Remove-Item $this.FullName -Force -Recurse }
    return $directory
}

Function Get-TempFile {
    [CmdletBinding(DefaultParameterSetName = 'pathSet')][OutputType('System.IO.FileInfo')]
    param (
        [Parameter(ParameterSetName = 'nameSet', Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Parameter(ParameterSetName = 'pathSet', Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string[]]
        ${Path},

        [Parameter(ParameterSetName = 'nameSet', Position = 1, Mandatory, ValueFromPipelineByPropertyName = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        ${Name}
    )
    if ($PSCmdlet.ParameterSetName -eq 'nameSet') {
        if (!$path) {$path = [System.IO.Path]::GetTempPath() }
        $path = Join-Path $path $name
    }
    if ($path) {
        $file = New-Item $path -ItemType File
    }
    else {
        $file = Get-Item ([IO.Path]::GetTempFileName())
    }
    $file | Add-Member -MemberType ScriptMethod -Name Dispose -Value {
        Remove-Item $this.FullName -Force }
    return $file
}

Function ConvertTo-Lines {
    [CmdLetBinding()] param(
        [Parameter(Position = 1, Mandatory, ValueFromPipeline)]
        [string]$inputObject,
        [string]$deliminator = [Environment]::NewLine
    )

    $inputObject -split [Environment]::NewLine
}