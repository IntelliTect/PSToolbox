$sut = ($PSCommandPath).Replace(".Tests", "")
. $sut

Describe "Get-Program" {
    Function Mock-GetCimInstance {
        return [PSCustomObject]@{ Version = "6.3.9600";ProductType  = "1"}
    }
    try { 
        $os = Get-CimInstance "Win32_OperatingSystem" 
        if("$($os.Version + "-" + $os.ProductType)" -ne "6.3.9600-1") {
            Mock Get-CimInstance { return Mock-GetCimInstance }
        }
    } 
    catch { 
            Mock Get-CimInstance { return Mock-GetCimInstance }
    }


    It "Windows 8.1" {
        Get-WindowsVersionName | Should Be "Windows 8.1"
    }
    
    $os=Get-WmiObject Win32_OperatingSystem
    if("$($os.Version + "-" + $os.ProductType)" -ne "6.1.7601-1") {
        Mock Get-CimInstance { 
            #Run unknonwn command
            Unknown-Command
        }
        Mock Get-WmiObject {
            return [PSCustomObject]@{
                Version = "6.1.7601"
                ProductType  = "1"
            }
        }
    }
    It "Windows 7" {
        Get-WindowsVersionName | Should Be "Windows 7"
    }
}