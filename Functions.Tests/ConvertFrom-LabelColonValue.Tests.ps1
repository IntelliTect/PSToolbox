$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut
 
function DebugBreak{}
function Debug{
    Set-PSBreakpoint -command DebugBreak
    DebugBreak
}

Describe "ConvertFrom-LabelColonValue" {
    It "Parse basic labelColonValue 1"{
        $labelColonValue = @"
        Local information:
          Local path : C:\data\SCC\SPUNK\IntelliTect.VS.com\2\SPIdeation\DEV\PSDefault
          Server path: $/SPIdeation/DEV/PSDefault
          Changeset  : 2842
          Change     : none
          Type       : folder
        Server information:
          Server path  : $/SPIdeation/DEV/PSDefault
          Changeset    : 2842
          Deletion ID  : 0
          Lock         : none
          Lock owner   : 
          Last modified: Friday, December 6, 2013 7:33:51 AM
          Type         : folder
"@
        $result = ConvertFrom-LabelColonValue($labelColonValue)
        $result.Changeset | Should Be 2842
    }

        It "Parse basic lavelColonValue 2" {
        $labelColonValue = @"
        Local information:
          Local path : C:\Data\SCC\SPUNK\IntelliTect.VS.com\2\SPIdeation\DEV\PSDefault\Functions\New-NugetPackage.ps1
          Server path: $/SPIdeation/DEV/PSDefault/Functions/New-NugetPackage.ps1
          Changeset  : 3783
          Change     : edit
          Type       : file
        Server information:
          Server path  : $/SPIdeation/DEV/PSDefault/Functions/New-NugetPackage.ps1
          Changeset    : 3783
          Deletion ID  : 0
          Lock         : none
          Lock owner   : 
          Last modified: Friday, January 24, 2014 8:34:12 AM
          Type         : file
          File type    : Windows-1252
          Size         : 3528
"@
        $result = ConvertFrom-LabelColonValue($labelColonValue)
        $result.Changeset | Should Be 3783
    }
}