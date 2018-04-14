

$script:gitActionsLookup =@{
    '??'= 'Untracked'
    'C'= 'Copied';
    'R'= 'Renamed';
    'D'= 'Deleted';
    'A'= 'Added';
    'M'= 'Modified'
};

Function Get-GitStatus {
    [CmdletBinding()]
    param(

    )

    git status --porcelain | ?{ 
        $_ -match '(?<Action>[AMRDC]|\?\?)\s+(?<Filename>.*)' } | %{ $matches } | %{
            [PSCustomObject]@{
                "Action"="$($script:gitActionsLookup.Item($_.Action))";
                "FileName"=$_.FileName
            }
        }
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