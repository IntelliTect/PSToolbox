<#[CmdletBinding(
    SupportsShouldProcess=$true #Tells the shell that your function supports both -confirm and -whatif.
    ,ConfirmImpact="Medium" #Causes Confirm prompt when $ConfirmPreference is "High"
)]
param(
        [string]$fromDirectory
        ,[string] $toRootDirectory="C:\Data\Photos\MarEli"
        ,[bool] $move=$true
        ,[Parameter(ValueFromPipeline=$true)][IO.FileInfo[]]$files=$(dir $fromDirectory -Recurse -Include *.MTS,*.JPG,*.MOV,*.JPEG,*MP4 )
)
#>

Set-StrictMode -Version "Latest"

# Future Features:
    #Add support for png and mp4 files.
    # For people tagging check out:
        # http://www.dustyfish.com/blog/using-wic-c-to-read-windows-live-photo-gallerys-people-tags
        # http://msdn.microsoft.com/en-us/library/ee719905(v=vs.85).aspx
        # http://poshcode.org/617
        # http://www.dustyfish.com/blog/understanding-how-windows-live-photo-gallerys-people-tags-are-stored

[string]$here=Split-Path -Path ($MyInvocation.MyCommand.Path);

Function script:LoadPhotoLibraryAssembly()
{
    $photoLibraryPath = Get-ChildItem "$PSScriptRoot\..\Lib","$PSScriptRoot" "PhotoLibrary.dll" |
      Sort-Object -Descending CreationTime | Select-Object -First 1 -ExpandProperty FullName
    if( !(test-path variable:\photoLibraryPath) -AND !(test-path $photoLibraryPath) )
    {
	    $photoLibraryPath="$utils\PhotoLibrary.dll"
    }
    if(!(test-path $photoLibraryPath)) {
      $photoLibraryPath='C:\data\Programs\Utilities\PhotoLibrary.dll'
    }
    #TODO: Switch to use Add-Type
    [void] [Reflection.Assembly]::LoadFrom($photoLibraryPath)
    $rootPath = $PSScriptRoot
    $photoLibraryPath = Get-ChildItem "$rootPath\..\Lib","$rootPath" "PhotoLibrary.dll" |
      Sort-Object -Descending CreationTime | Select-Object -First 1 -ExpandProperty FullName

    if(!(test-path variable:\photoLibraryPath) -or !(test-path $photoLibraryPath)) {
        throw "Unable to find PhotoLibrary.dll"
    }

    #TODO: Switch to use Add-Type
    Add-Type -Path $photoLibraryPath -ErrorAction Stop
}
LoadPhotoLibraryAssembly

function script:GetDateTimeOriginal($target) {
    [System.Nullable[System.DateTime]] $originalTimeStamp = Get-member DateTimeOriginal -InputObject $target | %{$target.DateTimeOriginal};
    return $originalTimeStamp;
}

#Admittedly we could just take the parameters as System.Object and call the $originalTimeStamp on them directly but
#the strongly typed approach ensures we can get the more accurate photo metadata when available.
#TODO: This doesn't work if PhotoLibrary.dll is not loaded.  Update to make it optional when a JPG file is not used.
function GetSubDirectoryWithDateTimePath(
    [Parameter(ParameterSetName="FileInfo",Mandatory)][IO.FileInfo]$file
    ,[Parameter(ParameterSetName="Photo",Mandatory)][Photolibrary.Photo]$photo
)
{
    [System.Nullable[System.DateTime]] $originalTimeStamp = $null;
    $target=$null;

    if($PSCmdlet.ParameterSetName -eq "Photo") {
        $originalTimeStamp=GetDateTimeOriginal $photo;
        if($originalTimeStamp -eq $null) {
            $file = New-Object IO.FileInfo -ArgumentList $photo.GetFullPath();
        }
    }

    if($originalTimeStamp -eq $null) {
        $originalTimeStamp=GetDateTimeOriginal $file;
    }

    if($originalTimeStamp -eq $null)
    {
        $originalTimeStamp = $file.CreationTime;
    }

    [string] $targetDirectory = join-path $originalTimeStamp.Year.ToString("0000") $originalTimeStamp.Month.ToString("00");
	return [String]$targetDirectory;
}


