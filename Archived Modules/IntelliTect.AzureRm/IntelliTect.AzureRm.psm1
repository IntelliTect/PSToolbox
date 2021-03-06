﻿function New-AzureRmVirtualMachine {
    <#
        .SYNOPSIS
        Creates a new Azure RM virtual machine
        .DESCRIPTION
        Creates a new virtual machine, and other resources if needed - Resource Group, Storage Account,
            Virtual Network, Public IP Address, Domain Name Label, Network Interface.
        Defaults can be set for inputs by using Set-AzureRmDefault.
        .EXAMPLE
        New-AzureRmVirtualMachine -VMName myVmName
        .EXAMPLE
        New-AzureRmVirtualMachine -VMName myVmName -ResourceGroupName newResourceGroup -DomainNameLabel mydomain
        .PARAMETER VMName
        Name of the virtual machine.  REQUIRED
        .PARAMETER Inputs
        When scripting menu inputs can be provided.
        $inputs = New-AzureRmVmInputs
        $inputs.Location = "westus""
        $inputs.SubscriptionId = "<subscription id>"
        ...
        New-AzureRmVirtualMachine -VMName myVmName -Inputs $inputs
        .PARAMETER ResourceGroupName
        Resource group to create resources in.  DEFAULT: none
        - If creating a new resource group it must be specified in the parameter.  
        - If not specified you can only choose from existing resource groups.
        - Can specify a default with Set-AzureRmDefault -ResourceGroupName <resourcegroupname>
        .PARAMETER VirtualNetworkName
        Name of virtual network.  Will be created if it doesn't exist.  DEFAULT: $ResourceGroupName
        - Can specify a default with Set-AzureRmDefault -VirtualNetworkName <virtualnetworkname>
        .PARAMETER DomainNameLabel
        Domain name to point at your public IP address.  DEFAULT: none
        - If a domain name is desired then it must be specified on the command line

        .NOTES
        Default values can be specified for:
            Location
            ResourceGroupName
            SubscriptionId
            VMImagePublisher
            VMImageOffer
            VMImageSku
            StorageAccountType
            VMSize
            OperatingSystem
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VmName,

        [AzureRmVmInputs]$Inputs = (New-Object AzureRmVmInputs),

        [string]$ResourceGroupName = $null,

        [string]$VirtualNetworkName = $null,

        [string]$DomainNameLabel = "",

        # Implementing our own -whatif and -confirm
        # Not all of the calls to Azure implement these switches, plus so much of
        #   the script is dependent on return values from previous commands 
        [switch]$WhatIf,
        [switch]$Confirm
    )
    Set-StrictMode -Version Latest

    $context = Assert-AzureRmSession

    # Process overrides from command line
    if ($ResourceGroupName) { $Inputs.ResourceGroupName = $ResourceGroupName }
    if ($VirtualNetworkName) { $Inputs.VirtualNetworkName = $VirtualNetworkName }
    $Inputs.DomainNameLabel = $DomainNameLabel

    # Choose a subscription ... and switch context to it if different than current
    Get-AzureRmSubscriptionMenu $Inputs | Out-Null
    if ($context.Subscription.SubscriptionId -ne $Inputs.SubscriptionId) {
        if (!(Confirm-ScriptShouldContinue $Confirm "Continuing will change your current Azure context to the selected subscription.")) { return }

        Write-Information "Switching Azure context to selected subscription ..." -InformationAction Continue
        Set-AzureRmContext -SubscriptionId $Inputs.SubscriptionId | Out-Null
    }

    # Choose a resource group
    Write-Information "Retrieving resource groups ..." -InformationAction Continue    
    $resourceGroups = {Get-AzureRmResourceGroup -WarningAction SilentlyContinue | Sort-Object ResourceGroupName | `
                            Select-Object -ExpandProperty ResourceGroupName}
    Get-InputFromMenu $Inputs "ResourceGroupName" "Select Resource Group" $resourceGroups $null $null $true
    if (!$Inputs.ResourceGroupName) { return }

    # Choose an image sku
    Get-AzureRmVmImageSkuMenu $Inputs | Out-Null

    # And a VM size
    Get-AzureRmVmSizeMenu $Inputs | Out-Null

    # Choose a storage account
    Write-Information "Retrieving storage accounts ..." -InformationAction Continue    
    $storageAccounts = {Get-AzureRmStorageAccount | Where-Object { $_.ResourceGroupName -eq $Inputs.ResourceGroupName } | `
                        Sort-Object StorageAccountName | Select-Object -ExpandProperty StorageAccountName}
    $defaultStorageAccountName = $Inputs.ResourceGroupName.ToLower() -Replace "[^0-9a-z]", ""
    $defaultStorageAccountName += (Get-Date).Ticks
    $defaultStorageAccountName = $defaultStorageAccountName.Substring(0, [System.Math]::Min(24, $defaultStorageAccountName.Length))
    Get-InputFromMenu $Inputs "StorageAccountName" "Select Storage Account" $storageAccounts $defaultStorageAccountName

    # If storage account doesn't exist then get additional info
    $storageAccount = Get-AzureRmStorageAccount | Where-Object { $_.StorageAccountName -eq $Inputs.StorageAccountName }
    if (!$storageAccount) {
        $storageAccountTypes = @("Standard_LRS, Locally Redundant Storage", "Standard_ZRS, Zone Redundant Storage", "Standard_GRS, Geo Redundant Storage", "Standard_RAGRS, Read-Access Geo Redundant Storage", "Premium_LRS, Locally Redundant Storage")
        Get-InputFromMenu $Inputs "StorageAccountType" "Select Storage Account Type" {$storageAccountTypes} $null "Please Note: Selected type must be available for selected VM size."

        $Inputs.StorageAccountType = $Inputs.StorageAccountType.Substring(0, $Inputs.StorageAccountType.IndexOf(",")) 
    }

    # Get the virtual network and network security group
    Write-Information "Retrieving virtual networks ..." -InformationAction Continue    
    $virtualNetworks = {Get-AzureRmVirtualNetwork | Where-Object { $_.ResourceGroupName -eq $Inputs.ResourceGroupName } | `
                        Sort-Object Name | Select-Object -ExpandProperty Name}
    Get-InputFromMenu $Inputs "VirtualNetworkName" "Select Virtual Network" $virtualNetworks $Inputs.ResourceGroupName

    Write-Information "Retrieving security groups ..." -InformationAction Continue    
    $securityGroups = {Get-AzureRmNetworkSecurityGroup | Where-Object { $_.ResourceGroupName -eq $Inputs.ResourceGroupName } | `
                        Sort-Object Name | Select-Object -ExpandProperty Name}
    Get-InputFromMenu $Inputs "NetworkSecurityGroup" "Select Network Security Group" $securityGroups $Inputs.ResourceGroupName

    # We run different commands based on the OS, and have no way to figure it out from the image
    $osChoices = @("Linux", "Windows")
    Get-InputFromMenu $Inputs "OperatingSystem" "Select Operating System" {$osChoices} $null "Please Note: Selected operating system must match the VM image selected."

    # The VM will need its admin credentials set
    $Inputs.AdminCredentials = (Get-Credential -UserName "vmadmin" -Message "Enter the username and password of the admin account for the new VM")
    
    # If a domain name label is supplied, then test that it isn't in use
    Assert-DomainNameIsAvailable $Inputs.DomainNameLabel $Inputs.Location

    if (!$WhatIf -and !(Confirm-ScriptShouldContinue $Confirm "Continuing will add resources to your current Azure subscription.")) { return }

    if ($WhatIf) {
        Write-Information "WhatIf: Virtual machine $($VmName) would be created in resource group $($Inputs.ResourceGroupName) in location $($Inputs.Location)" `
            -InformationAction Continue
        Write-Information "The following inputs were entered" -InformationAction Continue
        $Inputs
        return 
    }

    # Now start creating things and setting them up            
    # If the resource group doesn't exist, then create it
    $checkResourceGroup = Get-AzureRmResourceGroup | Where-Object { $_.ResourceGroupName -eq $Inputs.ResourceGroupName }
    if (!$checkResourceGroup)
    {
        Write-Information -MessageData "Creating new resource group" -InformationAction Continue
        New-AzureRmResourceGroup -Name $Inputs.ResourceGroupName -Location $Inputs.Location | Out-Null
    }
    
    # If the storage account doesn't exist, then create it
    if (!$storageAccount)
    {
        Write-Information -MessageData "Creating new storage account" -InformationAction Continue
        New-AzureRmStorageAccount -Name $Inputs.StorageAccountName -ResourceGroupName $Inputs.ResourceGroupName `
            -SkuName $Inputs.StorageAccountType -Location $Inputs.Location | Out-Null
    }
    
    # If the virtual network doesn't exist, then create it
    $vnet = $null
    $checkVirtualNetwork = Get-AzureRmVirtualNetwork | Where-Object { $_.Name -eq $Inputs.VirtualNetworkName }
    if (!$checkVirtualNetwork) {
        Write-Information -MessageData "Creating new virtual network" -InformationAction Continue
        $defaultSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name "defaultSubnet" -AddressPrefix "10.0.2.0/24"
        $vnet = New-AzureRmVirtualNetwork -Name $Inputs.VirtualNetworkName -ResourceGroupName $Inputs.ResourceGroupName `
            -Location $Inputs.Location -AddressPrefix "10.0.0.0/16" -Subnet $defaultSubnet -WarningAction SilentlyContinue
    }
    
    # Create, if needed, the network security group and add a default RDP rule
    $nsg = $null
    $securityGroupName = @{$true = $Inputs.ResourceGroupName; $false = $Inputs.NetworkSecurityGroup}[$Inputs.NetworkSecurityGroup -eq ""]
    if ($Inputs.NetworkSecurityGroup -ne "")
    {
        $nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $Inputs.ResourceGroupName | Where-Object { $_.Name -eq $Inputs.NetworkSecurityGroup }   
    }
    if (!$nsg)
    {
        Write-Information -MessageData "Creating security group and rule" -InformationAction Continue
        $nsg = New-AzureRMNetworkSecurityGroup -ResourceGroupName $Inputs.ResourceGroupName -Name $securityGroupName -Location $Inputs.Location -WarningAction SilentlyContinue
        $nsg | Add-AzureRmNetworkSecurityRuleConfig -WarningAction SilentlyContinue -Name 'Allow_RDP' -Priority 1000 -Protocol TCP -Access Allow `
                    -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Direction Inbound | `
                    Set-AzureRmNetworkSecurityGroup | Out-Null
    }

    # Create the public IP and NIC
    if (!$vnet) { $vnet = Get-AzureRmVirtualNetwork -Name $Inputs.VirtualNetworkName -ResourceGroupName $Inputs.ResourceGroupName }
    $ticks = (Get-Date).Ticks.ToString()
    $ticks = $ticks.Substring($ticks.Length - 5, 5)
    $nicName = "$($Inputs.ResourceGroupName)$($ticks)"
    if ($Inputs.DomainNameLabel -ne "")
    {
        Write-Information -MessageData "Creating new public IP address with domain name" -InformationAction Continue
        $pip = New-AzureRmPublicIpAddress -WarningAction SilentlyContinue -Name $nicName -ResourceGroupName $Inputs.ResourceGroupName `
                    -DomainNameLabel $Inputs.DomainNameLabel -Location $Inputs.Location -AllocationMethod Dynamic
    }
    else
    {
        Write-Information -MessageData "Creating new public IP address WITHOUT domain name" -InformationAction Continue
        $pip = New-AzureRmPublicIpAddress -WarningAction SilentlyContinue -Name $nicName -ResourceGroupName $Inputs.ResourceGroupName `
                    -Location $Inputs.Location -AllocationMethod Dynamic
    }
    Write-Information -MessageData "Creating new network interface" -InformationAction Continue
    $nic = New-AzureRmNetworkInterface -WarningAction SilentlyContinue -Name $nicName -ResourceGroupName $Inputs.ResourceGroupName `
                -Location $Inputs.Location -PublicIpAddressId $pip.Id -SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $nsg.Id
    
    # Create the VM configuration
    Write-Information -MessageData "Creating VM configuration" -InformationAction Continue
    $vm = New-AzureRmVMConfig -VMName $VMName -VMSize $Inputs.VMSize
    
    # Add additional info to the configuration
    if ($Inputs.OperatingSystem -eq "Windows") {
        $vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $VMName -Credential $Inputs.AdminCredentials -ProvisionVMAgent -EnableAutoUpdate
    } else {
        $vm = Set-AzureRmVMOperatingSystem -VM $vm -Linux -ComputerName $VMName -Credential $Inputs.AdminCredentials
    }
    $vm = Set-AzureRmVMSourceImage -VM $vm -PublisherName $Inputs.VMImagePublisher -Offer $Inputs.VMImageOffer -Skus $Inputs.VMImageSku -Version "latest"
    $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

    # Create the disk
    $diskName = "$($VMName)OSDisk"
    $storage = Get-AzureRmStorageAccount -ResourceGroupName $Inputs.ResourceGroupName -Name $Inputs.StorageAccountName
    $osDisk = $storage.PrimaryEndpoints.Blob.ToString() + "vhds/" + $diskName  + ".vhd"
    if ($Inputs.OperatingSystem -eq "Windows") {
        $vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $osDisk -CreateOption fromImage
    } else {
        $vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $osDisk -CreateOption fromImage
    }

    # And finally create the VM itself
    Write-Information -MessageData "Creating the VM ... this will take some time ..." -InformationAction Continue

    New-AzureRmVM -ResourceGroupName $Inputs.ResourceGroupName -Location $Inputs.Location -VM $vm

    Write-Information -MessageData "VM Created successfully" -InformationAction Continue
}


