# IntelliTect.AzureRM
A set of scripts for working with Azure RM resources.  Available on PowerShell Gallery at https://www.powershellgallery.com/packages/IntelliTect.AzureRm.

## Installation
To install any of the IntelliTect.PSToolbox modules, you need the latest version of the PowerShellGet module. If you have Windows 10, you already have it.
Otherwise, instructions may be found at https://www.powershellgallery.com/GettingStarted?section=Get%20Started, or you may also run Setup.ps1 inside 
the IntelliTect.PSToolbox repository to attempt to automatically install needed dependencies.

Once you are all set up, run `Install-Module IntelliTect.AzureRM` to install the latest version. 

## Examples
* Creating a new Azure RM virtual machine.
..* New-AzureRmVirtualMachine -VMName "MyVirtualMachine" -ResourceGroupName "MyVMs"
..* Script will prompt the user to select Azure options, i.e., subscription, location, VM size, VM Sku, etc.

* Enabling remote PowerShell on an Azure RM virtual machine.
..* Enable-RemotePowerShellOnAzureRmVm -VMName "MyVirtualMachine" -ResourceGroupName "MyVMs"
..* A script will be generated, uploaded and executed on the VM, where it will make necessary changes to settings to allow for remove PowerShell sessions.

* Prompting users for Azure RM resource choices
..* Get-AzureRmSubscriptionMenu
..* Get-AzureRmLocationMenu
..* Get-AzureRmVmImagePublisherMenu
..* Get-AzureRmVmImageOfferMenu
..* Get-AzureRmVmImageSkuMenu
..* Get-AzureRmVmSizeMenu
..* Menu calls will return the selected value.
..* An instance of AzureRmVmInputs (created with New-AzureRmVmInput) can be used to provide dependent selections and capture the selected value. 