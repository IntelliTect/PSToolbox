




Function Get-Device {
    Get-WmiObject Win32_USBControllerDevice |%{[wmi]($_.Dependent)} |
        Sort Manufacturer,Description,DeviceID |
        Ft -GroupBy Manufacturer Description,Service,DeviceID
        #Get-WmiObject -query "select * from Win32_SerialPort" 
}