function Enable-RemotePowerShellOnAzureRmVm {
    <#
        .SYNOPSIS
        Remotely configures an Azure RM virtual machine to enable Powershell remoting.
        Returns a command that can be used to connect to the remote VM.
        Much of this script came from a blog post by Marcus Robinson
        http://www.techdiction.com/2016/02/12/powershell-function-to-enable-winrm-over-https-on-an-azure-resource-manager-vm/
        .DESCRIPTION
        Generates a script locally, then uploads it to blob storage, where it is then installed as a custom script extension and run on the VM.  
            Opens the appropriate port in the network security group rules.
        .
        .EXAMPLE
        Enable-RemotePowerShellOnAzureRmVm -VMName myvm -ResourceGroupName myvirtualmachines
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
    [OutputType([string])]
    Param (
        [parameter(Mandatory=$true)]
        [string]$VMName,
          
        [parameter(Mandatory=$true)]
        [string]$ResourceGroupName,      

        [parameter()]
        [string]$DNSName = $env:COMPUTERNAME,
          
        [parameter()]
        [string]$SourceAddressPrefix = "*"
    ) 
    
    [string]$scriptName = "ConfigureWinRM_HTTPS.ps1"
    [string]$extensionName = "EnableWinRM_HTTPS"
    [string]$blobContainer = "scripts"
    [string]$securityRuleName = "WinRM_HTTPS"
    
    # Define a temporary file in the users TEMP directory
    Write-Information -MessageData "Creating script locally that we'll upload to the storage account" -InformationAction Continue
    [string]$file = $env:TEMP + "\" + $scriptName
      
    # Create the file containing the PowerShell
    {
        # POWERSHELL TO EXECUTE ON REMOTE SERVER BEGINS HERE
        param([string]$DNSName)
        
        # Force all network locations that are Public to Private
        Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq "Public" } | `
            ForEach-Object { Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private }
          
        # Ensure PS remoting is enabled, although this is enabled by default for Azure VMs
        Enable-PSRemoting -Force
        
        # Create rule in Windows Firewall, if it's not already there
        if ((Get-NetFirewallRule | Where-Object { $_.Name -eq "WinRM HTTPS" }).Count -eq 0)
        {
            New-NetFirewallRule -Name "WinRM HTTPS" -DisplayName "WinRM HTTPS" -Enabled True -Profile Any -Direction Inbound -Action Allow -LocalPort 5986 -Protocol TCP
        }
          
        # Create Self Signed certificate and store thumbprint, if it doesn't already exist
        $thumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$DNSName" } | Select-Object -First 1).Thumbprint
        if (!$thumbprint)
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
    $key = ((Get-AzureRmStorageAccountKey -Name $storageaccountname -ResourceGroupName $ResourceGroupName) | `
            Where-Object { $_.KeyName -eq "key1" }).Value

    # create storage context
    $storagecontext = New-AzureStorageContext -StorageAccountName $storageaccountname -StorageAccountKey $key
      
    # create a container called scripts
    if ((Get-AzureStorageContainer -Context $storagecontext | Where-Object { $_.Name -eq $blobContainer}).Count -eq 0)
    {
        New-AzureStorageContainer -Name $blobContainer -Context $storagecontext | Out-Null
    }
      
    #upload the file
    Set-AzureStorageBlobContent -Container $blobContainer -File $file -Blob $scriptName -Context $storagecontext -force | Out-Null
    
    # Create custom script extension from uploaded file
    Write-Information -MessageData "Create and run a script extension from our uploaded script" -InformationAction Continue
    Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name $extensionName `
        -Location $vm.Location -StorageAccountName $storageaccountname -StorageAccountKey $key -FileName $scriptName `
        -ContainerName $blobContainer -RunFile $scriptName -Argument $DNSName | Out-Null
      
    # Get the name of the first NIC in the VM
    Write-Information -MessageData "Create a new security rule that will allow us to connect remotely" -InformationAction Continue
    $nic = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name (Get-AzureRmResource -ResourceId $vm.NetworkInterfaceIDs[0]).ResourceName
    
    # Get the network security group attached to the NIC
    $nsg = Get-AzureRmNetworkSecurityGroup  -ResourceGroupName $ResourceGroupName  -Name (Get-AzureRmResource -ResourceId $nic.NetworkSecurityGroup.Id).Name 
        
    # Add the new NSG rule, and update the NSG
    if (($nsg.SecurityRules | Where-Object { $_.Name -eq "WinRM_HTTPS" }).Length -eq 0) {
        $nsg | Add-AzureRmNetworkSecurityRuleConfig -Name $securityRuleName -Priority 1100 -Protocol TCP -Access Allow `
            -SourceAddressPrefix $SourceAddressPrefix -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 5986 -Direction Inbound | `
            Set-AzureRmNetworkSecurityGroup | Out-Null
    }
    
    # get the NIC public IP
    $ip = Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Name (Get-AzureRmResource -ResourceId $nic.IpConfigurations[0].PublicIpAddress.Id).ResourceName 
    
    "To connect to the VM using the IP address while bypassing certificate checks use the following command:"
    "Enter-PSSession -ComputerName $($ip.IpAddress) -Credential <admin_username> -UseSSL -SessionOption (New-PsSessionOption -SkipCACheck -SkipCNCheck)"
}

