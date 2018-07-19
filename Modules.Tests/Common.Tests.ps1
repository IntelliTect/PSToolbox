<#Header#>
Set-StrictMode -Version "Latest"

#Get-Module IntelliTect.Common | Remove-Module
#Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common -Force


#EndHeader#>

Function Script:Get-SampleDisposeObject {
    $object = New-Object object
    $object | Add-Member -MemberType NoteProperty -Name DisposeCalled -Value $false
    $object | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $this.DisposeCalled = $true }
    return $object
}

Describe "Add-DisposeScript" {
    It "Verify that a dispose metthod is added." {
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
        Register-AutoDispose $sampleDisposeObject { Write-Output 42 } | Should Be "first",42
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
    It 'Verify the item is in the %TEMP% (temporary) directory' {
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
        It "Verify that the item has a Dispose member" {
            $_.PSobject.Members.Name -match "Dispose" | Should Be $true
        }
        It "Verify that Dispose removes the item" {
            $_.Dispose()
            Test-Path $$_ | Should Be $false
        }
    }
    (Get-TempDirectory), (Get-TempFile) | ForEach-Object {
        It "Verify dispose member is called by Register-AutoDispose" {
            Register-AutoDispose $_ {}
            Test-Path $_ | Should Be $false
       }
    }
    Register-AutoDispose (Get-TempDirectory) {
        param($inputObject)
        $path = $inputObject.FullName
        (Get-TempDirectory -Path $path), (Get-TempFile $path) | ForEach-Object {
            It "Verify item is created with the correct path" {
                Register-AutoDispose $_ {}
                Test-Path $_ | Should Be $false
        }
        }
    }
}

Describe "Get-TempFile" {
    It "Provide the full path (no `$Name parameter)" {
        $tempDirectory = Get-TempDirectory
        # Create a temporary directory to place the file into.
        Register-AutoDispose $tempDirectory {
            Register-AutoDispose ($tempFile=Get-TempFile -path $tempDirectory.FullName) {
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