<#Header#>
Set-StrictMode -Version "Latest"

Get-Module IntelliTect.Common | Remove-Module -Force
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common -Force

#EndHeader#>

Function Script:Get-SampleDisposeObject {
    $object = New-Object object
    $object | Add-Member -MemberType NoteProperty -Name DisposeCalled -Value $false
    $object | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $this.DisposeCalled = $true }
    return $object
}

Describe "Add-DisposeScript" {
    It "Verify that a dispose method is added." {
        $object = New-Object Object
        $object | Add-DisposeScript -DisposeScript { Write-Output  $true }
        $object.Dispose() | Should Be $true
        $object.IsDisposed | Should Be $true
    }
}

Describe "Register-AutoDispose" {
    It "Verify that dispose is called on Add-DisposeScript object" {
        $sampleDisposeObject = New-Object Object
        $sampleDisposeObject | Add-DisposeScript -DisposeScript { Write-Output  "first" }
        Register-AutoDispose $sampleDisposeObject { Write-Output 42 } | Should Be 42, "first"
        $sampleDisposeObject.IsDisposed | Should Be $true
    }
    It "Verify that dispose is called" {
        $sampleDisposeObject = Get-SampleDisposeObject
        Register-AutoDispose $sampleDisposeObject { Write-Output $true } | Should Be $true
        $sampleDisposeObject.DisposeCalled | Should Be $true
    }
    It "Verify that InputObject can be passed via pipeline" {
        # NOTE: Parameter $ScriptBlock must be named when passing $InputObject via the pipeline.
        #       If you remove the position from $ScriptBlock then you can't invoke
        #       Register-AutoDispose with unnamed parameters because the scriptblock
        #       is infered as a member of the $InputObject array
        $sampleDisposeObject = Get-SampleDisposeObject
        $sampleDisposeObject | Register-AutoDispose -ScriptBlock { Write-Output $true } | Should Be $true
    }
    It "Verify that the disposed object is passed as a parameter to the `$ScriptBlock" {
        $sampleDisposeObject = Get-SampleDisposeObject
        Register-AutoDispose $sampleDisposeObject {
            param($inputObject) Write-Output $inputObject } | Should Be $sampleDisposeObject
        $sampleDisposeObject.DisposeCalled | Should Be $true
    }
    It "NOTE: Both value types and refrence types can be passed in closure but neither will reflect change after the closure." {
        $sampleDisposeObject = Get-SampleDisposeObject
        [int]$count = 42
        [string]$text = "original"
        Register-AutoDispose $sampleDisposeObject {
            Write-Output "$text,$count";
            $count = 2
            $text = "updated"
        } | Should Be "original,42"
        $count | Should Be 42
        $text | Should Be "original"
    }
}

Describe "Get-Tempdirectory" {
    It 'Verify the temp directory created is in the %TEMP% (temporary) directory' {
        try {
            $tempItem = Get-TempDirectory
            $tempItem.Parent.FullName |Should Be ([IO.Path]::GetTempPath().TrimEnd([IO.Path]::DirectorySeparatorChar).TrimEnd([IO.Path]::AltDirectorySeparatorChar))
        }
        finally {
            Remove-Item $tempItem;
            Test-Path $tempItem | Should Be $false
        }
    }

}

Describe "Get-TempDirectory/Get-TempFile" {
    (Get-TempDirectory), (Get-TempFile) | ForEach-Object {
        It "Verify that the item has a Dispose and IsDisposed member" {
            $_.PSobject.Members.Name -match "Dispose" | Should Be 'IsDisposed', 'Dispose'
        }
        It "Verify that Dispose removes the item" {
            $_.Dispose()
            Test-Path $_ | Should Be $false
            $_.IsDisposed | Should Be $true
        }
    }
    (Get-TempDirectory), (Get-TempFile) | ForEach-Object {
        It "Verify dispose member is called by Register-AutoDispose" {
            Register-AutoDispose $_ {}
            Test-Path $_ | Should Be $false
            $_.IsDisposed | Should Be $true
        }
    }
    ($tempDirectory = Get-TempDirectory) |
        Register-AutoDispose -ScriptBlock {
        $path = $tempDirectory.FullName
        # Now that a temporary directory exists, call Get-TempDirectory and Get-TempFile
        # and specify the above directory in which to place the temp directory/file.
        (Get-TempDirectory -Path $path), (Get-TempFile $path) | ForEach-Object {
            It "Verify item is created with the correct path" {
                Register-AutoDispose $_ {}
                Test-Path $_ | Should Be $false
            }
        }
    }
    It 'Verify that the Dispose method removes the directory even if it contains files.' {
        $tempItem = $null
        try {
            $tempItem = Get-TempDirectory
            Get-TempFile -Path $tempItem
            $tempItem.Dispose()
            Test-Path $tempItem | Should Be $false
        }
        finally {
            if (Test-Path $tempItem) {
                Remove-Item $tempItem -Force -Recurse
            }
        }
    }
}