function Get-AzureRmSubscriptionMenu {
    <#
        .SYNOPSIS
        Displays a menu for selecting an Azure subscription.
        Returns chosen subscription id.
        .PARAMETER Inputs
        When scripting menu inputs can be provided.
        - This menu will set the value of $Inputs.SubscriptionId
        $inputs = New-AzureRmVmInputs
        $inputs.Location = "westus"
        ...
        Get-AzureRmSubscriptionMenu -Inputs $inputs
        .EXAMPLE
        Get-AzureRmSubscriptionMenu
    #>
    [CmdletBinding()]
    param (
        [AzureRmVmInputs]$inputs = (New-Object AzureRmVmInputs)
    )

    Write-Information "Retrieving subscriptions ..." -InformationAction Continue    
    $subscriptions = Get-AzureRmSubscription -WarningAction SilentlyContinue | `
                        Sort-Object Name | `
                        Select-Object @{ Name = "Subscription"; Expression = { "$($_.Name) [$($_.Id)]" } } | `
                        Select-Object -ExpandProperty Subscription
    Get-InputFromMenu $inputs "SubscriptionId" "Select Subscription" { $subscriptions }
    
    $sub = $inputs.SubscriptionId -Replace "]"    
    $inputs.SubscriptionId = $sub.Split("[")[1]

    $inputs.SubscriptionId
}

function Get-AzureRmVmImageSkuMenu {
    <#
        .SYNOPSIS
        Displays a menu for selecting an Azure VM image sku.
        - Returns the name of the chosen SKU.
        - Calling this menu will also call the Location, VMImagePublisher and
                VMImageOffer menus if needed.
        .PARAMETER Inputs
        When scripting menu inputs can be provided.
        - This menu will set the value of $Inputs.VMImageSku
        $inputs = New-AzureRmVmInputs
        $inputs.Location = "westus"
        $inputs.VMImagePublisher = "RedHat"
        ...
        Get-AzureRmVmImageSkuMenu -Inputs $inputs
        .EXAMPLE
        Get-AzureRmVmImageSkuMenu
    #>
    [CmdletBinding()]
    param (
        [AzureRmVmInputs]$inputs = (New-Object AzureRmVmInputs)
    )

    Get-AzureRmVmImageOfferMenu $inputs | Out-Null

    Write-Information "Retrieving VM image SKUs ..." -InformationAction Continue
    $skus = {Get-AzureRmVMImageSku -WarningAction SilentlyContinue -Location $inputs.Location -PublisherName $inputs.VMImagePublisher -Offer $inputs.VMImageOffer `
                            | Sort-Object Skus | Select-Object -ExpandProperty Skus}
    Get-InputFromMenu $inputs "VMImageSku" "Select VM Image Sku" $skus

    Get-AzureRmVMImageSku -WarningAction SilentlyContinue -Location $inputs.Location -PublisherName $inputs.VMImagePublisher -Offer $inputs.VMImageOffer
    $inputs.VMImageSku
}


