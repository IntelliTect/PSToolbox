

Function Get-WindowsVersionName {
    $os = $null
    try {
        #Consider using Get-Command with -ErrorAction of Ignore
        $os = Get-CimInstance "Win32_OperatingSystem" #Not supported prior to Windows 8
    }
    catch {
        $os = Get-WmiObject Win32_OperatingSystem
    }

    #See http://gallery.technet.microsoft.com/scriptcenter/6e1b6724-3674-4487-b544-2706bfe0b0b5/view/Discussions#content
    switch -Wildcard ("$($os.Version + "-" + $os.ProductType)") 
    {
	    "5.1.2600-*" { $result = "Windows XP"; } #Untested
	    "5.1.3790-*" { $result = "Windows Server 2003"; } #Untested
	    "6.0.6001-1" { $result = "Windows Vista"; } #Untested
	    "6.1.7601-1" { $result = "Windows 7"; } 
	    "6.1.7601-3" { $result = "Windows Server 2008 R2"; }
	    "6.2.9200-1" { $result = "Windows 8"; }
	    "6.2.9200-3" { $result = "Windows Server 2012"; }
        "6.3.9600-1" { $result = "Windows 8.1" }
	    default { throw "Windows Version not Identified" }
    }
    return $result
}

<#
Function Add-DirectoryToWindowsSearch {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateScript({Test-Path $_})][Parameter(Mandatory)][string[]]$path
    )
    $path | ForEach-Object{
        $item = (Resolve-Path $_).Path.Replace('\','\\')
    #Add C:\Data to windows Search:

#See http://dk.toastednet.org/iex_lh/Text/vista_search_guide.html

$regFile = (Join-Path $env:temp 'WindowsSearch.reg')
try {
    Write-Output @"
        Windows Registry Editor Version 5.00


        [HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex\StartPages\$NextEntry]
        "URL"="$item"
        "HostDepth"=dword:00000000
        "EnumerationDepth"=dword:ffffffff
        "FollowDirectories"=dword:00000001
        "StartPageIdentifier"=dword:$NextEntry
        "CrawlNumberInProgress"=dword:0000000c
        "CrawlNumberScheduled"=dword:ffffffff
        "ForceFullCrawl"=dword:00000000
        "ForceFullCrawlExternal"=dword:00000000
        "LastCrawlStopped"=dword:00000000
        "Type"=dword:00000000
        "CrawlControl"=dword:00000000
        "LastCrawlType"=dword:00000000
        "IncludeInProjectCrawls"=dword:00000001
        "LastCrawlTime"=hex:00,00,00,00,00,00,00,00
        "LastStartCrawlTime"=hex:2b,0e,75,2f,8d,46,cf,01
        "AccessControl"=hex:99,ca,ba,de,03,00,00,00,02,00,00,00,00,00,00,00,00,00,00,\
            00,07,00,00,00,01,00,00,00,00,00,00,00,00,00,00,00,07,00,00,00,00,00,00,00,\
            00,00,00,00,00,00,00,00,07,00,00,00,02,00,00,00
        "NotificationHRes"=dword:00000000
"@  `
        > $regFile
        Write-Verbose "Created $regFile"
        Reg.exe Import WindowsSearch.reg
    }
    finally {
         Get-Item $regFile -ErrorAction Ignore | Remove-Item -Force
    }
    }
}
#>
