

Function Get-WindowsVersionName {
    $os = $null
    try {
        #Consider using Get-Command with -ErrorAction of Ignore
        $os = Get-CimInstance "Win32_OperatingSystem" #Not supported prior to Windows 8
    }
    catch {
        $os = Get-WmiObject Win32_OperatingSystem
    }

    #See http://gallery.technet.microsoft.com/scriptcenter/6e1b6724-3674-4487-b544-2706bfe0b0b5/view/Discussions#content
    switch -Wildcard ("$($os.Version + "-" + $os.ProductType)") 
    {
	    "5.1.2600-*" { $result = "Windows XP"; } #Untested
	    "5.1.3790-*" { $result = "Windows Server 2003"; } #Untested
	    "6.0.6001-1" { $result = "Windows Vista"; } #Untested
	    "6.1.7601-1" { $result = "Windows 7"; } 
	    "6.1.7601-3" { $result = "Windows Server 2008 R2"; }
	    "6.2.9200-1" { $result = "Windows 8"; }
	    "6.2.9200-3" { $result = "Windows Server 2012"; }
        "6.3.9600-1" { $result = "Windows 8.1" }
	    default { throw "Windows Version not Identified" }
    }
    return $result
}

