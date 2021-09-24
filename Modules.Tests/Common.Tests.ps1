<#Header#>
Set-StrictMode -Version "Latest"

Get-Module IntelliTect.Common | Remove-Module -Force
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common\IntelliTect.Common.psm1 -Force
<#EndHeader#>

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
        $object.Dispose() | Should -Be $true
        $object.IsDisposed | Should -Be $true
    }
    It "Verify that a dispose method is added for multiple input objects on the pipe." {
        $object1 = New-Object Object
        $object2 = New-Object Object
        $object1,$object2 | Add-DisposeScript -DisposeScript { Write-Output  $true }
        $object1,$object2 | ForEach-Object {
            $_.PSobject.Members.Name -contains "Dispose" | Should -Be $true
            $_.Dispose() | Should -Be $true
            $_ | Get-Member -Name 'IsDisposed' | Select-Object -ExpandProperty Name | Should -Be 'IsDisposed'
            $_.IsDisposed | Should -Be $true
        }
    }
    It "Verify add dispose to string" { 
        [String]$text = "Inigo Montoya"
        { $text | Add-DisposeScript -DisposeScript { Write-Output  $true } } | Should -Throw
        # TODO  'Add-DisposeScript does not work for a string (it likely is behaves with pass-by-value because it is read-only'
        # As a result of the above warning, the following lines will fail if we didn't throw the exception.
        # $text | Add-DisposeScript -DisposeScript { Write-Output  $true } 
        # $text.Dispose() | Should -Be $true
        # $text.IsDisposed | Should -Be $true
    }
}

Describe "Register-AutoDispose" {
    It "Verify that dispose is called on Add-DisposeScript object" {
        $sampleDisposeObject = New-Object Object
        $sampleDisposeObject | Add-DisposeScript -DisposeScript { Write-Output  "first" }
        Register-AutoDispose $sampleDisposeObject { Write-Output 42 } | Should -Be 42, "first"
        $sampleDisposeObject.IsDisposed | Should -Be $true
    }
    It "Verify that dispose is called" {
        $sampleDisposeObject = Get-SampleDisposeObject
        Register-AutoDispose $sampleDisposeObject { Write-Output $true } | Should -Be $true
        $sampleDisposeObject.DisposeCalled | Should -Be $true
    }
    It "Verify that InputObject can be passed via pipeline" {
        # NOTE: Parameter $ScriptBlock must be named when passing $InputObject via the pipeline.
        #       If you remove the position from $ScriptBlock then you can't invoke
        #       Register-AutoDispose with unnamed parameters because the scriptblock
        #       is infered as a member of the $InputObject array
        $sampleDisposeObject = Get-SampleDisposeObject
        $sampleDisposeObject | Register-AutoDispose -ScriptBlock { Write-Output $true } | Should -Be $true
    }
    It "Verify that the disposed object is passed as a parameter to the `$ScriptBlock" {
        $sampleDisposeObject = Get-SampleDisposeObject
        Register-AutoDispose $sampleDisposeObject {
            param($parmameter) Write-Output $parmameter } | Should -Be $sampleDisposeObject
        $sampleDisposeObject.DisposeCalled | Should -Be $true
    }
    It "NOTE: Both value types and refrence types can be passed in closure but neither will reflect change after the closure." {
        $sampleDisposeObject = Get-SampleDisposeObject
        [int]$count = 42
        [string]$text = "original"
        Register-AutoDispose $sampleDisposeObject {
            Write-Output "$text,$count";
            $count = 2
            $text = "updated"
        } | Should -Be "original,42"
        $count | Should -Be 42
        $text | Should -Be "original"
    }
}

Describe "Get-Tempdirectory" {
    It 'Verify error handling when the directory is in use.' {
        $tempItem = $null
        try {
            $tempItem = Get-TempDirectory
            push-location $tempItem
            {
                $tempItem.Dispose()
            } | Should -Throw
        }
        finally {
            if (Test-Path $tempItem) {
                Pop-Location
                Remove-Item $tempItem -Force -Recurse
            }
        }
    }
    It 'Verify the temp directory created is in the %TEMP% (temporary) directory' {
        try {
            $tempItem = Get-TempDirectory
            $tempItem.Parent.FullName |Should -Be ([IO.Path]::GetTempPath().TrimEnd([IO.Path]::DirectorySeparatorChar).TrimEnd([IO.Path]::AltDirectorySeparatorChar))
        }
        finally {
            Remove-Item $tempItem;
            Test-Path $tempItem | Should -Be $false
        }
    }
}

