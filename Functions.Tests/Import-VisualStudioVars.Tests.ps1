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
    #Mock Invoke-BatchFile { $path | Should be $expected  }
    Context "Mock out the call" {
        
        It "Test 2008 Not Installed" {
            #TODO: This should mock out the environemtn variable and not assume 2008 not installed
            Mock Test-Path { $false }
            Try {
                Import-VisualStudioVars "2008"
            }
            Catch {
                $_ | Should Be "Visual Studio 2008 is not installed or the expected environment variable is not found."
            }
        }

        It "Test 2008 Installed" {
            $existingVariable = $Env:VS90COMNTOOLS;
            Try
            {
                #Debug
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
                $Env:VS90COMNTOOLS = $existingVariable;
            }
            Assert-VerifiableMocks
        }
        #It "Test 2012" {
        #    $installed = Test-Path "${Env:VS110COMNTOOLS}..\..\VC\vcvarsall.bat"
        #    #TODO: Consider modyfying environment variables so the test verifies both when VS 2010 is installed and when it isn't.
        #    #$expected = "C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\Tools\..\..\VC\vcvarsall.bat"
        #    Try {
        #        Import-VisualStudioVars "2012"
        #        #TODO: mock asserts
        #    }
        #    Catch {
        #        $(if ($installed) { Throw $_ } else { $_ | Should Be "Visual Studio 2012 is not installed or the expected environment variable is not found." } )
        #    }
        #}
        #It "Test 2013" {
        #    $expected = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\Tools\..\..\VC\vcvarsall.bat"
        #    Import-VisualStudioVars 2013    
        #}
        #It "Test with no version parameter" {
        #    $path = $((Get-Item "env:vs*comntools" | sort value | select -last 1).Value)
        #    $expected = "$path..\..\VC\vcvarsall.bat"
        #    Import-VisualStudioVars   
        #}
    }
}