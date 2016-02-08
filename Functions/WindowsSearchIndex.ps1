
#See http://powertoe.wordpress.com/2010/05/17/powershell-tackles-windows-desktop-search/#Load the dll
Add-Type -path "$PSScriptRoot\..\Lib\Microsoft.Search.Interop.dll"

Function Script:Get-WindowsSearchIndexCrawlManager() {
    #Create an instance of CSearchManagerClass
    $sm = New-Object Microsoft.Search.Interop.CSearchManagerClass 
    #Next we connect to the SystemIndex catalog
    $catalog = $sm.GetCatalog("SystemIndex")
    #Get the interface to the scope rule manager
    $crawlman = $catalog.GetCrawlScopeManager()
    Return $crawlman

}
Function Get-WindowsSearchIndexDirectory([string]$filter = "*") {
    $crawlman = Get-WindowsSearchIndexCrawlManager
    #Next we set some variables to use in the enumeration
    $scopes = @() #The array that will hold our scopes
    $begin=$true #A variable to test for the first run of the enumeration
    [Microsoft.Search.Interop.CSearchScopeRule]$scope = $null #This will be passed 
                                       #as a reference to the enumeration process.
                                       #It will hold the scope as we enumerate.

    #Grab the enumeration object from the Crawl Scope Manager
    $enum = $crawlman.EnumerateScopeRules() 
    while ($enum.Next(1,[ref]$scope,[ref]$null) -or ($scope -ne $null)) {
         #To traverse the collection you must use the Next method
         #$enum.Next(1,[ref]$scope,[ref]$null)
         #$begin = $false
         $scopes += $scope #populate our array so we can use it later Powershell style
    }
    $results = $scopes | %{
            $Path = $null;
            if($_.PatternOrURL -like "file*" ) { $Path = ((New-Object Uri $_.PatternOrUrl).LocalPath) }
            Add-Member -InputObject $_ -NotePropertyName Path -NotePropertyValue  $Path;
            $_
        }
    $results = $results | ?{ ($_.PatternOrURL -like "$filter") -OR ($_.Path -like "$filter") } 
    return $results
}

Function New-WindowsSearchIndexDirectory([string]$path <# e.g. "C:\Users\*\AppData\" #>) {
    [string] $uri = (New-Object Uri $path).AbsoluteUri
    $crawlman = Get-WindowsSearchIndexCrawlManager
    $crawlman.AddUserScopeRule("$uri",$true,$false,$null) 
    $crawlman.SaveAll()
}

Function Remove-WindowsSearchIndexDirectory([string]$path <# e.g. "C:\Users\*\AppData\" #>) {
    [string] $uri = (New-Object Uri $path).AbsoluteUri
    $crawlman = Get-WindowsSearchIndexCrawlManager
    $crawlman.RemoveScopeRule($uri)
    $crawlman.SaveAll()
}