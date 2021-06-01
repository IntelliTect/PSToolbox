

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
    [ValidateNotNullOrEmpty()][string]$Size;
    [ValidateNotNullOrEmpty()][string]$LastModified

    [DbxItem[]]GetRevisions() {
        return Get-DbxRevision -Path $this.Path
    }
}

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
            if($_ -match '(?<Revision>Revision\s*)(?<Size>Size\s*)(?<LastModified>Last Modified\s*)(?<Path>Path)') {
                $Header = [PSCustomObject]($Matches | Select-Object -ExcludeProperty 0)
            }
            else {
                throw "Unable to parse header ('$_')"
            }
            $regexLine="(?<Revision>.{$($Header.Revision.Length)})"+
                "(?<Size>.{$($Header.Size.Length)})"+
                "(?<LastModified>.{$($Header.LastModified.Length)})"+
                "(?<Path>.+?)\s*$"
        }
        else {
            if($_ -match $regexLine) {
                if( $Matches.Revision.Trim() -eq '-') {
                    if($Directory) {
                        # Revision, LastModified, and Size are not returned for a directory.
                        $item = ([PSCustomObject]($Matches | Select-Object -Property Path))
                        $item.Path = $item.Path+'/'
                        $item.PSObject.TypeNames.Insert(0,"Dbx.Directory")
                        Write-Output ([DbxDirectory]$item)
                    }
                    #else ignore
                }
                else {
                    if($File) {
                        $item = ([PSCustomObject]($Matches | Select-Object -ExcludeProperty '0'))
                        $item.PSObject.TypeNames.Insert(0,"Dbx.File")
                        # We ignore the '0' property
                        Write-Output ([DbxFile]$item)
                    }
                }
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
        "(?<LastModified>.+?)\t"+
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
                        'LastModified'=$_.Groups['LastModified'].Value;
                        'Path'=$_.Groups['Path'].Value;
                    }
                }
            }
        }
    }
}