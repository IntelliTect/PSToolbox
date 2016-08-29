# function Test-DynamicParameter {
#     <#
#         .SYNOPSIS
#         Demonstrates the use of dynamic parameters
#     #>
#     [CmdletBinding()]
#     param(
#     )

#     DynamicParam {
#         $context = Confirm-AzureRmSession

#         $params = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
#         $params.Add("Location", (getLocationParameter 1))
#         $params.Add("Subscription", (getSubscriptionParameter 2))

#         return $params
#     }

#     begin {
#         $VMName = ""

#         # Capture all of our dynamic parameters
#         $boundParameters = @{} + $PSBoundParameters

#         $Location = getDynamicParameterValue "Location" $boundParameters
#         $Subscription = getDynamicParameterValue "Subscription" $boundParameters

#         $sub = $Subscription -Replace "]"    
#         $Subscription = $sub.Split("[")[1]


#         # Repeat back full command
#         "New-AzureRmVirtualMachine -VMName $($VMName) -Location $($Location) -Subscription $($Subscription)"
#     }
# }

function New-AzureRmVirtualMachine {
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
        $inputs = New-Object AzureRmVmInputs
        $inputs.Location = westus
        $inputs.SubscriptinId = <subscription id>
        ...
        .PARAMETER ResourceGroupName
        - Resource group to create resources in.  DEFAULT: none  
        - If creating a new resource group it must be specified in the parameter.  
        - If not specified you can only choose from existing resource groups.
        - Can specify a default with Set-AzureRmDefault -ResourceGroupName <resourcegroupname>
        .PARAMETER VirtualNetworkName
        Name of virtual network.  Will be created if it doesn't exist.  DEFAULT: $ResourceGroupName
        .PARAMETER DomainNameLabel
        Domain name to point at your public IP address.  DEFAULT: none

        .NOTES
        Additional default values can be specified for:
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
    [CmdletBinding()]    
    param (
        [Parameter(Mandatory = $true)]
        [string]$VmName,

        [AzureRmVmInputs]$Inputs = (New-Object AzureRmVmInputs),

        [string]$ResourceGroupName = $null,

        [string]$VirtualNetworkName = $null,

        [string]$DomainNameLabel = ""
    )
    Set-StrictMode -Version Latest

    $context = Confirm-AzureRmSession

    # Process overrides from command line
    if ($ResourceGroupName) { $Inputs.ResourceGroupName = $ResourceGroupName }
    if ($VirtualNetworkName) { $Inputs.VirtualNetworkName = $VirtualNetworkName }
    $Inputs.DomainNameLabel = $DomainNameLabel

    # Choose a subscription ... and switch context to it if different than current
    Get-AzureRmSubscriptionMenu $Inputs | Out-Null
    if ($context.Subscription.SubscriptionId -ne $Inputs.SubscriptionId) {
        Write-Information "Switching Azure context to selected subscription ..." -InformationAction Continue
        Set-AzureRmContext -SubscriptionId $Inputs.SubscriptionId | Out-Null
    }

    # Choose a resource group
    $resourceGroups = {Get-AzureRmResourceGroup -WarningAction SilentlyContinue | Sort-Object ResourceGroupName | `
                            Select-Object -ExpandProperty ResourceGroupName}
    getInputFromMenu $Inputs "ResourceGroupName" "Select Resource Group" $resourceGroups

    # Choose an image sku
    Get-AzureRmVmImageSkuMenu $Inputs | Out-Null

    # And a VM size
    $vmSizes = {Get-AzureRmVMSize -Location $Inputs.Location | Sort-Object Name | Select-Object -ExpandProperty Name}
    getInputFromMenu $Inputs "VMSize" "Select VM Size" $vmSizes

    # Choose a storage account
    $storageAccounts = {Get-AzureRmStorageAccount | Where-Object { $_.ResourceGroupName -eq $Inputs.ResourceGroupName } | `
                        Sort-Object StorageAccountName | Select-Object -ExpandProperty StorageAccountName}
    $defaultStorageAccountName = $Inputs.ResourceGroupName.ToLower().Substring(0, [System.Math]::Min(24, $Inputs.ResourceGroupName.Length))
    getInputFromMenu $Inputs "StorageAccountName" "Select Storage Account" $storageAccounts $defaultStorageAccountName

    # If storage account doesn't exist then get additional info
    $storageAccount = Get-AzureRmStorageAccount | Where-Object { $_.StorageAccountName -eq $Inputs.StorageAccountName }
    if (!$storageAccount) {
        $storageAccountTypes = @("Standard_LRS", "Standard_ZRS", "Standard_GRS", "Standard_RAGRS", "Premium_LRS")
        getInputFromMenu $Inputs "StorageAccountType" "Select Storage Account Type" {$storageAccountTypes}
    }

    # Get the virtual network and network security group
    $virtualNetworks = {Get-AzureRmVirtualNetwork | Where-Object { $_.ResourceGroupName -eq $Inputs.ResourceGroupName } | `
                        Sort-Object Name | Select-Object -ExpandProperty Name}
    getInputFromMenu $Inputs "VirtualNetworkName" "Select Virtual Network" $virtualNetworks $Inputs.ResourceGroupName

    $securityGroups = {Get-AzureRmNetworkSecurityGroup | Where-Object { $_.ResourceGroupName -eq $Inputs.ResourceGroupName } | `
                        Sort-Object Name | Select-Object -ExpandProperty Name}
    getInputFromMenu $Inputs "NetworkSecurityGroup" "Select Network Security Group" $securityGroups $Inputs.ResourceGroupName

    # We run different commands based on the OS, and have no way to figure it out from the image
    $osChoices = @("Linux", "Windows")
    getInputFromMenu $Inputs "OperatingSystem" "Select Operating System" {$osChoices}

    # The VM will need its admin credentials set
    $Inputs.AdminCredentials = (Get-Credential -UserName "vmadmin" -Message "Enter the username and password of the admin account for the new VM")
    
    # If a domain name label is supplied, then test that it isn't in use
    if ($Inputs.DomainNameLabel -ne "")
    {
        $message = $null
        $domainOk = Test-AzureRmDnsAvailability -DomainQualifiedName $Inputs.DomainNameLabel -Location $Inputs.Location -ErrorAction SilentlyContinue
        if (!$?) {
            $message = "Test-AzureRmDnsAvailability failed with DomainNameLabel = $($Inputs.DomainNameLabel)"
        } elseif ( $domainOk -eq $false) {
            $message = "DomainNameLabel ($Inputs.DomainNameLabel) failed when tested for uniqueness."
        }
        if ($message) {
            Write-Information -MessageData $message -InformationAction Continue
            $Inputs
            return
        }
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
    if (!$checkVirtualNetwork)
    {
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

    $Inputs
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
    
    "To connect to the VM using the IP address while bypassing certificate checks use the following command:"
    "Enter-PSSession -ComputerName $($ip.IpAddress) -Credential <admin_username> -UseSSL -SessionOption (New-PsSessionOption -SkipCACheck -SkipCNCheck)"
}

function Get-AzureRmSubscriptionMenu {
    <#
        .SYNOPSIS
        Displays a menu for selecting an Azure VM image sku.
        .PARAMETER Inputs
        When scripting menu choices can be provided.
        $inputs = New-Object AzureRmVmInputs
        $inputs.SubscriptionId = <subscription id>
        ...        
    #>
    [CmdletBinding()]
    param (
        [AzureRmVmInputs]$inputs = (New-Object AzureRmVmInputs)
    )

    $subscriptions = $CachedSubscriptions | Sort-Object SubscriptionName | `
                        Select-Object @{ Name = "Subscription"; Expression = { "$($_.SubscriptionName) [$($_.SubscriptionId)]" } } | `
                        Select-Object -ExpandProperty Subscription
    getInputFromMenu $inputs "SubscriptionId" "Select Subscription" {$subscriptions}
    
    $sub = $inputs.SubscriptionId -Replace "]"    
    $inputs.SubscriptionId = $sub.Split("[")[1]

    $inputs.SubscriptionId
}

function Get-AzureRmVmImageSkuMenu {
    <#
        .SYNOPSIS
        Displays a menu for selecting an Azure VM image sku.
        .PARAMETER Inputs
        When scripting menu choices can be provided.
        $inputs = New-Object AzureRmVmInputs
        $inputs.Location = westus
        $inputs.VMImagePublisher = RedHat
        ...        
    #>
    [CmdletBinding()]
    param (
        [AzureRmVmInputs]$inputs = (New-Object AzureRmVmInputs)
    )

    Get-AzureRmVmImageOfferMenu $inputs | Out-Null

    $skus = {Get-AzureRmVMImageSku -WarningAction SilentlyContinue -Location $inputs.Location -PublisherName $inputs.VMImagePublisher -Offer $inputs.VMImageOffer `
                            | Sort-Object Skus | Select-Object -ExpandProperty Skus}
    getInputFromMenu $inputs "VMImageSku" "Select VM Image Sku" $skus

Get-AzureRmVMImageSku -WarningAction SilentlyContinue -Location $inputs.Location -PublisherName $inputs.VMImagePublisher -Offer $inputs.VMImageOffer
    $inputs.VMImageSku
}


function Get-AzureRmVmImageOfferMenu {
    <#
        .SYNOPSIS
        Displays a menu for selecting an Azure VM image offer.
        .PARAMETER Inputs
        When scripting menu choices can be provided.
        $inputs = New-Object AzureRmVmInputs
        $inputs.Location = westus
        $inputs.VMImagePublisher = RedHat
        ...        
    #>
    [CmdletBinding()]
    param (
        [AzureRmVmInputs]$inputs = (New-Object AzureRmVmInputs)
    )

    Get-AzureRmVmImagePublisherMenu $inputs | Out-Null

    $offers = {Get-AzureRmVMImageOffer -WarningAction SilentlyContinue -Location $inputs.Location -PublisherName $inputs.VMImagePublisher `
                            | Sort-Object Offer | Select-Object -ExpandProperty Offer}
    getInputFromMenu $inputs "VMImageOffer" "Select VM Image Offer" $offers

    $inputs.VMImageOffer
}


function Get-AzureRmVMImagePublisherMenu {
    <#
        .SYNOPSIS
        Displays a menu for selecting an Azure VM image publisher.
        .PARAMETER Inputs
        When scripting menu choices can be provided.
        $inputs = New-Object AzureRmVmInputs
        $inputs.Location = westus
        ...        
    #>
    [CmdletBinding()]
    param (
        [AzureRmVmInputs]$inputs = (New-Object AzureRmVmInputs)
    )

    Get-AzureRmLocationMenu $inputs | Out-Null

    $publishers = {Get-AzureRmVMImagePublisher -WarningAction SilentlyContinue -Location $inputs.Location `
                            | Sort-Object PublisherName | Select-Object -ExpandProperty PublisherName}
    getInputFromMenu $inputs "VMImagePublisher" "Select VM Image Publisher" $publishers

    $inputs.VMImagePublisher
}

function Get-AzureRmLocationMenu {
    <#
        .SYNOPSIS
        Displays a menu for selecting an Azure location.
        .PARAMETER Inputs
        When scripting menu choices can be provided.
        $inputs = New-Object AzureRmVmInputs
        $inputs.Location = westus
        ...        
    #>
    [CmdletBinding()]
    param (
        [AzureRmVmInputs]$inputs = (New-Object AzureRmVmInputs)
    )

    getInputFromMenu $inputs "Location" "Select Location" { $CachedLocations }

    $inputs.Location
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
        $context = Get-AzureRmContext
    }
    catch {
        Login-AzureRmAccount | Out-Null
        $context = Get-AzureRmContext
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
        Saves defaults to a JSON file in the profile folder.
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
function New-AzureRmVmInputs { return [AzureRmVmInputs]::new() }

## Private functions and variables
function getLocationParameter($position) {
    $param = createDynamicParameter "Location" $position $true $CachedLocations
    return $param
}

function getSubscriptionParameter($position) {
    $subscriptions = $CachedSubscriptions | Sort-Object SubscriptionName | `
                        Select-Object @{ Name = "Subscription"; Expression = { "$($_.SubscriptionName) [$($_.SubscriptionId)]" } } | `
                        Select-Object -ExpandProperty Subscription
    return createDynamicParameter "Subscription" $position $true $subscriptions
}

function createDynamicParameter([string]$attributeName, [int]$position, [bool]$mandatoryIfNoDefault, [string[]]$values) {
    $attributes = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

    [string]$default = $null
    if ($CachedDefaults.PSObject.Properties -match $attributeName) { $default = $CachedDefaults.$attributeName }

    $parameterAttr = New-Object System.Management.Automation.ParameterAttribute
    $parameterAttr.ParameterSetName = "__AllParameterSets"
    $parameterAttr.Position = $position
    if (!$default -and $mandatoryIfNoDefault) { $parameterAttr.Mandatory = $true }
    $attributes.Add($parameterAttr)
    
    $validateSetAttr = New-Object System.Management.Automation.ValidateSetAttribute($values)
    $attributes.Add($validateSetAttr)

    return New-Object System.Management.Automation.RuntimeDefinedParameter($attributeName, [string], $attributes)  
}

function getDynamicParameterValue([string]$parameterName, [System.Object]$params) {
    [string]$value = $params.$parameterName
    if (!$value) { $value = getCachedDefaultValue $parameterName }
    $value
}

function getCachedDefaultValue([string]$propertyName) {
    if ($CachedDefaults.PSObject.Properties -match $propertyName) { $CachedDefaults.$propertyName }
    else { $null }
}

function getMenuSelection([int]$max, [string]$prompt = "Please enter your selection") {
    $validSelection = $false
    $itemSelected = $false

    if ($OriginalMenuSelections.Count -ne $CurrentMenuSelections.Count) { $prompt += " (** to restore original menu items)" }
    else { $prompt += " (enter a partial value to filter menu items)"}

    do {
        $selection = Read-Host $prompt

        if ($selection -in 1..$max) {
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
function menuMaker {
    param (
        [string]$title = $null,
        
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$selections,

        [bool]$SubSelections = $false
    )

    if (!$SubSelections) { $script:OriginalMenuSelections = $selections } 
    $script:CurrentMenuSelections = $selections

    $width = ($selections | Where-Object { $_.Length } | Sort-Object Length -Descending | Select-Object -First 1).Length
    if ($title) {
        $width = @($width, $title.Length) | Sort-Object -Descending | Select-Object -First 1 
    }

    $buffer = if (($width * 1.5) -gt 200) {
        (200 - $width) / 2
    } else {
        $width / 4
    }
    if ($buffer -gt 4) { $buffer = 4 }
    $buffer = [int]$buffer

    $maxWidth = $buffer * 2 + $width + $([string]$selections.Count).Length + 2
    
    $menu = ""
    $menu += "╔" + "═" * $maxWidth + "╗`n"
    if ($title) {
        $menu += "║" + " " * [Math]::Floor(($maxwidth - $title.Length) / 2) + $title + " " * [Math]::Ceiling(($maxwidth - $title.Length) / 2) + "║`n"
        $menu += "╟" + "─" * $maxwidth + "╢`n"
    }
    for ($i = 1; $i -le $selections.Count; $i++) {
        $item = "$i`. "
        $menu += "║" + " " * $buffer + $item + $selections[$i - 1] + " " * ($maxWidth - $buffer - $item.Length - $selections[$i - 1].Length) + "║`n"
    }
    $menu += "╚" + "═" * $maxWidth + "╝`n"

    Write-Information $menu -InformationAction Continue
}

function getInputFromMenu([AzureRmVmInputs]$inputs, [string]$property, [string]$prompt, [ScriptBlock]$selectionScript, [string]$default = $null) {
    if (!$inputs.$property) {
        $inputs.$property = getCachedDefaultValue $property
        if (!$inputs.$property) {            
            $selections = &$selectionScript
            if ($selections -isnot [System.Array]) {
                if (($selections -eq "" -or $null -eq $selections) -and !$default) { throw "No $($property) values found for supplied inputs."}
                elseif (($selections -eq "" -or $null -eq $selections) -and $default) { $inputs.$property = $default } 
                else { $inputs.$property = $selections }
            } else {
                $selectedItem = $null
                $subSelections = $false
                do {
                    menuMaker -Title $prompt -Selections $selections -SubSelections $subSelections 
                    $selection = getMenuSelection $selections.Count

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
        }
    }
}

## Set up defaults
Confirm-AzureRmSession
$FilePath = (Split-Path -Path $profile) + "\IntelliTectUserSettings.json"
$CachedDefaults = Get-AzureRmDefault
$CachedLocations = Get-AzureRmLocation -WarningAction SilentlyContinue | Sort-Object DisplayName | Select-Object -ExpandProperty Location
$CachedSubscriptions = Get-AzureRmSubscription -WarningAction SilentlyContinue
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
#Export-ModuleMember -Function Test-DynamicParameter
