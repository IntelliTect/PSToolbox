
#ToDo: Submit this back to the PSCX code base.
Function Import-VisualStudioVars {
    [CmdletBinding(
        SupportsShouldProcess=$true #Tells the shell that your function supports both -confirm and -whatif.
        ,ConfirmImpact="High" #Causes Confirm prompt when $ConfirmPreference is "High"
    )]
    param
    (
        [Parameter(Position = 0)][string]$VisualStudioVersion,
        [Parameter(Position = 1)][string]$Architecture = $(if ($Pscx:Is64BitProcess) {'amd64'} else {'x86'})
    )

    End
    {
        switch -Regex ($VisualStudioVersion)
        {
            '2008' {
                If(Test-Path Env:VS90COMNTOOLS) {
                    Push-EnvironmentBlock -Description "Before importing VS 2008 $Architecture environment variables"
                    Invoke-BatchFile "${env:VS90COMNTOOLS}..\..\VC\vcvarsall.bat" $Architecture
                }
                Else {
                    Throw "Visual Studio $_ is not installed or the expected environment variable ('VS90COMNTOOLS') is not found."
                }
            }
      
            '2010' {
                If(Test-Path Env:VS100COMNTOOLS) {
                    Push-EnvironmentBlock -Description "Before importing VS 2010 $Architecture environment variables"
                    Invoke-BatchFile "${env:VS100COMNTOOLS}..\..\VC\vcvarsall.bat" $Architecture
                }
                Else {
                    Throw "Visual Studio $_ is not installed or the expected environment variable ('VS100COMNTOOLS') is not found."
                }
            }
 
            '2012' {
                If(Test-Path Env:VS110COMNTOOLS) {
                    Push-EnvironmentBlock -Description "Before importing VS 2012 $Architecture environment variables"
                    Invoke-BatchFile "${env:VS110COMNTOOLS}..\..\VC\vcvarsall.bat" $Architecture
                }
                Else {
                    Throw "Visual Studio $_ is not installed or the expected environment variable ('VS110COMNTOOLS') is not found."
                }
            }
            '2013' {
                If(Test-Path Env:VS110COMNTOOLS) {
                    Push-EnvironmentBlock -Description "Before importing VS 2013 $Architecture environment variables"
                    Invoke-BatchFile "${env:VS120COMNTOOLS}..\..\VC\vcvarsall.bat" $Architecture
                }
                Else {
                    Throw "Visual Studio $_ is not installed or the expected environment variable ('VS120COMNTOOLS') is not found."
                }
            } 
            default {
                $vscomntools = Get-Item "env:vs*comntools"
                If($vscomntools) {
                    Push-EnvironmentBlock -Description "Before importing lastest VS $Architecture environment variables"
                    Invoke-BatchFile "$((Get-Item "env:vs*comntools" | sort value | select -last 1).Value)..\..\VC\vcvarsall.bat" $Architecture
                }
                Else {
                    Throw "Visual Studio is not installed or no 'VS*COMNTOOLS' environment variable was not found."
                }
            }
        }
    }
}