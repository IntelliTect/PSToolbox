

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

    $Command += ' 2>&1'

    $result = Invoke-Expression $command -ErrorAction SilentlyContinue -ErrorVariable InvokeExpressionError
    if($LASTEXITCODE -ne 0) {
        Write-Error $InvokeExpressionError.ToString()
    }
    else {
        @($result) | Foreach-Object {
            if( $_ -like "Error: *" ) {
                Write-Error $_
            }
            else {
                Write-Output $_
            }
        }
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
        [Parameter(Mandatory)][string[]]$Path,
        # Parameter help description
        [Microsoft.PowerShell.Commands.TestPathType]$PathType = [Microsoft.PowerShell.Commands.TestPathType]::Any
    )
    BEGIN {
        $PathType = $PathType
    }
    PROCESS {
        @($Path) | ForEach-Object {
            [string]$item = Format-DbxPath $_

            if(($item[-1] -eq '/') -and ($PathType -eq 'Leaf')) {
                throw 'Seaching for file but folder provided (remove trailing slash)'
            }

            if(-not ($item -match '(?<DirectoryPath>/.*?)(?<FileName>.+?)/?$')) {
                throw "The path ('$item') is invalid."
            }

            # Handle root paths separately because you can't use a plain '/' for the "path-scope" (directory path) with dbxcli search
            if($Matches.DirectoryPath -eq '/') {
                # search for '*' in the $Path directory.  If no error, the folder exists.
                # (Using dbxcli ls for a folder returns all the items in the folder which seems suboptimal for large folders.)
                Invoke-DbxCli "dbxcli search * '$($item.TrimEnd('/'))'" `
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
                    return ([bool](Get-DbxItem -File $item))
                }
            }
            $result = Invoke-DbxCli "dbxcli search '$($Matches.FileName)' '$($Matches.DirectoryPath)'" `
                -ErrorAction SilentlyContinue -ErrorVariable InvokeDbxCliError
            if($InvokeDbxCliError) {
                Write-Output $false
            }
            else {
                Write-Output ($result -eq $item)
            }
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
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName = 'Path')]
    param (
        # The Dropbox path to the file to download
        [ValidateNotNullOrEmpty()][Parameter(ParameterSetName='Path',Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)][Alias('Path')][string[]]$DroboxPath,
        # The Revision ID for the file to be downloaded.
        # (If not the most recent version of the file, a copy will be temporarily be placed in
        # Dropbox while downloading.)
        [ValidateNotNullOrEmpty()][Parameter(ParameterSetName='Revision',Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)][string[]]$Revision,
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
        #Get-DbxItem 'Apps'
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
        "(?<DisplaySize>.+?)\t"+
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
                        'DisplaySize'=$_.Groups['DisplaySize'].Value;
                        'Size'=ConvertFrom-DisplaySize $_.Groups['DisplaySize'].Value
                        'Age'=$_.Groups['Age'].Value;
                        'Path'=$_.Groups['Path'].Value;
                    }
                }
            }
        }
    }
}