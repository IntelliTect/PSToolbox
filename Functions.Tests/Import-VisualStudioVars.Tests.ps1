$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

#ToDO: These should be imported from PSCX... for some reason that fails to happen.
Function Push-EnvironmentBlock() {}
Function Invoke-BatchFile([string]$Path, [string]$Parameters) {}

Describe "Import-VisualStudioVars" {
    $expected = $null;
    Mock Push-EnvironmentBlock {}
    Mock Invoke-BatchFile { $path | Should be $expected  }
    Context "Mock out the call" {
        It "Test 2010" {
            #TODO: Consider modyfying environment variables so the test verifies both when VS 2010 is installed and when it isn't.
            $expected = "C:\Program Files\Microsoft Visual Studio 10.0\Common7\Tools\..\..\VC\vcvarsall.bat"
            Try {
                Import-VisualStudioVars 2010
            }
            Catch {
                $_ | Should Be "Visual Studio 2010 is not installed or the expected environment variable ('VS100COMNTOOLS') is not found."
            }
        }
        It "Test 2012" {
            $expected = "C:\Program Files (x86)\Microsoft Visual Studio 11.0\Common7\Tools\..\..\VC\vcvarsall.bat"
            Import-VisualStudioVars 2012    
        }
        It "Test 2013" {
            $expected = "C:\Program Files (x86)\Microsoft Visual Studio 11.0\Common7\Tools\..\..\VC\vcvarsall.bat"
            Import-VisualStudioVars 2013    
        }
        It "Test with no version parameter" {
            $path = $((Get-Item "env:vs*comntools" | sort value | select -last 1).Value)
            $expected = "$path..\..\VC\vcvarsall.bat"
            Import-VisualStudioVars   
        }
    }
}