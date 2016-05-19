Function script:ShouldProcess {
    [CmdletBinding(SupportsShouldProcess=$True)]
    param(
	    [string] $verboseDescription,
	    [string] $verboseWarning,
	    [string] $caption
    )

    
    return $PSCmdlet.ShouldProcess($verboseDescription, $verboseWarning, $caption)
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


    "Azure","AzureRM" | %{ 
        $module = Get-Module $_ -ListAvailable
        if(!$module) {
            Write-Warning "The Azure module is not installed.  To install run 'Choco Install WindowsAzurePowershell'"
            return
        }
        Write-Output $module
    } | Import-Module

    Set-AzureSubscription -SubscriptionName $subscriptionName
}


Function New-AzureVM {
    [CmdletBinding()] Param(
        [Parameter(Mandatory)][string]$imageName
        , [Parameter(Mandatory)][string] $newName
        , [PSCredential] $credential
        , [string] $instanceSize = "Small"
        , [string] $location = "West US"
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