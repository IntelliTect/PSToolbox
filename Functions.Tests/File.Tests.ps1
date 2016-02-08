$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut


#TODO: This can surely be done using the Pester functions but I confess, I am not sure how.
#      Consider moving this to an It statement and possibly getting a handle to the $pester results
If(Test-Path variable:\psise) { 
    $commandLine = (Get-Command PowerShell).Path
    $tempFile = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), ".txt")
    #$process = Start-Process -FilePath $commandLine -ArgumentList "-noprofile -command `"& { Invoke-pester $PSCommandPath}" -PassThru -RedirectStandardOutput $tempFile
    $output = PowerShell -nologo -noninteractive -noprofile -command "& { Invoke-pester $PSCommandPath}"
    #$process.WaitForExit()
    $reachedOutput = $false;
    $outputErrorMessage = $false
    $output | ?{ 
        if($reachedOutput -or ($_ -like "[\[][-+]]*") ) {
            $reachedOutput = $true
        }
        $reachedOutput
    } | %{
        $line = $_
        switch -wildcard ($line) 
        { 
            "[\[][+]]*" {
                $outputErrorMessage = $false
                Write-Host -ForegroundColor darkgreen $line
            }
            "TestCompleted*" {
                $outputErrorMessage = $false
                Write-Host -ForegroundColor red $line
            }
            default { 
                if($outputErrorMessage -or ($line -like "[\[][-]]*")) {
                    $outputErrorMessage = $true
                    Write-Host -ForegroundColor red $line
                }
                else {
                    Write-Host $line
                }
            }
        }
    }
    return;
}

Describe "Edit-File" {
    It "Create a new temp file and open it to edit" {
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
    It "Create a new temp file and open from the pipeline" {
        $tempFile = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), ".txt")
        $notepadProcesses = Get-Process #Only needed when not in ISE
        try {
            $tempFile | Edit-File
            $openedFileProcess = Get-Process | ?{ $notepadProcesses.id -notcontains $_.id }
            $openedFileProcess.Count | Should Be 1;
            $openedFileProcess | Stop-Process
        }
        finally {
            Remove-Item $tempFile;
        }
    }
}
