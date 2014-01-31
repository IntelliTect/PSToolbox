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
            Get-TfInfo $sut

    }
        It "Get TfInfo on a path that does not exist"{
        
        try {
            Get-TfInfo "None existent item"
        }
        catch {
            $exception=$_.exception
        }
        $exception.Message | Should Be "Cannot find item in TFS"
    }
}