function Get-AzureRmVmImageOfferMenu {
    <#
        .SYNOPSIS
        Displays a menu for selecting an Azure VM image offer.
        - Returns the name of the chosen offer.
        - Calling this menu will also call the Location and VMImagePublisher
                menus if needed.
        .PARAMETER Inputs
        When scripting menu inputs can be provided.
        - This menu will set the value of $Inputs.VMImageOffer
        $inputs = New-AzureRmVmInputs
        $inputs.Location = "westus"
        $inputs.VMImagePublisher = "RedHat"
        ...
        Get-AzureRmVmImageOfferMenu -Inputs $inputs
        .EXAMPLE
        Get-AzureRmVmImageOfferMenu
    #>
    [CmdletBinding()]
    param (
        [AzureRmVmInputs]$inputs = (New-Object AzureRmVmInputs)
    )

    Get-AzureRmVmImagePublisherMenu $inputs | Out-Null

    Write-Information "Retrieving VM image offers ..." -InformationAction Continue
    $offers = {Get-AzureRmVMImageOffer -WarningAction SilentlyContinue -Location $inputs.Location -PublisherName $inputs.VMImagePublisher `
                            | Sort-Object Offer | Select-Object -ExpandProperty Offer}
    Get-InputFromMenu $inputs "VMImageOffer" "Select VM Image Offer" $offers

    $inputs.VMImageOffer
}


function Get-AzureRmVMImagePublisherMenu {
    <#
        .SYNOPSIS
        Displays a menu for selecting an Azure VM image publisher.
        - Returns the name of the chosen publisher.
        - Calling this menu will also call the Location menu if needed.
        .PARAMETER Inputs
        When scripting menu inputs can be provided.
        - This menu will set the value of $Inputs.VMImagePublisher
        $inputs = New-AzureRmVmInputs
        $inputs.Location = "westus"
        ...
        Get-AzureRmVmImagePublisherMenu -Inputs $inputs
        .EXAMPLE
        Get-AzureRmVmImagePublisherMenu
    #>
    [CmdletBinding()]
    param (
        [AzureRmVmInputs]$inputs = (New-Object AzureRmVmInputs)
    )

    Get-AzureRmLocationMenu $inputs | Out-Null

    Write-Information "Retrieving VM image publishers ..." -InformationAction Continue
    $publishers = {Get-AzureRmVMImagePublisher -WarningAction SilentlyContinue -Location $inputs.Location `
                            | Sort-Object PublisherName | Select-Object -ExpandProperty PublisherName}
    Get-InputFromMenu $inputs "VMImagePublisher" "Select VM Image Publisher" $publishers

    $inputs.VMImagePublisher
}

