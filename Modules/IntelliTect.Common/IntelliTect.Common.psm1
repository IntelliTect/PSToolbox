
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
    [CmdletBinding(SupportsShouldProcess)]
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
Function ConvertFrom-Hashtable {
    [CmdletBinding()]
    param(
        [parameter(Mandatory, Position = 1, ValueFromPipeline)]
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

function Initialize-Array {
    [CmdletBinding()]
    [OutputType('System.Array')]
    [System.Array]$args | Write-Output
}

Function Add-DisposeScript {
    [CmdletBinding()]
    param(
        [ValidateNotNull()][Parameter(Mandatory, ValueFromPipeline)][object[]]$InputObject,
        [ValidateNotNull()][Parameter(Mandatory)][ScriptBlock]$DisposeScript,
        [switch]$Force
    )
    PROCESS {
        $inputObject | Foreach-Object {
            if($_.GetType() -eq [string]) { throw 'Add-DisposeScript will not work with [string] type $InputObjects'}
            $eachInputObject = $_
            if($eachInputObject.PSObject.Members.Name -notcontains 'IsDisposed') {
                $eachInputObject | Add-Member -MemberType NoteProperty -Name 'IsDisposed' -Value $false
            }

            $eachInputObject | Add-Member -MemberType ScriptMethod -Name InternalDispose -Value $DisposeScript -Force:$Force

            # TODO: Figure out a way to combine ScriptBlocgs without making them strings.                            
            [ScriptBlock]$localDisposeScript = [scriptblock]::Create(
                # Set the IsDisposed property to true when Dispose() is called.
                "`n$DisposeScript; `n`$this.IsDisposed = `$true; "
            )
            $eachInputObject | Add-Member -MemberType ScriptMethod -Name Dispose -Value $localDisposeScript -Force:$Force

            # $eachInputObject | Add-Member -MemberType ScriptMethod -Name Dispose -Value {
            #     Invoke-Command -ScriptBlock $DisposeScript
            #     $this.IsDisposed = $true
            # }.GetNewClosure() -Force:$Force
        }
    }
}

<#
.SYNOPSIS
Registers to invoke the $InputObject's Dispose() method once the $ScriptBlock execution completes.

.DESCRIPTION
Provides equivalent functionality to C#'using statment, invoking Dispose after
executing the $ScriptBlock specified.

.PARAMETER inputObject
The object on which to find and invoke the Dispose method.  Note that if a collection (such as an array)
of object is used, the ScriptBlock will only be invoked once whereas, Dispose() will be called
on each item in the inputObject collection.

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
            [ValidateNotNull()][Parameter(Position = 0, Mandatory, ValueFromPipeline)]
            [Object[]]$InputObject,
        
        [Parameter(Position = 1, Mandatory)]
            [ScriptBlock]$ScriptBlock
        )
    PROCESS {
        try {
            # Only call the script once - even if the #InputObject is a collection of objects.
            Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $InputObject
        }
        finally {
            $InputObject | ForEach-Object {
                if($_-eq $null) { throw '$inputOject contains items that are null.'}
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
        [string[]]$Path = [System.IO.Path]::GetTempPath(),
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowNull()][AllowEmptyString()][string[]]${Name},
        [ValidateSet('File', 'Directory')][string]$ItemType = 'File'
    )

    PROCESS {
        $Path | ForEach-Object {

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
                    Remove-Item -Path $this.FullName -Force -Recurse -ErrorVariable failed # Recurse is allowed on both files and directoriese
                    if($failed) { throw $failed }
                }
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
        [string[]]$Path = [System.IO.Path]::GetTempPath(),
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
        [string[]]$Path = [System.IO.Path]::GetTempPath(),
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

Filter Test-Command {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][string[]]$command

    )
    $command | Foreach-Object {
        Write-Output ([bool](get-command $_ -ErrorAction Ignore))
    }
}

<#
.SYNOPSIS
Test is a property of the specified name exists on the object.

.DESCRIPTION
Given an input object, check to see whether a property of the specified name exists.

.PARAMETER InputObject
The input object on which to look for the property.

.PARAMETER Name
The name of the property to look for.

#>
Function Test-Property {
    [CmdLetBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)] $InputObject,
        [Parameter(Mandatory)][string[]]$Name
    )
    # TODO: Add support for hashtable name checks as well
    # TODO: Add support so you don't need to specifically provide the parameter name for -Name.
    $Name | ForEach-Object {
        $_ -in $InputObject.PSobject.Properties.Name | Write-Output
    }
}   

#[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
Function Test-VariableExists {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)][string[]]$name)

    $name | ForEach-Object { Test-Path Variable:\$_ }
}

Function Get-IsWindowsPlatform {
    [OutputType([bool])]
    [CmdletBinding()]param()
    return (('PSEdition' -in $PSVersionTable.Keys) `
        -and ($PSVersionTable.PSEdition -eq 'Desktop') `
        -and ($PSVersionTable.Clrversion.Major -ge 4)) 
}