Describe "Get-TempDirectory/Get-TempFile Support Dispose pattern" {
    It "Verify that the item has a Dispose and IsDisposed member" {
        (Get-TempDirectory), (Get-TempFile) | ForEach-Object {
            $_.PSobject.Members.Name -contains 'Dispose' | Should -Be $true
            $_.PSobject.Members.Name -contains 'IsDisposed' | Should -Be $true
            $_.Dispose()
        }
    }
    It "Verify that Dispose removes the item" {
        (Get-TempDirectory), (Get-TempFile) | ForEach-Object {
            $_.Dispose()
            Test-Path $_ | Should -Be $false
            $_.IsDisposed | Should -Be $true
        }
    }
    It "Verify dispose member is called by Register-AutoDispose" {
        (Get-TempDirectory), (Get-TempFile) | ForEach-Object {
            Register-AutoDispose $_ {}
            Test-Path $_ | Should -Be $false
            $_.IsDisposed | Should -Be $true
        }
    }
    It "Verify item is created with the correct path" {
        Register-AutoDispose -InputObject  ($tempDirectory = Get-TempDirectory) -ScriptBlock {
            $path = $tempDirectory.FullName
            # Now that a temporary directory exists, call Get-TempDirectory and Get-TempFile
            # and specify the above directory in which to place the temp directory/file.
            (Get-TempDirectory -Path $path), (Get-TempFile $path) | ForEach-Object {
                [System.IO.FileSystemInfo]$item = $_
                Split-Path -Parent $item.FullName | Should -Be $Path
                Register-AutoDispose $item {}
                Test-Path $item | Should -Be $false
            }
        }
    }
    It "Verify item is not created with DoNotCreate*" {
        (Get-TempDirectory -DoNotCreateDirectory), (Get-TempFile -DoNotCreateFile) | ForEach-Object {
            Test-Path $_.FullName | Should -BeFalse
            $ItemType = $null
            if($_.GetType() -eq [System.IO.FileInfo]) {$ItemType = 'File'}
            else { $ItemType = 'Directory'}
            New-Item -ItemType $ItemType $_.FullName
            Register-AutoDispose $_ {}
            Test-Path $_ | Should -BeFalse
            $_.IsDisposed | Should -BeTrue
        }
    }
    It 'Verify that the Dispose method removes the directory even if it contains files.' {
        $tempItem = $null
        try {
            $tempItem = Get-TempDirectory
            Get-TempFile -Path $tempItem
            $tempItem.Dispose()
            Test-Path $tempItem | Should -Be $false
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
                Test-Path $tempFile.FullName | Should -Be $true
                Split-Path $tempFile -Parent | Should -Be $tempDirectory.FullName
            }
        }
    }
    It "Provide the name but no path" {
        $fileName = Split-Path (Get-TempItemPath) -Leaf
        Register-AutoDispose ($tempFile = Get-TempFile -name $fileName) {
            Test-Path $tempFile.FullName | Should -Be $true
            $tempFile.Name | Should -Be $fileName
        }
    }
    It "Provide the path and the name" {
        # Create a temporary working directory
        Register-AutoDispose ($tempDirectory = Get-TempDirectory) {
            $tempFileName = Split-Path (Get-TempItemPath) -Leaf
            Register-AutoDispose ($tempFile = Get-TempFile $tempDirectory $tempFileName) {
                Test-Path $tempFile.FullName | Should -Be $true
                $tempFile.FullName | Should -Be (Join-Path $tempDirectory $tempFileName)
            }
            Test-Path $tempFile.FullName | Should -Be $false
        }
    }
}

Describe "Get-TempItemPath" {
    It "No file exists for the given name" {
        Get-TempItemPath | Test-Path | Should -Be $false
    }
    It "No file exists for the given name" {
        Register-AutoDispose ($evironmentTemporaryDirectory = Get-TempDirectory) {
            Get-TempItemPath $evironmentTemporaryDirectory | ForEach-Object {
                    Test-Path $_ | Should -Be $false
            }
        }
    }
    It "The root path is the directory specified." {
        Register-AutoDispose ($evironmentTemporaryDirectory = Get-TempDirectory) {
            Get-TempItemPath $evironmentTemporaryDirectory | ForEach-Object {
                Split-Path $_ -Parent | Should -Be $evironmentTemporaryDirectory.FullName
            }
        }
    }
}

Describe "Test-Command" {
    It "If command doesn't exist returns false" {
        Test-Command 'Command-Does-Not-Exist' | Should -Be $false
    }
    It 'Valid command returns true' {
        Test-Command 'Get-Item' | Should -Be $true
    }
    It 'Valid command via pipeline returns true' {
        'Get-Item','Test-Command','Command-Does-Not-Exist' | Test-Command | Should -Be $true,$true,$false
    }

}