# Temporarily Leaving function as a way of verifying
# new functionality matches the old.
# TODO: Delete this function if the replace
#       proves accruate.
Function Script:Get-LegacyTargetName([Photolibrary.Photo]$photo) {
    [string] $targetFileName=$photo.GetFileName();
    switch($photo.Model) {
        "NIKON D70" {
            $targetFileName = $targetFileName.Replace("IMG_", "NikonD70_");
        }
        "Canon EOS 30D" {
            $targetFileName = $targetFileName.Replace("IMG_", "EOS30D_");
        }
        "BlackBerry 9650" {
            $targetFileName = $targetFileName.Replace("IMG_", "BB9650_");
        }
        "" {
            #leave the name the same
        }
        default {
            #Should be changed to a switch statement.
            if($photo.Model -eq "Canon IXY DIGITAL 800 IS")
            {
                $targetFileName = $targetFileName.Replace("IMG_", "800IS_")
            }
            elseif($photo.Model -eq "Canon EOS 20D")
            {
                $targetFileName = $targetFileName.Replace("IMG_", "EOS20D_")
            }
            elseif($photo.Model -eq "SQ908 MEGA-Cam")
            {
                $targetFileName = $targetFileName.Replace("IMG_", "SQ908_")
            }
            elseif($photo.Model -eq "Canon PowerShot SD3500 IS")
            {
                $targetFileName = $targetFileName.Replace("IMG_", "SD3500_")
            }
            elseif($photo.Model -eq "Canon PowerShot SD780 IS")
            {
                $targetFileName = $targetFileName.Replace("IMG_", "SD780_")
            }
            elseif($photo.Model -eq "COOLPIX S4100")
            {
                $targetFileName = $targetFileName.Replace("DSCN", "NikonS4100_")
            }
            elseif($photo.Model -eq "Canon PowerShot ELPH 100 HS")
            {
                $targetFileName = $targetFileName.Replace("IMG_", "Elph100HS_")
            }
            elseif($photo.Model -eq "Canon EOS REBEL T4i")
            {
                $targetFileName = $targetFileName.Replace("IMG_", "EOST4i_")
            }
            elseif($photo.Model -eq "Canon EOS 70D")
            {
                $targetFileName = $targetFileName.Replace("IMG_", "EOS70D_")
            }
            elseif($photo.Model -eq "Canon PowerShot A2400 IS")
            {
                $targetFileName = $targetFileName.Replace("IMG_", "A2400_")
            }
            elseif($photo.Model -eq "Canon PowerShot G12")
            {
                $targetFileName = $targetFileName.Replace("IMG_", "PS-G12_")
            }
            elseif($photo.Model -eq "RHOD500")
            {
                $targetFileName = "RHOD500_" + $photo.GetFileName()
            }
            elseif($photo.Model -eq "NIKON D60")
            {
                $targetFileName = "NIKOND60_" + $photo.GetFileName()
            }
            elseif($photo.Model -eq "NIKON D3300")
            {
                $targetFileName = $targetFileName.Replace("DSC_", "NIKOND3300_")
            }
            elseif($photo.Model -eq "T-Mobile G2")
            {
                $targetFileName = $targetFileName.Replace("IMG_", "G2_")
            }
            elseif($photo.Model -eq "Canon PowerShot SD1200 IS")
            {
                $targetFileName = $targetFileName.Replace("IMG_", "SD1200_")
            }
            elseif($photo.Model -like "iPhone*")
            {
                $targetFileName = $photo.Model.Replace(" ", "") + "_" + $targetFileName
            }
            elseif($photo.Model -eq "HDR-CX160")
            {
                $targetFileName = "HDR-CX160_" + $photo.GetFileName()
            }
            elseif($photo.Model -eq "iPod touch")
            {
                $targetFileName = $targetFileName.Replace("image_", "")
                $targetFileName = $targetFileName.Replace("image", "")
                $targetFileName = "iPod" + $targetFileName;
            }
            elseif($photo.Model -eq "GT-I9300")
            {
                $targetFileName = "GT-I3900_" + $photo.GetFileName()
            }
            elseif($photo.Model -eq "XT907")
            {
                $targetFileName = "XT907_" + $photo.GetFileName()
            }
            elseif($photo.Model -eq "GT-I8190N")
            {
                $targetFileName = "GT-I8190N_" + $photo.GetFileName()
            }
            elseif($photo.Model -eq "SM-G935F")
            {
                    $targetFileName = "SM-G935F_" + $photo.GetFileName()
            }
            elseif($photo.Model -eq "GT-I9500")
            {
                $targetFileName = "GT-I9500_" + $photo.GetFileName()
            }
        }
    }
    return $targetFileName;
}

