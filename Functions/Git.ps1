

$script:gitActionsLookup =@{
    '??'= 'Untracked'
    'C'= 'Copied';
    'R'= 'Renamed';
    'D'= 'Deleted';
    'A'= 'Added';
    'M'= 'Modified'
};

Function Get-GitStatus {
    [CmdletBinding()]
    param(

    )

    git status --porcelain | ?{ 
        $_ -match '(?<Action>[AMRDC]|\?\?)\s+(?<Filename>.*)' } | %{ $matches } | %{
            [PSCustomObject]@{
                "Action"="$($script:gitActionsLookup.Item($_.Action))";
                "FileName"=$_.FileName
            }
        }
}