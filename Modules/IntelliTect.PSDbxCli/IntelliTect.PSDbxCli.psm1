

class DbxItem {
    [ValidateNotNullOrEmpty()][string]$Path
}
class DbxDirectory : DbxItem {
    [DbxItem[]]GetChildItems() {
        return Get-DbxItem -Path $this.Path
    }
}
class DbxFile : DbxItem {
    [ValidateNotNullOrEmpty()][string]$Revision;
    [ValidateNotNullOrEmpty()][int]$Size;
    [ValidateNotNullOrEmpty()]hidden[string]$DisplaySize
    [ValidateNotNullOrEmpty()][string]$Age

    [DbxItem[]]GetRevisions() {
        return Get-DbxRevision -Path $this.Path
    }
}
$dbxFileTypeData = @{
    TypeName = 'DbxFile'
    DefaultDisplayPropertySet = 'Path','DisplaySize','Age'
}
Update-TypeData @dbxFileTypeData -Force

Function Script:Invoke-DbxCli {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
    param (
        [Parameter(Mandatory)]
        [string]
        $Command
    )

    Invoke-Expression $command
}


Function Get-DbxItem {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Path,
        [Parameter()]
        [switch]
        $File,
        [Parameter()]
        [switch]
        $Directory,
        [Parameter()]
        [switch]
        $Recursive
    )
    $Header=$null
    $regexLine=$null
    $command = "dbxcli ls -l '$Path' $(if($Recursive){'-R'})"

    if(!$Directory -and !$File) {
        $Directory = [switch]$true
        $File = [switch]$true
    }

    if($Path) {
        $Path=$Path.Replace('\','/')
        if($Path[0] -ne '/') {
            $Path="/$Path"
        }
    }

    Invoke-DbxCli $command | ForEach-Object{
        if(-not $Header) {
            if($_ -match '(?<Revision>Revision\s*)(?<Size>Size\s*)(?<Age>Last Modified\s*)(?<Path>Path)') {
                $Header = [PSCustomObject]($Matches | Select-Object -ExcludeProperty 0)
            }
            else {
                throw "Unable to parse header ('$_')"
            }
            $regexLine="(?<Revision>.{$($Header.Revision.Length)})"+
                "(?<DisplaySize>.{$($Header.Size.Length)})"+
                "(?<Age>.{$($Header.Age.Length)})"+
                "(?<Path>.+?)\s*$"
        }
        else {
            if($_ -match $regexLine) {
                if( $Matches.Revision.Trim() -eq '-') {
                    if($Directory) {
                        # Revision, Age, and Size are not returned for a directory.
                        $item = ([PSCustomObject]($Matches | Select-Object -Property Path))
                        $item.Path = $item.Path+'/'
                        $item.PSObject.TypeNames.Insert(0,"Dbx.Directory")
                        Write-Output ([DbxDirectory]$item)
                    }
                    #else ignore
                }
                else {
                    if($File) {
                        $item = $Matches

                        $item['Size'] = ConvertFrom-DisplaySize $Matches.DisplaySize

                        $item.PSObject.TypeNames.Insert(0,"Dbx.File")
                        # We ignore the '0' property
                        Write-Output ([DbxFile]($item | Select-Object -ExcludeProperty '0'))
                    }
                }
            }
        }
    }
}
Function Script:ConvertFrom-DisplaySize {
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory)][string]$DisplaySize)
    $converter=@{
        B=1;
        KiB=1000;
        MiB=1000000;
        GiB=1000000000;
    }
    if($DisplaySize -match '(?<Amount>\d*?\.?\d*?) (?<Unit>GiB|KiB|MiB|B)') {
        return ([int]$Matches.Amount)*$converter.($Matches.Unit)
    }
    else { throw "Unable to parse size '$($Matches.DisplaySize)'"}
}

Function Save-DbxFile {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The Dropbox path to the file to download
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)][Alias('Path')][string]$DroboxPath,
        # The target path to download the file to.  The default
        # is the current directory with the same file name
        [Parameter()][string]$TargetPath,
        # Force the file to download even if it already exists.
        [Parameter()][switch]$Force
    )
    BEGIN {
        if(@($DroboxPath).Count -gt 1) {
            # The $TargetPath should be a directory
            if(!(Test-Path $TargetPath -PathType Container)) {
                Write-Warning "'$TargetPath is not a container causing multiple files to overwrite each other."
            }
        }
        $TargetPath = $TargetPath
        $Force = $Force
    }

    PROCESS {
        $DroboxPath | ForEach-Object {
            $item = $_
            if(!$TargetPath) {
                $itemTargetPath = Join-Path (Get-Location) (Split-Path $item -Leaf)
            }
            elseif(Test-Path $TargetPath -PathType Container) {
                $itemTargetPath = Join-Path ($TargetPath) (Split-Path $item -Leaf)
            }

            if((Test-Path $itemTargetPath) -and !$Force) {
                throw "Cannot download file when that file ('$itemTargetPath') already exists. Use -Force to override."
            }

            if($PSCmdlet.ShouldProcess("$item", "Save-DbxFile '$item' to '$itemTargetPath'")) {
                Invoke-DbxCli "dbxcli get '$item' '$itemTargetPath'"
                Write-Output (Get-Item $itemTargetPath)
            }
        }
    }
}

Function Get-DbxRevision {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [string]
        $Path
    )
    BEGIN {
        $regexLine="(?<Revision>.[0-9a-f]+?)\t"+
        "(?<Size>.+?)\t"+
        "(?<Age>.+?)\t"+
        "(?<Path>.+?)\t"
    }
    PROCESS {
        $Path | ForEach-Object {
            $command = "dbxcli revs -l '$Path'"
            Invoke-DbxCli $command | Select-Object -Skip 1 | ForEach-Object {
                [string]$line=$_
                [Regex]::Matches($line, $regexLine) | ForEach-Object {
                    [DbxFile]@{
                        'Revision'=$_.Groups['Revision'].Value;
                        'Size'=$_.Groups['Size'].Value;
                        'Age'=$_.Groups['Age'].Value;
                        'Path'=$_.Groups['Path'].Value;
                    }
                }
            }
        }
    }
}