function GetFileNameWithCameraTag(
    [Parameter(
        ValueFromPipeline=$true
        )][Photolibrary.Photo]$photo,
        [IO.FileInfo]$file)
{
    if($photo -eq $null) {
        LoadPhotoLibraryAssembly

        $photo = new-object photolibrary.photo($file.fullname)
    }

    $findValues = "IMG_","_MG","DSC","image_","image"

    $replaceLookup =
         @{
            "NIKON D70" = "NikonD70_";
            "Canon EOS 30D" = "EOS30D_";
            "Canon EOS 20D" = "EOS20D_";
            "Canon EOS 70D" = "EOS70D_";
            "Canon EOS 5D Mark IV" = "EOS5DMarkIV_";
            "BlackBerry 9650" = "BB9650_";
            "Canon IXY DIGITAL 800 IS" = "800IS_";
            "SQ908 MEGA-Cam" = "SQ908_";
            "Canon PowerShot SD3500 IS" = "SD3500_";
            "Canon PowerShot SD780 IS" = "SD780_";
            "Canon PowerShot SD1200 IS" = "SD1200_";
            "COOLPIX S4100" = "NikonS4100_"
            "Canon PowerShot ELPH 100 HS" = "Elph100HS_";
            "Canon EOS REBEL T4i" = "EOST4i_";
            "Canon PowerShot A2400 IS" = "A2400_";
            "Canon PowerShot G12" = "PS-G12_";
            "NIKON D3300"="NIKOND3300_";
            "T-Mobile G2" = "G2_";
            "iPod touch" = "iPod"
    }

    $prefixLookup = @{
        "NIKON D60" = "NIKOND60_";
    }
    "iPhone","RHOD500","HDR-CX160","GT-I9300","XT907","GT-I8190N","SM-G935F","GT-I9500" |
        %{ $prefixLookup.Add($_, "$($_)_") }

    $suffixLookup = @{
        "iPhone" = "iOS"
    }

    [string]$targetFileName = $null
    if(!($replaceLookup.ContainsKey($photo.Model))) {
        throw "Model '$($photo.Model)' is not recognized."
    }
    $replacement = $replaceLookup[$photo.Model]
    Write-Debug "`$replacement = $replacement"
    $prefix = $prefixLookup[$photo.Model]
    Write-Debug "`$prefix = $prefix"
    $suffixFindValue = $suffixLookup[$photo.Model]
    Write-Debug "`$suffixFindValue = $suffixFindValue"

    if($replacement) {
        [string] $targetFileName=$photo.GetFileName();
        $findValues | %{
                $targetFileName = $targetFileName.Replace($_, $replacement)
        }
    }
    elseif($prefix) {  # Currently: replaceLookup & suffixLookup are unique.
        $targetFileName = $prefix + $photo.GetFileName()
    }

    # We suffix search in addition to the above.
    if($suffixFindValue) {
        $targetFileName = $targetFileName.Replace(
            $suffixFindValue, "")
    }

    # TODO: Delete this function if the replace
    #       proves accruate.
    $legacyTargetName = Script:Get-LegacyTargetName($photo)
    if($targetFileName -ne $LegacyTargetName) {
        throw "New functionality did not match old functionlity: $targetFileName <> $legacyTargetName"
    }

    if(!$targetFileName)
    {
        throw "The file prefix for '" + $photo.Model + "' is missing on photo '" + $photo.GetFileName() + "'."
        $targetFileName = "UNKNOWN" + $targetFileName
    }

    return $targetFileName;
}

if(!(Test-Path variable:DefaultPhotoDirectory)) {
    $DefaultPhotoDirectory=[environment]::GetFolderPath([environment+specialfolder]::MyPictures)
}


