$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

Describe "New-HostsFileEntry" {
    It "Parse Normal line" {
        $result = New-HostsFileEntry "127.0.0.1`ttemp.local";
        $result.IPAddress | Should Be "127.0.0.1"
        $result.DnsName | Should Be "temp.local"
        $result.Comment | Should Be "" # ToDo: Why is this not $null?
        $result.IsCommentedOut | Should Be $false
    }
    It "Parse Commented out entry line" {
        $result = New-HostsFileEntry "#127.0.0.1`ttemp.local";
        $result.IPAddress | Should Be "127.0.0.1"
        $result.DnsName | Should Be "temp.local"
        $result.Comment | Should Be "" # ToDo: Why is this not $null?
        $result.IsCommentedOut | Should Be $true
    }
    It "Parse entry with trailing comment" {
        $result = New-HostsFileEntry "127.0.0.1`ttemp.local # Comment";
        $result.IPAddress | Should Be "127.0.0.1"
        $result.DnsName | Should Be "temp.local"
        $result.Comment | Should Be "Comment" # ToDo: Why is this not $null?
        $result.IsCommentedOut | Should Be $false
    }
    It "Parse blank line" {
        New-HostsFileEntry "" | Should Be $null
    }
    It "Parse null" {
        New-HostsFileEntry $null | Should Be $null
    }
    It "Parse whitespace" {
        New-HostsFileEntry "`t" | Should Be $null
    }
}


Describe "Get-HostsFileEntry" {
    Context "Using a fake HOSTS file" {
        $mockHostsFilePath = [IO.Path]::GetTempFileName();
        Get-Content (Get-HostsFilePath) | Select -First 100 | Set-Content $mockHostsFilePath
        Add-HostsFileEntry "127.0.0.1" "localhost" 
        Mock Get-HostsFilePath { return $mockHostsFilePath; }
        It "Find an existing entry using IP address" {
            $result = Get-HostsFileEntry 127.0.0.1 | select -First 1
            $result.IPAddress | Should Be 127.0.0.1
            $result.DnsName | Should Be "localhost"
            $result.ToString() | Should Be "localhost(127.0.0.1)"
        }
        It "Find an existing entry using DNS Name" {
            $result = Get-HostsFileEntry localhost | select -First 1
            $result.IPAddress | Should Be 127.0.0.1
            $result.DnsName | Should Be "localhost"
            $result.ToString() | Should Be "localhost(127.0.0.1)"
        }
        It "Verify There is no entry" {
            $result = Get-HostsFileEntry "NoSuchEntry.local"
            $result | Should Be $null
        }
    }
}


Describe "Add-HostFileEntry" {
    Context "Using a fake HOSTS file" {
        $mockHostsFilePath = [IO.Path]::GetTempFileName();
        Get-Content (Get-HostsFilePath) | Select -First 100 | Set-Content $mockHostsFilePath
        Mock Get-HostsFilePath { return $mockHostsFilePath; }

        It "Entry already added" {
            $result = Add-HostsFileEntry "127.0.0.1" "localhost" $true -confirm:$false
            $result | Should Be $null
        }
        It "Add new entry" {
            Add-HostsFileEntry "10.99.99.99" "nowhere1.local" $true -confirm:$false
            [IntelliTect.Net.HostsFileEntry] $result = Get-HostsFileEntry "nowhere1.local" 
            $result | Should Not Be $null
            $result.IPAddress | Should Be "10.99.99.99"
            $result.DnsName | Should Be "nowhere1.local"
        }
        It "Add new entry with PassThru" {
            [IntelliTect.Net.HostsFileEntry] $result = Add-HostsFileEntry "10.99.99.99" "nowhere.local" -PassThru
            $result | Should Not Be $null
            $result.IPAddress | Should Be "10.99.99.99"
            $result.DnsName | Should Be "nowhere.local"
        }
        #TODO: Test -confirm
    }
}

Describe "Remove-HostsFileEntry" {
    Context "Using a fake HOSTS file" {
        $mockHostsFilePath = [IO.Path]::GetTempFileName();
        Get-Content (Get-HostsFilePath) | Select -First 100 | Set-Content $mockHostsFilePath
        Mock Get-HostsFilePath { return $mockHostsFilePath; }
        It "Remove existing entry" {
            Get-HostsFileEntry "nowhere.local" | Should Not Be $null
            Remove-HostsFileEntry -DnsName "nowhere.local"
            Get-HostsFileEntry "nowhere.local" | Should Be $null 
        }
        #ToDo: Test -confirm
    }
}