$here = $PSScriptRoot
$sut = $PSCommandPath.Replace('.Tests', '')
. $sut


Describe "Get-GoogleSessionVariable" {
    It "Gets a WebRequestSession with Google session cookies" {
        $session = Get-GoogleSessionVariable intellitectpowershelltests@gmail.com pstestaccount
        $sidCookie = ($session.Cookies.GetCookies("http://www.google.com") | where {$_.Name -eq "SID"}).Value

        # Check that the SID cookie is at least 50 characters.
        # One I used while testing was 71 characters, so 50 should be a safe minimum.
        $sidCookie | Should Match ".{50,}"
    }
}

Describe "Get-GoogleLocationHistoryKmlFile" {
    It "Gets a kml file" {
        $session = Get-GoogleSessionVariable intellitectpowershelltests@gmail.com pstestaccount

        $request = Get-GoogleLocationHistoryKmlFile $session 2016-05-01 'test.kml'
        
        'test.kml' | Should Contain "http://www.opengis.net/kml/"
    }
}