Describe "Get-TempFile" {
    It "Provide the full path (no `$Name parameter)" {
        $tempDirectory = Get-TempDirectory
        # Create a temporary directory to place the file into.
        Register-AutoDispose $tempDirectory {
            Register-AutoDispose ($tempFile = Get-TempFile -path $tempDirectory.FullName) {
                Test-Path $tempFile.FullName | Should Be $true
                Split-Path $tempFile -Parent | Should Be $tempDirectory.FullName
            }
        }
    }
    It "Provide the name but no path" {
        $fileName = Split-Path (Get-TempItemPath) -Leaf
        Register-AutoDispose ($tempFile = Get-TempFile -name $fileName) {
            Test-Path $tempFile.FullName | Should Be $true
            $tempFile.Name | Should Be $fileName
        }
    }
    It "Provide the path and the name" {
        # Create a temporary working directory
        Register-AutoDispose ($tempDirectory = Get-TempDirectory) {
            $tempFileName = Split-Path (Get-TempItemPath) -Leaf
            Register-AutoDispose ($tempFile = Get-TempFile $tempDirectory $tempFileName) {
                Test-Path $tempFile.FullName | Should Be $true
                $tempFile.FullName | Should Be (Join-Path $tempDirectory $tempFileName)
            }
            Test-Path $tempFile.FullName | Should Be $false
        }
    }
}


Describe "Get-TempItemPath" {
    It "No file exists for the given name" {
        Get-TempItemPath | Test-Path | Should Be $false
    }
    Register-AutoDispose ($evironmentTemporaryDirectory = Get-TempDirectory) {
        Get-TempItemPath $evironmentTemporaryDirectory | ForEach-Object {
            It "No file exists for the given name" {
                Test-Path $_ | Should Be $false
            }
            It "The root path is the directory specified." {
                Split-Path $_ -Parent | Should Be $evironmentTemporaryDirectory.FullName
            }
        }
    }
}


Describe "Test-Command" {
    It "If command doesn't exist returns false" {
        Test-Command 'Command-Does-Not-Exist' | Should Be $false
    }
    It 'Valid command returns true' {
        Test-Command 'Get-Item' | Should Be $true
    }
}

Describe "Test-Property" {
    It 'Verify that an existing property on [string] returns true.' {
        Test-Property -InputObject 'Test' -Name 'Length' | Should Be $true
    }
    It 'Verify that an non-existent property on [string] returns false.' {
        Test-Property -InputObject 'Test' -Name 'DoesNotExist' | Should Be $false
    }
    It 'Verify that an non-existent property on [string] returns false.' {
        Test-Property 'Test' 'DoesNotExist' | Should Be $false
    }
    It 'Verify that an existing property on [string] passed via pipeline returns true.' {
        'Test' | Test-Property -Name 'Length' | Should Be $true
    }
    It 'Verify with two input objects.' {
        'Test1','Test2' | Test-Property -Name 'Length' | Should Be $true
    }
    It 'Verify that you can pass an array of property names.' {
        'Test' | Test-Property -Name 'Length','DoesNotExist' | Should Be $true,$false
    }
    It 'Verify that you can pass an array of property names without a naming the parameter.' -Skip {
        'Test' | Test-Property 'Length','DoesNotExist' | Should Be $true,$false
    }
}

Describe "Set-IsWindows" {
    if (-not $IsWindows) {
        It "When `$IsWindows exists, it does nothing" {
            dir env:
            Set-IsWindows 
            $IsWindows | Should Be (Test-Path env:\SystemRoot)


        }
    }
}