
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
