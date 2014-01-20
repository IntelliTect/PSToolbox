$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

#ToDO: These should be imported from PSCX... for some reason that fails to happen.
#Function Push-EnvironmentBlock() {}
Function Invoke-BatchFile([string]$Path, [string]$Parameters) {}

function DebugBreak{}
function Debug{
    Set-PSBreakpoint -command DebugBreak
    DebugBreak
}

Describe "Import-VisualStudioVars" {
    $expected = $null;
    $installed = $false;
    Mock Push-EnvironmentBlock {}

    Context "Mock out the call" {
        
        It "Test 2008 Not Installed" {
            Mock Test-Path { $false }
            $existingVariable = $Env:VS90COMNTOOLS
            $Env:VS90COMNTOOLS = "TEST_VARIABLE"
            Try 
            {
                Import-VisualStudioVars "2008"
            }
            Catch 
            {
                $_ | Should Be "Visual Studio 2008 is not installed or the expected environment variable is not found."
            }
            Finally
            {
                $Env:VS90COMNTOOLS = $existingVariable                
            }
            Assert-VerifiableMocks
        }
        
        It "Test 2008 Installed" {
            $existingVariable = $Env:VS90COMNTOOLS
            Try
            {
                $Env:VS90COMNTOOLS = "TEST_VARIABLE"
                Mock Test-Path { $true }
                Mock Invoke-BatchFile { ($Path.EndsWith("vcvarsall.bat") -and $Path.Contains("TEST_VARIABLE")) | Should be $true } -Verifiable 
                Import-VisualStudioVars "2008"
            }
            Catch [System.Exception]
            {
                Write-Host $_.Exception.Message
            }
            Finally
            {
                $Env:VS90COMNTOOLS = $existingVariable
            }
            Assert-VerifiableMocks
        }
        
        It "Test 2010 Not Installed" {
            Mock Test-Path { $false }
            $existingVariable = $Env:VS100COMNTOOLS
            $Env:VS100COMNTOOLS = "TEST_VARIABLE"
            Try 
            {
                Import-VisualStudioVars "2010"
            }
            Catch 
            {
                $_ | Should Be "Visual Studio 2010 is not installed or the expected environment variable is not found."
            }
            Finally
            {
                $Env:VS100COMNTOOLS = $existingVariable                
            }
            Assert-VerifiableMocks
        }
        
        #It "Test 2010 Installed" {
        #    $existingVariable = $Env:VS100COMNTOOLS
        #    Try
        #    {
        #        $Env:VS100COMNTOOLS = "TEST_VARIABLE"
        #        Mock Test-Path { $true }
        #        Mock Invoke-BatchFile { ($Path.EndsWith("vcvarsall.bat") -and $Path.Contains("TEST_VARIABLE")) | Should be $true } -Verifiable 
        #        Import-VisualStudioVars "2010"
        #    }
        #    Catch [System.Exception]
        #    {
        #        Write-Host $_.Exception.Message
        #    }
        #    Finally
        #    {
        #        $Env:VS100COMNTOOLS = $existingVariable
        #    }
        #    Assert-VerifiableMocks
        #}

        It "Test 2012 Not Installed" {
            Mock Test-Path { $false }
            $existingVariable = $Env:VS110COMNTOOLS
            $Env:VS110COMNTOOLS = "TEST_VARIABLE"
            Try 
            {
                Import-VisualStudioVars "2012"
            }
            Catch 
            {
                $_ | Should Be "Visual Studio 2012 is not installed or the expected environment variable is not found."
            }
            Finally
            {
                $Env:VS110COMNTOOLS = $existingVariable                
            }
            Assert-VerifiableMocks
        }

        It "Test 2012 Installed" {
            $existingVariable = $Env:VS110COMNTOOLS
            Try
            {
                $Env:VS110COMNTOOLS = "TEST_VARIABLE"
                Mock Test-Path { $true }
                Mock Invoke-BatchFile { ($Path.EndsWith("vcvarsall.bat") -and $Path.Contains("TEST_VARIABLE")) | Should be $true } -Verifiable 
                Import-VisualStudioVars "2012"
            }
            Catch [System.Exception]
            {
                Write-Host $_.Exception.Message
            }
            Finally
            {
                $Env:VS110COMNTOOLS = $existingVariable
            }
            Assert-VerifiableMocks
        }
        
        It "Test 2013 Not Installed" {
            Mock Test-Path { $false }
            $existingVariable = $Env:VS120COMNTOOLS
            $Env:VS120COMNTOOLS = "TEST_VARIABLE"
            Try 
            {
                Import-VisualStudioVars "2013"
            }
            Catch 
            {
                $_ | Should Be "Visual Studio 2013 is not installed or the expected environment variable is not found."
            }
            Finally
            {
                $Env:VS120COMNTOOLS = $existingVariable                
            }
            Assert-VerifiableMocks
        }
        
        #It "Test 2013 Installed" {
        #    $existingVariable = $Env:VS120COMNTOOLS
        #    Try
        #    {
        #        $Env:VS120COMNTOOLS = "TEST_VARIABLE"
        #        Mock Test-Path { $true }
        #        Mock Invoke-BatchFile { ($Path.EndsWith("vcvarsall.bat") -and $Path.Contains("TEST_VARIABLE")) | Should be $true } -Verifiable 
        #        Import-VisualStudioVars "2013"
        #    }
        #    Catch [System.Exception]
        #    {
        #        Write-Host $_.Exception.Message
        #    }
        #    Finally
        #    {
        #        $Env:VS120COMNTOOLS = $existingVariable
        #    }
        #    Assert-VerifiableMocks
        #}
    }
}