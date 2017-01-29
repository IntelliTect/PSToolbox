$script:progressIdStack = New-Object System.Collections.Generic.Stack[int]
$script:progressNextId = 1

Function script:Invoke-DropboxApiRequest {
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


Function script:Invoke-DropboxApiDownload {
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


Function script:Get-DropboxFileRevisions {
    [CmdletBinding()] param(
        [string] $AuthToken,
        [string] $Path = ""
    )

    $body = @{
        "path" = $Path;
        "limit" = 100
    }

    try {
        $response = Invoke-DropboxApiRequest -Endpoint "files/list_revisions" -Body $body -AuthToken $AuthToken
        return $response
    }
    catch {
        if ($_.ErrorDetails.Message.Contains("path/not_file")) {
            Write-Information "$Path appears to be a deleted folder."
            return @{ entries = @(); } 
        } else {
            throw 
        }
    }

}


Function script:Get-DropboxDirectoryContents {
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
    Retrieves the dropbox folder history.

    .DESCRIPTION
    Retrieves dropbox revision history and returns it as a hashtable.

    .PARAMETER AuthToken
    A Dropbox auth token that can be obtained by following the instructions at https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/

    .PARAMETER Path
    The path in your Dropbox account. This is relative to your root folder, and should begin with a forward-slash (/).
    If you wish to retrieve your entire Dropbox account, leave this parameter empty - do not use a single slash.

    .PARAMETER PathExcludes
    A list of wildcard patterns that will be compared against each file in Dropbox in the path.
    If the Dropbox path name matches any of these patterns, it will be ignored.

    .EXAMPLE
    To only retrieve files within a directory named MyFiles while excluding any subfolders:
    $history = Invoke-DropboxHistory -AuthToken "<token>" -Path "/MyFiles" -PathExcludes "/MyFiles/*/*"


    .LINK
    https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/

#>
Function Get-DropboxHistory {
    [CmdletBinding()] param(
        [string] $AuthToken = $(Read-Host -prompt @"
        Enter your Dropbox access token.  To get a token, follow the steps at
        https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/
"@),
        [string] $Path = "",
        [string[]] $PathExcludes = (new-object string[] 0)
    )
try { $Activity = "Get-DropboxHistory";$parentId=$script:progressIdStack.Push($id);$Id = $script:progressNextId++;$script:progressIdStack.Push($id)

    # TODO: Provide more examples including ones that consume the history.
    

    Write-Progress -Activity $Activity -Id $id -ParentId $parentId


    # Change '\' to '/', prefix with '/' and remove trailing '/'
    if($path.Contains('\')) { $Path = $Path.Replace('\','/') }
    if($path[0] -ne '/') { $Path = "/$Path" }
    if($path[-1] -eq '/') { $Path = $Path.TrimEnd('/')}

    $history = @{}
    $head = New-Object System.Collections.ArrayList
    $cursor = $null
    $hasMore = $true
    $objectCount = 0
    while ($hasMore -eq $true){
        # Dropbox's API returns up to 2000 file listings at once.
        # If there are more than that, a cursor is returned which can be passed to another call
        # in order to get more results. Loop until we've found all the file listings.
        Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Get Dropbox File List..."
        $content = Get-DropboxDirectoryContents -Path $Path -Cursor $cursor -AuthToken $AuthToken

        $objectCount = $objectCount + $content.entries.Count
        Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Get Dropbox File List..." -CurrentOperation "Got $objectCount file listings so far"

        foreach ($fileEntry in $content.entries) {
            Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Get file revisions" -CurrentOperation $fileEntry.path_Display
            # We only care about files, not directories. "deleted" represents a deleted file.
            if ($fileEntry.".tag" -eq "file" -or $fileEntry.".tag" -eq "deleted"){

                # Examine the file's path to see if it should be excluded.
                $matchedExcludes = $PathExcludes | Where-Object {$fileEntry.path_lower -like $_}
                if (!$matchedExcludes -or $matchedExcludes.Count -eq 0) {
                    # If the file passed the exclusion filter, grab the metadata about the revisions of the file.
                    [object[]]$revisions = Get-DropboxFileRevisions -Path $fileEntry.path_lower -AuthToken $AuthToken

                    $subpathDisplay = ($fileEntry.path_display -replace "(?i)^$([Regex]::Escape("$Path/"))","/") 
                    Add-Member -InputObject $fileEntry -TypeName "DropboxContentItem" -Name "subpath_display" -MemberType NoteProperty -Value $subpathDisplay

                    # Store the file's metadata in $head, and then
                    # store data about each revision of the file into a dictionary keyed by the date of the file.
                    # TODO: consider changing to only store deletes.
                    $null = $head.Add($fileEntry)

                    
                    foreach ($revision in $revisions.entries) { 
                        if (!$history.ContainsKey($revision.client_modified)){
                            $null = $history.Add($revision.client_modified, (New-Object System.Collections.ArrayList))
                        }
                        $subpathDisplay = ($fileEntry.path_display -replace "(?i)^$([Regex]::Escape("$Path/"))","/") 
                        Add-Member -InputObject $revision -TypeName "DropboxFileRevision" -Name "subpath_display" -MemberType NoteProperty -Value $subpathDisplay
                        $null = $history[$revision.client_modified].Add($revision)
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

    return $history,$head    
} finally {$script:progressNextId--; $script:progressIdStack.Pop();}
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
    [CmdletBinding(DefaultParametersetName="DropBoxConfig")] 
    param(
        [Parameter(Mandatory, ParameterSetName="DropBoxConfig")][string] $AuthToken = $(Read-Host -prompt @"
        Enter your Dropbox access token.  To get a token, follow the steps at
        https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/
"@),
        [Parameter(Mandatory, ParameterSetName="DropBoxConfig")][string] $Path = "",
        [Parameter(ParameterSetName="DropBoxConfig")][string[]] $PathExcludes = (new-object string[] 0),
        [Parameter(ParameterSetName="DropBoxConfig")][ValidateScript({Test-Path $_ -PathType Container })][string] $OutputDirectory,
        [Parameter(ParameterSetName="DropBoxHistory")] $history,
        [Parameter(ParameterSetName="DropBoxHistory")] $head
        # TO DO: Add [bool]$CaseSensitiveGit
    )
    
try { $Activity = "Invoke-ConvertDropboxToGit";$Id = $script:progressNextId++;$script:progressIdStack.Push($id)

    Write-Progress -Activity $Activity -Id $id -ParentId $parentId
    
    if($PsCmdlet.ParameterSetName -ne "DropBoxHistory") {
        Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Get-DropBoxHistory"
        # When we're done grabbing metadata, will will loop through this dictionary in order of its keys
        # to construct our git repo.
        $history,$head = Get-DropBoxHistory $AuthToken $Path $PathExcludes -ParentId $id
    }
     
    # Unfortunately, we have to change our working directory because git doesn't allow you to target commands to other directories.
    try {
        Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Initialize Git Repository"
        $originalLocation = Get-Location

        if([string]::IsNullOrEmpty($OutputDirectory)) {
            $OutputDirectory = $pwd
        }
        
        # The name of the folder created is always static.
        $dirName = Join-Path $OutputDirectory "DropboxHistoryBuild $((Get-Date -Format u).Replace(':', '-'))"

        New-Item -ItemType Directory -Path $dirName

        Set-Location $dirName

        git init 

        if ($PSBoundParameters.ContainsKey('CaseSensitiveGit')) {
            git config core.ignorecase $caseSensitiveGit
        }
    
        $userInfos = @{}
        # Loop over our dictionary of revisions in order of the key (which is the date of the revision)
        foreach ($entry in $history.GetEnumerator() | Sort-Object -Property Key) {
            Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Download file from dropbox..." -CurrentOperation $entry.path_display
            # Go out to Dropbox and download the revision of each file that corresponds to this date.
            foreach ($revisionEntry in $entry.Values) {
                $outFile = Join-Path "." ($revisionEntry.subpath_display)
                # TO DO: Test
                #if ([bool](git config core.ignorecase)) {
                #    if( (Test-Path $outFile) -and ($outFile -cne (Resolve-Path (Get-Item $outFile) -Relative)) ) {
                #        git mv (Resolve-Path $outFile).Path $outFile -f
                #    }
                #}
                Invoke-DropboxApiDownload -Path "rev:$($revisionEntry.rev)" -OutFile $outFile -AuthToken $AuthToken
            }
            $date = (([DateTime]$entry.Key).ToString("yyyy-MM-dd HH:mm:ss"))
        

            git add -A
            Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Git Add" -CurrentOperation "$(git status)"

            $authorId = $entry.Value[0].sharing_info.modified_by
            if ($authorId) {
                if (!$userInfos.ContainsKey($authorId)) {
                    # If we haven't seen this userId yet, make a request to get their name and email for the commit metadata.
                    $userInfos[$authorId] = Invoke-DropboxApiRequest -Endpoint "users/get_account" -Body @{"account_id" = "$authorId"}  -AuthToken $AuthToken
                }
                $userInfo = $userInfos[$authorId]

                $gitCommitMessage = git commit -m "Revisions made $date" --date $date --author "$($userInfo.name.display_name) <$($userInfo.email)>"
            }
            else {
                $gitCommitMessage = git commit -m "Revisions made $date" --date $date
            }
            Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Git Commit" -CurrentOperation "$gitCommitMessage" 

        }

        # All file revisions commits have now been made.
        # We will make on last pass through $head and delete every file that Dropbox reports as being deleted.
        # We have to do this at the end because dropbox doesn't report deletion times - only a boolean on if a file is deleted or not.
        # It's not ideal, but it's what we have to work with.
        foreach ($entry in $head){
            $outFile = Join-Path "." $entry.subpath_display
            if ($entry.".tag" -eq "deleted"){
                Remove-Item $outFile
            }
        }
    
        git add -A
        git commit -m "All Dropbox Deletions - Dropbox does not report deletion times."
        git tag dropbox-final

    }
    finally {
        # Move our current directory back up to where we were before we started. We're done!
        Set-Location $originalLocation
    }
}
finally {
    $script:progressNextId--
    $script:progressIdStack.Pop()  
}
}