function Get-AzureRmLocationMenu {
    <#
        .SYNOPSIS
        Displays a menu for selecting an Azure location.
        - Returns the name of the chosen location.
        .PARAMETER Inputs
        When scripting menu inputs can be provided.
        - This menu will set the value of $Inputs.Location
        $inputs = New-AzureRmVmInputs
        ...
        Get-AzureRmLocationMenu -Inputs $inputs
        .EXAMPLE
        Get-AzureRmLocationMenu
    #>
    [CmdletBinding()]
    param (
        [AzureRmVmInputs]$inputs = (New-Object AzureRmVmInputs)
    )

    Write-Information "Retrieving locations ..." -InformationAction Continue
    $locations = Get-AzureRmLocation -WarningAction SilentlyContinue | Sort-Object DisplayName | Select-Object -ExpandProperty Location 
    Get-InputFromMenu $inputs "Location" "Select Location" { $locations }

    $inputs.Location
}

function Get-AzureRmVmSizeMenu {
    <#
        .SYNOPSIS
        Displays a menu for selecting an Azure VM size.
        - Returns the name of the chosen size.
        - Calling this menu will also call the Location menu if needed.
        .PARAMETER Inputs
        When scripting menu inputs can be provided.
        - This menu will set the value of $Inputs.VMSize
        $inputs = New-AzureRmVmInputs
        $inputs.Location = "westus"
        ...
        Get-AzureRmVmSizeMenu -Inputs $inputs
        .EXAMPLE
        Get-AzureRmVmSizeMenu
    #>
    [CmdletBinding()]
    param (
        [AzureRmVmInputs]$Inputs = (New-Object AzureRmVmInputs)
    )
    
    Get-AzureRmLocationMenu $inputs | Out-Null

    Write-Information "Retrieving VM sizes ..." -InformationAction Continue    
    $vmSizes = { Get-AzureRmVMSize -Location $Inputs.Location | Sort-Object Name | Select-Object @{ Label = "Name"; Expression = { `
            "$($_.Name.PadRight(25))Cores = $($_.NumberOfCores.ToString().PadLeft(2)); Memory = $(($_.MemoryInMb / 1024).ToString().PadLeft(4)) GB; OS Disk = $(($_.OSDiskSizeInMB / 1024).ToString().PadLeft(4)) GB" }} | `
            Select-Object -ExpandProperty Name } 

    Get-InputFromMenu $Inputs "VMSize" "Select VM Size" $vmSizes

    if ($inputs.VMSize.Length -gt 25) { $inputs.VMSize = $inputs.VMSize.Substring(0, 25).TrimEnd() }
    $inputs.VMSize
}

function Assert-AzureRmSession {
    <#
        .SYNOPSIS
        Test if an Azure RM session exists, and throw an error if it doesn't.
        .DESCRIPTION
        Confirms an Azure RM session exists by checking for Get-AzureRmContext, and throws an error if $null is returned.
        .EXAMPLE
        Assert-AzureRmSession
    #>

    try {
        $context = Get-AzureRmContext
    }
    catch {
        throw "Commands in this module require an Azure session.  Please use Add-AzureRmAccount before continuing"
        
    }

    $context
}

function Get-AzureRmDefault {
    <#
        .SYNOPSIS
        Load defaults for AzureRm commands.
        .DESCRIPTION
        Defaults are loaded from a JSON file in the profile folder.
        .EXAMPLE
        $defaults = Get-AzureRmDefault
    #>
    
    if (Test-Path $script:FilePath) {
        $jsonObj = (Get-Content $script:FilePath) | ConvertFrom-Json
        if ($jsonObj.PSObject.Properties -match "AzureRmDefaults") { return $jsonObj.AzureRmDefaults }
    }
    return @{}
}

function Set-AzureRmDefault {
    <#
        .SYNOPSIS
        Update AzureRm defaults
        .DESCRIPTION
        Saves defaults for IntelliTect.AzureRm commands
            to a JSON file in the profile folder.
        .EXAMPLE
        Set-AzureRmDefault -Location westus
        .EXAMPLE
        Set-AzureRmDefault -RemoveLocation
    #>
    [CmdletBinding()]    
	param (
        [string]$Location = $null,
        [string]$ResourceGroupName = $null,
        [string]$SubscriptionId = $null,
        [string]$VMImagePublisher = $null,
        [string]$VMImageOffer = $null,
        [string]$VMImageSku = $null,
        [string]$StorageAccountType = $null,
        [string]$VMSize = $null,
        [string]$OperatingSystem = $null,
        [switch]$RemoveLocation,
        [switch]$RemoveResourceGroupName,
        [switch]$RemoveSubscriptionId,
        [switch]$RemoveVMImagePublisher,
        [switch]$RemoveVMImageOffer,
        [switch]$RemoveVMImageSku,
        [switch]$RemoveStorageAccountType,
        [switch]$RemoveVMSize,
        [switch]$RemoveOperatingSystem
    )

    $cache = $CachedDefaults

    function setDefaultProperty($name, $value)  {
        if ($value) {
            if (!($cache.PSObject.Properties -match $name)) {
                $cache | Add-Member -MemberType NoteProperty -Name $name -Value $null
            }
            $cache.$name = $value
        }
    }

    function removeProperty($name, $remove) {
        if ($remove) {
            if ($cache.PSObject.Properties -match $name) {
                $cache.PSObject.Properties.Remove($name)
            }
        }
    }

    setDefaultProperty "Location" $Location
    setDefaultProperty "ResourceGroupName" $ResourceGroupName
    setDefaultProperty "SubscriptionId" $SubscriptionId
    setDefaultProperty "VMImagePublisher" $VMImagePublisher
    setDefaultProperty "VMImageOffer" $VMImageOffer
    setDefaultProperty "VMImageSku" $VMImageSku
    setDefaultProperty "StorageAccountType" $StorageAccountType
    setDefaultProperty "VMSize" $VMSize
    setDefaultProperty "OperatingSystem" $OperatingSystem

    removeProperty "Location" $RemoveLocation
    removeProperty "ResourceGroupName" $RemoveResourceGroupName
    removeProperty "SubscriptionId" $RemoveSubscriptionId
    removeProperty "VMImagePublisher" $RemoveVMImagePublisher
    removeProperty "VMImageOffer" $RemoveVMImageOffer
    removeProperty "VMImageSku" $RemoveVMImageSku
    removeProperty "StorageAccountType" $RemoveStorageAccountType
    removeProperty "VMSize" $RemoveVMSize
    removeProperty "OperatingSystem" $RemoveOperatingSystem

    $jsonObj = @{}
    if (Test-Path $script:FilePath) {
        $jsonObj = (Get-Content $script:FilePath) | ConvertFrom-Json
    }
    $jsonObj.AzureRmDefaults = $cache
    ($jsonObj | ConvertTo-Json) | Out-File $script:FilePath

    $CachedDefaults = Get-AzureRmDefault
}

## Class definitions
class AzureRmVmInputs {
    [string]$SubscriptionId
    [string]$ResourceGroupName
    [string]$Location
    [string]$VMImagePublisher
    [string]$VMImageOffer
    [string]$VMImageSku
    [string]$StorageAccountName
    [string]$StorageAccountType
    [string]$DomainNameLabel
    [string]$VirtualNetworkName
    [string]$VMSize
    [string]$NetworkSecurityGroup
    [PSCredential]$AdminCredentials
    [string]$OperatingSystem
}
function New-AzureRmVmInputs { 
    <#
        .SYNOPSIS
        Generates a new instance of AzureRmVmInputs.
        .DESCRIPTION
        Useful for providing scripted inputs to the IntelliTect.AzureRm commands.
        .EXAMPLE
        $inputs = New-AzureRmVmInputs
        $inputs.Location = "westus"
        ...
        Get-AzureRmVmImagePublisher -Inputs $inputs
    #>

    return [AzureRmVmInputs]::new() 
}

## Private functions and variables
function Assert-DomainNameIsAvailable([string]$domainNameLabel = "", [string]$location = "") {
    <#
        .SYNOPSIS
        Verifies that a given domain name is available for a location.
        .PARAMETER domainNameLabel
        Domain name to verify.
        .PARAMETER location
        Azure RM location in which to check the domain name.
        .EXAMPLE
        Assert-DomainNameIsAvailable "mydomain" "westus"
    #>
    if ($domainNameLabel -eq "" -or $location -eq "") { return }

    Write-Information "Verifying domain name is available ..." -InformationAction Continue    

    $message = $null
    $domainOk = Test-AzureRmDnsAvailability -DomainQualifiedName $domainNameLabel -Location $location -ErrorAction SilentlyContinue

    if (!$?) {
        $message = "Test-AzureRmDnsAvailability failed with DomainNameLabel = $domainNameLabel"
    } elseif ( $domainOk -eq $false) {
        $message = "DomainNameLabel ($domainNameLabel) failed when tested for uniqueness."
    }
    if ($message) {
        throw $message
    }
    return
}

function Confirm-ScriptShouldContinue([bool]$confirm, [string]$message, [string]$continueMessage = $null) {
    <#
        .SYNOPSIS
        Prompt the user to determine if the script should continue.
        .PARAMETER confirm
        If false, then don't do the confirmation.  Allows for passing value of -Confirm in.
        .PARAMETER message
        Message displayed with the confirmation prompt.
        .PARAMETER continueMessage
        Override the default description for the continue option.
        .EXAMPLE
        Confirm-ScriptShouldContinue $true "This will mess up your stuff" "If you continue, your stuff will be messed up"
    #>    
    $confirmTitle = "Continue?"
    if (!$continueMessage) { $continueMessage = "Script will proceed which will result in changes to your Azure resources." }

    $confirmOptions = [System.Management.Automation.Host.ChoiceDescription[]]( `
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Continue", `
                    $continueMessage), `
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Stop", `
                    "Stop the script at this point."))

    if (!$confirm) { return $true }

    $confirmResult = $host.UI.PromptForChoice($confirmTitle, $message, $confirmOptions, 1)
    return ($confirmResult -eq 0)
}

