
<#
    .Synopsis
        Searches the Googes
    .DESCRIPTION
        Lets you quickly start a search from within Powershell

    .EXAMPLE
        Search-Google Error code 5
        --New google search results will open listing top entries for 'error code 5'

    .EXAMPLE
        search-google (gwmi win32_baseboard).Product maximum ram

        If you need to get the maximum ram for your motherboard, you can even use this
        type of syntax

    See http://foxdeploy.com/code-and-scripts/search-google/.
#>
Function Search-Google
{
    Begin
    {
        $query='https://www.google.com/search?q='
    }
    Process
    {
        if ($args.Count -eq 0)
        {
            "Args were empty, commiting `$input to `$args"
            Set-Variable -Name args -Value (@($input) | % {$_})
            "Args now equals $args"
            $args = $args.Split()
        }
        ELSE
        {
            "Args had value, using them instead"
        }
        
        Write-Host $args.Count, "Arguments detected"
        "Parsing out Arguments: $args"
        for ($i=0;$i -le $args.Count;$i++){
        $args | % {"Arg $i `t $_ `t Length `t" + $_.Length, " characters"} }
        
    $args | % {$query = $query + "$_+"}
    
}
End
{
    $url = $query.Substring(0,$query.Length-1)
    "Final Search will be $url `nInvoking..."
    start "$url"
}
}



Function Get-GoogleSessionVariable {
    [CmdletBinding()] param(
        [PSCredential] $credential
    )

    $EnterEmailPage = Invoke-WebRequest https://accounts.google.com/ServiceLoginAuth -SessionVariable session
    $EnterEmailPage.Forms[0].Fields["Email"] = $credential.UserName

    
    $EnterPasswordPage = Invoke-WebRequest -Uri $EnterEmailPage.Forms[0].Action -Method POST -Body $EnterEmailPage.Forms[0].Fields -WebSession $session
    $EnterPasswordPage.Forms[0].Fields["Passwd"] = $credential.GetNetworkCredential().Password
    $EnterPasswordPage.Forms[0].Fields["Email"] = $credential.UserName

    $AuthCompletePage = Invoke-WebRequest -Uri $EnterPasswordPage.Forms[0].Action -Method POST -Body $EnterPasswordPage.Forms[0].Fields -WebSession $session

    return $session
}

#pb=!1m8!1m3!1iYYYY!2iMM!3iDD!2m3!1iYYYY!2iMM!3iDD
Function Get-GoogleLocationHistoryKmlFileUri {
    [CmdletBinding()] param(
        [DateTime] $DateTime
    )
    #Subtract 1 from the month because the months are Zero based.
    #Note that KML files are located in PST.
    #authuser=1 indicates which user in the Goolge User Dropdown (0 based)
    return "https://www.google.com/maps/timeline/kml?authuser=1&pb=!1m8!1m3!1i$($DateTime.Year)!2i$($DateTime.Month-1)!3i$($DateTime.Day)!2m3!1i$($DateTime.Year)!2i$($DateTime.Month-1)!3i$($DateTime.Day)"
                                                               #pb=!1m8!1m3!1iYYYY             !2iMM                !3iDD                !2m3!1iYYYY             !2iMM                !3iDD
}
<#
$locationHistoryUrl = "https://www.google.com/maps/timeline/kml?authuser=0&pb=!1m8!1m3!1i2016!2i3!3i9!2m3!1i2016!2i3!3i9"
$webRequestResult1 = invoke-webrequest -uri "https://accounts.google.com/ServiceLogin" -SessionVariable sessionData1
$webRequestResult2 = Invoke-WebRequest -Uri "https://accounts.google.com/AccountLoginInfo" -Method Post -Body $webRequestResult1.Forms[0].Fields -SessionVariable sessionData2
$webRequestResult3 = Invoke-WebRequest -Uri $locationHistoryUrl -Method Get  -Body $webRequestResult1.Forms[0].Fields -SessionVariable sessionData2 -UseBasicParsing -OutFile out.txt
#>

Function Get-GoogleLocationHistoryKmlFile {
    [CmdletBinding()] param(
        [Microsoft.PowerShell.Commands.WebRequestSession] $session,
        [DateTime] $DateTime,
        [System.IO.FileInfo] $outFile
    )

    $uri = Get-GoogleLocationHistoryKmlFileUri $DateTime
    Invoke-WebRequest -Uri $uri -OutFile $outFile -WebSession $session
}