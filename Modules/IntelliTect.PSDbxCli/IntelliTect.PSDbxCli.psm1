
class DbxItem {
    [string]$Path
}
class DbxDirectory : DbxItem {
    [DbxItem[]]GetChildItems() {
        return Get-DbxItem -Path $this.Path
    }
}
class DbxFile : DbxItem {
    [string]$Revision;
    [string]$Size;
    [string]$LastModified

    [DbxItem[]]GetRevisions() {
        return Get-DbxItem -Path $this.Path
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

    script:Invoke-DbxCli $command | ForEach-Object{
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
                        $item.PSObject.TypeNames.Insert(0,"Dbx.Directory")
                        Write-Output ([DbxDirectory]$item)
                    }
                    #else ignore
                }
                else {
                    if($File) {
                        # We ignore the '0' property
                        $item = ([PSCustomObject]($Matches | Select-Object -ExcludeProperty '0'))
                        $item.PSObject.TypeNames.Insert(0,"Dbx.File")
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
        [Parameter()]
        [string]
        $Path
    )

    $command = "dbxcli revs '$Path'"

    Write-Output (Invoke-DbxCli $command)
}