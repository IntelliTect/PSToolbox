<#Header#>
Set-StrictMode -Version "Latest"

Get-Module IntelliTect.File | Remove-Module
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.File -Force

#EndHeader#>

#TODO: This can surely be done using the Pester functions but I confess, I am not sure how.
#      Consider moving this to an It statement and possibly getting a handle to the $pester results
If(Test-Path variable:\psise) {
    $commandLine = (Get-Command PowerShell).Path
    $tempFile = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), '.txt')
    #$process = Start-Process -FilePath $commandLine -ArgumentList "-noprofile -command `"& { Invoke-pester $PSCommandPath}" -PassThru -RedirectStandardOutput $tempFile
    $output = PowerShell.exe -nologo -noninteractive -noprofile -command "& { Invoke-pester $PSCommandPath}"
    #$process.WaitForExit()
    $reachedOutput = $false;
    $outputErrorMessage = $false
    $output | ?{
        if($reachedOutput -or ($_ -like '[\[][-+]]*') ) {
            $reachedOutput = $true
        }
        $reachedOutput
    } | %{
        $line = $_
        switch -wildcard ($line)
        {
            '[\[][+]]*' {
                $outputErrorMessage = $false
                Write-Host -ForegroundColor darkgreen $line
            }
            'TestCompleted*' {
                $outputErrorMessage = $false
                Write-Host -ForegroundColor red $line
            }
            default {
                if($outputErrorMessage -or ($line -like '[\[][-]]*')) {
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



# Describe 'Remove-DirectoryWithLongName' {
#     It 'Create a new temp file and open it to edit' {

#     }
# }

Describe 'Edit-File' {
    It 'Create a new temp file and open it to edit' {
        try {
            $tempFile = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), '.txt')
            $notepadProcesses = Get-Process #Only needed when not in ISE
            try {
                Edit-File $tempFile
                $openedFileProcess = @(Get-Process | ?{ $notepadProcesses.id -notcontains $_.id })
                $openedFileProcess.Length | Should Be 1;
            }
            finally {
                Get-Process | ?{ $notepadProcesses.id -notcontains $_.id } | Stop-Process
            }
        }
        finally {
            if(Test-Path $tempFile) {
                Remove-Item $tempFile;
            }
        }
    }
    It 'Create a new temp file and open from the pipeline' {
        try {
            $tempFile = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), '.txt')
            $notepadProcesses = Get-Process #Only needed when not in ISE
            try {
                $tempFile | Edit-File
                $openedFileProcess = @(Get-Process | ?{ $notepadProcesses.id -notcontains $_.id })
                $openedFileProcess.Length | Should Be 1;
            }
            finally {
                Get-Process | ?{ $notepadProcesses.id -notcontains $_.id } | Stop-Process
            }
        }
        finally {
            if(Test-Path $tempFile) {
                Remove-Item $tempFile;
            }
        }
    }
}


Describe 'Test-FileIsLocked' {
    It 'Create a new temp file and verify it is not locked' {
        $tempFile = [IO.Path]::GetTempFileName()
        Test-Path $tempFile | Should Be $true
        try {
            Test-FileIsLocked $tempFile | Should Be $false
        }
        finally {
            if(Test-Path $tempFile) {
                Remove-Item $tempFile;
            }
        }
    }
    It 'Create a new temp file, lock it, and verify it is locked' {
        $fileStream = $null
        try {
            $tempFile = [IO.Path]::GetTempFileName()
            Test-Path $tempFile | Should Be $true
            try {
                $fileInfo = New-Object System.IO.FileInfo $tempFile
                $fileStream = $fileInfo.Open( [System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None )

                Test-FileIsLocked $tempFile | Should Be $true
            }
            finally {
                if($fileStream) {
                    $fileStream.Close()
                }
            }
        }
        finally {
            if(Test-Path $tempFile) {
                Remove-Item $tempFile;
            }
        }
    }

}

Function Test-FileIsLocked {
    [CmdletBinding()]
    ## Attempts to open a file and trap the resulting error if the file is already open/locked
    param ([string]$filePath )
    $filelocked = $false
    try {
        $fileInfo = New-Object System.IO.FileInfo $filePath
        $fileStream = $fileInfo.Open( [System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None )
    }
    catch {
        $filelocked = $true
        if ($fileStream) {
            $fileStream.Close()
        }
    }

    return $filelocked
}


Describe 'Remove-FileToRecycleBin' {
    if(($PSVersionTable.PSEdition -eq 'Desktop') -and ($PSVersionTable.Clrversion.Major -ge 4)) {
        It 'Item is no longe rin original directory' {
            $sampleFileName = [IO.Path]::GetTempFileName()
            Test-Path $sampleFileName | Should Be $true
            Remove-FileToRecycleBin $sampleFileName
            Test-Path $sampleFileName | Should Be False
            #TODO: Check that the file is in the recycle bin.
        }
    }
    else {
        Write-Warning 'Remove-FileToRecycleBin is not currently supported on the this platform.'
    }
}