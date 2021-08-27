param (
	[string]$path = ".\",
    [string]$type = "Debug"
)

#Registry Key path for .net framework 4.x.x
[string]$keyPath = "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full"

#Release number for .net framework 4.6.x on windows 10 systems.
[string]$requiredVersion = "393295"
#Release numbers for .net framework 4.6.x on all other OS are greater than the number above.

[string]$clean = "/t:Clean"
[string]$build = "/t:Build"
[string]$options = "/v:m"
[string]$config = "/p:Configuration=" + $type
[string]$output = "/p:OutputPath=$(Join-Path $PSScriptRoot \bin)"
 
#Change pwd  to $PSScriptRoot
#checks for solution file in path
Function Check-Path() {
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $path))
	Write-Verbose "Solution Path - $fullPath"
	$solution = Get-ChildItem $fullPath *.sln -Recurse
	If(-not $solution) {
		Write-Error "Solution File Not Found"
	}
	Else {
		$solution = $solution.FullName
		Write-Verbose "Solution File Found - $solution"
	}
	return $solution
}

#Tests the registry key for matching or newer version of .Net Framework for building solution
#Idea for following function from
#http://blog.smoothfriction.nl/archive/2011/01/18/powershell-detecting-installed-net-versions.aspx
Function Test-Key ([string]$key) {
    if(!(Test-Path $keyPath)) { 
        return $false 
    }
    [int]$versionNumber = [int](Get-ItemProperty $keyPath).$key
    Write-Verbose "Version Release Number - $versionNumber"
    if ($versionNumber -ge [int]$requiredVersion) { 
        return $true 
    }
    Write-Verbose "Required Version - $requiredVersion"
    return $false
}
Function Check-Version() {
    If(Test-Key("Release")) { return $true }
    return $false
}

Function Build-Solution([string]$solutionName) {
    
    If($hasVersion -eq $false) {
        Write-Error "Unable to build - Incorrection version"
        return
    }
    If(-not $solutionName) {
        Write-Error "Unable to build - No Solution Found"
        return
    }
    
    Write-Host "Building solution - $solutionName"
    & $msbuild $solutionName $options $clean $config $output
    & $msbuild $solutionName $options $build $config $output
	
}
$msbuild = "${env:ProgramFiles(x86)}\MSBuild\14.0\Bin\MSBuild.exe"
$solutionName = Check-Path
$hasVersion = Check-Version
Build-Solution($solutionName)