function Get-CachedDefaultValue([string]$propertyName) {
    <#
        .SYNOPSIS
        Wrapper for Get-AzureRmDefault, but uses cached values.
        - Returns default value for property.
        .DESCRIPTION
        If the provided property doesn't exist in the stored defaults null will be returned.
        .PARAMETER propertyName
        If Set-AzureRmDefault has been used for this property, then the stored value is returned. 
        .EXAMPLE
        Set-AzureRmDefault -Location "westus"
        Get-CachedDefaultValue("Location")
    #>
    if (!$CachedDefaults) { $CachedDefaults = Get-AzureRmDefault }

    if ($CachedDefaults.PSObject.Properties -match $propertyName) { $CachedDefaults.$propertyName }
    else { $null }
}

function Get-MenuSelection([int]$selectionCount, [string]$prompt = "Please enter your selection") {
    <#
        .SYNOPSIS
        After a menu has been displayed this function is called to get the user's selection.
        - Returns menu value associated with the selection.
        .PARAMETER selectionCount
        How many menu selections are displayed.
        .PARAMETER prompt
        Prompt to display when asking for their selection.
        .EXAMPLE
        ... used internally by Get-InputFromMenu
    #>
    $validSelection = $false
    $itemSelected = $false

    if ($OriginalMenuSelections.Count -ne $CurrentMenuSelections.Count) { $prompt += " (** to restore original menu items)" }
    else { $prompt += " (enter a partial value to filter menu items)"}

    do {
        $selection = Read-Host $prompt

        if ($selection -in 1..$selectionCount) {
            $validSelection = $true
            $itemSelected = $true
        } elseif ($selection -eq "**") {
            $validSelection = $true   
        } elseif (($CurrentMenuSelections | Where-Object { $_.ToLower().Contains($selection.ToLower()) }).Count -gt 0) {
            $validSelection = $true
        }    
    }
    while (!$validSelection)
    @{ ItemSelected = $itemSelected; Selection = $selection }
}

