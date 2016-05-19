Function script:ShouldProcess {
    [CmdletBinding(SupportsShouldProcess=$True)]
    param(
	    [string] $verboseDescription,
	    [string] $verboseWarning,
	    [string] $caption
    )

    
    return $PSCmdlet.ShouldProcess($verboseDescription, $verboseWarning, $caption)
function Ensure-AzureSession {
    $Error.Clear();
    $currentErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    Get-AzureRmContext | Out-Null
    foreach ($ex in $Error) {
        if ($ex.Exception.ToString() -like "*Run Login-AzureRmAccount to login.*") {
            Login-AzureRmAccount | Out-Null
        }
    }
    $Error.Clear()
    $ErrorActionPreference = $currentErrorAction
}
  
Function Setup-AzureConfiguaration {
    # Removed ConfirmImpact="High" as you can't seem to have -force and -confirm and force is more typical with Azure PowerShell
    [CmdletBinding(ConfirmImpact="High", SupportsShouldProcess=$True)] 
    param(
           [pscredential]$azureCredentials = (Get-Credential -Message "Enter your azure credentials here."),
           [switch]$force 
        )

       if(!$force -and (!(ShouldProcess "Install-Module AzureRM`nInstall-AzureRM`nImport-Module AzureRM`nInstall-Module Azure" `
        “Installing Azure Modules" "Confirm to execution" )) ) {
            return
       }

         
        $nugetPackageProvider = Get-PackageProvider Nuget
        $psGalleryRepository = Get-PSRepository PSGallery
        if($psGalleryRepository) {
            $psRepositoryInstallationPolicy = (Get-PSRepository PSGallery).InstallationPolicy
        }
        try{
            if(!(Get-PackageProvider Nuget)) {
                # This is not uninstalled if installed since there is not Uninstall-PackageProvider or Remove-PackageProvider
                Install-PackageProvider -Name NuGet -Force 
            }
            if((Get-PSRepository PSGallery).InstallationPolicy -ne "Trusted") {
                Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
            }

            #Install-Module AzureRM -Force
            #Install-AzureRM -Force
            #Import-Module AzureRM -Force
            Install-Module Azure -Force

            Write-Warning "Prompts for Azure Credentials"
            Write-Output Add-AzureAccount # -Credential $azureCredentials doesn't work for live IDs.
        
            Write-Warning "Prompts to download PublishSettings file"
            Write-Output Get-AzurePublishSettingsFile 
            Get-ChildItem "$env:USERPROFILE\Downloads\" "*.publishsettings" | 
                %{ Import-AzurePublishSettingsFile $_.FullName }
                    }
        finally {
            if((Get-PSRepository PSGallery).InstallationPolicy -ne $psRepositoryInstallationPolicy) {
                Set-PSRepository -Name "PSGallery" -InstallationPolicy $psRepositoryInstallationPolicy
            }
        }
}

Function Initialize-Azure {
    [CmdletBinding()]
    Param(
        [string]$subscriptionName
    )

    "Azure","AzureRM" | % { 
        $module = Get-Module $_ -ListAvailable
        if (!$module) {
			Write-Warning "The Azure module is not installed.  To install run 'Choco Install WindowsAzurePowershell'"
			return
        }
        Write-Output $module
    } | Import-Module

    Set-AzureSubscription -SubscriptionName $subscriptionName
}

function Configure-AzureRmVmForRemotePS {
    # Much of the following script came from this blog post by Marcus Robinson
    # http://www.techdiction.com/2016/02/12/powershell-function-to-enable-winrm-over-https-on-an-azure-resource-manager-vm/
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

function New-AzureRmVirtualMachine {
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

    Ensure-AzureSession
    
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

Function New-AzureVM {
    [CmdletBinding()] 
	Param(
        [Parameter(Mandatory)]
		[string]$imageName,
        [Parameter(Mandatory)]
		[string] $newName,
		[PSCredential] $credential,
		[string] $instanceSize = "Small",
        [string] $location = "West US"
        #[OSImageContext] $image
    )

    $vmConfig = New-AzureVMConfig -Name $newName -InstanceSize $instanceSize -Image $imageName |
        Add-AzureProvisioningConfig -Windows -AdminUserName $credential.UserName -Password (Get-CredentialPassword $credential) |
        . Azure\New-AzureVM -ServiceName $newName -Location $location
}


Function Enter-AzurePSSEssion {
<#
    .SYNOPSIS
        Enter into a Remote PowerShell session runnning on Azure VM.
#>
    [CmdletBinding()]Param(
        #The specific virtual machine from which the certificate should be imported.
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="InputObject")]
            [Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleContext]$inputObject,
        [Parameter(Mandatory,ValueFromPipeline)][string]$dnsName,
        $credential = (Get-Credential) 
        #TODO: Add a parameter set that takes a session
    )

    switch ($PsCmdlet.ParameterSetName) 
    { 
        "InputObject"  { $dnsName = $inputObject.Name; break} 
    } 

    
    if($dnsName -notlike "*.cloudapp.net") {
        $dnsName = "$dnsName.cloudapp.net"
    }

    try {
        $pssession = New-AzurePSSEssion $dnsName $credential
        Enter-PSSession -session $pssession
        return $pssession

    }
    #TODO Catch not working!!!
    catch <#[System.Management.Automation.Remoting.PSRemotingTransportException]#> {
        switch -Wildcard ($_.Message) {
            "*The WinRM client cannot process the request because the server name cannot be resolved.*" {
                Throw "Either the virtual machine is off or the port, '5986', is incorret."
            }
        }
    }
}


Function New-AzurePSSession {
    [CmdletBinding()]Param(
        [Parameter(Mandatory,ValueFromPipeline)][string]$dnsName,
        $credential = (Get-Credential) 
    )
    
    if($dnsName -notlike "*.cloudapp.net") {
        $dnsName = "$dnsName.cloudapp.net"
    }

    try {
        $pssession = New-PSSession -ComputerName $dnsName -Port 5986 -Credential $credential -UseSSL
        return $pssession
    }
    #TODO Catch not working!!!
    catch <#[System.Management.Automation.Remoting.PSRemotingTransportException]#> {
        switch -Wildcard ($_.Message) {
            "*The WinRM client cannot process the request because the server name cannot be resolved.*" {
                Throw "Either the virtual machine is off or the port, '5986', is incorret."
            }
        }
    }
}

Function Reset-AzureVMCredentials {
    [CmdletBinding()] Param (
        [string]$serverURL,
        [PSCredential]$newCredential
    )

    $password = Get-CredentialPassword($newCredential)

    get-azurevm $serverURL | Set-AzureVMAccessExtension -UserName $newCredential.UserName -Password $password |Update-AzureVM
}

Function Import-AzureVMCertificate {
<#
    .SYNOPSIS
        Import the Azure Virtual Machine Certificate
#>
    [CmdletBinding()]Param(
        #The specific virtual machine from which the certificate should be imported.
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="InputObject")][Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleContext]$inputObject,
        #Cloud Service name/DNS name for your VM (without the .cloudapp.net part)
        [Parameter(Mandatory,ParameterSetName="ServiceName")][string]$serviceName
    )

    switch ($PsCmdlet.ParameterSetName) 
    { 
        "InputObject"  { $azureVM = $inputObject; break} 
        "ServiceName"  { $azureVM = Get-AzureVM -ServiceName $serviceName; break} 
    } 

    try{
        $tempFile = [IO.Path]::GetTempFileName()
        (Get-AzureCertificate -ServiceName $azureVM.ServiceName -Thumbprint $azureVM.VM.DefaultWinRmCertificateThumbprint -ThumbprintAlgorithm SHA1).Data | 
            Out-File $tempFile
 
        $X509Object = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $tempFile
        $X509Store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
        
        try {    
            $X509Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
            $X509Store.Add($X509Object)
        }
        finally {
            $X509Store.Close()
        }
    }
    finally {
        Remove-Item $tempFile
    }
}


#TODO: Move to somewhere more general
Function Get-CredentialPassword{
    [CmdletBinding()] param (
        [Parameter(Mandatory,ValueFromPipeline)][PSCredential]$credential
    )

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    return $password;
}



Return

Function Register-AzurePublishSettings {
    #Incomplete
    [CmdletBinding()]Param(
        [string]$publishSettingsFilePath = (Join-Path $env:ALLUSERSPROFILE "Azure.publishsettings")
    )
        if(!$publishSettingsFilePath) {
            Get-AzurePublishSettingsFile
            $publishSettingsFilePath = Read-Host -Prompt "Enter the path to the downloaded publishSettings file:"
        }
        Import-AzurePublishSettingsFile $publishSettingsFilePath
        Set-AzureService
        Write-Warning "More stuff needed in order to support 'Get-AzureCertificate'"
        # See  see http://michaelwasham.com/windows-azure-powershell-reference-guide/getting-started-with-windows-azure-powershell/
}

Function Get-AzureStarted {
    #see http://blogs.technet.com/b/heyscriptingguy/archive/2013/06/22/weekend-scripter-getting-started-with-windows-azure-and-powershell.aspx
    Add-AzureRmAccount
    Add-AzureAccount
}

Funcation Deploy-ServiceFabbricApps {
    [CmdletBinding()]
    Param(
        [string[]]$projects
    )

}
Connect-ServiceFabricCluster vestafabric.westus.cloudapp.azure.com:19000;

$projects = $("Services.PropertyListing", "Services.ContactManagement", "Services.NeighborhoodDna", "App.Mobile", "App.Web");

foreach ($project in $projects) {
	cd "..\Dev\Vesta\$project.ServiceFabric\";

	.\Scripts\Deploy-FabricApplication.ps1 `
		-ApplicationPackagePath .\pkg\Release `
		-PublishProfileFile .\PublishProfiles\Cloud.xml `
		-DeployOnly:$false `
		-UnregisterUnusedApplicationVersionsAfterUpgrade $false `
		-ForceUpgrade $false `
		-OverwriteBehavior 'Always' `
		-ErrorAction Stop `
		-UseExistingClusterConnection:$true;

	cd ..\..\..\Tools;
}


Function Write-AzureVMSnapshop {
# Set variable values
$resourceGroupName = "WindTalkerVMs"
$location = "West US"
$vmName = "WindTalker1"
$vmSize = "Standard_D1_V2"
$vnetName = "WindTalkerVMs"
$nicName = "windtalker155"
$dnsName = "windtalker1"
$diskName = "WindTalker12016124135052"
$storageAccount = "windtalkervms"
$storageAccountKey = "BJsrdNm+q10r0WK0E95SF+whF0zXzGKoa4nGT7UfkvoBFJ7qxSxnATUvkgp1VL+LdEAMifhmlhYDxyXjOq68eQ=="
$subscriptionName = "Visual Studio Enterprise with MSDN"
$publicIpName = "WindTalker1"

$diskBlob = "$diskName.vhd"
$backupDiskBlob = "$diskName-backup.vhd"
$vhdUri = "https://$storageAccount.blob.core.windows.net/vhds/$diskBlob"
$subnetIndex = 0

# login to Azure
Add-AzureRmAccount
Set-AzureRMContext -SubscriptionName $subscriptionName

# create backup disk if it doesn't exist
# Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName -Force -Verbose

$ctx = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccountKey
$blobCount = Get-AzureStorageBlob -Container vhds -Context $ctx | where { $_.Name -eq $backupDiskBlob } | Measure | % { $_.Count }

if ($blobCount -eq 0)
{
  $copy = Start-AzureStorageBlobCopy -SrcBlob $diskBlob -SrcContainer "vhds" -DestBlob $backupDiskBlob -DestContainer "vhds" -Context $ctx -Verbose
  $status = $copy | Get-AzureStorageBlobCopyState 
  $status 

  While($status.Status -eq "Pending"){
    $status = $copy | Get-AzureStorageBlobCopyState 
    Start-Sleep 10
    $status
  }
}

# delete VM
Remove-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName -Force -Verbose
Remove-AzureStorageBlob -Blob $diskBlob -Container "vhds" -Context $ctx -Verbose
Remove-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $resourceGroupName -Force -Verbose
Remove-AzureRmPublicIpAddress -Name $publicIpName -ResourceGroupName $resourceGroupName -Force -Verbose

# copy backup disk
$copy = Start-AzureStorageBlobCopy -SrcBlob $backupDiskBlob -SrcContainer "vhds" -DestBlob $diskBlob -DestContainer "vhds" -Context $ctx -Verbose
$status = $copy | Get-AzureStorageBlobCopyState 
$status 

While($status.Status -eq "Pending"){
  $status = $copy | Get-AzureStorageBlobCopyState 
  Start-Sleep 10
  $status
}

# recreate VM
$vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName

$pip = New-AzureRmPublicIpAddress -Name $publicIpName -ResourceGroupName $resourceGroupName -DomainNameLabel $dnsName -Location $location -AllocationMethod Dynamic -Verbose
$nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $resourceGroupName -Location $location -SubnetId $vnet.Subnets[$subnetIndex].Id -PublicIpAddressId $pip.Id -Verbose
$vm = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize
$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id
$vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $vhdUri -CreateOption attach -Windows

New-AzureRmVM -ResourceGroupName $resourceGroupName -Location $location -VM $vm -Verbose

}


Function Copy-AzureVMBlob {
# https://azure.microsoft.com/en-us/blog/migrate-azure-virtual-machines-between-storage-accounts/
function Copy-AzureVMBlob{
    param(
            [Parameter(Mandatory=$true)]
            [string] $destinationStorageAccountName,
            [Parameter(Mandatory=$true)]
            [string] $destinationKey,
            [Parameter(Mandatory=$true)]
            [string] $destinationContainerName,
            [string] $blobName = "windvmtim1-os-2016-02-22-7339A30E.vhd"
        )

    $servicename = "windvm08"
    $vmname = "windvm08"
    Get-AzureVM -ServiceName $servicename -Name $vmname | Stop-AzureVM

    # Source Storage Account Information #
    $sourceStorageAccountName = "windtalkerstorage"
    $sourceKey = "ZYtqb0Gazjd3steBjNvTF0oM1T/iYYwJ0UaK7RpQa0QsX2xNGTHcKwqFhfFj9jiIYIhZw/8ETV5FNpg5Djl+Sw=="
    $sourceContext = New-AzureStorageContext –StorageAccountName $sourceStorageAccountName -StorageAccountKey $sourceKey  
    $sourceContainer = "vhds"

    # Destination Storage Account Information #
    
    $destinationContext = New-AzureStorageContext –StorageAccountName $destinationStorageAccountName -StorageAccountKey $destinationKey  

    # Create the destination container #    
    New-AzureStorageContainer -Name $destinationContainerName -Context $destinationContext 

    # Copy the blob # 
    $blobCopy = Start-AzureStorageBlobCopy -DestContainer $destinationContainerName `
                            -DestContext $destinationContext `
                            -SrcBlob $blobName `
                            -Context $sourceContext `
                            -SrcContainer $sourceContainer
}

function Create-DiskFromVhd{
    param(
        [Parameter(Mandatory=$true)]
        [string] $diskName = "myMigratedTestVM",
        [string] $os = "Windows",
        [Parameter(Mandatory=$true)]
        [string] $mediaLocation
        
    )
    Add-AzureDisk -DiskName $diskName `
            -OS $os `
            -MediaLocation $mediaLocation `
            -Verbose
}

Function Restore-AzureVMSnapshot {
param([string]$SourceConnectionString = "Data Source=tcp:ordinotest.database.windows.net,1433; Initial Catalog=OrdinoTest; User ID=OrdinoTest@OrdinoTest;Password=1qaz@WSX;Trusted_Connection=False;Encrypt=True;Connection Timeout=30; MultipleActiveResultSets=False;", 
      [string]$DestConnectionString = "Data Source=(Localdb)\ProjectsV12;Initial Catalog=OrdinoDev;Integrated Security=True;Connection Timeout=300;MultipleActiveResultSets=False", 
      [string]$SourceDatabaseName = "OrdinoTest",
      [string]$DestDatabaseName = "OrdinoDev",
      [string]$SourceOutputFile = "C:\Temp\Hagadon\backup.bacpac", 
      [string]$SqlInstallationFolder = "C:\Program Files (x86)\Microsoft SQL Server")
      
# Load DAC assembly.
$DacAssembly = "$SqlInstallationFolder\120\DAC\bin\Microsoft.SqlServer.Dac.dll"
Write-Host "Loading Dac Assembly: $DacAssembly"
Add-Type -Path $DacAssembly
Write-Host "Dac Assembly loaded."

# Initialize Dac service.
$now = $(Get-Date).ToString("HH:mm:ss")
$Services = new-object Microsoft.SqlServer.Dac.DacServices $SourceConnectionString
if ($Services -eq $null)
{
    exit
}

# Start the actual export.
Write-Host "Starting backup at $SourceDatabaseName at $now"
$Watch = New-Object System.Diagnostics.StopWatch
$Watch.Start()
$Services.ExportBacpac($SourceOutputFile, $SourceDatabaseName)
$Watch.Stop()
Write-Host "Backup completed in" $Watch.Elapsed.ToString()

# Initialize Dac service.
$now = $(Get-Date).ToString("HH:mm:ss")
$Services = new-object Microsoft.SqlServer.Dac.DacServices $DestConnectionString
if ($Services -eq $null)
{
    exit
}

# Start the actual restore.
Write-Host "Starting restore to $DestDatabaseName at $now"
$Watch = New-Object System.Diagnostics.StopWatch
$Watch.Start()
$Package =  [Microsoft.SqlServer.Dac.BacPackage]::Load($SourceOutputFile)
$Services.ImportBacpac($Package, $DestDatabaseName)
$Package.Dispose()
$Watch.Stop()
Write-Host "Restore completed in" $Watch.Elapsed.ToString()
}
}