Function Set-IsWindowsVariable {
    [CmdletBinding(SupportsShouldProcess)]param()
    if (-not (Test-VariableExists "IsWindows")) {
        Invoke-ShouldProcess -ContinueMessage 'Seting global:IsWindows variable' -InquireMessage 'Set global:IsWindows variable?' `
                 -Caption 'Set global:IsWindows variable' {
            Set-Variable -Name "IsWindows" -Value `
                (('PSEdition' -in $PSVersionTable.Keys) `
                            -and ($PSVersionTable.PSEdition -eq 'Desktop') `
                            -and ($PSVersionTable.Clrversion.Major -ge 4)) -Scope global
        }
    }
}
Set-IsWindowsVariable

<#
.SYNOPSIS
Wait for the condition to be true on all inputObject items.

.DESCRIPTION
Given a set inputObjects, iterate over each of them until they all meet the condition specified or the timeout expires.

.PARAMETER InputObject
The object on which to check the condition.

.PARAMETER Condition
A predicate that takes the input object and returns true or false regarding whether the condition is met.

.PARAMETER TimeSpan
A timeout specified as a TimeSpan.  Note that TotalMilliseconds on the timeot must be more than 0 or else
the parameter will fail validation.

.PARAMETER TimeoutInMilliseconds
The timeout specified in milliseconds.

.EXAMPLE
PS>1..1000 | Wait-ForCondition -TimeSpan (New-TimeSpan -Seconds 1) -Condition { ((Get-Random -Minimum 1 -Maximum 11)%2) -eq 0 }
Attempt to generated even numbers 1000 times using Get-Random but timeout.

.NOTES
General notes
#>

Function Wait-ForCondition {
    [CmdletBinding(DefaultParametersetname='TimeoutInMilliseconds')] param(
        [Parameter(Mandatory,ValueFromPipeline)][object[]]$InputObject,
        [Parameter(Mandatory)][ScriptBlock]$Condition,
        [ValidateScript({$_.TotalMilliseconds -ne 0})][Parameter(ParameterSetName = "TimeSpan")][TimeSpan]$TimeSpan,
        [ValidateScript({$_ -ge 0})][Parameter(ParameterSetName = "TimeoutInMilliseconds")][long]$TimeoutInMilliseconds=0,
        [switch]$PassThru
    )
    BEGIN {
         $items=@()
         if ($PSBoundParameters.ContainsKey('TimeSpan')) {
            $TimeoutInMilliseconds = $TimeSpan.TotalMilliseconds
         }
         [System.Diagnostics.Stopwatch]$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
     }
    PROCESS {
        # Accumulate the response output from Start-Stuff here
        $items += $InputObject
    }
    END {
        # Iterate over all the items, waiting for them to complete here
        $moreItems = @($items)
        [int]$iterationCount = 0
        while ($moreItems -and ($moreItems.Count -gt 0)) {
            $iterationCount++
            Write-Progress "Checking condition on remaining $(@($moreItems).Length) items for the $iterationCount time"
            Write-Debug "Checking condition on remaining $(@($moreItems).Length) items for the $iterationCount time"
            $moreItems = $moreItems | Where-Object {
                # Filter out the items for which the condition is true.
                $conditionResult =  @($condition.Invoke($_)) # Invoke returns a Collection<PSObject>
                switch($conditionResult.Length) {
                    0 { throw 'The Condition script must return a Boolean value ([bool]), not $null' }
                    1 {
                        if($conditionResult[0].GetType() -ne [bool]) {
                            throw "The Condition script must be a predicate (return a [bool]), not a $($conditionResult.GetType())"
                        }
                        Write-Debug "Checking condition for item `$condition.Invoke($_)=$conditionResult"
                        if ($conditionResult[0] -ne $true) { <# Filter out anything that is not actually $true (even if it is not a bool) #>
                            Write-Debug "'$_' didn't meet the condition so checking for timeout..."
                            # If the condition still isn't met, check for timeout
                            if(($TimeoutInMilliseconds -gt 0) -and ($stopwatch.ElapsedMilliseconds -gt $TimeoutInMilliseconds)) {
                                throw [TimeoutException]::new("Execution time exceeded $TimeoutInMilliseconds milliseconds.")
                            }
                            return $true
                        }
                        else {
                            return $false
                        }
                    }
                    default { throw 'The Condition must return a scalar (a single boolean).' }
                }
            }
            Write-Debug "After iteration $iterationCount, there are $(@($moreItems).Length) items remaining."
        }
        if ($PSBoundParameters.ContainsKey('PassThru')) {
            $items | Write-Output
        }
        Write-Debug "Number of times iterated over the list for was $iterationCount"
    }
}