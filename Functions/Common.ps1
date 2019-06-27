
## TODO: Delete once it is no longer referenced and instead use the module IntelliTect.Common

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

function New-Array {
    [CmdletBinding()][OutputType('System.Array')]
    $args
}

Function ConvertTo-Lines {
    [CmdLetBinding()] param(
        [Parameter(Position=1, Mandatory, ValueFromPipeline)]
        [string]$inputObject,
        [string]$deliminator=[Environment]::NewLine
    )

    $inputObject -split [Environment]::NewLine
}