Function Copy-Photo {
[CmdletBinding(
    SupportsShouldProcess=$true #Tells the shell that your function supports both -confirm and -whatif.
    ,ConfirmImpact="Medium" #Causes Confirm prompt when $ConfirmPreference is "High"
)]
param(
        [string]$fromDirectory
        , <# [ValidateScript({$_ -notin "True","False" })] #> [string] $toRootDirectory=$DefaultPhotoDirectory
        # TODO: Check
        ,[Parameter(ValueFromPipeline=$true)][ValidateNotNull()][IO.FileInfo[]]$files=@(
            Get-ChildItem $fromDirectory -Recurse -Include *.JPG,*.MOV,*.JPEG,*.MTS,*.PDF,*.MP4,*.MP3,*.CR2 )
    )

    Get-ChildItem -Path $fromDirectory -Recurse -File |
        %{
            Move-Item (Join-Path $fromDirectory $_.Name) (Join-Path $fromDirectory (GetFileNameWithCameraTag $photo))
        }

}

Function Copy-Photo {
[CmdletBinding(
    SupportsShouldProcess=$true #Tells the shell that your function supports both -confirm and -whatif.
    ,ConfirmImpact="Medium" #Causes Confirm prompt when $ConfirmPreference is "High"
)]
param(
        [string]$fromDirectory
        , <# [ValidateScript({$_ -notin "True","False" })] #> [string] $toRootDirectory=$DefaultPhotoDirectory
        ,[bool] $move=$true
        # TODO: Check
        ,[Parameter(ValueFromPipeline=$true)][ValidateNotNull()][IO.FileInfo[]]$files=@(
            Get-ChildItem $fromDirectory -Recurse -Include *.JPG,*.MOV,*.JPEG,*.MTS,*.PDF,*.MP4,*.MP3,*.CR2 )
    )

BEGIN {
    [string]$targetFileName=$null;
    [string]$targetDirectoryName=$null;

    #TODO There must be a better way to bind parameters but I am not sure what it is.
    if($toRootDirectory -in "True","False") {
        #Handle when the second parameter is true or false (which was intended for the third parameter)
        $move = $toRootDirectory -eq "True"
        $toRootDirectory = "C:\Data\Photos\MarEli"
    }
}

PROCESS {
        Write-Progress -Id 42 -Activity "Copy-Photo";
        [int]$totalFileCount = $files.Count
        [int]$filesProcessedCount = 0
        foreach($file in $files) {
            if($file.Extension -in ".JPG",".JPEG")
	        {
                LoadPhotoLibraryAssembly

                [Photolibrary.Photo]$photo = new-object photolibrary.photo($file.fullname)

                $targetFileName=GetFileNameWithCameraTag $photo
                $targetDirectoryName= GetSubDirectoryWithDateTimePath -photo $photo
	        }
	        else
	        {
                $targetFileName= $file.Name
                $targetDirectoryName= GetSubDirectoryWithDateTimePath -File $file
	        }

            $targetDirectoryName = Join-Path $toRootDirectory $targetDirectoryName;

            $targetFullName = Join-Path $targetDirectoryName $targetFileName



	        if(!(test-path $targetDirectoryName) )
	        {
                #if ($pscmdlet.ShouldProcess($targetDirectoryName)) {
		            #echo "Create directory:" $targetDirectoryName
		            New-Item $targetDirectoryName -type directory
                #}
	        }


            if($move) {
                $copyCommand = "Move-Item"
                $Status = "Moving ";
            }
            else {
                $copyCommand = "Copy-Item"
                $Status = "Copying ";
            }

            if( (-not (Test-Path $targetFullName)) -or $PSCmdlet.ShouldContinue("Overwrite $targetFullName`?", "Confirm") ) {
                    Write-Progress -Id 42 -Activity "Copy-Photo" -Status "$Status $file to $targetFullName" -PercentComplete ($filesProcessedCount++/$totalFileCount)
                    #ToDo yes-to-all currently doesn't work.
                    &  $copyCommand $file.FullName $targetFullName -ErrorAction SilentlyContinue -ErrorVariable commandError -force:$true

                    if($commandError) {
                        Write-Error "$copyCommand $file.FullName $targetFullName`: $($commandError[0].Exception)";
                        $commandError = $null;
                    }
            }

        }
    }
}


