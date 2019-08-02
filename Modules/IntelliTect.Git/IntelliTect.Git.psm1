#Requires -Version 5.0  # Needed for enum definition.
#Requires -Modules IntelliTect.Common

. $PSScriptRoot\New-DynamicParam.ps1

# TODO: Using straight enum is not getting imported into other scripts.
 Enum GitAction {
    Untracked
    Copied
    Renamed
    Deleted
    Added
    Modified
}

$script:GitActionLookup =@{
    '??'= [GitAction]::Untracked;
    'C'= [GitAction]::Copied;
    'R'= [GitAction]::Renamed;
    'D'= [GitAction]::Deleted;
    'A'= [GitAction]::Added;
    'M'= [GitAction]::Modified;
};

Function Invoke-GitCommand {
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName='OutputAsObject')]
    param(
        [Parameter(Mandatory)][string]$ActionMessage
        ,[Parameter(Mandatory,ValueFromRemainingArguments)][string[]]$Command
        ,[Parameter(ParameterSetName='OutputAsText')][string]$Format = $null
    )
    DynamicParam {
        New-DynamicParam -Name GitProperty -ValidateSet (Get-GitItemProperty) `
            -HelpMessage 'The property(s) to be retrieved.' `
            -ParameterSetName 'OutputAsObject' -Position 3 -Type ([string[]])
    }
    BEGIN {
        $GitProperty = $PSBoundParameters.GitProperty
    }

    PROCESS {

        
        if($ActionMessage) {
            $ActionMessage = " $($ActionMessage.Trim())";
        }
        
        
        if($GitProperty) {
            # Format the output as JSON with keys&values single quoted (double quotes don't work with git format by default)
            # Later on the single quotes are converted back to double quotes.
            # TODO: What if there are single quotes in one of the values?
            $Format = "`"$( (Get-GitItemProperty -Name $GitProperty |
            ForEach-Object { "%($_)"})  -join ',')`""
        }
        
        $commandText = $Command | Where-Object { -not [string]::IsNullOrEmpty($_) } | Foreach-Object {
            # Remove git from the beginning of the command if it exists
            $eachCommandText = $_ -replace '^\s*(git)*\s',''

            if($Format) {
                $eachCommandText += " --format=$Format"
            }
            
            if($PSBoundParameters['Verbose'] -and ($eachCommandText -notmatch '.*\s(-v|--verbose)(?:\s.*?|$).*')) {
                $eachCommandText += ' --verbose'
            }

            if($eachCommandText -notmatch '\s*git\s.*') {
                $eachCommandText = "git $eachCommandText"
            }

            Write-Debug "Command: '$eachCommandText'"
            
            Write-Output $eachCommandText
        }

        [ScriptBlock]$CommandScript = [scriptblock]::Create($commandText -join '; ')

        Invoke-ShouldProcess "`tExecute$($ActionMessage): `n$commandText" "`tExecute$($ActionMessage): `n$commandText" "Executing$ActionMessage..." {
            try {
                $foregroundColor = $host.PrivateData.VerboseForegroundColor
                $backgroundColor = $host.PrivateData.VerboseBackgroundColor

                # TODO: $host.PrivateData.VerboseForegroundColor returns  RBG, not a color name.
                #       We need to convert to color name of vise-versa to compare.
                if( <# ("$foregroundColor" -eq "$($Host.ui.RawUI.ForegroundColor)") -and #>
                        ("$backgroundColor" -ne 'Gray') ) {
                    $foregroundColor = 'Gray'
                }
                Write-Host "Executing: `n`t$commandText" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
            }
            catch {
                Write-Host "Executing: `n`t$commandText" -ForegroundColor Gray
            }

            $result = Invoke-Command $CommandScript -ErrorAction Stop  #Change error handling to use throw instead.

            if($GitProperty) {
                $result = $result.Replace("'",'"') | ConvertFrom-Json
            }

            Write-Output $result
        }
    }
}

Function Get-GitItemStatus{
    [CmdletBinding()]
    param(
        [GitAction[]]$Action,
        [string[]]$Filter='*'
    )

    Invoke-GitCommand -ActionMessage 'Show the working tree status' -Command 'git status --porcelain' | Where-Object{
        $_ -match '(?<Action>[AMRDC]|\?\?)\s+(?<Filename>.*)' } | ForEach-Object{
            $matches
        } | ForEach-Object{
            [PSCustomObject]@{
                "Action"="$([GitAction]$script:GitActionLookup.Item($_.Action))";
                "FileName"=$_.FileName
            }
        } | Where-Object{
            (!$PSBoundParameters.ContainsKey('action') -or @($Action) -contains $_.Action) -and
                ($_.FileName -like $Filter)
        }
}

Function Update-GitAuthor {
        [CmdletBinding(SupportsShouldProcess)] param(
            [string]$originalHash,
            [string]$newAuthor
        )

        $currentBranch = (Invoke-GitCommand 'Pick out and massage parameters' 'git rev-parse --abbrev-ref HEAD')
        Invoke-GitCommand "Restore working files to original commit ($originalHash)" "git checkout $originalHash"
        Invoke-GitCommand "Change the author name to $newAuthor" "git commit --amend --author $newAuthor"
        $newHash = (Invoke-GitCommand 'Retrieve the hash' 'git show -s --format=%H')
        Invoke-GitCommand 'Replace the original commit hash with the new one' "git replace $originalHash $newHash"
        Invoke-GitCommand 'Remove the original commit' "git replace -d $originalHash"
        Invoke-GitCommand 'Switch back to the head of the branch we started with' "git checkout $currentBranch"
        Write-Warning 'Execute ''git filter-branch -- --all'' once all updates are complete. '
}

Function New-GitIgnore {
    [CmdletBinding()]
    param(
         [ValidateSet("actionscript","ada","adobe","agda","alteraquartusiiandroid","anjuta","ansible","apachecordova","appbuilderappceleratortitanium","appcode","appengine","aptanastudio
","arcanistarchive","archives","archlinuxpackages","assembler","atmelstudioautomationstudio","autotools","basercms","basic","batchbazaar","bazel","bitrix","blackbox","bluejbower","bricxcc","c","c++","cakecakep
hp","calabash","carthage","ceylon","cfwheelschefcookbook","clion","clojure","cloud9","cmakecocos2dx","code","code-java","codeblocks","codeignitercodeio","codekit","coffeescript","commonl
isp","composercompressedarchive","compression","concrete5","coq","craftcmscrashlytics","crossbar","crystal","csharp","cudacvs","d","dart","darteditor","datarecoverydelphi","django","dm",
"dotfilessh","dotsettingsdreamweaver","dropbox","drupal","eagle","easybookeclipse","eiffelstudio","elasticbeanstalk","elisp","elixirelm","emacs","ember","ensime","episervererlang","espre
sso","expressionengine","extjs","f#fancy","fastlane","finale","flashbuilder","flexflexbuilder","fontforge","forcedotcom","fortran","freepascalfuelphp","fusetools","gcov","genero4gl","ggt
sgit","gitbook","go","gpg","gradlegrails","greenfoot","grunt","gwt","haskellhsp","hugo","iar_ewarm","idris","igorproimages","infer","intellij","intellij+iml","jabrefjava","jboss","jdevel
oper","jekyll","jetbrainsjmeter","joe","joomla","jspm","juliajustcode","kate","kdevelop4","kicad","kirby2kobalt","kohana","komodoedit","labview","laravellatex","lazarus","leiningen","lem
onstand","lessliberosoc","librarian-chef","libreoffice","lilypond","linuxlithium","lua","lyx","m2e","macosmagento","matlab","maven","mercurial","mercurymetaprogrammingsystem","meteorjs",
"microsoftoffice","modelsim","modxmomentics","monodevelop","nanoc","ncrunch","nescnetbeans","nette","nim","ninja","nodenotepadpp","objective-c","ocaml","octobercms","opaopencart","opencv
","openfoam","openframeworks","oracleformsosx","otto","packer","perl","ph7cmsphalcon","phoenix","phpstorm","pimcore","pinegrowplayframework","plone","polymer","premake-gmake","prestashop
processing","progressabl","puppet-librarian","purescript","pycharmpython","qml","qooxdoo","qt","rracket","rails","redcar","redis","rhodesrhomobileroot","ros","ruby","rubymine","rustsas",
"sass","sbt","scala","schemescons","scrivener","sdcc","seamgen","senchatouchserverless","shopware","silverstripe","sketchup","slickeditsmalltalk","sonar","sourcepawn","splunk","statastel
la","stellar","stylus","sublimetext","sugarcrmsvn","swift","symfony","symphonycms","synologysynopsysvcs","tags","tarmainstallmate","terraform","testtestcomplete","tex","textmate","textpa
ttern","theos-tweaktortoisegit","tower","turbogears2","typings","typo3umbraco","unity","unrealengine","vagrant","vimvirtualenv","virtuoso","visualstudio","visualstudiocode","vivadovvvv",
"waf","wakanda","webmethods","webstormwerckercli","windows","wintersmith","wordpress","xamarinstudioxcode","xilinxise","xojo","xtext","yeomanyii","yii2","zendframework","zephir")]
         [Parameter(Mandatory)]$projectType = "VisualStudio"
    )
    process {
        Invoke-WebRequest -Uri "https://www.gitignore.io/api/$projectType" |
            Select-Object -ExpandProperty Content | Out-File -FilePath $(Join-Path -path $pwd -ChildPath ".gitignore") -Encoding ascii
    }
}


Function Undo-Git {
    [CmdletBinding(DefaultParameterSetName='TrackedAndIgnored',SupportsShouldProcess)]
    param(
        [ValidateScript({ Test-Path $_ })]
        [Parameter(Position=0,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Alias('FullName')][string[]]$Path
        # Parameter help description
        ,[switch]$RestoreTrackedFiles
        ,[Parameter(ParameterSetName='TrackedOnly')]
        [Parameter(ParameterSetName='TrackedAndIgnored')][switch]$RemoveUntrackedFiles=$false
        ,[Parameter(ParameterSetName='TrackedAndIgnored')][switch]$RemoveIgnoredFilesToo
    )

    #Write-Host "Parameters: "; $PSBoundParameters | Out-String
    if($RemoveIgnoredFilesToo -and !$RemoveUntrackedFiles) {
        Write-Error '-RemoveIgnoredFilesToo only valid if -RemoveUntrackedFiles is set' -ErrorAction Stop
    }

    #TODO: Handle an array for $path
    
    if($RemoveUntrackedFiles -and $RemoveIgnoredFilesToo) {
        Invoke-GitCommand -ActionMessage 'Remove files ignored by Git.' -Command "git clean -f -d -X $path"
    }
    if($RemoveUntrackedFiles) {
       Invoke-GitCommand -ActionMessage 'Remove untracked directories in addition to untracked files.' -Command "git clean -f -d $path"
    }
    if($RestoreTrackedFiles) {
        Invoke-GitCommand -ActionMessage 'Reset current branch to the latest commit (HEAD)' -Command "git reset --hard HEAD"
    }
}

Function Remove-GitBranch {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        # The filter, when matched, excludes from the branches to delete
        [Parameter(Mandatory,ValueFromPipeline)] [string] $Name,
        [Parameter()] [switch] $Force
    )

    [string]$additionalActionMessageDetail = ''

    $branches = Get-GitBranch $Name
    if (@($branches).Count -eq 0) {
        throw "Cannot remove branches matching name '$Name' because it does not exist."
    }

    $deleteIfNotMergedOption = '-d'
    if ($Force.IsPresent) {
        $additionalActionMessageDetail += ' even if not merged'
        $deleteIfNotMergedOption = '-D'
    }

    $commandText = "git branch $deleteIfNotMergedOption"
    $branches | ForEach-Object { Invoke-GitCommand "Remove the $Name branch$additionalActionMessageDetail." "$commandText $_" }
}

Function Get-GitBranch {
    [CmdletBinding()]
    param(
        # The filter, when matched, excludes from the branches to delete
        [Parameter(ValueFromPipeline)] [string] $Name
        ,[Alias('Remotes')][switch]$IncludeRemotes=$false
        ,[Alias('Locals')][switch]$IncludeLocals=$true
    )

    [string]$options = ' --list'

    if($IncludeLocals) {
        Invoke-GitCommand -ActionMessage "List branch $Name" -command "git branch $Name $options" -verbose  | ForEach-Object {
            #if($_)
            $_.TrimStart('* ') # Remove the '*' that indicates the branch is current.
        }
    }

    if($IncludeRemotes.IsPresent) {
        $options += ' --remotes'  # --remotes is exclusive, it removes locals
        Invoke-GitCommand -ActionMessage "List branch $Name" -command "git branch $Name $options" -verbose | ForEach-Object {
            #if($_)
            $_.TrimStart('* ') # Remove the '*' that indicates the branch is current.
        }
    }
}

Function Get-GitItemProperty {
    [CmdletBinding()]
    param(
        [string[]]$Name
    )

    $result = 'refname:short','refname','objecttype','objectsize','objectname','tree','parent','numparent','object','type','tag','author','authorname','authoremail','authordate','committer','committername','committeremail','committerdate','tagger','taggername','taggeremail','taggerdate','creator','creatordate','subject','body',<#'contents',#><#'contents:subject',#><#'contents:body'#>,'contents:signature','upstream','symref','flag','HEAD'
        # 'contents' removes because no further parsing occurs after this property with --format
        # 'contents:subject', 'contents:body' removed as they appear to be duplicates.
    if($Name) {
        $result = $result | Where-Object {
            $property = $_
            $Name | Where-Object {
                    $property -like $_
            }
        }
    }

#    [string]$compositFormat = $null
#     switch ($Format) {
#         'GitFormat' {
#             $compositFormat = "%({0})"
#         }
#         'Json' {
#             $compositFormat = "`"{0}`":`"%({0})`""
#         }
#     }

    # if($compositFormat) {
    #     $result = $result | ForEach-Object{
    #         $compositFormat -f $_
    #     }
    # }

    $result | Write-Output
}

#Function ConvertFrom-Git