


#See http://blogs.technet.com/b/heyscriptingguy/archive/2013/03/25/learn-about-using-powershell-value-binding-by-property-name.aspx
Function New-ObjectFromHashtable {
            [CmdletBinding()]
            param(
                        [parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
                        [Hashtable] $Hashtable
            )
            begin { }
            process {
                        $r = new-object System.Management.Automation.PSObject
                        $Hashtable.Keys | % {
                            $key=$_
                            $value=$Hashtable[$key]
                            $r | Add-Member -MemberType NoteProperty -Name $key -Value $value -Force
                        }
                        $r
            }
            end { }
}



#TODO: Outputs ane extra NewLine: $definition = (get-command edit-file).Definition ; $definition | hl name
#TODO: Select only the 10 lines around the item found
#TODO: Consider renaming $pattern as it indicates the wild card characters (*) are already embedded.
Function Highlight([string]$pattern, [Int32]$Context=10, [Parameter(ValueFromPipeline=$true)][string[]]$item)
{
    PROCESS {
        $items = $item.Split([Environment]::NewLine)
        foreach($line in $items) {
	        if( $line -like "*$pattern*")
	        { 
		        write-host  $line -foregroundcolor Yellow
	        } 
	        else
	        {
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

Function Register-AutoDispose {
    [CmdletBinding()] param(
        [ValidateScript({ 
            $_.PSobject.Members.Name -contains "Dispose"})]
        [Parameter(Mandatory)]
        [Object[]]$inputObject,

        [Parameter(Mandatory)]
        [ScriptBlock]$script
    )

    try{
        Invoke-Command -ScriptBlock $script
    }
    finally {
        $inputObject | %{try{
            $_.Dispose()
        }
        catch {
            Write-Error $_
        }}
    }
}
Set-Alias Using Register-AutoDispose


Function Get-TempDirectory {
    [CmdletBinding(DefaultParameterSetName='pathSet')][OutputType('System.IO.DirectoryInfo')] 
    param (
        [Parameter(ParameterSetName='nameSet', Position=0, ValueFromPipelineByPropertyName=$true)]
        [Parameter(ParameterSetName='pathSet', Position=0, ValueFromPipelineByPropertyName=$true)]
        [string[]]
        ${Path},

        [Parameter(ParameterSetName='nameSet', Position=1, Mandatory, ValueFromPipelineByPropertyName=$true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        ${Name}
    )
    if($PSCmdlet.ParameterSetName -eq 'nameSet') {
        if(!$path) {$path = [System.IO.Path]::GetTempPath() }
        $path = Join-Path $path $name
    }
    if(!$path) {
        $path = Get-Item ([IO.Path]::GetTempFileName())
        Remove-Item $path -Force
    }

    $directory = New-Item -Path $path -ItemType Directory
    $directory | Add-Member -MemberType ScriptMethod -Name Dispose -Value { 
        Remove-Item $this.FullName -Force -Recurse }
    return $directory
}

Function Get-TempFile {
    [CmdletBinding(DefaultParameterSetName='pathSet')][OutputType('System.IO.FileInfo')] 
    param (
        [Parameter(ParameterSetName='nameSet', Position=0, ValueFromPipelineByPropertyName=$true)]
        [Parameter(ParameterSetName='pathSet', Position=0, ValueFromPipelineByPropertyName=$true)]
        [string[]]
        ${Path},

        [Parameter(ParameterSetName='nameSet', Position=1, Mandatory, ValueFromPipelineByPropertyName=$true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        ${Name}
    )
    if($PSCmdlet.ParameterSetName -eq 'nameSet') {
        if(!$path) {$path = [System.IO.Path]::GetTempPath() }
        $path = Join-Path $path $name
    }
    if($path) {
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
        [Parameter(Position=1, Mandatory, ValueFromPipeline)]
        [string]$inputObject,
        [string]$deliminator=[Environment]::NewLine
    )

    $inputObject -split [Environment]::NewLine
}