$sut = ($PSCommandPath).Replace(".Tests", "")
. $sut

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
        
        $tempFile = (Join-path $env:TEMP (Split-Path $PSCommandPath -Leaf))
        Mock Get-Program {
            # Swapped 'C:\Program Files (x86)\WinDirStat\Uninstall.exe
            $windirStatRegistryCsv = @"
#TYPE System.Management.Automation.PSCustomObject
"UninstallString","InstallLocation","DisplayName","DisplayIcon","dwVersionMajor","dwVersionMinor","dwVersionRev","dwVersionBuild","URLInfoAbout","NoModify","NoRepair","PSPath","PSParentPath","PSChildName","PSDrive","PSProvider"
"""C:\Program Files (x86)\WinDirStat\Uninstall.exe""","C:\Program Files (x86)\WinDirStat","WinDirStat 1.1.2","C:\Program Files (x86)\WinDirStat\windirstat.exe,0","1","1","2","79","http://windirstat.info/","1","1","Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software
\Microsoft\Windows\CurrentVersion\Uninstall\WinDirStat","Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall","WinDirStat","HKCU","Microsoft.PowerShell.Core\Registry"
"@
            
            $windirStatRegistryCsv = $windirStatRegistryCsv -replace '""C:\\Program Files \(x86\)\\WinDirStat\\Uninstall.exe""',"c:\Windows\System32\xcopy.exe $PSCommandPath $(split-path $tempFile) /f /y"
            $regEntries = ($windirStatRegistryCsv | ConvertFrom-Csv)[0]
            return $regEntries 
        }
        It "Mock Uninstall Command" {
            Uninstall-Program "WinDirStat"

            Test-Path $tempFile | Should Be $True
            Remove-Item $tempFile
        }
        It "Mock Uninstall Command using Pipeline" {
            Get-Program "WinDirStat" | Uninstall-Program

            Test-Path $tempFile | Should Be $True
            Remove-Item $tempFile
        }
    }
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