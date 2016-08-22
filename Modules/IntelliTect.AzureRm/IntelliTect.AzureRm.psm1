function New-AzureRmVirtualMachine {
    <#
        .SYNOPSIS
        Creates a new Azure RM virtual machine
        .DESCRIPTION
        Creates a new virtual machine, and other resources if needed - Resource Group, Storage Account,
            Virtual Network, Public IP Address, Domain Name Label, Network Interface.
        Currently only 2 Windows 2012 server image SKUs are supported.
        .EXAMPLE
        New-AzureRmVirtualMachine -ResourceGroupName myvirtualmachines -VMName myvm -ImageSku '2012-Datacenter'
        .PARAMETER ResourceGroupName
        Resource group to create resources in.  Will be created if it doesn't exist.  REQUIRED
        .PARAMETER VMName
        Name of the virtual machine.  REQUIRED
        .PARAMETER ImageSku
        VM image to use.  REQUIRED
        .PARAMETER StorageAccountName
        Storage account to store VHD in.  Will be created if it doesn't exist.  DEFAULT: $ResourceGroupName
        .PARAMETER VMLocation
        Azure location for resources.  DEFAULT: "West US"
        .PARAMETER StorageAccountType
        What type of disks will be used.  DEFAULT: Standard_LRS
        .PARAMETER DomainNameLabel
        Domain name to point at your public IP address.  DEFAULT: none
        .PARAMETER VirtualNetworkName
        Name of virtual network.  Will be created if it doesn't exist.  DEFAULT: $ResourceGroupName
        .PARAMETER VMSize
        Size of Azure VM.  DEFAULT: Standard_DS1_v2
        .PARAMETER NetworkSecurityGroup
        Name of network security group.  Will be created, along with an Allow_RDP rule, if it doesn't exist.  DEFAULT: $ResourceGroupName
        .PARAMETER AdminCredentials
        PSCredential with username/password of admin account for new VM.
    #>
    [CmdletBinding()]    
	param ( 
        [Parameter(Mandatory)]
        [string]$VMName,

        [string]$ResourceGroupName=(Get-AzureRmResourceGroup | Out-GridView -Title "Select Azure Resource Group" -OutputMode Single),
      
		[Parameter(Mandatory)]
		[ValidateSet('2012-Datacenter', '2012-R2-Datacenter')]
		$ImageSku,
        
        [string]$StorageAccountName = "",
        [string]$VMLocation = "West US",
        [string]$StorageAccountType = "Standard_LRS",
        [string]$DomainNameLabel = "",
        [string]$VirtualNetworkName = "",
        [string]$VMSize = "Standard_DS1_v2",
        [string]$NetworkSecurityGroup = "",
        [PSCredential]$AdminCredentials = (Get-Credential -UserName vmadmin -Message "Enter the username and password of the admin account for the new VM")
	)

    $ErrorActionPreference = "Stop"
    Set-StrictMode -Version Latest

    Confirm-AzureRmSession
    
    # Defaults
    if ($VirtualNetworkName -eq "")
    {
        $VirtualNetworkName = $ResourceGroupName
    }

    if ($StorageAccountName -eq "")
    {
        $StorageAccountName = $ResourceGroupName
    }

    # Choices
    if ($VMSize -eq "choose") {
        $selectedSizes = Get-AzureRmVmSize -Location $VMLocation | Out-GridView -OutputMode Single
        if ($selectedSizes -eq $null) {
            throw 'When $VMSize == choose, you must choose a size to continue.'
        } else {
            $VMSize = $selectedSizes[0].Name
        }
    }

    # If the resource group doesn't exist, then create it
    $groups = Get-AzureRmResourceGroup | ? { $_.ResourceGroupName -eq $ResourceGroupName }
    if ($groups -eq $null)
    {
        Write-Information -MessageData "Creating new resource group" -InformationAction Continue
        $ignore1 = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $VMLocation
    }
    
    # If the storage account doesn't exist, then create it
    $accounts = Get-AzureRmStorageAccount | ? { $_.StorageAccountName -eq $StorageAccountName }
    if ($accounts -eq $null)
    {
        Write-Information -MessageData "Creating new storage account" -InformationAction Continue
        $ignore1 = New-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName –Type $StorageAccountType -Location $VMLocation
    }
    
    # If the virtual network doesn't exist, then create it
    $vns = Get-AzureRmVirtualNetwork | ? { $_.Name -eq $VirtualNetworkName }
    if ($vns -eq $null)
    {
        Write-Information -MessageData "Creating new virtual network" -InformationAction Continue
        $defaultSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name "defaultSubnet" -AddressPrefix "10.0.2.0/24"
        $ignore1 = New-AzureRmVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $ResourceGroupName -Location $VMLocation -AddressPrefix "10.0.0.0/16" -Subnet $defaultSubnet
    }
    
    # If a domain name label is supplied, then test that it isn't in use
    if ($DomainNameLabel -ne "")
    {
        $domainOk = Test-AzureRmDnsAvailability -DomainQualifiedName $DomainNameLabel -Location $VMLocation
        if ($domainOk -eq $false)
        {
            $message = "DomainNameLabel ($DomainNameLabel) failed when tested for uniqueness."
            Write-Information -MessageData $message -InformationAction Continue
            return @{
                Success = $false
                Message = $message
            }
        }
    }
    
    # Create, if needed, the network security group and add a default RDP rule
    $nsg = $null
    $securityGroupName = @{$true = $ResourceGroupName; $false = $NetworkSecurityGroup}[$NetworkSecurityGroup -eq '']
    if ($NetworkSecurityGroup -ne "")
    {
        $nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName | ? { $_.Name -eq $securityGroupName }   
    }
    if ($nsg -eq $null)
    {
        Write-Information -MessageData "Creating security group and rule" -InformationAction Continue
        $nsg = New-AzureRMNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $securityGroupName -Location $VMLocation
        $nsg | Add-AzureRmNetworkSecurityRuleConfig -Name 'Allow_RDP' -Priority 1000 -Protocol TCP -Access Allow -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Direction Inbound | Set-AzureRmNetworkSecurityGroup | Out-Null
    }

    # Create the public IP and NIC
    $vnet = Get-AzureRmVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $ResourceGroupName
    $ticks = (Get-Date).Ticks.ToString()
    $ticks = $ticks.Substring($ticks.Length - 5, 5)
    $nicName = "$ResourceGroupName$ticks"
    if ($DomainNameLabel -ne "")
    {
        Write-Information -MessageData "Creating new public IP address with domain name" -InformationAction Continue
        $pip = New-AzureRmPublicIpAddress -Name $nicName -ResourceGroupName $ResourceGroupName -DomainNameLabel $DomainNameLabel -Location $VMLocation -AllocationMethod Dynamic
    }
    else
    {
        Write-Information -MessageData "Creating new public IP address WITHOUT domain name" -InformationAction Continue
        $pip = New-AzureRmPublicIpAddress -Name $nicName -ResourceGroupName $ResourceGroupName -Location $VMLocation -AllocationMethod Dynamic
    }
    Write-Information -MessageData "Creating new network interface" -InformationAction Continue
    $nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -Location $VMLocation -PublicIpAddressId $pip.Id -SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $nsg.Id
    
    # Create the VM configuration
    Write-Information -MessageData "Creating VM configuration" -InformationAction Continue
    $vm = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
    
    # Add additional info to the configuration
    $vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $VMName -Credential $AdminCredentials -ProvisionVMAgent -EnableAutoUpdate
    $vm = Set-AzureRmVMSourceImage -VM $vm -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus $ImageSku -Version "latest"
    $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

    # Create the disk
    $diskName = "$($VMName)OSDisk"
    $storage = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    $osDisk = $storage.PrimaryEndpoints.Blob.ToString() + "vhds/" + $diskName  + ".vhd"
    $vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $osDisk -CreateOption fromImage

    # And finally create the VM itself
    Write-Information -MessageData "Creating the VM ... this will take some time ..." -InformationAction Continue
    New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $VMLocation -VM $vm

    return @{
        Success = $true
        Message = "VM created successfully"
    }
}

