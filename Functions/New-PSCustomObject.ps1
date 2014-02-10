#see http://blogs.microsoft.co.il/scriptfanatic/2012/04/13/custom-objects-default-display-in-powershell-30/

function New-PSCustomObject
{
       [CmdletBinding()] 

       param(
              [Parameter(Mandatory,Position=0)]
              [ValidateNotNullOrEmpty()]
              [System.Collections.Hashtable]$Property,

              [Parameter(Position=1)]
              [ValidateNotNullOrEmpty()]
              [Alias('dp')]
              [System.String[]]$DefaultProperties
       )


       $psco = [PSCustomObject]$Property 

       # define a subset of properties
       $ddps = New-Object System.Management.Automation.PSPropertySet `
                DefaultDisplayPropertySet,$DefaultProperties
       $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]$ddps 

       # Attach default display property set
       $psco | Add-Member -MemberType MemberSet -Name PSStandardMembers `
                -Value $PSStandardMembers -PassThru
}