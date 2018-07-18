
$here = $PSScriptRoot


# Sort by the date on the object that is the newest.
#get-childitem -directory | %{ ($_.LastAccessTime.ToUniversalTime(),$_.lastwritetime.ToUniversalTime(),$_.CreationTimeUtc | sort-object )[0] } | sort -Descending
$TimeProperties = Get-ChildItem | Get-Member | ?{ ($_.Name -match ".*Time(?!Utc).*") -and ($_.MemberType -eq "Property")  } | Select-Object -ExpandProperty Name -Unique


Function Script:Get-LastUsefulDateDebugMessage {
    [CmdletBinding()]
    param($item, $result)
    $item = $_
    $message = "{0,-30}" -f "$($_.Name):"
    $TimeProperties | %{
        if($item."$_" -eq $result) { $message += "{0,25}" -f ("$($item."$_")*") }
        else {$message += "{0,25}" -f ("$($item."$_")") }
    }
    return $message
}


Function Get-ItemLastUsefulDate {
    [CmdletBinding(DefaultParameterSetName='Items')]
    param (
        [ValidateScript({ Test-Path $_ })]
        [Parameter(ParameterSetName='Items', Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('FullName')]
        [string[]]
        ${Path},

        [Parameter(ParameterSetName='LiteralItems', Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('PSPath')]
        [string[]]
        $LiteralPath

#        ,[ValidateScript({ Test-Path $_.FullName })]
#        [Parameter(ParameterSetName='FileSystemInfo', Mandatory=$true, Position, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
#        [System.IO.FileInfo[]]
#        $FileInfo
    )
    BEGIN {
    }
    PROCESS {
            $items = Get-Item @PSBoundParameters
            $items | %{
            $item = $_
            if(Test-Path -LiteralPath $item -PathType Container) {
                $childrenLastUsefulDate = Get-ChildItem -LiteralPath $item | %{
                    #TODO: How do you get Get-ItemLastUsefulDate to take $_ rather than $_.FullName?
                    Get-ItemLastUsefulDate -LiteralPath $_.FullName } | Sort-Object -Descending | select-object -first 1
                $result = $childrenLastUsefulDate,$item.LastAccessTime,$item.LastWriteTime,$item.CreationTime | sort-object -Descending | Select-Object -first 1
                $item | %{
                    Write-Debug (Get-LastUsefulDateDebugMessage $_ $result)
                }

                return $result
            }
            else {
                $result = $item.LastAccessTime,$item.LastWriteTime,$item.CreationTime | sort-object -Descending | Select-Object -first 1
                $item | %{
                    Write-Debug (Get-LastUsefulDateDebugMessage $_ $result)
                }
                return $result
            }
        }
    }
}

Function Clear-Temp {
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='Path')]
    param (
        [ValidateScript({ Test-Path $_ })]
        [Parameter(ParameterSetName='Path', Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("FullName")]
        [string[]]
        $Path = $env:TEMP,

        [Parameter(ParameterSetName='LiteralPath', Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('PSPath')]
        [string[]]
        $LiteralPath,

        [Parameter(Position=1)]
        [int]$MonthsOld = 12
    )

    PROCESS {
        if(($Path -eq $env:TEMP) -and #the default value
                (Test-Path env:Data) -and (Test-Path ($dataTemp = Join-Path $env:Data "Temp"))) {
            $items =  $path,$dataTemp | %{ Get-item -literalpath $_ }    # Add $dataTemp to be cleared as well.
        }
        else {
            $parameters = $null;
            switch($PSCmdlet.ParameterSetName) {
            "LiteralPath" {$parameters = @{ LiteralPath = $LiteralPath }}
            "Path" { $parameters = @{ Path = $Path} }
            }
            $items = Get-Item @parameters
        }
        $pathsProcessingCounter = 1

        $items | %{
            $item = $_
            $itemsProcessedCount = 0;
            $items = Get-ChildItem -literalPath $item;
            $items| %{
                Write-Progress -Activity "Clear-Temp" -PercentComplete ($itemsProcessedCount++/$items.Count) `
                    -Status "Phase $pathsProcessingCounter/$($path.Count): Checking date/time usage for '$($_.FullName)'"
                $itemLastUsefulDate = (Get-ItemLastUsefulDate -literalPath $_.FullName) # Use literal path to handle scenarios where there are square brackets in the name.
                if($itemLastUsefulDate -lt [DateTime]::Now.AddMonths(-$MonthsOld)) {
                    Write-Verbose "$($_.FullName) was last used on $itemLastUsefulDate"
                    if($PSCmdlet.ShouldProcess("'$($_.FullName)' (dated $itemLastUsefulDate)",
                            "Move to Recycle Bin")) {
                        Write-Progress -Activity "Clear-Temp" -PercentComplete ($itemsProcessedCount++/$items.Count) `
                            -Status "Phase $pathsProcessingCounter/$($path.Count): Moving '$($_.FullName)' to RecycleBin"
                        Remove-FileToRecycleBin -literalPath $_.FullName
                    }
                }
            }
            $itemsProcessedCount=0
            $pathsProcessingCounter++
        }
    }
}