Describe "Test-Property" {
    It 'Verify that an existing property on [string] returns true.' {
        Test-Property -InputObject 'Test' -Name 'Length' | Should -Be $true
    }
    It 'Verify that an non-existent property on [string] returns false.' {
        Test-Property -InputObject 'Test' -Name 'DoesNotExist' | Should -Be $false
    }
    It 'Verify that an non-existent property on [string] returns false.' {
        Test-Property 'Test' 'DoesNotExist' | Should -Be $false
    }
    It 'Verify that an existing property on [string] passed via pipeline returns true.' {
        'Test' | Test-Property -Name 'Length' | Should -Be $true
    }
    It 'Verify with two input objects.' {
        'Test1','Test2' | Test-Property -Name 'Length' | Should -Be $true,$true
    }
    It 'Verify that you can pass an array of property names.' {
        'Test' | Test-Property -Name 'Length','DoesNotExist' | Should -Be $true,$false
    }
}

Describe "Get-IsWindowsPlatform" {
    It "Get-IsWindowsPlatform verifiction using existence of env:SystemRoot" {
        Get-IsWindowsPlatform | Should -Be $(Get-Variable IsWindows).Value
    }
}

Describe 'Wait-ForCondition' {
    It 'Simplest Wait' {
        $script:falseCount=0
        [int]$script:sum=0
        [int]$script:innvocationCount=0
        1..3 | Wait-ForCondition -Condition {
            param($_)
            $script:innvocationCount++
            [bool]$passed=(($script:sum+=$_) -gt 1)
            if(!$passed) {
                $script:falseCount++
            }
            return $passed
        }
        $script:falseCount | Should -Be 1
        [int]$script:innvocationCount | Should -Be 4
    }
    It 'Check for timeout when waiting for even numbers 10000 times' {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $exception=$null
        [int]$timeout = 10
        try {
            1..10000 | Wait-ForCondition -TimeoutInMilliseconds $timeout  -Condition { ((Get-Random -Minimum 1 -Maximum 11)%2) -eq 0 } > $null
        }
        catch [TimeoutException] {
            $exception = $_.Exception
        }
        $stopwatch.ElapsedMilliseconds | Should -BeGreaterThan $timeout
        $exception | Should -BeOfType [TimeoutException]
    }
    It 'Wait for 100 random even numbers to be generated.' {
        [int]$script:falseCount=0
            1..100 | Wait-ForCondition -Condition {
                [bool]$even=((Get-Random -Minimum 1 -Maximum 11)%2) -eq 0
            if(-not $even) {
                $script:falseCount++
            }
            return $even
        }
        $script:falseCount | Should -BeGreaterThan 0
    }
    It 'Timeout cannot be less than 0' {
        {1 | Wait-ForCondition -TimeoutInMilliseconds -1 -Condition {}} | Should -Throw
    }
    It 'TimeSpan cannot be 0.0.0 (checking TotalMilliseconds = 0).  Note that .5 seconds registers as 0 milliseconds  ' {
        {1 | Wait-ForCondition -TimeSpan (New-TimeSpan -seconds (.5)) -Condition {}} | Should -Throw
    }
    It 'Check for timeout of 5 milliseconds' {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $exception=$null
        [int]$timeout = 5
        try {
            1..100 | Wait-ForCondition -TimeoutInMilliseconds $timeout -Condition { Start-Sleep 1;$false } > $null
        }
        catch [TimeoutException] {
            $exception = $_.Exception
        }
        $stopwatch.ElapsedMilliseconds | Should -BeGreaterThan $timeout
        $exception | Should -BeOfType [TimeoutException]
    }
    It 'Check for timeout of .54 milliseconds using TimeSpan' {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $exception=$null
        [int]$timeout = .54
        try {
            1..100 | Wait-ForCondition -TimeSpan (New-TimeSpan -Seconds ($timeout)) -Condition { Start-Sleep 1;$false } > $null
        }
        catch [TimeoutException] {
            $exception = $_.Exception
        }
        $stopwatch.ElapsedMilliseconds | Should -BeGreaterThan $timeout
        $exception | Should -BeOfType [TimeoutException]
    }
}

Describe 'Wait-ForCondition Error Checking' {
    It 'Verify that the Condition must be a predicate (return a [bool]' {
        try {
            Wait-ForCondition -InputObject 'Input' -Condition { return 'Inigo Montoya'}
        }
        catch {
            $_.Exception.Message | Should -BeLike '*The Condition script must be a predicate*'
        }
    }
    It 'Verify that the condition must be a scalar (a single value)' {
        try {
            Wait-ForCondition -InputObject 'Input' -Condition { return $true,$false }
        }
        catch {
            $_.Exception.Message | Should -BeLike '*The Condition must return a scalar*'
        }
    }
    It 'Verify that the condition have a return' {
        try {
            Wait-ForCondition -InputObject 'Input' -Condition { }
        }
        catch {
            $_.Exception.Message | Should -BeLike '*The Condition script must return a Boolean value*'
        }
    }
}