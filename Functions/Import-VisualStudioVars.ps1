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
        switch ($VisualStudioVersion)
        {
            '2008' {
                Push-EnvironmentBlock -Description "Before importing VS 2008 $Architecture environment variables"
                Invoke-BatchFile "${env:VS90COMNTOOLS}..\..\VC\vcvarsall.bat" $Architecture
            }
      
            '2010' {
                Push-EnvironmentBlock -Description "Before importing VS 2010 $Architecture environment variables"
                Invoke-BatchFile "${env:VS100COMNTOOLS}..\..\VC\vcvarsall.bat" $Architecture
            }
 
            '2012' {
                Push-EnvironmentBlock -Description "Before importing VS 2012 $Architecture environment variables"
                Invoke-BatchFile "${env:VS110COMNTOOLS}..\..\VC\vcvarsall.bat" $Architecture
            }
 
            default {
                Push-EnvironmentBlock -Description "Before importing lastest VS $Architecture environment variables"
                Invoke-BatchFile "$((Get-Item "env:vs*comntools" | select -last 1).Value)..\..\VC\vcvarsall.bat" $Architecture
            }
        }
    }
}