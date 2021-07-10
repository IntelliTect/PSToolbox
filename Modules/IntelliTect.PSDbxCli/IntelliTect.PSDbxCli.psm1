

class DbxItem {
    [ValidateNotNullOrEmpty()][string]$Path
}
class DbxDirectory : DbxItem {
    [DbxItem[]]GetChildItems() {
        return Get-DbxItem -Path $this.Path
    }
}
class DbxFile : DbxItem {
    [string]$Revision;
    [ValidateNotNullOrEmpty()][int]$Size;
    [ValidateNotNullOrEmpty()]hidden[string]$DisplaySize;
    [ValidateNotNullOrEmpty()][string]$Age;
    [DbxItem[]]hidden $Revisions;

    [string]ToString() {
        return $this.Path
    }
    [DbxItem[]]GetRevisions() {
        if(-not $this.Revisions) {
            $this.Revisions = Get-DbxRevision -Path $this.Path
        }
        return $this.Revisions
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

    $Command += ' 2>&1'

    Invoke-Expression $command -ErrorAction SilentlyContinue `
            -ErrorVariable InvokeExpressionError | Where-Object {
        Write-Output ($_ -and (![string]::IsNullOrWhiteSpace($_)))
    } | ForEach-Object {
        if( $_ -like "Error: *" ) {
            throw $_
        }
        else {
            Write-Output $_
        }
    }
    if($LASTEXITCODE -ne 0) {
        $InvokeExpressionError = $InvokeExpressionError | Where-Object{ -not [string]::IsNullOrWhiteSpace($_) }
        # TODO: Consider throwing an error instead so that execution stops when it unexpectedly errors.
        Write-Error $InvokeExpressionError.ToString()
    }
}
Function Script:Format-DbxPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The path to format
        [Parameter(Mandatory,ValueFromPipeline)][string[]]$Path
    )
    BEGIN {
        $Path = $Path
    }
    PROCESS {
        @($Path) | ForEach-Object {
            $item = $_
            $item=$item.Replace('\','/')
            if($item[0] -ne '/') {
                $item="/$item"
            }
            Write-Output $item
        }
    }

}

Function Test-DbxPath {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)][string]$Path,
        # Parameter help description
        [Microsoft.PowerShell.Commands.TestPathType]$PathType = [Microsoft.PowerShell.Commands.TestPathType]::Any
    )
    PROCESS {
        $Path = Format-DbxPath $Path

        if(($Path[-1] -eq '/') -and ($PathType -eq 'Leaf')) {
            throw 'Seaching for file but folder provided (remove trailing slash)'
        }

        if(-not ($Path -match '(?<DirectoryPath>/.*?)(?<FileName>.+?)/?$')) {
            throw "The path ('$Path') is invalid."
        }

        # Handle root paths separately because you can't use a plain '/' for the "path-scope" (directory path) with dbxcli search
        if($Matches.DirectoryPath -eq '/') {
            # search for '*' in the $Path directory.  If no error, the folder exists.
            # (Using dbxcli ls for a folder returns all the items in the folder which seems suboptimal for large folders.)
            Invoke-DbxCli "dbxcli search * '$($Path.TrimEnd('/'))'" `
                -ErrorAction SilentlyContinue -ErrorVariable InvokeDbxCliError > $null
            [bool]$directoryExists = (-not [bool]$InvokeDbxCliError)
            if( $directoryExists -and ($PathType -in 'Container','Any') ) {
                # We checked for the directory but it didn't exist
                return $true
            }
            elseif ( (-not $directoryExists) -and ($PathType -in 'Container') ) {
                # The item exists but it is a directory and we are looking for a leaf.
                return $false
            }
            else {
                # Check whether the file exists.
                return ([bool](Get-DbxItem -File $Path))
            }
        }
        $result = Invoke-DbxCli "dbxcli search '$($Matches.FileName)' '$($Matches.DirectoryPath)'" `
            -ErrorAction SilentlyContinue -ErrorVariable InvokeDbxCliError
        if($InvokeDbxCliError) {
            Write-Output $false
        }
        else {
            Write-Output ($result -eq $Path)
        }
    }
}

Function Get-DbxItem {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()][Parameter()][string]$Path = '/',
        [Parameter()][switch]$File,
        [Parameter()][switch]$Directory,
        [Parameter()][switch]$Recursive
    )
    $Header=$null
    $regexLine=$null
    $command = "dbxcli ls -l '$Path' $(if($Recursive){'-R'})"

    if(!$Directory -and !$File) {
        $Directory = [switch]$true
        $File = [switch]$true
    }

    $Path = Format-DbxPath $Path

    Invoke-DbxCli $command | ForEach-Object{
        if(-not $Header) {
            if($_ -match '(?<Revision>Revision\s*?) (?<Size>Size\s*?) (?<Age>Last Modified\s*?) (?<Path>Path)\s*') {
                $Header = [PSCustomObject]($Matches | Select-Object -ExcludeProperty 0)
            }
            else {
                throw "Unable to parse header ('$_')"
            }
            $regexLine="(?<Revision>.{$($Header.Revision.Length)}) "+
                "(?<DisplaySize>.{$($Header.Size.Length)}) "+
                "(?<Age>.{$($Header.Age.Length)}) "+
                "(?<Path>.+?)\s*$"
        }
        else {
            if($_ -match $regexLine) {
                if( $Matches.Revision.Trim() -eq '-') {
                    if($Directory) {
                        # Revision, Age, and Size are not returned for a directory.
                        $item = ([PSCustomObject]($Matches | Select-Object -Property Path))
                        $item.Path = $item.Path+'/'
                        $item.PSObject.TypeNames.Insert(0,"DbxDirectory")
                        Write-Output ([DbxDirectory]$item)
                    }
                    #else ignore
                }
                else {
                    if($File) {
                        $item = $Matches

                        $item['Size'] = ConvertFrom-DisplaySize $Matches.DisplaySize
                        $item.Revision = '' # The Revision is blanked out for the most recent verstion
                                               # so that when calling Save-File the revision is not used.
                                               # i.e Get-DbxItem -File | Save-DbxFile
                        $item.PSObject.TypeNames.Insert(0,"DbxFile")
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

Function Restore-DbxFile {
    [CmdletBinding()]
    param (
        # The revision ID of the file to be restored.
        [Parameter(Mandatory)][string]$Revision,
        # The target location to restore the file in Dropbox
        [Parameter(Mandatory)][string]$DbxTargetLocation,
        [switch]$PassThru
    )

    Invoke-DbxCli "dbxcli restore '$DbxTargetLocation' '$Revision'"
    if($PassThru) {
        Write-Output (Get-DbxItem -Path $DbxTargetLocation)
    }
}

Function Save-DbxFile {
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName = 'Path')]
    param (
        # The Dropbox path to the file to download
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][Alias('Path')][string]$DropboxPath,
        # The Revision ID for the file to be downloaded.
        # If not the most recent version of the file (the Revision property is set), a copy 
        # will be temporarily be placed in Dropbox while downloading.)
        [Parameter(ValueFromPipelineByPropertyName)][string]$Revision,
        # The target path to download the file to.  The default
        # is the current directory with the same file name
        [Parameter()][string]$TargetPath,
        # Force the file to download even if it already exists.
        [Parameter()][switch]$Force
    )
    BEGIN {
        if(@($DropboxPath).Count -gt 1) {
            # The $TargetPath should be a directory
            if(!(Test-Path $TargetPath -PathType Container)) {
                Write-Warning "'$TargetPath is not a container causing multiple files to overwrite each other."
            }
        }
    }

    PROCESS {
        try {
            if($Revision) {
                [string]$dbxAppDirectory = '/Apps/IntelliTect.PSDbxCli'
                if(-not (Test-DbxPath -Path $dbxAppDirectory -PathType Container)) {
                    Invoke-DbxCli "dbxcli mkdir $dbxAppDirectory"
                }
                $DropboxPath = "$dbxAppDirectory/$(Split-Path $DropboxPath -Leaf)"
                Write-Progress -Activity "Save-File '$DropboxPath' ($Revision)" -Status "Restoring..."
                Restore-DbxFile -Revision $Revision -DbxTargetLocation $DropboxPath
            }

            if(!$TargetPath) {
                $TargetPath = Join-Path (Get-Location) (Split-Path $DropboxPath -Leaf)
            }
            elseif(Test-Path $TargetPath -PathType Container) {
                $TargetPath = Join-Path ($TargetPath) (Split-Path $DropboxPath -Leaf)
            }

            if((Test-Path $TargetPath) -and !$Force) {
                throw "Cannot download file when that file ('$TargetPath') already exists. Use -Force to override."
            }

            if($PSCmdlet.ShouldProcess("$DropboxPath", "Save-DbxFile '$DropboxPath' to '$TargetPath'")) {
                Invoke-DbxCli "dbxcli get '$DropboxPath' '$TargetPath'" | ForEach-Object {
                    if($_ -match 'Downloading (?<SizeDownloaded>.+?)/(?<SizeTotal>.+?)$') {
                        $sizeDownloaded,$sizeTotal=(ConvertFrom-DisplaySize $Matches.SizeDownloaded),(ConvertFrom-DisplaySize $Matches.SizeTotal)
                        Write-Progress -Activity "Save-File '$DropboxPath' ($Revision)" -Status $_ -PercentComplete (($sizeDownloaded*100)/$sizeTotal)
                    }
                    else {
                        Write-Progress -Activity "Save-File '$DropboxPath' ($Revision)" -Status $_
                    }
                }
                Write-Output (Get-Item $TargetPath)
            }
        }
        finally {
            if($Revision) {
                Invoke-DbxCli "dbxcli rm $DropboxPath --force"
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
        "(?<DisplaySize>.+?)\t"+
        "(?<Age>.+?)\t"+
        "(?<Path>.+?)\t"
    }
    PROCESS {
        $command = "dbxcli revs -l '$Path'"
        Invoke-DbxCli $command | Select-Object -Skip 1 | ForEach-Object {
            [string]$line=$_
            [Regex]::Matches($line, $regexLine) | ForEach-Object {
                [DbxFile]@{
                    'Revision'=$_.Groups['Revision'].Value;
                    'DisplaySize'=$_.Groups['DisplaySize'].Value;
                    'Size'=ConvertFrom-DisplaySize $_.Groups['DisplaySize'].Value
                    'Age'=$_.Groups['Age'].Value;
                    'Path'=$_.Groups['Path'].Value;
                }
            }
        }
    }
}