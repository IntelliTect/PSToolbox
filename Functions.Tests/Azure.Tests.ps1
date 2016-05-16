# Load the script we are going to test
$sut = $PSCommandPath.Replace('.Tests', '')
. $sut

function CreateMocks {
    Mock Get-AzureRmResourceGroup { return @{ ResourceGroupName = 'My Resource Group' } }
    Mock New-AzureRmResourceGroup {}
    Mock Get-AzureRmStorageAccount { return @{ 
        StorageAccountName = 'My Storage Account'
        PrimaryEndpoints = @{ 
            Blob = "Blob URL" 
        }}}
    Mock New-AzureRmStorageAccount {}
    Mock Get-AzureRmVirtualNetwork { return @{ 
        Name = 'My Virtual Network'
        Subnets = @(
            @{ Id = 1 },
            @{ Id = 2 }
        )
    }}
    Mock New-AzureRmVirtualNetwork {}
    Mock New-AzureRmVirtualNetworkSubnetConfig { 
        param($Name) 
        $ret = New-Object 'System.Collections.Generic.List[Microsoft.Azure.Commands.Network.Models.PSSubnet]'
        $ret.Add(@{ Name = $Name })
    }
    Mock New-AzureRmNetworkInterface { param($Name) return @{ 
        Id = 1  
        Name = $Name 
    }}
    Mock New-AzureRmPublicIpAddress { param($Name) return @{ 
        Id = 1
        Name = $Name 
    }}        
    Mock New-AzureRmVMConfig { return @{} }
    Mock Set-AzureRmVMOperatingSystem { return @{} }
    Mock Set-AzureRmVMSourceImage { return @{} }
    Mock Add-AzureRmVMNetworkInterface { return @{} }
    Mock Set-AzureRmVMOSDisk { return @{} }
    Mock New-AzureRmVM {}

    Mock Test-AzureRmDnsAvailability { return $false }

    Mock Get-AzureRmNetworkSecurityGroup { return @{ Id = 1 } }
    Mock New-AzureRMNetworkSecurityGroup { return @{ Id = 1 } }
    Mock Add-AzureRmNetworkSecurityRuleConfig {}
    Mock Set-AzureRmNetworkSecurityGroup {}
}

Describe "New-AzureRMVirtualMachine Unit Tests" {
    Context "All supporting Azure items are created new" {
        CreateMocks

        $newRG = 'My New Resource Group'
        $newSA = 'My New Storage Account'
        $newVN = 'My New Virtual Network'
        
        $result = New-AzureRMVirtualMachine -ResourceGroupName $newRG -VMName 'MyNewVM' -StorageAccountName $newSA -VirtualNetworkName $newVN -ImageSku '2012-Datacenter'
         
        It "Creates a resource group" {
            Assert-MockCalled New-AzureRmResourceGroup -Times 1 -ParameterFilter { $Name -eq $newRG }
        }

        It "Creates a storage account" {
            Assert-MockCalled New-AzureRmStorageAccount -Times 1 -ParameterFilter { $Name -eq $newSA }
        }
        
        It "Creates a virtual network" {
            Assert-MockCalled New-AzureRmVirtualNetwork -Times 1 -ParameterFilter { $Name -eq $newVN }
        }
        
        It "Creates a public IP" {
            Assert-MockCalled New-AzureRmPublicIpAddress -Times 1
        }
        
        It "Creates a network interface" {
            Assert-MockCalled New-AzureRmNetworkInterface -Times 1
        }
        
        It "Succeeds with valid parameters" {
            $result.Success | Should Be $true
        }
    }

    Context "All supporting Azure items already exist" {
        CreateMocks

        $newRG = 'My Resource Group'
        $newSA = 'My Storage Account'
        $newVN = 'My Virtual Network'
        $newDomain = 'existingdomain'

        $result = New-AzureRMVirtualMachine -ResourceGroupName $newRG -VMName 'My New VM' -StorageAccountName $newSA -VirtualNetworkName $newVN -DomainNameLabel $newDomain -ImageSku '2012-Datacenter'

        It "Fails when an existing domain name label is provided" {
            $result.Success | Should Be $false
        }
        
        $result = New-AzureRMVirtualMachine -ResourceGroupName $newRG -VMName 'My New VM' -StorageAccountName $newSA -ImageSku '2012-Datacenter'
        
        It "Does not create a resource group" {
            Assert-MockCalled New-AzureRmResourceGroup -Times 0 -ParameterFilter { $Name -eq $newRG }
        }

        It "Does not create a storage account" {
            Assert-MockCalled New-AzureRmStorageAccount -Times 0 -ParameterFilter { $Name -eq $newSA }
        }
        
        It "Does not create a virtual network" {
            Assert-MockCalled New-AzureRmVirtualNetwork -Times 0 -ParameterFilter { $Name -eq $newVN }
        }
        
        It "Succeeds with valid parameters" {
            $result.Success | Should Be $true
        }
    }
}

$functionalTest = @{
    ResourceGroupName = "danhaleyvm2"
    VMName = "danhaley2"
    ImageSku = "2012-Datacenter"
    StorageAccountName = ""
    VMLocation = "West US"
    StorageAccountType = "Standard_LRS"
    DomainNameLabel = ""
    VirtualNetworkName = ""
    VMSize = "Standard_DS1_v2"
    AdminCredentials = (New-Object PSCredential("vmadmin", ("P@ssword1!" | ConvertTo-SecureString -AsPlainText -Force)))
}

Describe "New-AzureRMVirtualMachine Functional Test" {
    Context "Functional test" {
        if ($functionalTest.ResourceGroupName -eq "")
        {
            Write-Information -MessageData "Test is inconclusive" -InformationAction Continue
            Set-TestInconclusive "Functional test to create a VM has not been run.  Specify resource group, VM name, and image SKU to run functional test."
        }
        else 
        {
            Write-Information -MessageData "Creating a VM - this will take some time" -InformationAction Continue
            $result = New-AzureRMVirtualMachine `
                        -ResourceGroupName $functionalTest.ResourceGroupName `
                        -VMName $functionalTest.VMName `
                        -StorageAccountName $functionalTest.StorageAccountName `
                        -ImageSku $functionalTest.ImageSku `
                        -VMLocation $functionalTest.VMLocation `
                        -StorageAccountType $functionalTest.StorageAccountType `
                        -DomainNameLabel $functionalTest.DomainNameLabel `
                        -VirtualNetworkName $functionalTest.VirtualNetworkName `
                        -VMSize $functionalTest.VMSize `
                        -AdminCredentials $functionalTest.AdminCredentials

            It "Creates a VM on Azure" {
                $result.Success | Should Be $true
            }

            Write-Information -MessageData "Removing test resource group" -InformationAction Continue
            Remove-AzureRmResourceGroup -Name $functionalTest.ResourceGroupName -Force
        }
    }
}

