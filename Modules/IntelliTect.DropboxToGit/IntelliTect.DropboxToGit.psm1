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
        [string] $OutFile
    )

    $dir = ([System.IO.FileInfo]$OutFile).Directory
    if (!$dir.Exists) { 
        $dir.Create()
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
        Invoke-DropboxApiDownload -Path "rev:$($entry.rev)" -OutFile $outFile -AuthToken $AuthToken
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
try { $Activity = "$($PSCmdlet.MyInvocation.MyCommand.Name)";$parentId=[int]::MaxValue;if($script:progressNextIndex -gt 0){$parentId=$script:progressIdStack[-1]};$Id = $script:progressNextIndex++;$script:progressIdStack.Add($id)>$null

    # TODO: Provide more examples including ones that consume the history.
    

    Write-Progress -Activity $Activity -Id $id -ParentId $parentId


    # Change '\' to '/', prefix with '/' and remove trailing '/'
    if($path.Contains('\')) { $Path = $Path.Replace('\','/') }
    if($path[0] -ne '/') { $Path = "/$Path" }
    if($path[-1] -eq '/') { $Path = $Path.TrimEnd('/')}

    $history = @{}
    $head = New-Object System.Collections.ArrayList
    $contents = New-Object System.Collections.ArrayList

    $contents = Get-DropboxDirectoryContents -Path $Path -AuthToken $AuthToken

    [int]$totalEntryCount = $contents.Count
    [int]$entryCount=0
    foreach($fileEntry in $contents) {
        # We only care about files, not directories. "deleted" represents a deleted file.
        if ($fileEntry.".tag" -eq "file" -or $fileEntry.".tag" -eq "deleted"){
            # Examine the file's path to see if it should be excluded.
            $matchedExcludes =  @($PathExcludes | Where-Object {$fileEntry.path_lower -like $_} )

            if (!$matchedExcludes -or $matchedExcludes.Count -eq 0) {
                Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Get file revisions" -CurrentOperation $fileEntry.path_Display -PercentComplete ($entryCount++/$totalEntryCount)
                # If the file passed the exclusion filter, grab the metadata about the revisions of the file.
                $revisions = Get-DropboxFileRevisions -Path $fileEntry.path_lower -AuthToken $AuthToken

                $subpathDisplay = ($fileEntry.path_display -replace "(?i)^$([Regex]::Escape("$Path/"))","/") 
                Add-Member -InputObject $fileEntry -TypeName "DropboxContentItem" -Name "subpath_display" -MemberType NoteProperty -Value $subpathDisplay

                # Store the file's metadata in $head, and then
                # store data about each revision of the file into a dictionary keyed by the date of the file.
                # TODO: consider changing to only store deletes.
                $null = $head.Add($fileEntry)

                    
                foreach ($revision in $revisions) { 
                    if (!$history.ContainsKey($revision.client_modified)){
                        $null = $history.Add($revision.client_modified, (New-Object System.Collections.ArrayList))
                    }
                    $subpathDisplay = ($fileEntry.path_display -replace "(?i)^$([Regex]::Escape("$Path/"))","/") 
                    Add-Member -InputObject $revision -TypeName "DropboxFileRevision" -Name "subpath_display" -MemberType NoteProperty -Value $subpathDisplay
                    $null = $history[$revision.client_modified].Add($revision)
                }
                Add-Member -InputObject $fileEntry -TypeName "DropboxContentItem" -Name "Revisions" -MemberType NoteProperty -Value @($revisions)

                Write-Output $fileEntry
                    
            }
        }
    }

    if ($totalEntryCount -eq 0) {
        Write-Warning "No files were found. Exiting."
        return;
    }

    #return $history,$head,$contents   
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
    [CmdletBinding(DefaultParametersetName="DropBoxConfig",SupportsShouldProcess=$true)] 
    param(
        [Parameter(Mandatory)][string] $AuthToken = $(Read-Host -prompt @"
        Enter your Dropbox access token.  To get a token, follow the steps at
        https://blogs.dropbox.com/developers/2014/05/generate-an-access-token-for-your-own-account/
"@),
        [Parameter(Mandatory, ParameterSetName="DropBoxConfig")][string] $Path = "",
        [Parameter(ParameterSetName="DropBoxConfig")][string[]] $PathExcludes = (new-object string[] 0),
        [ValidateScript({Test-Path $_ -PathType Container })][string] $OutputDirectory,
        [Parameter(ParameterSetName="DropBoxHistory")] $contents
        # TO DO: Add [bool]$CaseSensitiveGit
    )
    
try { $Activity = "$($PSCmdlet.MyInvocation.MyCommand.Name)";$parentId=[int]::MaxValue;if($script:progressNextIndex -gt 0){$parentId=$script:progressIdStack[-1]};$Id = $script:progressNextIndex++;$script:progressIdStack.Add($id)>$null

    Write-Progress -Activity $Activity -Id $id -ParentId $parentId
    
    if($PsCmdlet.ParameterSetName -ne "DropBoxHistory") {
        Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Get-DropBoxHistory"
        # When we're done grabbing metadata, will will loop through this dictionary in order of its keys
        # to construct our git repo.
        $contents = Get-DropboxHistory $AuthToken $Path $PathExcludes 
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

        
        if(![bool]$WhatIfPreference.IsPresent){
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

        if(![bool]$WhatIfPreference.IsPresent){
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

#            $currentDirectory = Split-Path $entry.subpath_display -Parent
             
#            "v3.0","v4.0","v5.0" | %{
#                if($entry.subpath_display -like "*/$_/*") {
#                    git checkout -b $_
#                    $version = $_
#                }
#                else {
                    
#                }                
#            }

#            $lastDirectory = Split-Path $entry.subpath_display -Parent

            $before = $outFile

            Function Edit-FileName {
                $FindAndReplace = @(
                    ('(?<Start>.*\.)Mindmap\.(?<End>.*)(?<Extension>\.([^\\/.]*)$)','${Start}${End}.Contents${Extension}'),  #Swap where Contents appears
                    ("(?<Start>.*)_ch(?<End>\d{1,2}\..*)","`${Start}_Ch`${End}"),
                    # ("(?<Start>.*)Michaelis_ch(?<End>.*)","`${Start}Michaelis_Ch`${End}"),
                    ("(?<Start>.*)michaelis(?<End>.*)","`${Start}Michaelis`${End}"),
                    ("(?<Start>.*)(?<Appendix>App[ABCDEF])(?<Extension>\..*)","`${Start}Michaelis_`${Appendix}`${Extension}"),
                    ("(?<Start>.*)(?<Appendix>App[ABCDE])Michaelis(?<Extension>\..*)","`${Start}Michaelis_`${Appendix}`${Extension}"),
                    ("(?<Start>.*)Chapter(?<ChapterNumber>\d\d?)Michaelis(?<Extension>\..*)","`${Start}Michaelis_Ch`${ChapterNumber}`${Extension}"),
                    ("(?<Start>.*)Michaelis_Ch(?<ChapterNumber>\d)(?<Extension>\..*)","`${Start}Michaelis_Ch0`${ChapterNumber}`${Extension}"), # Change to use 0 padding on chapter number to two digits
                    ("(?<Start>.*)\(.*conflicted copy \d\d\d\d-\d\d-\d\d\)(?<Extension>\..*)","`${Start}`${Extension}")
                )
                $FindAndReplace | %{  $outFile = $outFile -replace $_[0],$_[1] }
                Write-Output $outFile
            }; 
            $outFile = Edit-FileName

            if ($outfile -clike "*_ch*") {
                Write-Host $outFile;
            }
            Function Assert-FileNameStartsWithPeriod {
                if( $outFile[0] -ne '.') {
                    Write-Error "File name '$outFile' does not begin with a period."
                }
            }; Assert-FileNameStartsWithPeriod

            $contributors = @(
                    @{FN="Audrey";LN="Doyle";Search="__AD.doc";Email="audrey.doyle@comcast.net"},
                    @{FN="Eric";LN="Lippert";Search="";Email="Eric@lippert.com"},
                    @{FN="Shane";LN="Kercheval";Search="";Email="shane.kercheval@gmail.com"},
                    @{FN="Ian";LN="Davis";Search="";Email="ian.f.davis@gmail.com"},
                    @{FN="Stephen";LN="Toub";Search="";Email="stoub@microsoft.com"},
                    @{FN="Jason";LN="Morse";Search="";Email="jason@eveningcreek.com"},
                    @{FN="Michael";LN="Stokesbary";Search="";Email="mike@IntelliTect.com"},
                    @{FN="Elisabeth";LN="Ryan";Search="";Email="elizabeth.c.ryan@pearson.com"},
                    @{FN="Mark";LN="Michaelis";Search="";Email="mark@IntelliTect.com"}
                )
            $AuthorFolderRegex = -join ("((?<AuthorFolder>(",(($contributors | %{ "($($_.FN)\.?($($_.LN))?)" }) -join "|"),")?)(Reviews?)?\\?)?")
            $authorInitialsTagRegex = -join ("(?<AuthorInitials>",(($contributors | %{ "$($_.FN[0])$($_.LN[0])" }) -join "|"),")")
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
                        ,"(\(v\d{1,2}\))?"
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

            if("$outFilePath\" -match $filePathRegex) {
                $authorFolder =  Get-RegExGroupNameValue $Matches "AuthorFolder"
                $rootFolder = Get-RegExGroupNameValue $Matches "RootFolder"
                $version = Get-RegExGroupNameValue $Matches "Version"
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
                }
                {$_ -in 'CopyEditsReviewed','EssentialCSharpSubmitted'} {
                    $rootFolder = ''
                    if(!$version) { 
                        Write-Error "Version not set for $outFile dated $date."
                    }
                    else {
                        $gitCommitMessage = "Final $(if($version){"$version "}else{''})manuscript submitted."
                        $tag = "$version Submitted"
                    }
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
                    Write-Error "`$ramainingPath = $remainingPath"
                }
                Default {
                    Write-Debug "`$remainingPath = $remainingPath"
                }
            }

            switch ($outFileName)
            {
                {$_ -in ' (Mark Michaelis''s conflicted copy 2016-12-20).gitignore','.gitignore'} {
                    $finalFileName =""
                    $outFileExtension = ".gitignore"
                    $outFileName = ".gitignore"
                }
                {$_ -in '032167491X.pdf','0321533925_Michaelis_FINAL.pdf','Essential C# v4.0.pdf'} {
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
                Default {
                    if($outFileName -match $fileNameRegex) {
                        $finalFileName = Get-RegExGroupNameValue $Matches "FinalFileName"
                        $authorFileTag = Get-RegExGroupNameValue $Matches "AuthorFileTag"
                    }
                    else {
                        throw "Unable to parse file name: $outfile"
                    }
                }
            }
            if($rootFolder -eq "Contracts") { 
                continue 
            }

            $outFile = [IO.Path]::Combine(".",$rootFolder,$remainingPath, "$finalFileName$outFileExtension")

            if($version -and ($version -ne $oldVersion)) {
                git checkout -b $version
                $oldVersion = $version
            }
            elseif(!$version -and ($rootFolder -notin "Figures","Slides")) {
                Write-Warning "$($entry.client_modified) $outFile '$($entry.id)')"
                $version = $oldVersion
            }



            if ($outFile -in ,'.')
            {
                #Ignore this file and continue to next file.
                continue
            }

            $authorItem=$contributors | ?{ 
                ($authorFolder -like "$($_.FN)*$($_.LN)") -or 
                ($authorFileTag -eq "$($_.FN[0])$($_.LN[0])"  )
            }
            if($authorItem) {
                $authorId = $authorItem.FN,$authorItem.LN -f "{0}.{1}"
                $authorFullName = $authorItem.FN,$authorItem.LN -f "{0} {1}"
                if (!$userInfos.ContainsKey($authorId)) {
                    # If we haven't seen this userId yet, make a request to get their name and email for the commit metadata.
                    $userInfos.Add($authorFullName, [PSCustomObject]@{ account_id=$authorId; name=@{display_name=$authorFullName}; email=$authorItem.Email }) > $null
                }
            }
            
            if( ([IO.Path]::GetExtension($outFile) -eq ".docx") -and (Test-Path ([IO.Path]::ChangeExtension($outFile,".doc"))) ) {
                git mv "$([IO.Path]::ChangeExtension($outFile,".doc"))" "$outFile"
            }
            elseif ( ([IO.Path]::GetExtension($outFile) -eq ".doc") -and (Test-Path ([IO.Path]::ChangeExtension($outFile,".docx"))) ) {
                git mv "$([IO.Path]::ChangeExtension($outFile,".docx"))" "$outFile"
                Write-Warning "The file extension on $([IO.Path]::ChangeExtension($outFile,".docs")) has gone back to $outFile"
            }
            # Above
            ###################

            # TO DO: Test
            #if ([bool](git config core.ignorecase)) {
            #    if( (Test-Path $outFile) -and ($outFile -cne (Resolve-Path (Get-Item $outFile) -Relative)) ) {
            #        git mv (Resolve-Path $outFile).Path $outFile -f
            #    }
            #}

            if(![bool]$WhatIfPreference.IsPresent){
                ###################################
                # Below 
                Copy-Item ("C:\Temp\EssentialCSharpDropboxFileHistory\$($entry.id)").Replace("id:","") $outFile
                #Invoke-DropboxApiDownload -Path "rev:$($entry.rev)" -OutFile (Join-Path $pwd $outFile) -AuthToken $AuthToken
            }

            & git add -A

            Write-Progress -Activity $Activity -Id $id -ParentId $parentId -Status "Git Add" -CurrentOperation "$(git status --short)"

            [string]$gitCommitOutput=$null
            if(!$gitCommitMessage) {
                $gitCommitMessage = "Revisions made $date`: $(git status --short)".Replace('"','`' )
            }
            if($authorId -or ($authorId=$entry[0].sharing_info.modified_by)) {  # Check before setting to support future (custom) injection of Author 
                if (!$userInfos.ContainsKey($authorId)) {
                    # If we haven't seen this userId yet, make a request to get their name and email for the commit metadata.
                    $userInfos[$authorId] = Invoke-DropboxApiRequest -Endpoint "users/get_account" -Body @{"account_id" = "$authorId"}  -AuthToken $AuthToken
                }
                $userInfo = $userInfos[$authorId]
            }   
      
            Function Git-Commit {
                [Cmdletbinding(SupportsShouldProcess=$true)]
                param()
                $gitParameters = @(
                    "commit", "-m",$gitCommitMessage,"--date","`"$date`""
                )
                if($userInfo) {
                    $gitParameters += @("--author", "`"$($userInfo.name.display_name) <$($userInfo.email)>`"")
                }
                
                ##################
                $tempStatusMessage = if($before -ne $outFile) {"Rename $before => $outFile"} else { $outFile }
                Write-Host ("{2}: {0} ({1})" -f $tempStatusMessage,($userInfo.name.display_name),$version )
                ##################   
                $gitCommitOutput = & git $gitParameters
                    
                if( ($gitCommitOutput -like "*fatal: could not open*") -or 
                        ($gitCommitOutput -like "*fatal: Unable to create * File exists.*") ) {
                    ## On occasion files are busy and retrying generally succeeds
                    Start-Sleep -Seconds 5
                    #$gitCommitOutput = git commit -m "$gitCommitMessage" --date $date --author "$($userInfo.name.display_name) <$($userInfo.email)>"
                    $gitCommitOutput = & git $gitParameters
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

            }; Git-Commit


            ############################
            # Below
            $manuscriptFiles =  (1..21 | %{ "Michaelis_Ch{0:00}" -f $_ } ) + ("A","B","C","D","F" | %{ "Michaelis_App{0}" -f $_ }) +  
                ("Preface","AbtAuthor","Acknowledgments","D","F" | %{ "Michaelis_App{0}" -f $_ }) + @("EssentialC#.dotx")
            
            switch ($outFile)
            {
                '.\Figures\Michaelis_Ch14.Mindmap_CollectionInterfacesWithStandardQueryOperators.mmap' {
                    Write-Warning "$($entry.client_modified) ($($entry.id): $outFile"
                }
                {$_ -in 'A','B','C'} {}
                'value3' {}
                Default {}
            }

            $miscFiles = "Notes.docx", 
            

            $outFile | Out-File -FilePath ".\files.txt" -Append -WhatIf:$false
            switch ($entry.id)
            {

                Default {}
            }
            # Above
            ##########################
        }

        Function Remove-DeletedFiles {
            # All file revisions commits have now been made.
            # We will make on last pass through $contents and delete every file that Dropbox reports as being deleted.
            # We have to do this at the end because dropbox doesn't report deletion times - only a boolean on if a file is deleted or not.
            # It's not ideal, but it's what we have to work with.
            foreach ($entry in $contents){
                $outFile = Join-Path "." $entry.subpath_display
                if ($entry.".tag" -eq "deleted"){
                    Remove-Item $outFile
                }
            }
    
            git add -A
            git commit -m "All Dropbox Deletions - Dropbox does not report deletion times."
        }

        git tag dropbox-final
    }
    finally {
        # Move our current directory back up to where we were before we started. We're done!
        Set-Location $originalLocation
    }
} finally {$script:progressNextIndex--;$script:progressIdStack.Remove($script:progressIdStack[-1]);Write-Progress -Activity $Activity -Id $id -Completed}
}