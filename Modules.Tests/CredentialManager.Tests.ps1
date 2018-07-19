Set-StrictMode -Version "Latest"

Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.CredentialManager

$targetName='tempCredentialManagerCredential.Test'

Describe "CredentialManagerCredenial Set and Get" {
    It "Verify successful set and get using a credential" {
        [PSCredential]$credential=
            new-object -typename System.Management.Automation.PSCredential '<username>',('<password>' | ConvertTo-SecureString -force -AsPlainText);
        Set-CredentialManagerCredential $targetName $credential
        [PSCredential]$result=Get-CredentialManagerCredential $targetName
        $result.UserName | should be '<username>';
        $result.GetNetworkCredential().password | should be '<password>';
    }
}


