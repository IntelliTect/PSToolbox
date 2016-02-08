Set-StrictMode -Version "Latest"
$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

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

    It "Verify successful set and get using username and password parameters" {
        Set-CredentialManagerCredential $targetName '<username>' '<password>'
        [PSCredential]$result=Get-CredentialManagerCredential $targetName
        $result.UserName | should be '<username>';
        $result.GetNetworkCredential().password | should be '<password>';
    }
}

Describe "CredentialManagerCredential Set-CredentialManagerCredenial.ps1 and Get-CredentialManagerCredenial.ps1" {
    It "Verify successful set and get using a credential" {
        [PSCredential]$credential=
            new-object -typename System.Management.Automation.PSCredential '<username>',('<password>' | ConvertTo-SecureString -force -AsPlainText);
        Set-CredentialManagerCredential $targetName $credential
        [PSCredential]$result=(Get-CredentialManagerCredential $targetName)
        $result.UserName | should be '<username>';
        $result.GetNetworkCredential().password | should be '<password>';
    }

    It "Verify successful set and get using username and password parameters" {
        Set-CredentialManagerCredential $targetName '<username>' '<password>'
        [PSCredential]$result=(Get-CredentialManagerCredential $targetName)
        $result.UserName | should be '<username>';
        $result.GetNetworkCredential().password | should be '<password>';
    }
}



