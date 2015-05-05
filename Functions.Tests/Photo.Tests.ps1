$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
#dir "$ChocolateyInstall\lib\Pester*" Pester.psm1 -Recurse | Select-Object -Last 1 | Import-Module  
. "$here\$sut"

#TODO:
# Move the sample files into a zip file so there aren't so many files.
#Fix Pester Import-Module line above


function DebugBreak{}
function Debug{
    Set-PSBreakpoint -command DebugBreak
    DebugBreak
}

Describe "GetSubDirectoryWithDateTimePath" {

    It "Verify the correct path, given the DateTimeOriginal, is calculated" {
        [IO.FileInfo]$sampleFile = (dir "$here\PhotoLibrary.dll")[0]
        $result = GetSubDirectoryWithDateTimePath -file $sampleFile
        $result | should be "2012\05";
    }

    It "Verify the correct path, given the DateTimeOriginal of a photo - passed as a file, is calculated" {
        [IO.FileInfo]$sampleFile = (dir "$here\copy-photo.NikonD70.IMG_SamplePhoto1.jpg")[0]
        $result = GetSubDirectoryWithDateTimePath -file $sampleFile
        $result | should be "2013\08";
    }
    It "Verify the correct path, given the DateTimeOriginal of a photo, is calculated" {
        [Photolibrary.Photo]$photo = new-object photolibrary.photo("$here\copy-photo.NikonD70.IMG_SamplePhoto1.jpg")
        $result = GetSubDirectoryWithDateTimePath -photo $photo
        $result | should be "2005\11";
    }
}

Describe "GetFileNameWithCameraTag" {
    It "Verify the correct path, given the DateTimeOriginal of a photo, is calculated" {
        [Photolibrary.Photo]$photo = new-object photolibrary.photo("$here\copy-photo.NikonD70.IMG_SamplePhoto1.jpg")
        $result = GetFileNameWithCameraTag $photo
        $result | Should Be "copy-photo.NikonD70.NikonD70_SamplePhoto1.jpg";
    }
    It "Verify the correct path, given the DateTimeOriginal of a photo, is calculated using file" {
        [IO.FileInfo]$file = new-object IO.FileInfo("$here\copy-photo.NikonD70.IMG_SamplePhoto1.jpg")
        $result = GetFileNameWithCameraTag -file $file
        $result | Should Be "copy-photo.NikonD70.NikonD70_SamplePhoto1.jpg";
    }
}

function SetupMultipleSamplePhotos([string][string]$photoSource, [int] $sampleFileCount) {
        [void] (mkdir $photoSource);
        for ($i = 1; $i -ile $sampleFileCount; $i++) {
            copy "$here\copy-photo.NikonD70.IMG_SamplePhoto1.jpg" (Join-Path "$photoSource" "copy-photo.NikonD70.IMG_SamplePhoto$i.jpg");
        }
        @(dir $photoSource).Length | should be $sampleFileCount
}

Describe "CopyPhoto" {
    [string]$photoSource = "TestDrive:\PhotoSource\"
    [string]$photoTarget = "TestDrive:\PhotoTarget\"

    Context "When there is only one photo" {
        SetupMultipleSamplePhotos $photoSource 1

        It "Copy the photo to a subdirectory with the name prefix based on the camera model w/-WhatIf" {
            CopyPhoto $photoSource $photoTarget -whatif
            Join-Path "$photoTarget\2005\11" "copy-photo.NikonD70.NikonD70_SamplePhoto1.jpg" | Should Not Exist
        }
        It "Copy the photo to a subdirectory with the name prefix based on the camera model" {
            CopyPhoto $photoSource $photoTarget 
            Join-Path "$photoTarget\2005\11" "copy-photo.NikonD70.NikonD70_SamplePhoto1.jpg" | Should Exist
        }
    }

    Context "When there are multiple photos via pipeline" {
        SetupMultipleSamplePhotos $photoSource 2

        It "Copy one photo to a subdirectory with the name prefix based on the camera model w\-WhatIf" {
            dir "$photoSource" | CopyPhoto -toRootDirectory $photoTarget -whatif;
            Join-Path "$photoTarget" "2005\11\copy-photo.NikonD70.NikonD70_SamplePhoto1.jpg" | Should Not Exist
            Join-Path "$photoTarget" "2005\11\copy-photo.NikonD70.NikonD70_SamplePhoto2.jpg" | Should Not Exist
        }
        It "Copy one photo to a subdirectory with the name prefix based on the camera model" {
            dir "$photoSource" | CopyPhoto -toRootDirectory $photoTarget;
            Join-Path "$photoTarget" "2005\11\copy-photo.NikonD70.NikonD70_SamplePhoto1.jpg" | Should Exist
            Join-Path "$photoTarget" "2005\11\copy-photo.NikonD70.NikonD70_SamplePhoto2.jpg" | Should Exist
        }
    }

    Context "Using fromDirectory parameter with multiple photos" {
        SetupMultipleSamplePhotos $photoSource 2

        It "Copy one photo to a subdirectory with the name prefix based on the camera model" {
            (dir $photoSource).Length | should be 2
            CopyPhoto -fromDirectory $photoSource -toRootDirectory $photoTarget;
            Join-Path "$photoTarget" "2005\11\copy-photo.NikonD70.NikonD70_SamplePhoto1.jpg" | Should Exist
            Join-Path "$photoTarget" "2005\11\copy-photo.NikonD70.NikonD70_SamplePhoto2.jpg" | Should Exist
        }
    }

    Context "Using fromDirectory parameter with multiple photos and -whatif" {
        SetupMultipleSamplePhotos $photoSource 2

        It "Copy one photo to a subdirectory with the name prefix based on the camera model" {
            (dir $photoSource).Length | should be 2
            CopyPhoto -fromDirectory $photoSource -toRootDirectory $photoTarget -whatif;
            Join-Path "$photoTarget" "2005\11\copy-photo.NikonD70.NikonD70_SamplePhoto1.jpg" | Should Not Exist 
            Join-Path "$photoTarget" "2005\11\copy-photo.NikonD70.NikonD70_SamplePhoto2.jpg" | Should Not Exist
        }
    }
}

Describe "copy-photos.ps1" {
    [string]$photoSource = "TestDrive:\PhotoSource\";
    [string]$photoTarget = "TestDrive:\PhotoTarget\";

    Context "Using fromDirectory parameter with multiple photos" {
        SetupMultipleSamplePhotos $photoSource 2

        It "Copy one photo to a subdirectory with the name prefix based on the camera model" {
            & "$here\copy-photo.ps1" $photoSource $photoTarget -whatif
            Join-Path "$photoTarget" "2005\11\copy-photo.NikonD70.NikonD70_SamplePhoto1.jpg" | Should Not Exist
            Join-Path "$photoTarget" "2005\11\copy-photo.NikonD70.NikonD70_SamplePhoto2.jpg" | Should Not Exist
        }
        It "Copy one photo to a subdirectory with the name prefix based on the camera model" {
            & "$here\copy-photo.ps1" $photoSource $photoTarget
            Join-Path "$photoTarget" "2005\11\copy-photo.NikonD70.NikonD70_SamplePhoto1.jpg" | Should Exist
            Join-Path "$photoTarget" "2005\11\copy-photo.NikonD70.NikonD70_SamplePhoto2.jpg" | Should Exist
        }
    }
    
}