function Write-PhotoInfo
{
	param ([IO.FileInfo] $photoFileInfo)

	$photo=new-object photolibrary.photo($photoFileInfo.FullName)

	Write-Host "`tAdd $numberOfHours hours to $photoFileInfo`: "
	Write-Host	"`t`t DateOriginal  :`t"	$photo.DateTimeOriginal -noNewLine
				Write-Host "`t`t" $photo.DateTimeOriginal.AddHours($numberOfHours) -foregroundcolor Green
	Write-Host	"`t`t PhotoDateTime :`t" 	$photo.DateTime -noNewLine
				Write-Host "`t`t" $photo.DateTimeOriginal.AddHours($numberOfHours) -foregroundcolor Green
	Write-Host	"`t`t DateDigitized :`t" 	$photo.DateTimeDigitized -noNewLine
				Write-Host "`t`t" $photo.DateTimeOriginal.AddHours($numberOfHours) -foregroundcolor Green
	Write-Host	"`t`t FileCreateTime:`t"	$photoFileInfo.CreationTime -noNewLine
		Write-Host "`t`t" $photo.DateTimeOriginal.AddHours($numberOfHours) -foregroundcolor Green

	## LastWriteTime is not set.
	Write-Host	"`t`t DateModified  :`t" 	$photoFileInfo.LastWriteTime -noNewLine
				Write-Host "`t`t" $photoFileInfo.LastWriteTime ## Unchanged -foregroundcolor Green
}


function Add-HourToPhoto {
    param(
        [string] $fromDirectory = $(throw "fromDirectory is required.")
        , [string] $filter="*.jpg", [int]$numberOfHours=0
        , [Switch]$verbose, [Switch]$confirm, [Switch]$whatif
    )

    $AllAnswer = $null
    $photoLibraryPath = (join-path(Split-Path -Path ($MyInvocation.MyCommand.Path)) "PhotoLibrary.dll")
    if(! (test-path $photoLibraryPath) )
    {
	    $photoLibraryPath="$utils\PhotoLibrary.dll"
    }
    [void] [Reflection.Assembly]::LoadFrom($photoLibraryPath)

    if($fromDirectory -eq $null)
    {
        Write-Error fromDirectory
    }
    if(! (test-path $fromDirectory) )
    {
	    #Write out an error about the directory
	    Get-ChildItem $fromDirectory
	    exit
    }

    $photoFileInfos = dir $fromDirectory $filter -recur

    foreach( $photoFileInfo in $photoFileInfos )
    {
	    $photo=new-object photolibrary.photo($photoFileInfo.FullName)

	    [string] $verboseMessage = "`nAdd $numberOfHours hours to $photoFileInfo`: " +
		    "`n`t FileCreateTime: " 	+ 	$photoFileInfo.CreationTime +
		    "`n`t PhotoDateTime: " 		+ 	$photo.DateTime +
		    "`n`t DateDigitized: " 		+ 	$photo.DateTimeDigitized +
		    "`n`t DateOriginal: "		+	$photo.DateTimeOriginal +
		    "`n`t DateModified: " 		+ 	$photoFileInfo.LastWriteTime

	    $shouldProcess = Should-Process AddHours-Photo $photoFileInfo ([REF]$AllAnswer) "" -Verbose:$Verbose -Confirm:$Confirm -Whatif:$Whatif

	    if($shouldProcess)
	    {
		    ##Write-Host "Working..." -foregroundcolor Magenta
		    $photo.DateTimeOriginal = $photo.DateTimeOriginal.AddHours($numberOfHours)
		    $photo.DateTime = $photo.DateTimeOriginal.AddHours($numberOfHours)
		    $photo.DateTimeDigitized = $photo.DateTimeOriginal.AddHours($numberOfHours)
		    $photoFileInfo.CreationTime = $photo.DateTimeOriginal.AddHours($numberOfHours)
		    $photo.Save()
		    ## No change
		    ##$photoFileInfo.LastWriteTime
	    }

	    if($verbose)
	    {
		    Write-PhotoInfo $photoFileInfo
	    }
    }
}