## StackOverflow gems
function Invoke-MenuMaker {
    <#
        .SYNOPSIS
        Displays a list of menu selections, along with an optional Title and Note
        .PARAMETER title
        Displayed above the menu.
        .PARAMETER note
        Displayed above the menu, but below the title.
        .PARAMETER selections
        List of menu choices.
        .PARAMETER subSelections
        Indicates a subset of an original list of selections is being displayed.
        .EXAMPLE
        ... used internally by Get-InputFromMenu
    #>
    param (
        [string]$title = $null,

        [string]$note = $null,
        
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$selections,

        [bool]$subSelections = $false
    )

    if (!$subSelections) { $script:OriginalMenuSelections = $selections } 
    $script:CurrentMenuSelections = $selections

    $width = ($selections | Where-Object { $_.Length } | Sort-Object Length -Descending | Select-Object -First 1).Length
    if ($title -or $note) {
        $widthArray = @($width)
        if ($title) { $widthArray += $title.Length }
        if ($note) { $widthArray += $note.Length }

        $width = $widthArray | Sort-Object -Descending | Select-Object -First 1 
    }

    $buffer = if (($width * 1.5) -gt 200) {
        (200 - $width) / 2
    } else {
        $width / 4
    }
    if ($buffer -gt 4) { $buffer = 4 }
    $buffer = [int]$buffer

    $maxWidth = $buffer * 2 + $width + 5
    
    $menu = ""
    $menu += "╔" + "═" * $maxWidth + "╗`n"
    if ($title) {
        $menu += "║" + " " * [Math]::Floor(($maxWidth - $title.Length) / 2) + $title + " " * [Math]::Ceiling(($maxWidth - $title.Length) / 2) + "║`n"
        $menu += "╟" + "─" * $maxWidth + "╢`n"
    }
    if ($note) {
        $menu += "║" + " " * [Math]::Floor(($maxWidth - $note.Length) / 2) + $note + " " * [Math]::Ceiling(($maxWidth - $note.Length) / 2) + "║`n"
        $menu += "╟" + "─" * $maxWidth + "╢`n"
    }
    for ($i = 1; $i -le $selections.Count; $i++) {
        $item = "$i`. ".PadRight(5)
        $menu += "║" + " " * $buffer + $item + $selections[$i - 1] + " " * ($maxWidth - $buffer - $item.Length - $selections[$i - 1].Length) + "║`n"
    }
    $menu += "╚" + "═" * $maxWidth + "╝`n"

    Write-Information $menu -InformationAction Continue
}

