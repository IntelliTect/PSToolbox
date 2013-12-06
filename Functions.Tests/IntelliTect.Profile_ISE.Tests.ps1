$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
#dir "$ChocolateyInstall\lib\Pester*" Pester.psm1 -Recurse | Select-Object -Last 1 | Import-Module -Scope Local
#Get-Module "Import-Script" | remove-module
#Import-Module "$here\Import-Script.psm1" -Scope Local -Force
#Import-Script "$here\$sut" -IncludeVariables
#Invoke-Pester "$MyInvocation.MyCommand.Path"

function DebugBreak{}
function Debug{
    Set-PSBreakpoint -command DebugBreak
    DebugBreak
}


Function OpenTempFile() {
        $tempFile = [IO.Path]::GetTempFileName()
        if(!(Test-Path $tempFile)) { New-Item $tempFile -ItemType File}
        ISE $tempFile
        start (get-command powershell_ise.exe).Path -Wait $tempFile #Use start to ensure it is synchronous for testing purposes.
        $openedTempFile = ($psISE.CurrentPowerShellTab.Files | ?{ $_.FullPath -eq $tempFile })
        $openedTempFile.FullPath | Should Be $tempFile
        return $tempFile
}
Describe "Close-File" {
    It "Close a file passed as a parameter" {
        $tempFile = OpenTempFile
        Close-File $tempFile
        ($psISE.CurrentPowerShellTab.Files | ?{ $_.FullPath -eq $tempFile }).Count | Should Be 0
        Remove-Item $tempFile
    }
    It "Close a file passed on the pipeline" {
        $tempFile = OpenTempFile
        $tempFile | Close-File 
        ($psISE.CurrentPowerShellTab.Files | ?{ $_.FullPath -eq $tempFile }).Count | Should Be 0
        Remove-Item $tempFile
    }
    It "Close multiple files passed on the pipeline" {
        $tempFiles = (OpenTempFile),(OpenTempFile),(OpenTempFile)
        $tempFiles | Close-File 
        ($psISE.CurrentPowerShellTab.Files | ?{ $tempFiles -contains $_.FullPath }).Count | Should Be 0
        $tempFiles | Remove-Item
    }
}