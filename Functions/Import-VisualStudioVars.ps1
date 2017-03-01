
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
                Import-VisualStudioVarsFromScript "2008" "${Env:VS90COMNTOOLS}" $Architecture
            }
   
            '2010' {
                Import-VisualStudioVarsFromScript "2010" "${Env:VS100COMNTOOLS}" $Architecture
            }
 
            '2012' {
                Import-VisualStudioVarsFromScript "2012" "${Env:VS110COMNTOOLS}" $Architecture
            }

            '2013' {
                Import-VisualStudioVarsFromScript "2013" "${Env:VS120COMNTOOLS}" $Architecture
            } 
            '2015' {
                Import-VisualStudioVarsFromScript "2015" "${Env:VS140COMNTOOLS}" $Architecture
            } 
            '2017' {
                $batchPath = Resolve-Path  "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\*\Common7\tools\vsdevcmd.bat"
                if(!(Test-Path $batchPath)) {
                    throw "Unable to find Visuals Studio Developer Command batch file"
                }
                Invoke-BatchFile $batchPath
            }                         
            default {
                $vscomntools = Get-Item "env:vs*comntools"
                If($vscomntools) {
                    Push-EnvironmentBlock -Description "Before importing lastest VS $Architecture environment variables"
                    Invoke-BatchFile "$((Get-Item "env:vs*comntools" | sort value | select -last 1).Value)..\..\VC\vcvarsall.bat" $Architecture
                }
                else {
                    Import-VisualStudioVars 2017
                }
            }
        }
    }
}

Function Import-VisualStudioVarsFromScript([string] $version, [string]$commonToolsPath, [string] $architecture) {
    If([string]::IsNullOrEmpty($commonToolsPath) -eq $false -and (Test-Path $commonToolsPath)) {
        [string]$batchPath = "$commonToolsPath..\..\VC\vcvarsall.bat"
        If(Test-Path $batchPath) {
            Push-EnvironmentBlock -Description "Before importing VS $version $architecture environment variables"
            Invoke-BatchFile $batchPath $architecture
        }
        Else {
            Throw "$batchPath not found"
        }
    }
    Else {
        Throw "Visual Studio $version is not installed or the expected environment variable is not found."
    }
}