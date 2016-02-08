
$sut = ($PSCommandPath).Replace(".Tests", "")
. $sut
$mockUninstallCommand = "c:\Windows\System32\robocopy.exe $(Split-Path $sut) `"$tempFile`" $(Split-Path $sut -Leaf)"

Describe "Get-Program" {
    $programFilter = "Microsoft *"
    if(!($global:ProgramPS1_programListFromWmi)) {
        Write-Host "`tGet list of installed programs via WMI (to verify Get-Program functionality against)..."
        $global:ProgramPS1_programListFromWmi = Get-ProgramUsingWmi $programFilter # use global and cache as this function takes a long time to run
    }

    It "Find first Microsoft program with exact match" {
        
        $expectedProgram = $global:ProgramPS1_programListFromWmi | 
            Select-Object -first 1 -ExpandProperty Name
            
        $actual = Get-Program $expectedProgram

        $actual.DisplayName | Should Be $expectedProgram
    }
    It "Find all Microsoft Programs" {
        $expectedNames = ( $global:ProgramPS1_programListFromWmi).Name
            
        $actual = Get-Program $programFilter
            
        ($actual.Count -ge $expectedNames.Count) | Should Be $true # The registry approach could quite possibly return more items. TODO - Investigate
    }
}

Describe "Split-CommandLine" {
    Function Test-SplitCommandLine([string]$exePath, [string]$arguments) {
        $result = Split-CommandLine "$exePath $arguments" -Debug
        $result.ExePath | Should Be $exePath
        If(![string]::IsNullOrWhiteSpace($arguments)) {$result.Arguments.Trim() | Should Be $arguments}
    }
    
    It "A variety of explicit command lines" {
        Test-SplitCommandLine "C:\Program Files (x86)\NortonInstaller\{0C55C096-0F1D-4F28-AAA2-85EF591126E7}\NIS\A5E82D02\20.5.0.28\InstStub.exe" "/X /ARP"
        Test-SplitCommandLine "C:\Program Files (x86)\NortonInstaller\{0C55C096-0F1D-4F28-AAA2-85EF591126E7}\NIS\A5E82D02\20.5.0.28\InstStub.exe" "-X -ARP"
        Test-SplitCommandLine "`"C:\Program Files (x86)\NortonInstaller\{0C55C096-0F1D-4F28-AAA2-85EF591126E7}\NIS\A5E82D02\20.5.0.28\InstStub.exe`"" "-X -ARP"
        Test-SplitCommandLine "`'C:\Program Files (x86)\NortonInstaller\{0C55C096-0F1D-4F28-AAA2-85EF591126E7}\NIS\A5E82D02\20.5.0.28\InstStub.exe`'" "-X -ARP"
    }
    
    It "Command line with no arguments" {
        Test-SplitCommandLine "C:\Program Files (x86)\NortonInstaller\{0C55C096-0F1D-4F28-AAA2-85EF591126E7}\NIS\A5E82D02\20.5.0.28\InstStub.exe" ""
    }

    It "Split-CommandLine with rundll32.exe" {
        Test-SplitCommandLine "rundll32.exe" "C:\PROGRA~1\DIFX\048B92BA3327CEF8\DIFxAppA.dll, DIFxARPUninstallDriverPackage C:\WINDOWS\System32\DriverStore\FileRepository\grmnusb.inf_amd64_d77b1dda68556870\grmnusb.inf"

    }

    Function Test-SplitCommandLineWithMsiExec() {
           get-program | ?{ $_.UninstallString -and !($_.UninstallString -like "MsiExec*") } | Select-Object -ExpandProperty uninstallstring | 
           %{ 
                $result = (Split-CommandLine $_);
                $exePath = $result.ExePath.Trim();
                $arguments = if($result.Arguments){$result.Arguments.Trim()}
                $parsedCommandLine =  ($exePath,$arguments -join " ").Trim()
                #Using replace "  /" below to handle the one case (OneDrive), where there are two spaces before the arguments.
                if($parsedCommandLine -ne $_.Trim().Replace("  /", " /") ) {
                    #Compare-Object "`"$parsedCommandLine`'" "`'$_`'"
                    "$parsedCommandLine" | Should Be $_ 
                }
           }
    }

    It "Test all uninstall strings on the computer for successful parsing" {
        Test-SplitCommandLineWithMsiExec
    }
}

