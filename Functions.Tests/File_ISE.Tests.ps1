$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

Function OpenTempFile() {
        $tempFile = [IO.Path]::GetTempFileName()
        if(!(Test-Path $tempFile)) { New-Item $tempFile -ItemType File}
        start (get-command powershell_ise.exe).Path -Wait $tempFile #Use start to ensure it is synchronous for testing purposes.
        $openedTempFile = ($psISE.CurrentPowerShellTab.Files | ?{ $_.FullPath -eq $tempFile })
        $openedTempFile.FullPath | Should Be $tempFile
        return $tempFile
}

Describe "Open-File" {
    It "Open a temp file" {
        $tempFile = [IO.Path]::GetTempFileName()
        Open-File $tempFile
        $openedTempFile = ($psISE.CurrentPowerShellTab.Files | ?{ $_.FullPath -eq $tempFile })
        $openedTempFile.FullPath | Should Be $tempFile
        Close-File $openedTempFile.FullPath
    }
    It "Open a temp file from pipeline" {
        $tempFile = [IO.Path]::GetTempFileName()
        type function:\Open-File
        $tempFile | Open-File 
        $openedTempFile = ($psISE.CurrentPowerShellTab.Files | ?{ $_.FullPath -eq $tempFile })
        $openedTempFile.FullPath | Should Be $tempFile
        Close-File $openedTempFile.FullPath
    }
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