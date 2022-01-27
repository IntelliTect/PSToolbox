Set-StrictMode -version latest

$script:progressIdStack = New-Object System.Collections.ArrayList
$script:progressNextIndex = 0

# See https://www.dropbox.com/developers/documentation/http/documentation for Dropbox HTTP API Documentation

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

    return [PSCustomObject]$response
}


Function script:Invoke-DropboxApiDownload {
    # Not supporting 'SupportsShouldProcess=$true)' since Invoke-WebRequest doesn't support it.
    [CmdletBinding()] param(
        [string] $AuthToken,
        [object] $Path,
        [string] $OutFile,
        [switch] $force
    )

    $dir = ([System.IO.FileInfo]$OutFile).Directory
    if (!$dir.Exists) { 
        $dir.Create()
    }    

    if((Test-Path $OutFile) -and $force) {
        Remove-Item $OutFile
    }

    try {
        $response = Invoke-WebRequest `
            -Method Post `
            -Uri "https://content.dropboxapi.com/2/files/download" `
            -Headers @{"Authorization" = "Bearer $AuthToken"; "Dropbox-API-Arg" = "{`"path`": `"$Path`"}"} `
            -ContentType "" `
            -OutFile $OutFile
            
    }
    catch [System.IO.IOException] {
        Write-Warning "Unable to download $outfile.  Retrying...."
        Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Download file from dropbox..." -CurrentOperation "Unable to download $outfile.  Retrying...."
        Start-Sleep -Seconds 5
        $response = Invoke-DropboxApiDownload -Path "rev:$($entry.rev)" -OutFile $outFile -AuthToken $AuthToken
    } 

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
        return @($response.entries)
    }
    catch {
        if ($_.ErrorDetails.Message.Contains("path/not_file")) {
            Write-Information "$Path appears to be a deleted folder."
            return [PSCustomObject] @(); 
        } else {
            throw 
        }
    }

}


Function script:Get-DropboxDirectoryContents {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string] $AuthToken,
        [string] $Path = ""
    )
try { $Activity = "$($PSCmdlet.MyInvocation.MyCommand.Name)";$parentId=[int]::MaxValue;if($script:progressNextIndex -gt 0){$parentId=$script:progressIdStack[-1]};$Id = $script:progressNextIndex++;$script:progressIdStack.Add($id)>$null

    $cursor = $null
    $hasMore = $true
    [int]$totalEntryCount = 0
    [string] $Cursor = $null
    $contents = New-Object System.Collections.ArrayList 

    while ($hasMore -eq $true){
        # Dropbox's API returns up to 2000 file listings at once.
        # If there are more than that, a cursor is returned which can be passed to another call
        # in order to get more results. Loop until we've found all the file listings.

        Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Retrive Dropbox content..." -CurrentOperation "Retrieved $totalEntryCount Dropbox content items so far"
    
        $body = @{
            "path" = $Path;
            "recursive" = $true;
            "include_deleted" = $true;
        }

        [string]$continueUrlPart = ""

        if ($Cursor) {
            $continueUrlPart = "/continue"
            $body = @{
                "cursor" = $Cursor
            }
        }

        $response = Invoke-DropboxApiRequest -Endpoint "files/list_folder$continueUrlPart" -Body $body -AuthToken $AuthToken    

        $totalEntryCount = $totalEntryCount + $response.entries.Count
        $response.entries | Write-Output
        $cursor = $response.cursor
        $hasMore = $response.has_more
    }


    ##return $contents
} finally {$script:progressNextIndex--;$script:progressIdStack.Remove($script:progressIdStack[-1]);Write-Progress -Activity $Activity -Id $id -Completed}
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

    .PARAMETER Filter
    A list of wildcard patterns that will be compared against each file in Dropbox in the path.
    If the Dropbox path name matches any of these patterns, it will be ignored.

    .EXAMPLE
    To only retrieve files within a directory named MyFiles while excluding any subfolders:
    $history = Invoke-DropboxHistory -AuthToken "<token>" -Path "/MyFiles" -Filter "/MyFiles/*/*"


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
        [string[]] $Filter = (new-object string[] 0)
    )
