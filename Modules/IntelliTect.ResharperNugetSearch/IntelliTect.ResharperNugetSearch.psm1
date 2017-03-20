<#
    .Synopsis
        Searches for Nuget packages by the name of a type.
    .DESCRIPTION
        Searches Jet Brain's awesome Resharper API for Nuget packages by type name, and returns 
        a paged list of objects. Results are limited to 20 per page, so this function also returns
        the total number of items, the total pages and the current page (if applicable).

    .PARAMETER Search
        Type name to search, can be with full namespace.

    .PARAMETER AllowPrerelease
        Allow searching for prerelease nuget packages, false by default.

    .PARAMETER CaseSensitive
        Use case sensitive matching for type name, false by default.

    .PARAMETER LatestVersion
        Search only latest versions of packages, true by default

    .PARAMETER PageIndex
        Search results page index, page size is 20 items.

    .EXAMPLE
        Simple search for a specific type:

        Search-NugetForType OpenStreetMapLayer

    .EXAMPLE
        Go to a specific page in the search results:

        Search-NugetForType Date -PageIndex 8
#>
Function Search-NugetForType {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true, Position=0 )] [String] $Search,
        [Parameter()] [Switch]$AllowPrerelease = $false,
        [Parameter()] [Switch]$CaseSensitive = $false,
        [Parameter()] [Switch]$LatestVersion,
        [Parameter()] [Int32]$PageIndex = 0        
    )
    Begin 
    {
        $rootUri = "http://resharper-nugetsearch.jetbrains.com/api/v1/find-type?"

        # Fix for Invoke-RestMethod through authenticated proxies
        [System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
        [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    }
    Process
    {
        $queryUri = "$($rootUri)name={0}&allowPrerelease={1}&caseSensitive={2}&latestVersion={3}&pageIndex={4}" -f $Search, `
            $AllowPrerelease, `
            $CaseSensitive, `
            $LatestVersion, `
            $PageIndex
        $results = Invoke-RestMethod -Uri $queryUri
    }
    End
    {
        Write-Host "    Total Results : $($results.totalResults)" -ForegroundColor DarkCyan
        Write-Host "    Total Pages   : $($results.totalPages)" -ForegroundColor DarkCyan
        if ($results.pageIndex -ne 0) {
            Write-Host "    Page Index    : $($results.pageIndex)" -ForegroundColor DarkCyan
        }

        if ($results.packages.Count -eq 0) {
            Write-Host "No packages found."
        }
        return $results.packages
    }
}

<#
    .Synopsis
        Searches for Nuget packages by a namespace name.
    .DESCRIPTION
        Searches Jet Brain's awesome Resharper API for Nuget packages by namespace, and returns 
        a paged list of objects. Results are limited to 20 per page, so this function  also returns 
        the total number of items, the total pages and the current page (if applicable).

    .PARAMETER Search
        Namespace name to search.

    .PARAMETER AllowPrerelease
        Allow searching for prerelease nuget packages, false by default.

    .PARAMETER CaseSensitive
        Use case sensitive matching for type name, false by default.

    .PARAMETER LatestVersion
        Search only latest versions of packages, true by default

    .PARAMETER PageIndex
        Search results page index, page size is 20 items.

    .EXAMPLE
        Simple search for a specific type:

        Search-NugetForNamespace Esri

    .EXAMPLE
        Go to a specific page in the search results:

        Search-NugetForNamespace Date -PageIndex 8
#>
Function Search-NugetForNamespace {
    [CmdletBinding()] param(
        [Parameter(Mandatory=$true, Position=0 )] [String] $Search,
        [Parameter()] [Switch]$AllowPrerelease = $false,
        [Parameter()] [Switch]$CaseSensitive = $false,
        [Parameter()] [Switch]$LatestVersion,
        [Parameter()] [Int32]$PageIndex = 0        
    )
    Begin 
    {
        $rootUri = "http://resharper-nugetsearch.jetbrains.com/api/v1/find-namespace?"

        # Fix for Invoke-RestMethod through authenticated proxies
        [System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
        [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    }
    Process
    {
        $queryUri = "$($rootUri)name={0}&allowPrerelease={1}&caseSensitive={2}&latestVersion={3}&pageIndex={4}" -f $Search, `
            $AllowPrerelease, `
            $CaseSensitive, `
            $LatestVersion, `
            $PageIndex
        $results = Invoke-RestMethod -Uri $queryUri
    }
    End
    {
        Write-Host "    Total Results : $($results.totalResults)" -ForegroundColor DarkCyan
        Write-Host "    Total Pages   : $($results.totalPages)" -ForegroundColor DarkCyan
        if ($results.pageIndex -ne 0) {
            Write-Host "    Page Index    : $($results.pageIndex)" -ForegroundColor DarkCyan
        }

        if ($results.packages.Count -eq 0) {
            Write-Host "No packages found."
        }
        return $results.packages
    }
}
