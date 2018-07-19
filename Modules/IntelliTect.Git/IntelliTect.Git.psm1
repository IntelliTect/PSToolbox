#Requires -Version 5.0  # Needed for enum definition.
#Requires -Modules IntelliTect.Common

#Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common

enum GitAction {
    Untracked
    Copied
    Renamed
    Deleted
    Added
    Modified
}


$script:gitActionsLookup =@{
    '??'= [GitAction]::Untracked;
    'C'= [GitAction]::Copied;
    'R'= [GitAction]::Renamed;
    'D'= [GitAction]::Deleted;
    'A'= [GitAction]::Added;
    'M'= [GitAction]::Modified;
};


Function Invoke-GitCommand {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ActionMessage,
        [Parameter(Mandatory,ValueFromRemainingArguments)][string[]]$Command
    )

    if(@($command).Count -gt 1) {
        $command = $command -join ' '
    }

    if($Command -notmatch '\s*git\s.*') {
        $Command = "git $Command"
    }

    if($ActionMessage) {
        $ActionMessage = " $($ActionMessage.Trim())";
    }

    if($PSBoundParameters['Verbose'] -and ($Commnd -notmatch '.*\s(-v|--verbose)(?:\s.*?|$).*')) {
        $Command += ' --verbose'
    }

    Write-Debug "Command: '$Command'"

    Invoke-ShouldProcess "`tExecute$($ActionMessage): `n$Command" "`tExecute$($ActionMessage): `n$Command" "Executing$ActionMessage..." {
        try {
            $foregroundColor = $host.PrivateData.VerboseForegroundColor
            $backgroundColor = $host.PrivateData.VerboseBackgroundColor

            # TODO: $host.PrivateData.VerboseForegroundColor returns  RBG, not a color name.
            #       We need to convert to color name of vise-versa to compare.
            if( <# ("$foregroundColor" -eq "$($Host.ui.RawUI.ForegroundColor)") -and #>
                    ("$backgroundColor" -ne 'Gray') ) {
                $foregroundColor = 'Gray'
            }
            Write-Host "Executing: `n`t$Command" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
        }
        catch {
            Write-Host "Executing: `n`t$Command" -ForegroundColor Gray
        }

        Invoke-Expression "$Command" -ErrorAction Stop  #Change error handling to use throw instead.
    }
}

Function Get-GitStatusObject {
    [CmdletBinding()]
    param(
        [GitAction[]]$action,
        [string[]]$path='*'
    )

    Invoke-GitCommand 'git status --porcelain' | Where-Object{
        $_ -match '(?<Action>[AMRDC]|\?\?)\s+(?<Filename>.*)' } | ForEach-Object{
            $matches
        } | ForEach-Object{
            [PSCustomObject]@{
                "Action"="$($script:gitActionsLookup.Item($_.Action))";
                "FileName"=$_.FileName
            }
        } | Where-Object{
            (!$PSBoundParameters.ContainsKey('action') -or @($action) -contains $_.Action) -and
                ($_.FileName -like $path)
        }
}

Function Update-GitAuthor {
        [CmdletBinding(SupportsShouldProcess)] param(
            [string]$originalHash,
            [string]$newAuthor
        )

        $currentBranch = (Invoke-GitCommand 'git rev-parse --abbrev-ref HEAD')
        Invoke-GitCommand "git checkout $originalHash"
        Invoke-GitCommand "git commit --amend --author $newAuthor"
        $newHash = (Invoke-GitCommand 'git show -s --format=%H')
        Invoke-GitCommand "git replace $originalHash $newHash"
        Invoke-GitCommand "git replace -d $originalHash"
        Invoke-GitCommand "git checkout $currentBranch"
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

    Write-Host "Parameters: "; $PSBoundParameters | Out-String
    if($RemoveIgnoredFilesToo -and !$RemoveUntrackedFiles) {
        Write-Error '-RemoveIgnoredFilesToo only valid if -RemoveUntrackedFiles is set' -ErrorAction Stop
    }
    return

    [string]$command = $null
    if($RemoveUntrackedFiles -and $RemoveIgnoredFilesToo) {
        $command += "`tgit clean -f -d -X $path `n"
    }
    if($RemoveUntrackedFiles) {
        $command += "`tgit clean -f -d $path `n"
    }
    if($RestoreTrackedFiles) {
        $command += "`tgit reset --hard HEAD `n"
    }

    if([string]::IsNullOrWhiteSpace($command)) {
        Echo 'test'
    }

    Invoke-GitCommand $command
}

Function Remove-GitBranch {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        # The filter, when matched, excludes from the branches to delete
        [Parameter(Mandatory,ValueFromPipeline)] [string] $Name,
        [Parameter()] [switch] $Force
    )
    $branches = Get-GitBranch $Name
    if (@($branches).Count -eq 0) {
        throw "Cannot branches matching name '$Name' because it does not exist."
    }

    $deleteIfNotMergedOption = '-d'
    if ($Force.IsPresent) {
        $deleteIfNotMergedOption = '-D'
    }

    $command = "git branch $deleteIfNotMergedOption"
    $branches | ForEach-Object { Invoke-GitCommand "$command $_" }
}

Function Get-GitBranch {
    [CmdletBinding()]
    param(
        # The filter, when matched, excludes from the branches to delete
        [Parameter(ValueFromPipeline)] [string] $Name
    )
    $nameIsNull = [bool]$Name
    Invoke-GitCommand "git branch" |
        ForEach-Object {
            $_.TrimStart('* ')
        } | Where-Object {
            (!$nameIsNull) -or ($_ -like $Name)
    }
}
