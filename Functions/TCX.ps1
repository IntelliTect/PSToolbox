


Function Join-TCXFile {
    [CmdletBinding()]param(
        [string]$firstFile, 
        [string]$secondFile) 
    [XML]$firstXml = Get-Content $firstFile
    [XML]$secondXml = Get-Content $secondFile
    [double]$firstLastTrackPointDistanceMeters = Get-TcxDistance $firstXml
    #Add the total distance in the first file to the distances in the second file
    $secondXML.TrainingCenterDatabase.Activities.Activity.Lap.Track.TrackPoint | `
        #Some nodes (specifically the first one) don't have a DistanceMeters node so ignore it.
        ?{ ($_.PSObject.Properties.Match('DistanceMeters').Count) } | `
        #Add the distance from the first file to each of the distance elements in the second
        %{ $_.DistanceMeters = ([long]$_.DistanceMeters + $firstLastTrackPointDistanceMeters).ToString() } > $null

    $parentActivity = $firstXML.TrainingCenterDatabase.Activities.Activity
    
    $secondXML.TrainingCenterDatabase.Activities.Activity.Lap | %{ 
        $node = $firstXml.ImportNode($_, $true)
        $parentActivity.AppendChild($node) 
    } > $null
    return $firstXml
}

Function Get-TcxDistance {
    [CmdletBinding()]param(
        [XML]$tcxContent) 
    Return [double]($tcxContent.TrainingCenterDatabase.Activities.Activity.Lap.Track.TrackPoint | Select-Object -last 1 -ExpandProperty DistanceMeters)
}

Function Get-TcxLap {
    [CmdletBinding(DefaultParameterSetName="path")] param( 
        [Parameter(ParameterSetName='path', Mandatory)][ValidateScript({Test-Path $_})][string]$path, #ToDo: Improve the error message when the path does not exist.
        [Parameter(ParameterSetName='xml', Mandatory)][ValidateNotNullOrEmpty()][Xml]$xml) 

    if($psCmdlet.ParameterSetName -ne 'xml') {
        $xml = ([Xml](Get-Content $path))
    }
    Return $xml.TrainingCenterDatabase.Activities.Activity.Lap
}