function Convert-KmlToTcx {
    param(
        [ValidateScript({Test-Path $_ -PathType Leaf})][Parameter(Mandatory)][string]$kmlFile
        , [string]$tcxFile=[IO.Path]::ChangeExtension($kmlFile, "tcx")
    )


    #gpsbabel -t -i kml -f C:/Data/Photos/MarEli/2015/04/history-04-09-2015.kml -o gtrnctr -F C:/Data/Photos/MarEli/2015/04/history-04-09-2015.tcx -o gpx -F C:/Users/Mark/AppData/Local/Temp/GPSBabel.d13316
    #gpsbabel -t -i kml -f C:/Data/Photos/MarEli/2015/04/history-04-12-2015.kml -o gtrnctr -F C:/Data/Photos/MarEli/2015/04/history-04-12-2015.tcx
    #gpsbael should be aliased to "C:\Program Files (x86)\GPSBabel\gpsbabel.exe".
    & gpsbabel -t -i kml -f "$kmlFile" -o gtrnctr -F "$tcxFile"
    if(Test-Path $tcxFile) {
        return $tcxFile
    }
    else {
        throw "gpsbabel call not working."
    }
}


# Check out https://developers.google.com/identity/protocols/OAuth2UserAgent for google oauth2 with Google

function Invoke-GoogleLocationHistoryRequest {
    $loginPage =(Invoke-WebRequest -Uri "https://accounts.google.com/ServiceLogin")

}


function Set-PhotoGeoTag {
    param(

    )



}


<#
if($PSBoundParameters.Count -ne 0) {
    Copy-Photo @PSBoundParameters
}
#>














# $items | %{$_.DateTimeOriginal}
# | %{ if(! test-path (.getdirectoryname() +
#\ + .datetimeoriginal.Month.tostring(00)))) { ni (.getdirectoryname() + \ + .datetimeoriginal.Month.tostring(00)) -type directory}}


#>$items = dir c:\photos\MarEli *.jpg -recur | %{new-object photolibrary.photo($_.fullname)}
#>$items | ?{$_.Model -eq "Canon IXY DIGITAL 800 IS"} | %{$_.Rename($_.GetFileName().Replace("IMG", "800IS"))}
#>$items | ?{$_.Model -eq "Canon EOS 20D"} | %{$_.Rename($_.GetFileName().Replace("IMG", "EOS20D"))}
#>$items | ?{$_.Model -eq "SQ908 MEGA-Cam"} | %{$_.Rename($_.GetFileName().Replace("IMG", "SQ908"))}

#  [void] [Reflection.Assembly]::LoadFrom("$env:utils\PhotoLibrary.dll")
#  $items = dir .\ *.jpg -recur | %{new-object photolibrary.photo($_.fullname)}
#  $items | %{ $_.DateTime = $_.DateTime.AddHours(2)   }
#  $items | %{ $_.DateTimeDigitized=$_.DateTimeDigitized.AddHours(2)   }
#  $items | %{ $_.DateTimeOriginal=$_.DateTimeOriginal.AddHours(2)   }
#  $items | %{ $_.LastWriteTime = $_.LastWriteTime.AddHours(2) }





##$photos = $files | %{new-object photolibrary.photo($_.fullname)}
#$months= $photos | %{$_.DateTimeOriginal.Month.ToString("00")} | sort -unique

#foreach($month in $months)
#{
#	$targetDirectory = join-path $toRootDirectory $month
#	if(!(test-path $targetDirectory) )
#	{
#		New-Item $targetDirectory -type directory
#	}
#}


## Used to set dates
##$photos | sort DateTimeOriginal -desc | ?{ ($_.Model -eq "Canon EOS 20D") -or ($_.Model -eq "Canon IXY DIGITAL 800 IS")} |  ft -property DateTimeOriginal,  DateTimeDigitized, DateTime
##$photos | sort DateTimeOriginal -desc | ?{ ($_.Model -eq "Canon EOS 20D") -or ($_.Model -eq "Canon IXY DIGITAL 800 IS")} |  %{ $_.DateTimeOriginal=$_.DateTimeOriginal.AddHours(2);  $_.DateTimeDigitized=$_.DateTimeDigitized.AddHours(2); $_DateTime=$_.DateTime.AddHours(2)}
##$photos | sort DateTimeOriginal -desc | ?{ ($_.Model -eq "Canon EOS 20D") -or ($_.Model -eq "Canon IXY DIGITAL 800 IS")} |  %{new-object IO.FileInfo($_.getfullpath()) } | %{$_.LastWriteTime=$_.LastWriteTime.AddHours(2)}
