$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

Describe "Get-TcxFile" {
    It "Get the distance from activity_521153787.tcx" {
        [Xml]$tcxContent = Get-Content "$here\activity_521153787.tcx"
        $result = Get-TcxDistance $tcxContent
        $result | Should Be 140292.953125
    }
}

Describe "Get-TcxLap" {
    It "Get laps from activity_521153787.tcx" {
        #Why is "-path" requried explicitly?
        $laps = Get-TcxLap -path "$here\activity_521153787.tcx"
        $laps.Count | Should Be 87
    }
    It "Get laps from activity_521153787.tcx using -xml" {
        #Why is "-path" requried explicitly?
        [Xml]$xml = Get-Content "$here\activity_521153787.tcx"
        $laps = Get-TcxLap -xml $xml
        $laps.Count | Should Be 87
    }
    <# It "Provide an invalid path" {
        #TODO: Correct so error is caught
        Get-TcxLap -path "$here\DoeNotExist.tcx" -ErrorVariable $err -ErrorAction SilentlyContinue
    }
    #>
}

Describe "Join-TcxFile" {
    It "Join activity_521153787.tcx and activity_521169279.tcx" {
        $firstLapElementCount = (Get-TcxLap -path "$here\activity_521153787.tcx").Count
        $secondLapElementCount = (Get-TcxLap -path "$here\activity_521169279.tcx").Count
        [Xml]$result = Join-TcxFile "$here\activity_521153787.tcx" "$here\activity_521169279.tcx"
        $resultLapElementCount = (Get-TcxLap -xml $result).Count
        $resultLapElementCount | Should Be 88
    }
}