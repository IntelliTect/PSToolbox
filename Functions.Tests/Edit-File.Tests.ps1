Describe "Edit-File" {
    It "Create a new file called and open it to edit" {
        $tempFile = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), ".txt")
        $notepadProcesses = Get-Process Notepad* #Only needed when not in ISE
        try {
        Edit-File $tempFile
        $openedFileProcess = Get-Process Notepad* | ?{ $notepadProcesses.id -notcontains $_.id }
        $openedFileProcess.Count | Should Be 1;
        $openedFileProcess | Stop-Process
        }
        finally {
            Remove-Item $tempFile;
        }
    }
}
