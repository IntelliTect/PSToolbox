
Function Invoke-DropboxApiRequest {
    [CmdletBinding()] param(
        [string] $AuthToken,
        [string] $Endpoint,
        [object] $Body
    )

    $response = Invoke-WebRequest `
        -Method Post `
        -Uri "https://api.dropboxapi.com/2/$Endpoint" `
        -Headers @{"Authorization" = "Bearer $AuthToken"} `
        -ContentType "application/json" `
        -Body (ConvertTo-Json $Body)

    if ($response.Content){
        return ConvertFrom-Json $response.Content
    }

    return $response
}


Function Invoke-DropboxApiDownload {
    [CmdletBinding()] param(
        [string] $AuthToken,
        [object] $Path,
        [string] $OutFile
    )

    $OutFile = Join-Path (pwd) $OutFile
    $dir = ([System.IO.FileInfo]$OutFile).Directory
    if (!$dir.Exists) { 
        $dir.Create()
    }    

    $response = Invoke-WebRequest `
        -Method Post `
        -Uri "https://content.dropboxapi.com/2/files/download" `
        -Headers @{"Authorization" = "Bearer $AuthToken"; "Dropbox-API-Arg" = "{`"path`": `"$Path`"}"} `
        -ContentType "" `
        -OutFile $OutFile

    return $response
}


Function Get-DropboxFileRevisions {
    [CmdletBinding()] param(
        [string] $AuthToken,
        [string] $Path = ""
    )

    $body = @{
        "path" = $Path;
        "limit" = 10
    }
    return Invoke-DropboxApiRequest -Endpoint "files/list_revisions" -Body $body -AuthToken $AuthToken

}


Function Get-DropboxDirectoryContents {
    [CmdletBinding()] param(
        [string] $AuthToken,
        [string] $Path = "",
        [string] $Cursor = $null
    )

    $body = @{
        "path" = $Path;
        "recursive" = $true;
        "include_deleted" = $true;
    }

    $continueUrlPart = ""
    if ($Cursor) {
        $continueUrlPart = "/continue"
        $body = @{
            "cursor" = $Cursor
        }
    }

    $content = Invoke-DropboxApiRequest -Endpoint "files/list_folder$continueUrlPart" -Body $body -AuthToken $AuthToken
    
    return $content
}


<#
    .SYNOPSIS
    Takes a Dropbox folder structure and converts it into a git repository.

    .DESCRIPTION
    The provided path and all subfolders and files will be analyzed, and a git repository will be created
    that represents the historical information of the Dropbox revision history.

    Paths can be excluded using a wildcard format.

    .PARAMETER AuthToken
    A Dropbox auth token that can be obtained by following the instructions at https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/

    .PARAMETER Path
    The path in your Dropbox account that you wish to convert to a git repository.
    This is relative to your root folder, and should begin with a forward-slash (/).
    If you wish to convert your entire Dropbox account to a git repository, leave this parameter empty - do not use a single slash.

    .PARAMETER PathExcludes
    A list of wildcard patterns that will be compared against each file in Dropbox in the path.
    If the Dropbox path name matches any of these patterns, it will be ignored.

    .EXAMPLE
    To only convert files within a directory named MyFiles while excluding any subfolders:
    Invoke-ConvertDropboxToGit -AuthToken "<token>" -Path "/MyFiles" -PathExcludes "/MyFiles/*/*"


    .LINK
    https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/

#>
Function Invoke-ConvertDropboxToGit {
    [CmdletBinding()] param(
        [string] $AuthToken = $(Read-Host -prompt @"
        Enter your Dropbox access token.  To get a token, follow the steps at
        https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/
"@),
        [string] $Path = "",
        [string[]] $PathExcludes = (new-object string[] 0)
    )

    $history = @{}
    $head = New-Object System.Collections.ArrayList
    
    $cursor = $null
    $hasMore = $true
    $objectCount = 0
    while ($hasMore -eq $true){
        $content = Get-DropboxDirectoryContents -Path $Path -Cursor $cursor -AuthToken $AuthToken

        $objectCount = $objectCount + $content.entries.Count
        Write-Host "Got $objectCount object metadatas so far"


        foreach ($fileEntry in $content.entries) {
            if ($fileEntry.".tag" -eq "file" -or $fileEntry.".tag" -eq "deleted"){
                $matchedExcludes = $PathExcludes | where {$fileEntry.path_lower -like $_}
                if ($matchedExcludes.Count -eq 0) {
                    [object[]]$revisions = Get-DropboxFileRevisions -Path $fileEntry.path_lower -AuthToken $AuthToken
                    

                    $revisionEntries = $revisions.entries | Sort-Object client_modified,server_modified -Descending

                    $null = $head.Add($fileEntry)

                    foreach ($oldEntry in $revisionEntries) {
                        if (!$history.ContainsKey($oldEntry.client_modified)){
                            $null = $history.Add($oldEntry.client_modified, (New-Object System.Collections.ArrayList))
                        }
                        $null = $history[$oldEntry.client_modified].Add($oldEntry)
                    }
                }
            }
        }


        $cursor = $content.cursor
        $hasMore = $content.has_more
    }

    if ($objectCount -eq 0) {
        Write-Warning "No files were found. Exiting."
        return;
    }


    $dirName = "DropboxHistoryBuild $((Get-Date -Format u).Replace(':', '-'))"
    md -Name "$dirName"
    cd "./$dirName"
    git init 

    
    $userInfos = @{}
    foreach ($entry in $history.GetEnumerator() | Sort-Object -Property Key) {
        foreach ($revisionEntry in $entry.Value) {
            $outFile = Join-Path "." $revisionEntry.path_display
            Invoke-DropboxApiDownload -Path "rev:$($revisionEntry.rev)" -OutFile $outFile -AuthToken $AuthToken
        }
        $date = (([DateTime]$entry.Key).ToString("yyyy-MM-dd HH:mm:ss"))
        
        git add -A

        $authorId = $entry.Value[0].sharing_info.modified_by
        if ($authorId) {
            if (!$userInfos.ContainsKey($authorId)) {
                $userInfos[$authorId] = Invoke-DropboxApiRequest -Endpoint "users/get_account" -Body @{"account_id" = "$authorId"}  -AuthToken $AuthToken
            }
            $userInfo = $userInfos[$authorId]

            git commit -m "Revisions made $date" --date $date --author "$($userInfo.name.display_name) <$($userInfo.email)>"
        }
        else {
            git commit -m "Revisions made $date" --date $date
        }

    }

    foreach ($entry in $head){
        $outFile = Join-Path "." $entry.path_display
        if ($entry.".tag" -eq "deleted"){
            rm $outFile
        }
    }
    
    git add -A
    git commit -m "All Dropbox Deletions - Dropbox does not report deletion times."
    git tag dropbox-final

    cd ..
}