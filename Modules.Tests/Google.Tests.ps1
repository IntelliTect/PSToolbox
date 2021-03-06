
BeforeAll{
    Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.CredentialManager
    Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common
    
    Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Google -Force
    
    Function Get-TestCredential {
        $credentialName = "IntelliTect.Google.Tests"
    
        [PSCredential]$credential = Get-CredentialManagerCredential $credentialName -ErrorAction SilentlyContinue
        if ($credential -eq $null) {
            # Future versions (post 3.0) of Pester include 'Set-TestInconclusive' that should be used here.
            # For now, we just throw an error to discontinue the test while providing instructions on how to correctly configure the test.
            Write-Warning -Message "Couldn't find a credential named $credentialName. Add it using 'Set-CredentialManagerCredential $credentialName'. You will be prompted for a Google email account and password, which will be stored in the Windows credential manager."
        }
        return $credential
    }
}


# Describe "Get-GoogleSessionVariable" {
#     if (Get-IsWindowsPlatform) {
#         It "Gets a WebRequestSession with Google session cookies" {
#             $credential = Get-TestCredential

#             $session = Get-GoogleSession $credential
#             $sidCookie = ($session.Cookies.GetCookies("https://www.google.com") | where {$_.Name -eq "SID"}).Value

#             # Check that the SID cookie is at least 50 characters.
#             # One I used while testing was 71 characters, so 50 should be a safe minimum.
#             $sidCookie | Should Match ".{50,}"
#         }
#     }
#     else {
#         It "Verify throws on non-Windows platforms" {
#             { Get-TestCredential } | Should -Throw 'This cmdlet is not supported on non-Windows operating systems.'
#         }
#     }
# }

# Describe "Get-GoogleLocationHistoryKmlFile" {
#     if (Get-IsWindowsPlatform) {
#         It "Gets a kml file" {
#             $credential = Get-TestCredential

#             $session = Get-GoogleSession $credential

#             $outFile = Get-TempItemPath
#             $request = Get-GoogleLocationHistoryKmlFile $session 2016-05-01 -outFile $outFile

#             $outFile | Should Contain "http://www.opengis.net/kml/"

#             # cleanup
#             Get-Item $outFile | Remove-Item
#             Test-Path $outFile | Should Be $false
#         }
#     }
#     else {
#         It "Verify throws on non-Windows platforms" {
#             { Get-TestCredential } | Should -Throw 'This cmdlet is not supported on non-Windows operating systems.'
#         }
#     }
# }

