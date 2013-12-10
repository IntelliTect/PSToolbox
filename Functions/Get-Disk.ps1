If(!(get-module Storage -ListAvailable)) {
    function Get-Disk {
        Get-wmiObject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername localhost `
            | Select  DeviceID, `
                      VolumeName, `
                      Description, `
                      FileSystem, `
                      @{Name="SizeGB";Expression={($_.Size / 1GB).ToString("f3")}}, `
                      @{Name="FreeGB";Expression={($_.FreeSpace / 1GB).ToString("f3")}} `
            | Format-Table -AutoSize
    }
}

Set-Alias df Get-Disk