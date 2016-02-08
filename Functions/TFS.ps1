Set-StrictMode -Version Latest

Function Script:Get-TfsRestCredentialHeaders {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][PSCredential]$credential
    ) 
    $username = $credential.GetNetworkCredential().username
    $password = $credential.GetNetworkCredential().password
 
    $basicAuth = ("{0}:{1}" -f $username,$password)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    $headers = @{Authorization=("Basic {0}" -f $basicAuth)}
    return $headers
}


Function Get-TfsQuery { 
    [CmdletBinding()] param( 
        [Parameter(Mandatory)][string] $collection, 
        [Parameter(Mandatory)][PSCredential]$credential, 
        [Parameter(Mandatory)][string]$project, 
        [string]$Filter = "*", 
        [string]$Url
    ) 
    $headers = Script:Get-TfsRestCredentialHeaders $credential

    if(!$url) {
        $Url = "$collection/_apis/wit/queries?project=$project"
    }

    $RootRestResult = Invoke-RestMethod -Uri $Url -headers $headers -Method Get -Verbose # -Body $body -ContentType "application/json"
    $queries = $RootRestResult.value | ?{$_.value.Count -gt 0} | %{ $_.value | Add-Member -NotePropertyName "Folder" -NotePropertyValue $_.name; $_.value }
    $queries = $queries | ?{ $_.name -like $filter } 
    return $queries
}

Function Get-TfsWorkItemId {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][string] $collection, 
        [Parameter(Mandatory)][string]$Project, 
        [Parameter(Mandatory)][PSCredential]$credential, 
        [string]$Url = $null,
        [Guid]$QueryId,
        [string]$TitleFilter,
        [string]$isActive = $true
    ) 

    if($QueryId) {
        $hash = @{
            Id = $QueryId}
    } 
    else {
        $query = “Select [System.Id] From WorkItems WHERE [System.TeamProject] = @project”
        if($TitleFilter) {
            $query += " AND [System.Title] = `"$TitleFilter`""
        }
        if($isActive) {
            $query += " AND [System.State] <> `"Removed`""
        }
        $hash = @{ 
            wiql = $query}
    }

    [string]$body = ConvertTo-Json $hash

    $headers = Script:Get-TfsRestCredentialHeaders $credential
    [int[]]$workItemIds =  Invoke-RestMethod -Uri "$collection/_apis/wit/queryresults?@project=$Project" -headers $headers -Method Post -Verbose -Body $body -ContentType "application/json" | 
        Select -ExpandProperty Results | Select -ExpandProperty sourceId

    return $workItemIds
}

Function Get-TfsWorkItem {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][string]$Project, 
        [Parameter(Mandatory)][string] $collection, 
        [Parameter(Mandatory)][PSCredential]$credential, 
        [string]$Url = $null,
        [Parameter(Mandatory, ValueFromPipeline=$true)][int]$workItemIds,
        [string[]]$fields
    ) 

    #ToDO - clean up.
    [string]$workItemIdsText = $workItemIds -join ","
    $uri = "https://IntelliTect.visualstudio.com/defaultcollection/_apis/wit/workitems?ids=$workItemIdsText"
    if($fields) {
        $uri += "&fields=$($fields -join `",`")"
    }

    $headers = Script:Get-TfsRestCredentialHeaders $credential
    $result = Invoke-RestMethod -Uri $uri -headers $headers -Verbose
    #Return Invoke-RestMethod -Uri "$collection/_apis/wit/workitems/99" -headers $headers -Method Get
    return $result.value
}


#$Credential = Get-CredentialManagerCredential.ps1 IntelliTect.VisualStudio.com
#Get-WorkItem "HTTPS://IntelliTect.VisualStudio.com/DefaultCollection" $Credential "https://{account}.visualstudio.com/defaultcollection/_apis/wit/queryresults"

<# Function Copy-TfsWorkItem(
        [Parameter(Mandatory)][string]$sourceProject, 
        [Parameter(Mandatory)][string] $sourceCollection, 
        [Parameter(Mandatory)][PSCredential]$sourceCredential, 
        [Parameter(Mandatory)][string]$targetProject, 
        [Parameter(Mandatory)][string] $targetCollection, 
        [Parameter(Mandatory)][PSCredential]$targetCredential, 
        [string]$workItemFieldsInJson
    ) { 
    $soureHeaders = Script:Get-TfsRestCredentialHeaders $sourceCredential
    $targetHeaders = Script:Get-TfsRestCredentialHeaders $targetCredential

} #>

Function New-TfsWorkItem {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][string]$Collection,
        [Parameter(Mandatory)][string]$Project,
        [Parameter(Mandatory)][PSCredential]$Credential, 
        [Parameter(Mandatory)][PSCustomObject]$workItem
    ) 

    $title = $workItem.fields | ?{ $_.field.refName -eq "System.Title"} | Select -ExpandProperty value;
    $existingWorkItemIds = Get-TfsWorkItemId -collection $collection -Project $Project -credential $credential -TitleFilter $title
    if($existingWorkItemIds.Count -gt 0) {
        #try {
        Throw  [System.ArgumentException] "Work item `"$title`" already exists `(see Work Item id#(s): $($existingWorkItemIds -join ", ")`)"
        <#}
        catch [System.ArgumentException] {
            $exception = $_
            Throw
        }#>
    }

    #Freezes so using for loop instead.
    for($counter=0;$counter -lt $workItem.fields.count-1;$counter++) {
        if($workItem.fields[$counter].field.refName -in "System.IterationPath","System.AreaPath") {
            $workItem.fields[$counter].value = $workItem.fields[$counter].value -replace "^[^\\]+","$Project"
        }
        elseif($workItem.fields[$counter].field.refName -in ,"System.TeamProject") {
            $workItem.fields[$counter].value = $Project 
        }
        #Remove all field entries except the refName.
        $workItem.fields[$counter].field = @{ refName=$workItem.fields[$counter].field.refName }
    }
    $workItem.fields[$workItem.fields.count-1].field = @{ refName=$workItem.fields[$counter].field.refName }
    $workItem.fields += [PSCustomObject] @{ field=@{ refName='System.Reason'; }; value='New backlog item' }

    $body = @"
        { `"fields`": 
            $($workItem.fields | ConvertTo-Json) 
                 
         }
"@

    try {
        $headers = Script:Get-TfsRestCredentialHeaders $credential
        $result = Invoke-RestMethod -Uri "$collection/_apis/wit/workitems" -headers $headers -Method Post -Body $body -ContentType "application/json" -Verbose
    }
    catch [System.InvalidOperationException] {
        if ($_.ErrorDetails) {
            $jsonException = ($_.ErrorDetails.Message | ConvertFrom-Json).exception 
        }
        Write-Verbose $body
        if( ($jsonException) `
                -AND ( $jsonException.Message -like "TF*") `
                -AND ($jsonException.ClassName -like "*TeamFoundation*") ) {
                $exception = New-Object System.Exception "$($_.Exception.Message): $($jsonException.Message)",$_.Exception
                Throw $exception
        }
        else {
            #Wrap in an exception otherwise ToString() buries the message.
            $exception = New-Object System.Exception "$($_.Exception.Message)",$_.Exception
            Throw $exception
        }
    }
    return $result;
}