
Function Script:Get-SampleFunction {
    [CmdletBinding()][OutputType('System.String[]')] 
    param(
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [Parameter(Mandatory, ValueFromPipeLine, ValueFromPipelineByPropertyName, Position)]
        [Alias("FullName","InputObject")]
        [string[]]$Path,

        [switch]$ReadOnly = $true    
    )

}

Function New-PSScriptFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FileName
    )

    $path = (Split-Path ($PSCommandPath) -Parent)

    $fileNameWithoutExtension = [IO.Path]::GetFileNameWithoutExtension($FileName)

    $FileName = Join-path $path "$fileNameWithoutExtension.ps1"
    $testsFileName = Join-path $path "..\Functions.Tests\$fileNameWithoutExtension.Tests.ps1"

    if(!(Test-Path $fileName)) {
    [string]$text = @'
<#Header#> {
Set-StrictMode -Version "Latest"

[string]$here=$PSScriptRoot;
<#EndHeader#>

Function Get-SampleFunction {
    #FunctionBody#
}
'@ 
    $functionBody = (Get-Command Get-SampleFunction).Definition.Trim()
    $text=$text.Replace("#FunctionBody#",$functionBody)

        $text | Out-File -FilePath $fileName 
    }
    Edit-File $fileName

    if(!(Test-Path $testsfileName)) {
    [string]$text = @'
<#Header#>
Set-StrictMode -Version "Latest"
$sut = $PSCommandPath.ToLower().Replace(".tests", "")
. $sut
. Join-Path (Split-Path $sut) "PSScript.ps1"
[string]$here=$PSScriptRoot;
<#EndHeader#>

Describe "MyFunction" {
    It "Verify that the functionality does X" {
        $tempFile = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), ".txt")
        $notepadProcesses = Get-Process #Only needed when not in ISE
        try {
            Edit-File $tempFile
            $openedFileProcess = Get-Process | ?{ $notepadProcesses.id -notcontains $_.id }
            $openedFileProcess.Count | Should Be 1;
            $openedFileProcess | Stop-Process
        }
        finally {
            Remove-Item $tempFile;
        }
    }
}

'@

        $text | Out-File -FilePath $testsfileName 
    }
    Edit-File $testsfileName
}


Function Get-FunctionMetaData {
    [CmdletBinding()][OutputType('System.String[]')] 
    param(
        [Parameter(Mandatory, ValueFromPipeLine, ValueFromPipelineByPropertyName, Position)]
        [string[]]$CmdLet
    )
PROCESS { 
    $CmdLet | %{
        $Metadata = New-Object System.Management.Automation.CommandMetaData (Get-Command $Cmdlet) 
        $NewMeta = [System.Management.Automation.ProxyCommand]::Create($Metadata) 
        return $NewMeta
    }
}
}