Describe "Uninstall-Program" {
    Context "Mock Invoke-Uninstall" {
        Mock Invoke-Uninstall { 
            $uninstallString = $args[0]
            Write-Verbose "Invoke-Expression $uninstallString" 
        }
        It "Mock uninstall the first program" {
            $Program = Get-Program "Microsoft Office Professional *" | Select -First 1
            Uninstall-Program $Program.Name

            Assert-MockCalled Invoke-Uninstall
        } 
    }
    Context "Invalid uninstall requests" {
        It "Given an invalid type an exception will be thrown" {
            { Uninstall-Program ([PSCustomObject] 1) } | Should Throw
        }
        It "Given non-existent program an error will be thrown" {
            { Uninstall-Program "does not exist" } | Should Throw
        }
    }
    Context "Mock Registry Setting for Windirstat" {
        $tempFile = [io.path]::GetTempFileName()
        Mock Get-Program {
            if(Test-Path $tempFile) {
                # It could possibly exist because the same temp file is used throughout.
                Remove-Item $tempFile -Recurse
            }
            # Swapped 'C:\Program Files (x86)\WinDirStat\Uninstall.exe
            $registryCsv = @"
#TYPE System.Management.Automation.PSCustomObject
"UninstallString","InstallLocation","DisplayName","DisplayIcon","dwVersionMajor","dwVersionMinor","dwVersionRev","dwVersionBuild","URLInfoAbout","NoModify","NoRepair","PSPath","PSParentPath","PSChildName","PSDrive","PSProvider"
"""C:\Program Files (x86)\WinDirStat\Uninstall.exe""","C:\Program Files (x86)\WinDirStat","WinDirStat 1.1.2","C:\Program Files (x86)\WinDirStat\windirstat.exe,0","1","1","2","79","http://windirstat.info/","1","1","Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software
\Microsoft\Windows\CurrentVersion\Uninstall\WinDirStat","Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall","WinDirStat","HKCU","Microsoft.PowerShell.Core\Registry"
"@
            $mockUninstallCommand = "c:\Windows\System32\robocopy.exe $(Split-Path $sut) `"$tempFile`" $(Split-Path $sut -Leaf)"    
            $regEntries = ($registryCsv | ConvertFrom-Csv)[0]
            $regEntries.UninstallString = $mockUninstallCommand
            return $regEntries 
        }
        It "Mock Uninstall Command" {
            Uninstall-Program "WinDirStat"

            Test-Path $tempFile | Should Be $True
            Remove-Item $tempFile -Recurse
        }
        It "Mock Uninstall Command using Pipeline" {
            Get-Program "WinDirStat" | Uninstall-Program

            Test-Path $tempFile | Should Be $True
            Remove-Item $tempFile -Recurse
        }
    }
        Context "Mock Registry Setting for Norton Internet Security" {
        
        $tempFile = [io.path]::GetTempFileName()
        Mock Get-Program {
            # Swapped 'C:\Program Files (x86)\WinDirStat\Uninstall.exe
            $registryCsv = @"
#TYPE Selected.System.Management.Automation.PSCustomObject
"InstallLocation","UninstallString","DisplayIcon","VersionMajor","VersionMinor","DisplayVersion","InstallDate","URLInfoAbout","DisplayName","Publisher","InstallSource","InstallFileName","PSPath","PSParentPath","PSChildName","PSProvider","Name"
"C:\Program Files (x86)\Norton Internet Security","C:\Program Files (x86)\NortonInstaller\{0C55C096-0F1D-4F28-AAA2-85EF591126E7}\NIS\A5E82D02\20.5.0.28\InstStub.exe /X /ARP","C:\Program Files (x86)\NortonInstaller\{0C55C096-0F1D-4F28-AAA2-85EF591126E7}\NIS\A5E82D02\20.5.0.28\InstStub.exe,0","20","5","20.5.0.28","20140201","http://www.symantec.com/techsupp/","Norton Internet Security","Symantec Corporation","C:\Users\Administrator\AppData\Local\Temp\7zS8C38.tmp\","C:\Users\Administrator\AppData\Local\Temp\7zS8C38.tmp\Setup.exe","Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\NIS","Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall","NIS","Microsoft.PowerShell.Core\Registry","Norton Internet Security"
"@
            
            $regEntries = ($registryCsv | ConvertFrom-Csv)[0]
            $regEntries.UninstallString = $mockUninstallCommand
            return $regEntries 
        }#>
        It "Mock Uninstall Command using Pipeline" {
            Get-Program "Norton Internet Security" | Uninstall-Program

            Test-Path $tempFile | Should Be $True
            Remove-Item $tempFile -Recurse
        }
    }

}


Describe "Get-FileAssociation" {
    It "Get-FileAssociation for .txt" {
        $result =  Get-FileAssociation ".txt"
        $result.Name | Should Be "Text Document"
        $result.FileType | Should Be "txtfile"
        $result.Extension | Should Be ".txt"
        $result.Command | Should Be "%SystemRoot%\system32\NOTEPAD.EXE %1"
    }
    It "Get-FileAssociation for txt (no '.' prefix)" {
        $result =  Get-FileAssociation "txt"
        $result.Name | Should Be "Text Document"
        $result.FileType | Should Be "txtfile"
        $result.Extension | Should Be ".txt"
        $result.Command | Should Be "%SystemRoot%\system32\NOTEPAD.EXE %1"
    }

    It "Get-FileAssociation with missing extension errors out" {
        {Get-FileAssociation ".MissingExtension" } | Should Throw
    }

    It "Get-FileAssociation with missing extension and -ErrorAction Ignore won't error out" {
        Get-FileAssociation ".MissingExtension" -ErrorAction Ignore
    }
    

    if(((Get-Random) % 3) -eq 0) {
        It "Get-FileAssociation t*" {
            $result = Get-FileAssociation "t*"
            $result.Count -gt 1 | Should Be $true # Presumably there are more than two extensions that start with t*
        }
    }
    else { Write-Host -ForegroundColor Gray "[+]   Ignoring long running test, 'Get-FileAssociation t*', as it is only executed occasionally" }

    if(((Get-Random) % 9) -eq 0) {
        Write-Host  "Executing long running test...."
        It "Get-FileAssociation for all entries" {
        #Only run occasionally since it is so slow

            $result = Get-FileAssociation
            $result.Count -gt 100 | Should Be $true # Presumably there are more than 100 extensions registered.
        }
    }
    else { Write-Host -ForegroundColor Gray "[+]   Ignoring long running test, 'Get-FileAssociation for all entries', as it is only executed occasionally" }
}





    <#     Mock Get-ProgramRegistryKeys {
        $windirStatRegistryCsv = @"
#TYPE System.Management.Automation.PSCustomObject
"UninstallString","InstallLocation","DisplayName","DisplayIcon","dwVersionMajor","dwVersionMinor","dwVersionRev","dwVersionBuild","URLInfoAbout","NoModify","NoRepair","PSPath","PSParentPath","PSChildName","PSDrive","PSProvider"
"""C:\Program Files (x86)\WinDirStat\Uninstall.exe""","C:\Program Files (x86)\WinDirStat","WinDirStat 1.1.2","C:\Program Files (x86)\WinDirStat\windirstat.exe,0","1","1","2","79","http://windirstat.info/","1","1","Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software
\Microsoft\Windows\CurrentVersion\Uninstall\WinDirStat","Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall","WinDirStat","HKCU","Microsoft.PowerShell.Core\Registry"
"@
            $regEntries = ($windirStatRegistryCsv | ConvertFrom-Csv)[0]
            New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\MockWinDirStat"
            foreach( $item in $regEntries.psobject.Properties) {
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\MockWinDirStat" -Name $item.Name -Value $item.Value
            }
            return "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\MockWinDirStat"
        } #>