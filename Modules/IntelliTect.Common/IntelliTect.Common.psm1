

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
Function Invoke-ShouldProcess {
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
        $Hashtable.Keys | ForEach-Object {
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
        [ValidateNotNull()][Parameter(Mandatory, ValueFromPipeline)][object[]]$InputObject,
        [ValidateNotNull()][Parameter(Mandatory)][ScriptBlock]$DisposeScript
    )

    $InputObject | Add-Member -MemberType NoteProperty -Name IsDisposed -Value $false
    # Set the IsDisposed property to true when Dispose() is called.
    [ScriptBlock]$DisposeScript = [scriptblock]::Create(
        "$DisposeScript; `n`$this.IsDisposed = `$true; "
    )
    $InputObject | Add-Member -MemberType ScriptMethod -Name Dispose -Value $DisposeScript
}

<#
.SYNOPSIS
Registers to invoke the $InputObject's Dispose() method once the $ScriptBlock execution completes.

.DESCRIPTION
Provides equivalent functionality to C#'using statment, invoking Dispose after
executing the $ScriptBlock specified.

.PARAMETER inputObject
The object on which to find and invoke the Dispose method.

.PARAMETER ScriptBlock
The ScriptBlock to execute before calling the $InputObject's dispose method.

.EXAMPLE
Register-AutoDispose (Get-TempFile) { Get-ChildItem }

Calls the return from Get-TempFile's Dispose() method upon completion of Get-ChildItem.

.EXAMPLE
.EXAMPLE
Register-AutoDispose (Get-TempFile) { param($tempFile) Write-Output $tempFile }

Calls the return from Get-TempFile's Dispose() method upon completion of Write-Output $inputObject.
In this case, because the $ScriptBlock accepts a parameter, the parameter will be initialized
with the value of $inputObject


.NOTES
If a $ScriptBlock takes a parameter, the parameter value will be set to the value of $InputObject.

#>
Function Register-AutoDispose {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateScript( {$_.PSobject.Members.Name -contains "Dispose"})]
            [ValidateNotNull()][Parameter(Mandatory, ValueFromPipeline)]
            [Object[]]$InputObject,

        [Parameter(Position=1,Mandatory)]
            [ScriptBlock]$ScriptBlock
    )

  PROCESS  {
          try {
            Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $InputObject
        }
        finally {
            $InputObject | ForEach-Object {
                try {
                    $_.Dispose()
                }
                catch {
                    Write-Error $_
                }
            }
        }
  }
}
Set-Alias Using Register-AutoDispose



Function Script:Get-FileSystemTempItem {
    [CmdletBinding()]
    [OutputType('System.IO.FileSystemInfo')]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]${Path} = [System.IO.Path]::GetTempPath(),
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowNull()][AllowEmptyString()][string[]]${Name},
        [ValidateSet('File', 'Directory')][string]$ItemType = 'File'
    )

    PROCESS {
        $path | ForEach-Object {

            [string]$fullName = $null
            # If the directory doesn't exist then Resolve-Path will report an error.
            $eachPath = Resolve-Path $_ -ErrorAction Stop
            if ((!$Name) -or ([string]::IsNullOrEmpty($Name))) {
                $fullName = Get-FileSystemTempItemPath $_
            }
            else {
                $fullName = $Name | ForEach-Object {
                    if ([string]::IsNullOrEmpty($_)) {
                        do {
                            $eachFullName = Join-Path $eachPath ([System.IO.Path]::GetRandomFileName())
                        } while (Test-Path $eachFullName)
                        Write-Output $eachFullName
                    }
                    else {
                        Write-Output (Join-Path $eachPath $_)
                    }
                }
            }

            $fullName | ForEach-Object {
                # If we fail to create the item (for example the name was specified and the the file already exists)
                # then we stop further execution.
                $file = New-Item $_ -ItemType $ItemType -ErrorAction Stop

                $file | Add-DisposeScript -DisposeScript {
                    Remove-Item $this.FullName -Force }

                Write-Output $file

            }
        }
    }
}


Function Get-TempDirectory {
    [CmdletBinding()]
    [OutputType('System.IO.DirectoryInfo')]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]${Path} = [System.IO.Path]::GetTempPath(),
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowNull()][AllowEmptyString()][string[]]${Name}
    )

    Get-FileSystemTempItem -Path $Path -Name $Name -ItemType Directory
}

Function Get-TempFile {
    [CmdletBinding()]
    [OutputType('System.IO.FileInfo')]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]${Path} = [System.IO.Path]::GetTempPath(),
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowNull()][AllowEmptyString()][string[]]${Name}
    )

    Get-FileSystemTempItem -Path $Path -Name $Name -ItemType File
}

<#
.SYNOPSIS
Gets the name of a temporary file or directory that does not exist.

.PARAMETER Path
An optional path to the parent directory.  If no path is specified,
the directory defaults to the operating system temporaray directory (System.IO.Path]::GetTempPath())

#>
Function Get-FileSystemTempItemPath {
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(ValueFromPipeLine, ValueFromPipelineByPropertyName)]
        [string[]]${Path} = [System.IO.Path]::GetTempPath()
    )

    $path | ForEach-Object {
        [string]$eachName = $null
        [string]$tempItemPath = $null
        do {
            $eachName = [System.IO.Path]::GetRandomFileName()
            $tempItemPath = Join-Path $_ $eachName
        } while (Test-Path $tempItemPath)
        Write-Output $tempItemPath
    }
}
Set-Alias -Name Get-TempItemPath -Value Get-FileSystemTempItemPath

Function ConvertTo-Lines {
    [CmdLetBinding()] param(
        [Parameter(Position = 1, Mandatory, ValueFromPipeline)]
        [string]$inputObject,
        [string]$deliminator = [Environment]::NewLine
    )

    $inputObject -split [Environment]::NewLine
}