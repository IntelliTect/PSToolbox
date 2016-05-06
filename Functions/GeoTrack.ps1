
function script:Test-CommandExists {
    param ($command)

    $oldPreference = $ErrorActionPreference

    $ErrorActionPreference = 'stop'

    try {
        if(Get-Command $command){
            return $true
        }
    }

    catch {
        Write-Host “$command does not exist”
        return $false
    }

    finally {
        $ErrorActionPreference=$oldPreference
    }

} #end function test-CommandExists

Function script:Add-GPSBabelCommandAlias {
    [CmdletBinding()] param(
    )

    if(script:Test-CommandExists 'GPSBabel') {
        # Note: Error handling for Get-Command does not work.  
        # See https://blogs.technet.microsoft.com/heyscriptingguy/2013/02/19/use-a-powershell-function-to-see-if-a-command-exists/)
        Get-Command GPSBabel
    }
    else {
        $gpsBabelPath = "${ProgramFiles(x86)}\GPSBabel\GPSBabel.exe"
        if(Test-Path $gpsBabelPath) {
            Set-Alias -Name  GPSBabel -Value $gpsBabelPath
        }
        elseif( ($PSVersionTable.PSVersion.Magor -ge 5) -and 
                (Get-Package gpsbabel -ErrorAction Ignore -OutVariable GpsBabelPackage) -and
                (Test-Path (Join-Path $gpsbabelpackage.Metadata["InstallLocation"] "GpsBabel.exe"))
            ) {
            $gpsbabelpath = Join-Path $gpsbabelpackage.Metadata["InstallLocation"] "GpsBabel.exe"
            Set-Alias -Name  GPSBabel -Value $gpsBabelPath
        }
        else {
            Throw "GPSBabel.exe is not installed or not in your path.  Please install GPSBabel before running this command."
        }
    }
}


Function GpsBabel {
    [CmdletBinding()]
    
        $gpsBabelPath = "${ProgramFiles(x86)}\GPSBabel\GPSBabel.exe"
        if(!(Test-Path $gpsBabelPath)) {
            if( ($PSVersionTable.PSVersion.Magor -ge 5) -and 
                (Get-Package gpsbabel -ErrorAction Ignore -OutVariable GpsBabelPackage) -and
                (Test-Path (Join-Path $gpsbabelpackage.Metadata["InstallLocation"] "GpsBabel.exe"))
            ) {
            $gpsbabelpath = Join-Path $gpsbabelpackage.Metadata["InstallLocation"] "GpsBabel.exe"
        }
        if(!(Test-Path $gpsBabelPath)) {
            Throw "GPSBabel.exe is not installed or not in your path.  Please install GPSBabel before running this command."
        }

        if($args.Count -eq 0) {
            '`n' | & $gpsBabelPath | select -SkipLast 1
        }
    }


    
}
Add-GPSBabelCommandAlias

<#
    .SYNOPSIS 
      Converts a GPS track from one type to another.

    .EXAMPLE
    Invoke-ComUsing ($application = $sr.Start-MicrosoftWord) { 
      $application.Visible = $false
    } 
    
    This command instantiates the Word Application, sets it to invisible, and then removes all COM references.
#>
Function Convert-GeoTrack {
    [CmdletBinding(SupportsShouldProcess=$true)]param (
        [ValidateScript({ (Test-Path $_ -PathType Leaf) -and ([IO.Path]::GetExtension($_) -in ,".kml")})] # Limited to extensions that have been tested.
            [Parameter(Mandatory, ValueFromPipeLine, ValueFromPipelineByPropertyName)][Alias("FullName","InputObject")][string]$inputFile,
        [ValidateScript({ ([IO.Path]::GetExtension($_) -in ,".gpx")})] # Limited to extensions that have been tested.
            [Parameter(Mandatory)][string]$outputFile = [IO.Path]::ChangeExtension($inputFile.FullName, ".gpx")
    )

    $command = "gpsbabel -i $([IO.Path]::GetExtension($inputFile).Trim(".")) -f $inputFile  -o $([IO.Path]::GetExtension($outputFile).Trim(".")) -F $outputFile"
    if ($PSCmdlet.ShouldProcess("`tExecuting: $command", "`tExecute gpsbabel.exe: $command", "Executing gpsbabel.exe")) {
        Invoke-Expression $command
    }
}

Function Get-GoogleSessionVariable {
    [CmdletBinding()] param(
        [string] $email,
        [string] $password
    )

    $EnterEmailPage = Invoke-WebRequest https://accounts.google.com/ServiceLoginAuth -SessionVariable session
    $EnterEmailPage.Forms[0].Fields["Email"] = $email

    
    $EnterPasswordPage = Invoke-WebRequest -Uri $EnterEmailPage.Forms[0].Action -Method POST -Body $EnterEmailPage.Forms[0].Fields -WebSession $session
    $EnterPasswordPage.Forms[0].Fields["Passwd"] = $password
    $EnterPasswordPage.Forms[0].Fields["Email"] = $email

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


Function Get-GoogleLocationHistoryKmlFile {
    [CmdletBinding()] param(
        [Microsoft.PowerShell.Commands.WebRequestSession] $session,
        [DateTime] $DateTime,
        [System.IO.FileInfo] $outFile
    )

    $uri = Get-GoogleLocationHistoryKmlFileUri $DateTime
    Invoke-WebRequest -Uri $uri -OutFile $outFile -WebSession $session
}

<#
$locationHistoryUrl = "https://www.google.com/maps/timeline/kml?authuser=0&pb=!1m8!1m3!1i2016!2i3!3i9!2m3!1i2016!2i3!3i9"
$webRequestResult1 = invoke-webrequest -uri "https://accounts.google.com/ServiceLogin" -SessionVariable sessionData1
$webRequestResult2 = Invoke-WebRequest -Uri "https://accounts.google.com/AccountLoginInfo" -Method Post -Body $webRequestResult1.Forms[0].Fields -SessionVariable sessionData2
$webRequestResult3 = Invoke-WebRequest -Uri $locationHistoryUrl -Method Get  -Body $webRequestResult1.Forms[0].Fields -SessionVariable sessionData2 -UseBasicParsing -OutFile out.txt
#>