function Enable-RemotePowerShellOnAzureRmVm {
    # Much of the following script came from this blog post by Marcus Robinson
    # http://www.techdiction.com/2016/02/12/powershell-function-to-enable-winrm-over-https-on-an-azure-resource-manager-vm/

    <#
        .SYNOPSIS
        Remotely configures an Azure RM virtual machine to enable Powershell remoting.
        .DESCRIPTION
        Generates a script locally, then uploads it to blob storage, where it is then installed as a custom script extension and run on the VM.  
            Opens the appropriate port in the network security group rules.
        .EXAMPLE
        Enable-RemotePowerShellOnAzureRmVm -ResourceGroupName myvirtualmachines -VMName myvm
        .PARAMETER VMName
        Name of the virtual machine.  REQUIRED
        .PARAMETER ResourceGroupName
        Name of the resource group.  REQUIRED
        .PARAMETER DnsName
        Name of the computer that will be connecting.  Used in name of certificate and in WinRM listener.  DEFAULT: $env:ComputerName
        .PARAMETER SourceAddressPrefix
        Prefix of source IP addresses in network security group rule.  DEFAULT: *

    #>
    [CmdletBinding()]
    Param (
        [parameter(Mandatory=$true)]
        [String] $VMName,
          
        [parameter(Mandatory=$true)]
        [String] $ResourceGroupName,      

        [parameter()]
        [String] $DNSName = $env:COMPUTERNAME,
          
        [parameter()]
        [String] $SourceAddressPrefix = "*"
    ) 
    
    $scriptName = "ConfigureWinRM_HTTPS.ps1"
    $extensionName = "EnableWinRM_HTTPS"
    $blobContainer = "scripts"
    $securityRuleName = "WinRM_HTTPS"
    
    # define a temporary file in the users TEMP directory
    Write-Information -MessageData "Creating script locally that we'll upload to the storage account" -InformationAction Continue
    $file = $env:TEMP + "\" + $scriptName
      
    #Create the file containing the PowerShell
    {
        # POWERSHELL TO EXECUTE ON REMOTE SERVER BEGINS HERE
        param($DNSName)
        
        # Force all network locations that are Public to Private
        Get-NetConnectionProfile | ? { $_.NetworkCategory -eq "Public" } | % { Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private }
          
        # Ensure PS remoting is enabled, although this is enabled by default for Azure VMs
        Enable-PSRemoting -Force
        
        # Create rule in Windows Firewall, if it's not already there
        if ((Get-NetFirewallRule | ? { $_.Name -eq "WinRM HTTPS" }).Count -eq 0)
        {
            New-NetFirewallRule -Name "WinRM HTTPS" -DisplayName "WinRM HTTPS" -Enabled True -Profile Any -Direction Inbound -Action Allow -LocalPort 5986 -Protocol TCP
        }
          
        # Create Self Signed certificate and store thumbprint, if it doesn't already exist
        $thumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | ? { $_.Subject -eq "CN=$DNSName" } | Select -First 1).Thumbprint
        if ($thumbprint -eq $null)
        {
            $thumbprint = (New-SelfSignedCertificate -DnsName $DNSName -CertStoreLocation Cert:\LocalMachine\My).Thumbprint
        }
          
        # Run WinRM configuration on command line. DNS name set to computer hostname, you may wish to use a FQDN
        $cmd = "winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=""$DNSName""; CertificateThumbprint=""$thumbprint""}"
        cmd.exe /C $cmd
          
        # POWERSHELL TO EXECUTE ON REMOTE SERVER ENDS HERE
    }  | out-file -width 1000 $file -force
    
      
    # Get the VM we need to configure
    Write-Information -MessageData "Getting information needed to find and update the blob storage with the new script" -InformationAction Continue
    $vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName
    
    # Get storage account name
    $storageaccountname = $vm.StorageProfile.OsDisk.Vhd.Uri.Split('.')[0].Replace('https://','')
      
    # get storage account key
    $key = (Get-AzureRmStorageAccountKey -Name $storageaccountname -ResourceGroupName $ResourceGroupName).Key1
      
    # create storage context
    $storagecontext = New-AzureStorageContext -StorageAccountName $storageaccountname -StorageAccountKey $key
      
    # create a container called scripts
    if ((Get-AzureStorageContainer -Context $storagecontext | ? { $_.Name -eq $blobContainer}).Count -eq 0)
    {
        $ignore1 = New-AzureStorageContainer -Name $blobContainer -Context $storagecontext
    }
      
    #upload the file
    $ignore1 = Set-AzureStorageBlobContent -Container $blobContainer -File $file -Blob $scriptName -Context $storagecontext -force
    
    # Create custom script extension from uploaded file
    Write-Information -MessageData "Create and run a script extension from our uploaded script" -InformationAction Continue
    $ignore1 = Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name $extensionName -Location $vm.Location -StorageAccountName $storageaccountname -StorageAccountKey $key -FileName $scriptName -ContainerName $blobContainer -RunFile $scriptName -Argument $DNSName
      
    # Get the name of the first NIC in the VM
    Write-Information -MessageData "Create a new security rule that will allow us to connect remotely" -InformationAction Continue
    $nic = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name (Get-AzureRmResource -ResourceId $vm.NetworkInterfaceIDs[0]).ResourceName
    
    # Get the network security group attached to the NIC
    $nsg = Get-AzureRmNetworkSecurityGroup  -ResourceGroupName $ResourceGroupName  -Name (Get-AzureRmResource -ResourceId $nic.NetworkSecurityGroup.Id).Name 
        
    # Add the new NSG rule, and update the NSG
    $nsg | Add-AzureRmNetworkSecurityRuleConfig -Name $securityRuleName -Priority 1100 -Protocol TCP -Access Allow -SourceAddressPrefix $SourceAddressPrefix -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 5986 -Direction Inbound   | Set-AzureRmNetworkSecurityGroup
    
    # get the NIC public IP
    $ip = Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Name (Get-AzureRmResource -ResourceId $nic.IpConfigurations[0].PublicIpAddress.Id).ResourceName 
    
    Write-Host "To connect to the VM using the IP address while bypassing certificate checks use the following command:" -ForegroundColor Green
    Write-Host "Enter-PSSession -ComputerName " $ip.IpAddress  " -Credential <admin_username> -UseSSL -SessionOption (New-PsSessionOption -SkipCACheck -SkipCNCheck)" -ForegroundColor Green
}

function Confirm-AzureRmSession {
    <#
        .SYNOPSIS 
        Confirm Azure RM session exists.
        .DESCRIPTION
        Confirms an Azure RM session exists by checking for Get-AzureRmContext.  Prompts the user to sign in if it doesn't.
        .EXAMPLE
        Confirm-AzureRmSession
    #>

    try {
        Get-AzureRmContext -ErrorAction SilentlyContinue 
    }
    catch {
            Login-AzureRmAccount | Out-Null
    }
}
