Set-StrictMode -Version "Latest"

Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.CredentialManager\IntelliTect.CredentialManager.psm1 -force

$targetName = 'tempCredentialManagerCredential.Test'

Describe "CredentialManagerCredenial Set and Get" {
    if (Get-IsWindowsPlatform) {
        It "Verify successful set and get using a credential" {
            Remove-CredentialManagerCredential $targetName -ErrorAction SilentlyContinue # Remove the credential if it already exists. 
            try {
                [PSCredential]$credential = `
                    new-object -typename System.Management.Automation.PSCredential '<username>', ('<password>' | ConvertTo-SecureString -force -AsPlainText);
                Set-CredentialManagerCredential $targetName $credential
                [PSCredential]$result = Get-CredentialManagerCredential $targetName
                $result.UserName | should be '<username>';
                $result.GetNetworkCredential().password | should be '<password>';
            }
            finally {
                Remove-CredentialManagerCredential $targetName -ErrorVariable E -ErrorAction SilentlyContinue
                $E | Should Be $null
            }
        }
    }
    else {
        It "Verify throws on non-Windows platforms" {
            { Get-CredentialManagerCredential "FOO" } | Should -Throw 'This cmdlet is not supported on non-Windows operating systems.'
            { Set-CredentialManagerCredential "FOO" $null } | Should -Throw 'This cmdlet is not supported on non-Windows operating systems.'
        }
    }
}