function Get-InputFromMenu([AzureRmVmInputs]$inputs, [string]$property, [string]$prompt, [ScriptBlock]$selectionScript, `
                            [string]$default = $null, [string]$note = $null, [bool]$confirmSingle = $false) {
    <#
        .SYNOPSIS
        Displays a menu and prompts the user for input.
        - Menu is not displayed:
            - If the property is already set on the provided $inputs.
            - If a default has been set for this property.
            - If $selectionScript only returns one option.
                - User will need to confirm
            - If $selectionScript returns no values and $default is provided.
                - An error is thrown if no $default is provided.
        .PARAMETER inputs
        AzureRmVmInputs instance to add the selection to.
        .PARAMETER property
        Name of the property on inputs that will be set.
        .PARAMETER prompt
        Prompt displayed to the user.
        .PARAMETER selectionScript
        Once a decision is made to display the menu, this script will provide the selections.
        - Won't be evaluated unless the menu will be displayed.
        .PARAMETER default
        If selectionScript returns no values then default will be used.
        .PARAMETER note
        Passed to Invoke-MenuMaker
        .PARAMETER confirmSingle
        Determines if user will be prompted if selectionScript returns only one value. 
        .EXAMPLE
        $inputs = New-AzureRmVmInputs
        $locations = Get-AzureRmLocation -WarningAction SilentlyContinue | Sort-Object DisplayName | Select-Object -ExpandProperty Location 
        Get-InputFromMenu $inputs "Location" "Select Location" { $locations }
    #>
    if (!$inputs.$property) {
        $inputs.$property = Get-CachedDefaultValue $property
        if (!$inputs.$property) {            
            $selections = &$selectionScript
            if ($selections -isnot [System.Array]) {
                if (($selections -eq "" -or $null -eq $selections) -and !$default) { throw "No $($property) values found for supplied inputs."}
                elseif (($selections -eq "" -or $null -eq $selections) -and $default) { 
                    $inputs.$property = $default 
                    Write-Information "Using default value for $property - $($inputs.$property)" -InformationAction Continue
                } 
                else { 
                    $inputs.$property = $selections
                    Write-Information "Using single available value for $property - $($inputs.$property)" -InformationAction Continue

                    if ($confirmSingle) {
                        if (!(Confirm-ScriptShouldContinue $true "Single value available for $property - $($inputs.$property)." "Continuing will use the only available value.")) {
                            $inputs.$property = $null 
                        }
                    } 
                }
            } else {
                $selectedItem = $null
                $subSelections = $false
                do {
                    Invoke-MenuMaker -Title $prompt -Selections $selections -SubSelections $subSelections -Note $note
                    $selection = Get-MenuSelection $selections.Count

                    if ($selection.ItemSelected) {
                        $selectedItem = $selection.Selection
                    } else {
                        if ($selection.Selection -eq "**") {
                            $selections = $OriginalMenuSelections
                            $subSelections = $false
                        } else {
                            $selections = $selections | Where-Object { $_.ToLower().Contains($selection.Selection.ToLower()) }
                            $subSelections = $true
                        }
                    }
                } while (!$selectedItem)

                if ($selections -isnot [System.Array]) { $inputs.$property = $selections }
                else { $inputs.$property = $selections[$selectedItem - 1] }
            }

        } else {
            Write-Information "Using cached value for $property - $($inputs.$property)" -InformationAction Continue
        }
    } else {
        Write-Information "Using provided input for $property - $($inputs.$property)" -InformationAction Continue
    }
}

## Set up defaults
$FilePath = (Split-Path -Path $profile) + "\IntelliTectUserSettings.json"
$CachedDefaults = $null
$CurrentMenuSelections = $null
$OriginalMenuSelections = $null


Export-ModuleMember -Function New-AzureRmVirtualMachine
Export-ModuleMember -Function Enable-RemotePowerShellOnAzureRmVm
Export-ModuleMember -Function Get-AzureRmDefault
Export-ModuleMember -Function Set-AzureRmDefault
Export-ModuleMember -Function Get-AzureRmSubscriptionMenu
Export-ModuleMember -Function Get-AzureRmLocationMenu
Export-ModuleMember -Function Get-AzureRmVmImagePublisherMenu
Export-ModuleMember -Function Get-AzureRmVmImageOfferMenu
Export-ModuleMember -Function Get-AzureRmVmImageSkuMenu
Export-ModuleMember -Function New-AzureRmVmInputs
Export-ModuleMember -Function Get-AzureRmVmSizeMenu