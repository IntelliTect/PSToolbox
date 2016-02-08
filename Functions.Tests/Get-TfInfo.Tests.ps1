$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut
 
function DebugBreak{}
function Debug{
    Set-PSBreakpoint -command DebugBreak
    DebugBreak
}

Describe "Get-TfInfo" {
    It "Get TfInfo Tfs File"{
        try {
            Get-TfInfo $sut
        }
        catch {
            #Debug
            If($_.exception.Message -contains "Team Foundation services are not available from server") {
                Write-Warning "Inconclusive: TFS Server unavailable."   
            }
        }
    }
    It "Get TfInfo on a path that does not exist"{
        try {
            Get-TfInfo "None existent item"
        }
        catch {
            $exception=$_.exception
        }
        #Debug;
        If($exception.Message -contains "Team Foundation services are not available from server") {
            Write-Warning "Inconclusive: TFS Server unavailable."   
        } else {
            $exception.Message | Should Be "Cannot find item in TFS"
        }
    }
}