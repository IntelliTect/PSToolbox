$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

Describe "Get-CurrentUserModuleDirectory" {
    It "Get-CurrentUserModuleDirectory returns [Documents]\WindowsPowerShell\Modules\" {
        $actual = Get-CurrentUserModuleDirectory
        $expected = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Modules"
        $actual | Should Be $expected
    }
}

Describe "Install-NugetPSModule" {
    It "Install a module from a local file URL" {
        #Verify module folder for the module is created in Documents\WindowsPowerShell\Modules
        #Verify psm1 corresponding to the module name is created.
        #Import the module (presumably so it is available without restarting PowerShell)
        #Create a new session and verify the module gets loaded.
        Throw "Test not yet implemented"
    }
    It "Install a module from a http url (perhaps just file:\\...?)" {
        #Verify module folder for the module is created in Documents\WindowsPowerShell\Modules
        #Verify psm1 corresponding to the module name is created.
        #Import the module (presumably so it is available without restarting PowerShell)
        #Create a new session and verify the module gets loaded.
        Throw "Test not yet implemented"
    }
}