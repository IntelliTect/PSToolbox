# See http://www.tellingmachine.com/post/Test-Member-The-Missing-PowerShell-Cmdlet.aspx
# TODO: Consider $_.PSObject.Properties.Match("DisplayName") as it may be faster
function Test-Member()
{
<# 
.Synopsis 
    Verifies whether a specific property or method member exists for a given .NET object 
.Description 
    Verifies whether a specific property or method member exists for a given .NET object  
.Example
    Test-Member -PropertyName "Context" -InputObject (new-object System.Collections.ArrayList)
.Example
    new-object "System.Collections.ArrayList" | Test-Member -PropertyName "ToArray"
.Parameter PropertyName
    Name of a Property to test for 
.Parameter MethodName
    Name of a Method to test for  
.ReturnValue 
    $True or $False
.Link 
    about_functions_advanced 
    about_functions_advanced_methods 
    about_functions_advanced_parameters 
.Notes 
NAME:      Test-Member
AUTHOR:    Klaus Graefensteiner 
LASTEDIT:  04/20/2010 12:12:42
#Requires -Version 2.0 
#> 
     
    [CmdletBinding(DefaultParameterSetName="Properties")]
    PARAM(
         
        [ValidateNotNull()]
        [Parameter(Position=0, Mandatory=$True, ValueFromPipeline=$True)]
        $InputObject,
         
        [ValidateNotNullOrEmpty()]
        [Parameter(Position=1, Mandatory=$True, ValueFromPipeline=$False, ParameterSetName="Properties")]
        [string] $PropertyName,
         
        [ValidateNotNullOrEmpty()]
        [Parameter(Position=1, Mandatory=$True, ValueFromPipeline=$False, ParameterSetName="Methods")]
        [string] $MethodName     
    )
    Process{
         
        switch ($PsCmdlet.ParameterSetName) 
        { 
            "Properties"
            {
                $Members = Get-Member -InputObject $InputObject;
                if ($Members -ne $null -and $Members.count -gt 0)
                {
                    foreach($Member in $Members)
                    {
                        if(($Member.MemberType -like "*Property" ) -and ($Member.Name -eq $PropertyName))
                        {
                            return $true
                        }
                    }
                    return $false
                }
                else
                {
                    return $false;
                }
            }
            "Methods"
            {
                $Members = Get-Member -InputObject $InputObject;
                if ($Members -ne $null -and $Members.count -gt 0)
                {
                    foreach($Member in $Members)
                    {
                        if(($Member.MemberType -eq "Method" ) -and ($Member.Name -eq $MethodName))
                        {
                            return $true
                        }
                    }
                    return $false
                }
                else
                {
                    return $false;
                }
            }
        }
     
    }# End Process
}
 
 
function Parse-XML([string] $XMLString, [String] $XPath, [int] $Status )
{
    $XMLResult = [XML] $XMLString;
     
    if($XMLResult -ne $null)
    {
        if($Status -eq 200)
        {
            $XPathSingle = $XPath.substring(0, $XPath.Length -1)
            return $XMLResult.$XPath.$XPathSingle;
        }
        else
        {
            return $XMLResult.Error;
        }
    }
}