try { $Activity = "$($PSCmdlet.MyInvocation.MyCommand.Name)";$parentId=[int]::MaxValue;if($script:progressNextIndex -gt 0){$parentId=$script:progressIdStack[-1]};$Id = $script:progressNextIndex++;$script:progressIdStack.Add($id)>$null

    # TODO: Provide more examples including ones that consume the history.
    

    Write-Progress -Activity $Activity -Id $id -ParentId $parentId


    # Change '\' to '/', prefix with '/' and remove trailing '/'
    if($path.Contains('\')) { $Path = $Path.Replace('\','/') }
    if($path[0] -ne '/') { $Path = "/$Path" }
    if($path[-1] -eq '/') { $Path = $Path.TrimEnd('/')}

    $history = @{}
    $contents = New-Object System.Collections.ArrayList

    $contents = Get-DropboxDirectoryContents -Path $Path -AuthToken $AuthToken

    [int]$totalEntryCount = $contents.Count
    [int]$entryCount=0
    foreach($entry in ($contents | ?{ 
        $_.".tag" -in 'deleted','file'}) ) {         # We only care about files, not directories. "deleted" represents a deleted file.

        # Examine the file's path to see if it should be excluded.
        $matchedExcludes =  @($Filter | Where-Object {$entry.path_lower -like $_} )

        if (!$matchedExcludes -or $matchedExcludes.Count -eq 0) {
            Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Get file revisions" -CurrentOperation $entry.path_Display -PercentComplete ($entryCount++/$totalEntryCount)
            # If the file passed the exclusion filter, grab the metadata about the revisions of the file.
            $revisions = Get-DropboxFileRevisions -Path $entry.path_lower -AuthToken $AuthToken

            $subpathDisplay = ($entry.path_display -replace "(?i)^$([Regex]::Escape("$Path/"))","/") 
            Add-Member -InputObject $entry -TypeName "DropboxContentItem" -Name "subpath_display" -MemberType NoteProperty -Value $subpathDisplay
            Add-Member -InputObject $entry -TypeName "DropboxContentItem" -Name "tag" -MemberType AliasProperty -Value ".tag"
                    
            foreach ($revision in $revisions) { 
                if (!$history.ContainsKey($revision.client_modified)){
                    $null = $history.Add($revision.client_modified, (New-Object System.Collections.ArrayList))
                }
                $subpathDisplay = ($entry.path_display -replace "(?i)^$([Regex]::Escape("$Path/"))","/") 
                Add-Member -InputObject $revision -TypeName "DropboxFileRevision" -Name "subpath_display" -MemberType NoteProperty -Value $subpathDisplay
                $null = $history[$revision.client_modified].Add($revision)
            }
            Add-Member -InputObject $entry -TypeName "DropboxContentItem" -Name "Revisions" -MemberType NoteProperty -Value @($revisions)

            Write-Output $entry
                    
        }
    }

    if ($totalEntryCount -eq 0) {
        Write-Warning "No files were found. Exiting."
        return;
    }

} finally {$script:progressNextIndex--;$script:progressIdStack.Remove($script:progressIdStack[-1]);Write-Progress -Activity $Activity -Id $id -Completed}
}

Function Invoke-MockGit ([switch]$A, $argumentList) {
    $parameters = $args
    if([bool]((& "C:\Program Files\Git\cmd\git.cmd" add -help) -like "*--dry-run*")) {
        $parameters = $parameters | ?{ $_ -notin ,"--dryrun" }
        & "C:\Program Files\Git\cmd\git.cmd"  $parameters "--dryrun" 
    }
    else {
        Write-Host "Executing: git $parameters"
    }
}

Function Get-CurrentGitBranch {
    git branch | ?{ $_ -match '\* (?<CurrentBranch>.*)' } | %{ $Matches.CurrentBranch }
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

    .PARAMETER Filter
    A list of wildcard patterns that will be compared against each file in Dropbox in the path.
    If the Dropbox path name matches any of these patterns, it will be ignored.

    .EXAMPLE
    To only convert files within a directory named MyFiles while excluding any subfolders:
    Invoke-ConvertDropboxToGit -AuthToken "<token>" -Path "/MyFiles" -Filter "/MyFiles/*/*"


    .LINK
    https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/

#>
Function Invoke-ConvertDropboxToGit {
    [CmdletBinding(DefaultParametersetName="DropBoxConfig",SupportsShouldProcess=$true)] 
    param(
        [Parameter(Mandatory)][string] $AuthToken = $(Read-Host -prompt @"
        Enter your Dropbox access token.  To get a token, follow the steps at
        https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/
"@),
        [Parameter(Mandatory, ParameterSetName="DropBoxConfig")][string] $Path = "",
        [Parameter(ParameterSetName="DropBoxConfig")][string[]] $Filter = (new-object string[] 0),
        [ValidateScript({Test-Path $_ -PathType Container })][string] $OutputDirectory,
        [Parameter(Mandatory, ParameterSetName="DropBoxHistory")] $contents
        # TO DO: Add [bool]$CaseSensitiveGit
    )
    
try { $Activity = "$($PSCmdlet.MyInvocation.MyCommand.Name)";$parentId=[int]::MaxValue;if($script:progressNextIndex -gt 0){$parentId=$script:progressIdStack[-1]};$Id = $script:progressNextIndex++;$script:progressIdStack.Add($id)>$null

    Write-Progress -Activity $Activity -Id $id -ParentId $parentId
    
    if($PsCmdlet.ParameterSetName -ne "DropBoxHistory") {
        Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Get-DropBoxHistory"
        # When we're done grabbing metadata, will will loop through this dictionary in order of its keys
        # to construct our git repo.
        $contents = Get-DropboxHistory $AuthToken $Path $Filter 
    }
     
    # Unfortunately, we have to change our working directory because git doesn't allow you to target commands to other directories.
    try {
        Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Initialize Git Repository"
        $originalLocation = Get-Location

        if([string]::IsNullOrEmpty($OutputDirectory)) {
            $OutputDirectory = $pwd
        }
        
        ###########################################
        # Below
        Get-ChildItem $OutputDirectory "DropboxHistoryBuild*" | Remove-item -Recurse -Force -ErrorAction Ignore
        # Above
        #########################################
        
        # The name of the folder created is always static.
        $dirName = Join-Path $OutputDirectory "DropboxHistoryBuild $((Get-Date -Format u).Replace(':', '-'))"

        
        if(![bool]$WhatIfPreference){
            New-Item -ItemType Directory -Path $dirName  > $null
            Set-Location $dirName
            git init 
            if ($PSBoundParameters.ContainsKey('CaseSensitiveGit')) {
                git config core.ignorecase $caseSensitiveGit
            }
        }
        else {
            $gitNoOp = $(Join-Path -path $env:temp -ChildPath "gitNoOp.cmd")
            "@ECHO OFF`nif %1 NEQ add if %1 NEQ checkout (Echo git %*)" | Out-File -FilePath $gitNoOp -Encoding ascii -Force -WhatIf:$false
            if(Test-Path alias:git) {
                Set-Alias -name Git -value $gitNoOp -Scope Script -WhatIf:$false
            }
            else {
                New-Alias -Name Git -Value $gitNoOp -Scope Script -WhatIf:$false
            }
        }
        Start-Process -FilePath git -ArgumentList editor -ErrorAction Continue # Launch a viewer 
    
        [string]$currentDirectory = $null;
        [string]$lastDirectory = $null;

        $userInfos = @{}
        ###################
        # Special Stuff
        if(!(test-path alias:git)) {
            Set-Alias Git "C:\Program Files\Git\cmd\git.cmd" -Scope Script 
        }

        if(![bool]$WhatIfPreference){
            start-process -FilePath "gitex.cmd" "browse .\"
        }
        if(Test-Path "$env:temp\userinfos.xml") {
            [Hashtable]$userInfos = Import-Clixml -Path "$env:temp\userinfos.xml"
        }
        else {
            try {
                "dbid:AAB__8e_WYIdagDowO23QIewUPexUkG0ckg","dbid:AADD_oEVX59Mi8_lY_8K3qHP49v2nMMoyyM","dbid:AACLwi6CRR1S_yopklvDbLJp_hGpfJ2MJPk" | %{
                    if (!$userInfos.ContainsKey($_)) {
                        # If we haven't seen this userId yet, make a request to get their name and email for the commit metadata.
                        $userInfos[$_] = Invoke-DropboxApiRequest -Endpoint "users/get_account" -Body @{"account_id" = "$_"}  -AuthToken $AuthToken
                    }
                }
                $userInfos | Export-Clixml -Path "$env:Temp\userInfos.xml" -Force
            }
            catch{};
        }
        [string]$oldVersion = $null
        "*" > ".gitignore"
        $expectedManuscriptFiles= (".gitignore",'.gitattributes',"EssentialC#.dotx","*.mmap",'*.ps1',"Figures/","Slides/")  + 
                ((1..21 | %{ "Michaelis_Ch{0:00}" -f $_ } ) + ("A","B","C","D","F" | %{ "Michaelis_App{0}" -f $_ }) +  
                ("Preface","Bio","AboutIntelliTechture","AboutIntelliTect","Dedication","AbtAuthor","Acknowledgments","Forward","AboutIntelliTect" | %{ "Michaelis_{0}" -f $_ }) | %{ "$_.docx";"$_.doc" })
        $expectedManuscriptFiles | %{ "!$_"} >> ".gitignore"
        $expectedManuscriptFiles = $expectedManuscriptFiles | %{ $_.TrimEnd("/") }

        '*.docx    binary' > '.gitattributes'
        '*.pdf    binary' >> '.gitattributes'
        git config core.autocrlf false

        git add -A
        git commit -m "Initialize repository with .gitignore and .gitattributes"

        [bool]$FoundAndrewOrDan=$false
        git checkout -b v3.0
        $oldVersion = "v3.0"
        # Above
        ###################

        # Loop over our dictionary of revisions in order of the key (which is the date of the revision)
        foreach ($entry in ( $contents | %{ $_.Revisions } | Sort-Object -Property client_modified,subpath_display)  ) {
            [Nullable[DateTime]]$datetime = $null
            [string]$authorId = $null
            [PSCustomObject]$userInfo = $null

            #################################
            # Below
            [string]$gitCommitMessage = $null
            [string]$tag = $null
            # Above
            #################################

            Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Download file from dropbox..." -CurrentOperation $entry.path_display
            # Go out to Dropbox and download the revision of each file that corresponds to this date.

            $outFile = Join-Path "." ($entry.subpath_display)

            $date = (([DateTime]$entry.client_modified).ToString("yyyy-MM-dd HH:mm:ss"))

            ###################
            # Below
            # Special Stuff

            $before = $outFile          

            $contributors = @(
                    @{FN="Audrey";LN="Doyle";Search="__AD.doc";Email="audrey.doyle@comcast.net"},
                    @{FN="Eric";LN="Lippert";Search="";Email="Eric@lippert.com"},
                    @{FN="Shane";LN="Kercheval";Search="";Email="shane.kercheval@gmail.com"},
                    @{FN="Ian";LN="Davis";Search="";Email="ian.f.davis@gmail.com"},
                    @{FN="Stephen";LN="Toub";Search="";Email="stoub@microsoft.com"},
                    @{FN="Jason";LN="Morse";Search="";Email="jason@eveningcreek.com"},
                    @{FN="Michael";LN="Stokesbary";Search="";Email="mike@IntelliTect.com"},
                    @{FN="Elisabeth";LN="Ryan";Search="";Email="elizabeth.c.ryan@pearson.com"},
                    @{FN="Mark";LN="Michaelis";Search="";Email="mark@IntelliTect.com"},
                    @{FN="Brian";LN="Jones";Search="ab";Email="Brian@IntelliTect.com"},
                    @{FN="Andrew";LN="Scott";Search="";Email="Andrew.Scott@IntelliTect.com"},
                    @{FN="Dan";LN="Haley";Search="";Email="Dan.Haley@IntelliTect.com"}
                )
            if("$($entry.id),$($entry.rev)" -eq "id:kX2lV54A50EAAAAAAABltQ,36fc481c2c2e") {
                Write-Host "host"
            }

            $outFile,$authorItem,$version = Rename-Entry $entry $outFile 


            switch("$($entry.id),$($entry.rev)") {
                {$_ -in @(
                    ,'id:2Nj6yporhyoAAAAAACBr6w,22d481c2c2e'               # 2004-11-22T01:28:20Z (v3.0) - /Figures/Michaelis_ch03.Fig05_RegionsInVS/Backup/TicTacToe.cs
                    ,'id:2nj6yporhyoaaaaaacbtja,1d60481c2c2e'               # 2009-09-07t07:56:08z (v3.0) - michaelis_ch14.mindmap_collectioninterfaceswithstandardqueryoperators.mmap

                    ) } {
                    $version = "v3.0"
                }
                {$_ -in @(
                    ,'id:kX2lV54A50EAAAAAAAAfQg,1d68481c2c2e'              # 2013-01-26 06:55:21  (v4.0) - .\v4.0\michaelisextractedwordfiles-4.0.zip
                    #'id:2Nj6yporhyoAAAAAACB3cA,28e1481c2c2e'               # 2012-09-07T23:19:44Z (v4.0) - /EssentialCSharp/v5.0/Michaelis_FM.zip
                    #,'id:eO6XreEhyqAAAAAAAAApkA,29f5481c2c2e'              # 2012-09-07 16:08:20  (v4.0) - /EssentialCSharp/v5.0/EssentialCSharpSubmitted/Michaelis_ch07.docx
                    )} {
                    $version = "v4.0"
                }
                {$_ -in @(
                    ,'id:2Nj6yporhyoAAAAAACBTxA,290481c2c2e'   # 2013-01-26 12:44:02 (v6.0) - /EssentialCSharp/Preface.docx
                    ,'id:2Nj6yporhyoAAAAAACB2mw,28db481c2c2e'  # 2014-04-21T06:15:52Z (v5.0) - /EssentialCSharp/v5.0/BookImage.png
                    ) } {
                    $version = "v5.0"
                }
                {$_ -in @(
                    ,'id:eO6XreEhyqAAAAAAAAAq5w,38e2481c2c2e'  # 2016-12-21T21:11:04Z (v6.0) - /EssentialCSharp/EssentialC#.dotx
                    ,'id:kX2lV54A50EAAAAAAAAmTw,26b481c2c2e'   # 2014-07-21T12:49:11Z (v6.0) - /EssentialCSharp/Michaelis_TableOfContents.docx
                    #,'id:eO6XreEhyqAAAAAAAAApqQ'               # 2014-09-12T23:51:32Z (v6.0) - /EssentialCSharp/v5.0/Michaelis_ch03ab.docx
                    ,'id:kX2lV54A50EAAAAAAAAtNg,215481c2c2e'      # 2015-03-29 08:35:25  (v6.0) - /EssentialCSharp/EssentialC#.dotx
                    ,'id:eO6XreEhyqAAAAAAAAAq5w'               # 2016-12-21T21:11:04Z (v6.0) - /EssentialCSharp/EssentialC#.dotx

                    ) } {
                    #$oldVersion = "v5.0"
                    $version = "v6.0"
                }
                {$_ -in @(
                    ,'id:eO6XreEhyqAAAAAAAAApFA,294e481c2c2e'   # 2016-08-05 13:18:17 (v7.0)  - /EssentialCSharp/Essential C# 7 Proposal.doc
                    ,'id:eO6XreEhyqAAAAAAAAApFA,294c481c2c2e'   # 2016-08-05 13:18:17 (v7.0)  - /EssentialCSharp/Essential C# 7 Proposal.doc
                    ,'id:eO6XreEhyqAAAAAAAAAq6A,38e1481c2c2e'   # 2016-12-21T21:11:04Z (v7.0) - /EssentialCSharp/Essential C# 7 Proposal.doc

                    ) } {    # 2016-12-21T21:11:04Z () - /EssentialCSharp/Essential C# 7 Proposal.doc
                    $version = "v7.0"
                }
                { $_ -in (
                    ,'id:kX2lV54A50EAAAAAAABoIg,36fb481c2c2e'  # 22016-12-16 16:01:20 (v6.0 - Overwrites) - /EssentialCSharp/Michaelis_AppA.docx
                )} {                       
                    $version = "v6.0-Overwrites"
                }
                default {
                }
            }

            Function Merge-GitToMain {
                if(Get-CurrentGitBranch -ne "main") {
                    git checkout main
                    git merge --no-commit --no-ff "$oldVersion" --strategy=recursive 
                    Get-ChildItem .\ * -Exclude $expectedManuscriptFiles | %{
                        git reset $_
                        Remove-Item $_ -Recurse -Force
                    }
                    git commit -m "Merged in material from $oldVersion"
                    git checkout -b $version
                }
                else {
                    Write-Warning "Already on branch main"
                }
            }

            if(([int]$version[1] -eq ([int]$oldVersion[1])+1) ) { 
                Merge-GitToMain
            }
            elseif(("$($entry.id),$($entry.rev)" -in @( 
                ,'id:kX2lV54A50EAAAAAAABoIg,i36fb481c2c2e'                       # 22016-12-16 16:01:20 (v6.0 - Overwrites) - /EssentialCSharp/Michaelis_AppA.docx
                )) ) {
                Merge-GitToMain
            }
            elseif($version -and ($version -ne $oldVersion)) {
                git checkout $version
            }
            $oldVersion = $version

            #if($version -notin "","v7.0","v6.0") { continue }

            if($authorItem) {
                $authorId = $authorItem.FN,$authorItem.LN -f "{0}.{1}"
                $authorFullName = $authorItem.FN,$authorItem.LN -f "{0} {1}"
                if (!$userInfos.ContainsKey($authorId)) {
                    # If we haven't seen this userId yet, make a request to get their name and email for the commit metadata.
                    $userInfos.Add($authorFullName, [PSCustomObject]@{ account_id=$authorId; name=@{display_name=$authorFullName}; email=$authorItem.Email }) > $null
                }
            }
            
            # Above
            ###################

            # TO DO: Test
            #if ([bool](git config core.ignorecase)) {
            #    if( (Test-Path $outFile) -and ($outFile -cne (Resolve-Path (Get-Item $outFile) -Relative)) ) {
            #        git mv (Resolve-Path $outFile).Path $outFile -f
            #    }
            #}


            if(![bool]$WhatIfPreference){
                ###################################
                # Below 

                if(!(Test-Path (Split-Path $outFile))) {
                    New-Item -ItemType Directory -Path (Split-Path $outFile) > $null
                }
                #Copy-Item ("C:\Temp\EssentialCSharpDropboxFileHistory\$($entry.id)$($entry.rev)").Replace("id:","") $outFile
                
                try {
                    if(!(Test-Path "c:\temp\essentialcsharpdropboxfilehistory\$($entry.id),$($entry.rev)".Replace("id:",""))) {
                        invoke-dropboxapidownload -path "rev:$($entry.rev)" -outfile (join-path $pwd $outfile) -authtoken $authtoken
                        copy-item (join-path $pwd $outfile) ("c:\temp\essentialcsharpdropboxfilehistory\$($entry.id),$($entry.rev)").replace("id:","") -force
                    }
                    else {
                        Copy-Item ("C:\Temp\EssentialCSharpDropboxFileHistory\$($entry.id),$($entry.rev)").Replace("id:","") $outFile -Force
                    }
                }
                catch {
                    Copy-Item ("C:\Temp\EssentialCSharpDropboxFileHistory\$($entry.id),$($entry.rev)").Replace("id:","") $outFile -Force
                }
                if( ( Get-FileHash ("C:\Temp\EssentialCSharpDropboxFileHistory\$($entry.id),$($entry.rev)").Replace("id:","") ).Hash -ne ( Get-FileHash $outFile ).Hash ) {
                    Write-Error "The files are not the same."
                }


                Function Expand-OutFile {
                    [CmdletBinding()]
                    param(
                         $outFile
                    )
                        if([IO.Path]::GetExtension($outfile) -eq '.zip' -and ($outfile -notlike "*MichaelisExtractedWordFiles*.zip*") ) {
                            if(("$($entry.id),$($entry.rev)" -notin (
                                ,'id:2Nj6yporhyoAAAAAACB3cA,28e1481c2c2e' # 2012-09-07T23:19:44Z (v5.0) /EssentialCSharp/v5.0/Michaelis_FM.zip    
                                ) ) ) {
                                write-host "here"
                            }                            # Handle files that need to be expanded.
                            expand-archive -path $outFile -FlattenPaths -OutputPath .\ -Force
                            Remove-Item $outFile
                            git status -s | ?{ ($_ -ne $outfile) -and ($_ -notlike " D *") } | %{ $_ -replace "\?\? ","" -replace " M ",""} | %{ 
                                # Unzip an additional zip files that were embedded
                                Expand-OutFile $_
                            }
                            git status -s | ?{ ($_ -ne $outfile) -and ($_ -notlike " D *") } | %{ $_ -replace "\?\? ","" -replace " M ",""} | %{ 
                                $uncompressfile,$temp1,$temp2 = Rename-Entry $entry ".\$_" $contributors 
                                Move-Item .\$_ $uncompressfile -Force
                            }                        }
                };Expand-OutFile $outFile
                # Above (uncomment line above)
                ###################################
            }



            & git add -A

            Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Git Add" -CurrentOperation "$(git status --short)"

            [string]$gitCommitOutput=$null

            $gitCommitMessage = ($gitCommitMessage,"Revisions made $date`: $(git status --short)".Replace('"','`' ) -join "; ").Trim(";").Trim()
            if($authorId -or ($authorId=$entry[0].sharing_info.modified_by)) {  # Check before setting to support future (custom) injection of Author 
                if (!$userInfos.ContainsKey($authorId)) {
                    # If we haven't seen this userId yet, make a request to get their name and email for the commit metadata.
                    $userInfos[$authorId] = Invoke-DropboxApiRequest -Endpoint "users/get_account" -Body @{"account_id" = "$authorId"}  -AuthToken $AuthToken
                }
                $userInfo = $userInfos[$authorId]
            }   
      
            #################################
            # Below

                $gitCommitMessageContent =  @{ 'date'=$date;'id'=$entry.id;'rev'=$entry.rev;'author'=$userInfo.name.display_name;'path_display'=$entry.path_display } | ConvertTo-Json -Compress
                if($userInfo.name.display_name -like "*haley*" ) { #-or $userInfo.name.display_name -like "*andrew*") {
                    Write-Warning "Author is: $($userInfo.name.display_name)"
                    $FoundAndrewOrDan = $true
                    if($entry.id -eq "kX2lV54A50EAAAAAAABoJw") {
                        Write-Error "Ready"
                    }
                }
                elseif($FoundAndrewOrDan) {
                    $version = "v6.0-Overwrites"
                    #Merge-GitToMain
                }
            # Above
            ################################

            Function Git-Commit {
                [Cmdletbinding(SupportsShouldProcess=$true)]
                param()
                $gitParameters = @(
                    "commit", "-m",$gitCommitMessage,"-m",$gitCommitMessageContent,"--date","`"$date`""
                )
                #####################
                # Below
                $gitCommitMessageFileName = [IO.Path]::GetTempFileName()
                Out-File -FilePath  $gitCommitMessageFileName -InputObject $gitCommitMessage  -Encoding ascii
                Out-File -FilePath  $gitCommitMessageFileName -InputObject "`nDropbox Entry:`n$gitCommitMessageContent"  -Encoding ascii -Append
                $gitParameters = @(
                    "commit", '-F', $gitCommitMessageFileName ,"--date","`"$date`""
                )

                # above
                ############### 
                if($userInfo) {
                    $gitParameters += @("--author", "`"$($userInfo.name.display_name) <$($userInfo.email)>`"")
                }
                
                for ($i = 0; $i -lt 5; $i++)
                { 
                    $gitCommitOutput = & git $gitParameters                 
    
                    if( ($gitCommitOutput -like "*fatal: could not open*") -or 
                            ($gitCommitOutput -like "*fatal: Unable to create * File exists.*") -or
                            ($gitCommitOutput -like "*fatal: Unable to write new index file*") ) {
                        ## On occasion files are busy and retrying generally succeeds
                        Start-Sleep -Seconds 5
                        # Try again...
                    }
                    elseif( [string]$gitCommitOutput -like "*nothing to commit*working directory clean*" -and ($i -eq 0) -and (([IO.Path]::GetExtension($entry.path_display) -ne '.zip'))) {
                        invoke-dropboxapidownload -path "rev:$($entry.rev)" -outfile (join-path $pwd $outfile) -authtoken $authtoken
                        copy-item (join-path $pwd $outfile) ("c:\temp\essentialcsharpdropboxfilehistory\$($entry.id),$($entry.rev)").replace("id:","") -force
                    }
                    else {
                        break
                    }
                }

                if( $LastExitCode -gt 0 ) {
                    if([string]::IsNullOrWhiteSpace( (git status --short) )) {
                        # There is nothing to commit, working directory clean
                        Write-Warning "$(git status).`n'$outFile' has possibly not changed."
                    }
                    else {
                        throw $gitCommitOutput
                    }
                }
                
                #$gitCommitOutput = & git commit -m "$gitCommitMessage" --date $dated
                Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Git Commit" -CurrentOperation "$gitCommitOutput" 

                ############################
                # Below
                Remove-item $gitCommitMessageFileName # -ErrorAction Ignore
                
                $transactionData = "{0}-{1}: {2,-100}{5,-30}({3})`t`t{4,-100}" -f $date,$version,$outFile,$($entry.id),$before,$($userInfo.name.display_name)
                
                Write-Host $transactionData

                # Above
                ##########################
            }; Git-Commit
        }

        Function Remove-DeletedFiles {
            # All file revisions commits have now been made.
            # We will make on last pass through $contents and delete every file that Dropbox reports as being deleted.
            # We have to do this at the end because dropbox doesn't report deletion times - only a boolean on if a file is deleted or not.
            # It's not ideal, but it's what we have to work with.
            foreach($entry in ($contents | ?{ $_.".tag" -eq "deleted" }) ) {  
                $outFile = Join-Path "." $entry.subpath_display
                ########################################
                if($entry.subpath_display -like "*Figures*") {
                    Remove-Item $outFile -Verbose
                }
                ########################################
            }
    
            git add -A
            git commit -m "All Dropbox Deletions - Dropbox does not report deletion times."
        }; # Remove-DeletedFiles

        git tag dropbox-final
    }
    finally {
        # Move our current directory back up to where we were before we started. We're done!
        Set-Location $originalLocation
    }
} finally {$script:progressNextIndex--;$script:progressIdStack.Remove($script:progressIdStack[-1]);Write-Progress -Activity $Activity -Id $id -Completed}
}



################################
# Below

Function Rename-Entry {
    [CmdletBinding()]
    param(
        $entry,
        [string]$outfile,
        $contributos
    )
            Function Edit-FileName {
                $FindAndReplace = @(
                    ('(?<Start>.*\.)Mindmap\.(?<End>.*)(?<Extension>\.([^\\/.]*)$)','${Start}${End}.Contents${Extension}'),  #Swap where Contents appears
                    ("(?<Start>.*)_ch(?<End>\d{1,2}\..*)","`${Start}_Ch`${End}"),
                    ("Michaelis_ch","Michaelis_Ch"),
                    ("(?<Start>.*)michaelis(?<End>.*)","`${Start}Michaelis`${End}"),
                    ("(?<Start>.*)(?<Appendix>App[ABCDEF])(?<Extension>\..*)","`${Start}`${Appendix}`${Extension}"),
                    ("(?<Start>.*)(?<Appendix>App[ABCDE])Michaelis(?<Extension>\..*)","`${Start}`${Appendix}`${Extension}"),
                    ("(?<Start>.*)Chapter(?<ChapterNumber>\d\d?)Michaelis(?<Extension>\..*)","`${Start}Michaelis_Ch`${ChapterNumber}`${Extension}"),
                    ("EssentialCSharp(?<ChapterNumber>\d\d?)(?<Extension>\..*)","Michaelis_Ch`${ChapterNumber}`${Extension}"),
                    ("(?<Start>.*)Michaelis_Ch(?<ChapterNumber>\d)(?<Extension>\..*)","`${Start}Michaelis_Ch0`${ChapterNumber}`${Extension}"), # Change to use 0 padding on chapter number to two digits
                    ("(?<Start>.*)\(.*conflicted copy \d\d\d\d-\d\d-\d\d\)(?<Extension>\..*)","`${Start}`${Extension}"),
                    ("\(v\d{1,2}\)",""),
                    ("Foreward","Forward"),
                    ("(?<FileName>Michaelis_App[ABCDEF]).*(?<Extension>\..*)","`${FileName}`${Extension}")
                )
                $FindAndReplace | %{  $outFile = $outFile -replace $_[0],$_[1] }
                Write-Output $outFile
            }; 
            $outFile = Edit-FileName

            if ($outfile -clike "*_ch*") {
                Throw "Output contains lowercase '_ch': $outFile"
            }

            Function Assert-FileNameStartsWithPeriod {
                if( $outFile[0] -ne '.') {
                    Write-Error "File name '$outFile' does not begin with a period."
                }
            }; Assert-FileNameStartsWithPeriod

            $AuthorFolderRegex = -join ("((?<AuthorFolder>(",(($contributors | %{ "($($_.FN)\.?($($_.LN))?)" }) -join "|"),")?)(Reviews?)?\\?)?")
            $authorInitialsTagRegex = -join ("(?<AuthorInitials>",(($contributors | %{ "$($_.FN[0])$($_.LN[0])|$($_.FN) $($_.LN)" }) -join "|"),")")
            $authorSearchTagRegex = -join ("(?<AuthorSearchTag>",(($contributors | ?{![string]::IsNullOrWhiteSpace($_.Search)} |  %{ "$($_.Search)" }) -join "|"),")")
            $filePathRegex = [string]::Join(""
                ,"(?<Path>\.\\"
                    ,"(?<Version>v\d\.0)?\\?" 
                    ,"$AuthorFolderRegex" 
                    ,"(?<RootFolder>.+?)?"
                    ,"([\\/](?<RemainingPath>.*))?"
                ,"$)");
            $fileNameRegex = [string]::Join(""
                ,"(?<FileName>"
                        ,"(?<FinalFileName>.+?)"
                        ,"(?<AuthorFileTag>([ _-]+$authorInitialsTagRegex))?([ ]*(re)+views?)?"
                        ,"($authorSearchTagRegex)?"
                    ,")"
                    ,"(?<Extension>\.([^\\/.]*)$)")

            $outFilePath = Split-Path $outFile;
            $outFileName = [IO.Path]::GetFileName($outFile)
            $outFileExtension = [IO.Path]::GetExtension($outFile)

            Function Get-RegExGroupNameValue { [CmdletBinding()] param([System.Collections.Hashtable]$regExMatches, [string]$propertyName) if( $propertyName -in $regExMatches.keys) { ($regExMatches."$propertyName").Trim("\") } else { $null } }

            [string]$authorFolder=$null
            [string]$rootFolder=$null
            [string]$version=$null
            [string]$oldRootFolder = $null
            [string]$finalFileName=$null
            [string]$authorFileTag=$null
            [string]$remainingPath=$null

            if($outFile -match "\.\\((Contracts)|(v[345]\.0\.zip)|(.*\.docx?\.crdownload))|(\.\\v5\.0\\PFDs\.zip)|(.gitignore)") {
                continue            
            }
            if($outfile -in (".rels","[Content_Types].xml","theme1.xml","themeManager.xml","themeManager.xml.rels")) {
                remove-item $outfile
            }
            elseif("$outFilePath\" -match $filePathRegex) {
                $authorFolder =  Get-RegExGroupNameValue $Matches "AuthorFolder"
                $rootFolder = Get-RegExGroupNameValue $Matches "RootFolder"
                $version = Get-RegExGroupNameValue $Matches "Version"
                if([string]::IsNullOrWhiteSpace($version) ) {
                    $version = $oldVersion
                }
                $remainingPath = Get-RegExGroupNameValue $Matches "RemainingPath"
                #$rootFolder = Split-Path $remainingPath -Parent

            }
            else {
                throw "Unable to parse file name: $outfile"
            }

            switch ($rootFolder)
            {
                'Figures' {}
                'PageProofs' {}
                'Slides' {}
                'ErrataVersions' {
                    Write-Warning "ErrataVersions: $outFile"
                    $remainingPath = ''
                    $rootFolder = ''
                }
                'CopyEditsReviewed'{
                   $gitCommitMessage = "Copy Edits Reviewed"
                    $rootFolder = ''

                }
                'EssentialCSharpSubmitted' {
                    $gitCommitMessage = "Manuscript submitted"
                    $rootFolder = ''
                }
                {$_ -in 'PDFs','PFDs','PageLayoutsReviewed'} {
                    $rootFolder = 'PageProofs'

                }
                '' {}
                Default {
                }
            }
            $remainingPath = $remainingPath -replace "\\Backup",""
            switch ($remainingPath)
            {
                {$_ -like '*Michaelis_Ch03.Fig05_RegionsInVS*'} {
                    Write-Debug "`$remainingPath=$remainingPath"
                }
                'Michaelis_Ch09.Fig02_XMLCommentsAsTipsInVisualStudioIDE' {}
                'Michaelis_Ch09.Fig02_XMLCommentsAsTipsInVisualStudioIDE' {}
                'Backup' {}
                '' {}
                'Feedback' {
                    # 2010-01-22T05:39:24Z (v3.0) id:2Nj6yporhyoAAAAAACBquA, /EssentialCSharp/v3.0/PageProofs/Feedback/Michaelis_ch15.doc
                    $authorFileTag = "BJ"
                    $remainingPath = ''
                    $rootFolder = ''
                }
                Default {
                    Write-Debug "`$remainingPath = $remainingPath"
                }
            }

            if($outFileName -match $fileNameRegex) {
                $finalFileName = Get-RegExGroupNameValue $Matches "FinalFileName"
                if(!$authorFileTag) {
                    $authorFileTag = Get-RegExGroupNameValue $Matches "AuthorFileTag"
                }
                $authorSearchTag = Get-RegExGroupNameValue $Matches "AuthorSearchTag"
                switch ($outFileName)
                {
                    {$_ -in '032167491X.pdf','0321533925_Michaelis_FINAL.pdf','Essential C# v4.0.pdf','MichaelisBook.pdf'} {
                        $finalFileName ="Essential C# $version (Final)"
                        $outFileExtension = ".pdf"
                        $outFileName = "$finalFileName$outFileExtension"                    
                        $tag = "$version - Final"
                    }
                    'Michaelis_Ch19.CSharp3.0.docx' {
                        $finalFileName ="Michaelis_Ch19"
                        $outFileExtension = ".docx"
                        $outFileName = "$finalFileName$outFileExtension"                    
                    }
                    {$_ -like '*EssentialC*Errata*'} {
                        if($_ -match 'EssentialC.*(?<ChapterNumber>\d).*Errata.*') {
                            $version = "v$($Matches.ChapterNumber).0"
                            $finalFileName ="Essential C# $version Errata"
                        }
                        else {
                            throw "Unable to match on the Errata chapter."
                        }
                    }
#                    {$_ -like "*Errata*" } {
#                            $finalFileName ="Essential C# $version Errata"
#                    }
                    'Michaelis_FM.zip' {
                        Write-Warning "Michaelis_FM.zip"
                    }
                    'BookImage.png' {
                        if($version -ne "v5.0") { throw "The version number on the bookimage.png is not correct."}
                        $rootFolder = "BookPhotos"
                    }
                    'Indexes.pdf' {
                        $finalFileName ="Michaelis_Indexes"
                        $outFileExtension = ".pdf"
                        $outFileName = "$finalFileName$outFileExtension" 
                        $rootFolder = "PageProofs"
                    }
                    'Preface.docx' {
                        $finalFileName ="Michaelis_Preface"
                        $outFileExtension = ".docx"
                        $outFileName = "$finalFileName$outFileExtension"                       
                    }
                    'Michaelis_MultithreadingPatternsPriorToC#5.docx' {
                        $finalFileName ="Michaelis_AppC"
                        $outFileExtension = ".docx"
                        $outFileName = "$finalFileName$outFileExtension"                       
                    }
                    'Michaelis_ch03ab.docx' {
                        $finalFileName ="Michaelis_Ch03"
                        $outFileExtension = ".docx"
                        $outFileName = "$finalFileName$outFileExtension"                       
                    }
                    'Michaelis_AboutIntelliTechture.docx' {
                        if( (test-path 'Michaelis_AboutIntelliTechture.docx') -and ($version -gt 'v3.0')) {
                            #git mv 'Michaelis_AboutIntelliTechture.docx' 'Michaelis_AboutIntelliTect.docx'
                            $finalFileName ="Michaelis_AboutIntelliTect"
                            $outFileExtension = ".docx"
                            $outFileName = "$finalFileName$outFileExtension"                       
                        }
                    }
                }
                switch($entry.id) {
                    'eO6XreEhyqAAAAAAAAAq6Q' {  "Essential C# Eric Lippert Comments.docx"
                        $authorFileTag = "EL"
                    }
                }
            }
            else {
                switch ($outFileName)
                {
                    {$_ -in ' (Mark Michaelis''s conflicted copy 2016-12-20).gitignore','.gitignore',' .gitignore'} {
                        $finalFileName =""
                        $outFileExtension = ".gitignore"
                        $outFileName = ".gitignore"
                    }
                    '.rels' {
                    }
                    Default {
                            throw "Unable to parse file name: $outfile"
        
                    }
                }
            }            

            $outFile = [IO.Path]::Combine(".",$rootFolder,$remainingPath, "$finalFileName$outFileExtension")

            if( ([IO.Path]::GetExtension($outFile) -eq ".docx") -and (Test-Path ([IO.Path]::ChangeExtension($outFile,".doc"))) ) {
                git mv "$([IO.Path]::ChangeExtension($outFile,".doc"))" "$outFile"
            }
            elseif ( ([IO.Path]::GetExtension($outFile) -eq ".doc") -and (Test-Path ([IO.Path]::ChangeExtension($outFile,".docx"))) ) {
                git mv "$([IO.Path]::ChangeExtension($outFile,".docx"))" "$outFile"
                Write-Warning "The file extension on $([IO.Path]::ChangeExtension($outFile,".docx")) has gone back to $outFile"
            }

            $authorItem=$contributors | ?{ 
                ($authorFolder -like "$($_.FN)*$($_.LN)") -or 
                ($authorFileTag -eq "$($_.FN[0])$($_.LN[0])") -or 
                ($authorSearchTag -eq "$($_.Search)" )
            }

            Write-Output $outfile $authorItem $version
}


# Above
################################