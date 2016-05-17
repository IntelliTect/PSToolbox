function Confirm-AzureRmSession {
    <#
        .SYNOPSIS
        Confirm Azure RM session exists.
        .DESCRIPTION
        Confirms an Azure RM session exists by checking for Get-AzureRmContext.  Prompts the user to sign in if it doesn't.
        .EXAMPLE
        Confirm-AzureRmSession
    #>

    $Error.Clear();
    $currentErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    $context = Get-AzureRmContext
    if ($context -eq $null) {
        Login-AzureRmAccount | Out-Null
    }
    $Error.Clear()
    $ErrorActionPreference = $currentErrorAction
}

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
        PSCredential with username/password of admin account for new VM.  DEFAULT: vmadmin / P@ssword1!

    #>
    [CmdletBinding()]    
	param (
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory)]
        [string]$VMName,
      
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
        [PSCredential]$AdminCredentials = (New-Object PSCredential("vmadmin", ("P@ssword1!" | ConvertTo-SecureString -AsPlainText -Force)))
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
