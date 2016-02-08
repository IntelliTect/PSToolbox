#Invoke-Pester C:\data\scc\W540\IntelliTect.vs.com\1\SPIdeation\DEV\PSDefault\Functions.Tests\TFS.Tests.ps1 "Export/Import"

$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

$Credential = Get-CredentialManagerCredential.ps1 "IntelliTect.VisualStudio.com"

Describe "Get-TfsQuery" {
    It "Get List" {
        $results = Get-TfsQuery -collection "https://IntelliTect.visualstudio.com/defaultcollection" $Credential -Project "Hagadone"
        $queryNames = $results | Select -ExpandProperty name 
        Write-Host $queryNames
        $queryNames -contains "Current Sprint" | Should Be $true
    }
    It "Get 'Current Sprint' query" {
        $result = Get-TfsQuery "https://IntelliTect.visualstudio.com/defaultcollection" $Credential -Project "Hagadone" -Filter "Current Sprint"
        $result.name | Should Be "Current Sprint"
    }
}

Describe "Get-TfsWorkItemId" {
    It "Get All Id" {
        [int[]] $ids = Get-TfsWorkItemId "https://IntelliTect.visualstudio.com/defaultcollection" $Credential -Project "Hagadone"
        $ids.Count -gt 0 | Should Be $true
        Write-Host $ids
    }
}

Describe "Get-TfsWorkItem" {
    It "Get one work item" {
        $result = Get-TfsWorkItem "https://IntelliTect.visualstudio.com/defaultcollection" $Credential -Project "Hagadone" -workItemIds 5000
        $result.fields[0].field.name | Should Be "ID"
        $result.fields[0].value | Should Be 5000
    }
}

Describe "Export/Import" {
    It "Export" {
        $query = Get-TfsQuery "https://IntelliTect.visualstudio.com/defaultcollection" $Credential -Project "Hagadone" -Filter "ProductBacklogItems for Export"
        Write-Host $query
        $query.name | Should Be "ProductBacklogItems for Export"
        [int[]]$workItemIds = Get-TfsWorkItemId "https://IntelliTect.visualstudio.com/defaultcollection" $Credential -Project "Hagadone" -QueryId "b9143c52-c560-413b-9c25-a67e6bf03e99"
        $workItems = Get-TfsWorkItem "https://IntelliTect.visualstudio.com/defaultcollection" $Credential -Project "Hagadone" -workItemIds $workItemIds `
            -fields System.Title,Microsoft.Vsts.Common.BacklogPriority,System.State,System.Description,System.WorkItemType,System.AreaPath,System.IterationPath,Microsoft.VSTS.Common.AcceptanceCriteria,Microsoft.VSTS.Scheduling.Effort
        #$hagadoneCredential = Get-CredentialManagerCredential.ps1 "Hagadone.VisualStudio.com"
        foreach($workItem in $workItems) {
            try {
                for($counter=0;$counter -lt $workItem.fields.count-1;$counter++) {                
                    if($workItem.fields[$counter].field.refName -in "System.IterationPath") {
                        $workItem.fields[$counter].value = $workItem.fields[$counter].value -replace "Hagadone\Sprint","Hagadone\Release 1\Sprint"
                    }
                }
                $ignore = ($workItem.fields | ?{ $_.field.refName -in "System.State" } | Select -ExpandProperty value) -eq "Removed"
                if(!$ignore) {
                    $newWorkItem = New-TfsWorkItem "https://Hagadone.visualstudio.com/defaultcollection" "Ticketing" $Credential $workItem 
                    Write-Host $newWorkItem
                }
            } 
            catch [System.ArgumentException] { 
                if($_.Exception.Message -like "Work item * already exists*") {
                    Write-Warning $_.Exception.Message
                }
                else {
                    Throw
                }
            }
        }
    }
}

