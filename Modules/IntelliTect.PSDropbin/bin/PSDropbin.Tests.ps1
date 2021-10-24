
if(!(Test-Path variable:PsDropbinTesting)) {
    try {
        $sessionName = "$PSCommandPath Session"
        $testSession = New-PSSession -Name $sessionName -SessionOption (New-PSSessionOption -NoMachineProfile) -EnableNetworkAccess

        Context "Invoking a new session" {
            Invoke-Command -Session $testSession -ArgumentList $PSCommandPath -ScriptBlock { 
                param($PSCommandPath)
                New-Variable PSDropbinTesting -Scope Global -Value $True -Visibility Public
                Import-Module Pester
                Invoke-Pester $PSCommandPath;
            }; 
        }
    }
    finally {
         if(Test-Path variable:testSession) {
            remove-PSSession $testSession;
         }
    }
    return;
}
else {
    $sut = $PSCommandPath.Replace(".Tests", "").Replace(".ps1", ".psd1");
    #Write-Output "`$PSCommandPath = '$PSCommandPath'"
    #Write-Output "`$sut = '$sut'"
    Try {
        $dropbinModule = Import-Module $sut -Verbose -PassThru
        $originalLocation = Get-Location

        Describe "PSDropbin" {
            It "Does the PSDropbin module load successfully" {    
                $dropboxProvider = (Get-PSProvider Dropbox)
                Write-Debug $dropboxProvider
                if($dropboxProvider -eq $null) { throw "Not yet loaded" };
                Get-PSDrive Drpbx | Should Be "Drpbx"
            } 
            It "Try Test-Path and Set-Location on the default drive's Public folder" {    
                #$dropbox = New-PSDrive -PSProvider Dropbox -Name Drpbx -Root "/" -ErrorAction Stop
                Test-Path "Drpbx:\Public" | Should Be $true
                Set-Location "Drpbx:\Public"
                $pwd | should be "Drpbx:\Public"
            } 
            It "Try Test-Path and Set-Location on the default drives root folder" {    
                Test-Path "Drpbx:\" | Should Be $true
                Set-Location "Drpbx:\"
                $pwd | should be "Drpbx:\"
            } 
            It "Verify Set-Location works on the root of a Dropbin drive." { 
                Try {   
                    $dropbox = New-PSDrive -PSProvider Dropbox -Name DrpbxTemp -Root "/"
                    $currentPath = $pwd;
          		    Set-Location DrpbxTemp:\ | should not throw
         		    $pwd | should be "DrpbxTemp:\"
                }
                Finally {
                    if($dropbox) {
                        Set-Location $currentPath;
                        Remove-PSDrive $dropbox;
                    }
                }
            } 
         	It "Verify test-path returns false for non-existen path." {    
            	$doesExist = Test-Path "drpbx:\ThisPathDoesNotExist"
                $doesExist | Should Be $false
            }
         	It "Verify test-path returns true for existing path." {    
            	$doesExist = Test-Path "drpbx:\Public"
                $doesExist | Should Be $true
            }
        }
    }
    Finally {
        If($dropbinModule) {
            Set-Location $originalLocation
            Remove-Module $dropbinModule
        }
    }
}