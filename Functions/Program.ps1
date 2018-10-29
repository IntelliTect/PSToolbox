
Function Script:Get-ProgramRegistryKeys {
    [CmdletBinding()][OutputType('System.String[]')] param()

    return [string[]] "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                  "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                  "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                  "Microsoft.PowerShell.Core\Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Uninstall"
}

# REview for 32/64 Bit
# http://gallery.technet.microsoft.com/scriptcenter/PowerShell-Installed-70d0c0f4

Function Get-Program {
    [CmdletBinding()] param([string] $Filter = "*") 

    (Get-ProgramRegistryKeys) | Get-ChildItem  | Get-ItemProperty | 
            Select-Object  *,@{Name="Name"; Expression = { 
                if( ($_ | Get-Member "DisplayName") -and $_.DisplayName) { #Consider $_.PSObject.Properties.Match("DisplayName") as it may be faster
                    $_.DisplayName
                } 
                else { 
                    $_.PSChildName 
                } 
            }} | 
            ?{ ($_.Name -Like $Filter) -or ($_.PSChildName -Like $Filter)  } 
}

Function Get-ProgramUsingWmi {
    [CmdletBinding()] param([string] $Filter = "*") 

    Write-Progress -Activity "Get Program List using WMI"
    Get-WmiObject -Class Win32_Product | 
            Where-Object -Property Name -Like $Filter
    Write-Progress -Activity "Get Program List using WMI" -Completed
}

$script:commandLineType = @{
    MemberType = 'NoteProperty'
    TypeName = 'PSDefult.Program.CommandLine'
    Value = $null
}
 
#Update-TypeData @commandLineType -MemberName ExePath -Force -value 
#Update-TypeData @commandLineType -MemberName Arguments -Force

Function Split-CommandLine {
    [CmdletBinding()][OutputType('PSDefult.Program.CommandLine')] param([string] $commandLine) 

    [PSCustomObject]$result = @{ ExePath = $commandLine; Arguments = "" }
    if($commandLine -match "(?<ExePath>.*\.exe['`"]?)(?<Arguments>(\s)?.*)?"  ) {
        $result.ExePath = $Matches.ExePath
        $result.Arguments = $Matches.Arguments
        Write-Host "Split-Command Line Result: $result"
    }
    else {
        write-host "unable to parse '$commandline'" 
    }
    Return [PSCustomObject]$result
}


Function script:Invoke-Uninstall {
    [CmdletBinding()] param([string] $uninstallString) 
    #Bug, #TODO: Get-Program sugarsync* | uninstall-program doesn't work

    If(Test-Path $uninstallString -ErrorAction Ignore) {
        $uninstallString = (Resolve-Path $uninstallstring).Path
        $uninstallString = "`"$uninstallString`""
    }
    #if ($uninstallString.Trim()[0] -ne '"') {
        #TODO: Use regular expression to split on " -" or " /"

        $uninstallProgram = Split-CommandLine $uninstallString

        #$uninstallStringParts = $uninstallString -split " -", 2
        
        Write-Verbose "Invoke-Command $uninstallString"
        Invoke-Expression "Start-Process $($uninstallProgram.ExePath) $($uninstallProgram.Arguments) -Wait"
        #Invoke-Command $uninstallStringParts[0] $uninstallStringParts[1]
    #}
    <# else {
        Write-Verbose "Invoke-Expression `"& $uninstallString`""
        Invoke-Expression "& $uninstallString"
    } #>
    <# if ($uninstallString.Trim()[0] -ne '"') { 
        Invoke-Expression ("& {0}" -f (Resolve-Path $uninstallString))
    }
    else { 
        Invoke-Expression (Resolve-Path $uninstallString)
    } #>
}

#[CmdletBinding]
#ToDo: Add support for piping Get-Program to Uninstall-Program (without selecting the name specicially)
#ToDo: Although using Function Get-ProgramUsingWmi is significantly slower, the object returns supports an Uninstall() method.
Function Uninstall-Program{
    [CmdletBinding()] param([Parameter(Mandatory, ValueFromPipeline=$True)]$Programs) 
    foreach($program in $Programs) {
        

    if($Program -is [string]) {
        $Program = Get-Program $Program;  # Note: This converts program from a string to a PSCustomObject
        if(!$Program) {
            Throw "Cannot find path '$program' because it does not exist."
        }
    }
    elseif ($Program -isnot [PSCustomObject] -or (!($Program | Get-Member "UninstallString"))){
        throw "`$Program is not a valid type and doesn't support an UninstallString property"
    }
    

    #Invoke Uninstall Command Directly
    $uninstallString = $Program.UninstallString
    Write-Verbose "Invoke-Expression $uninstallString"

    #If(Test-Path $uninstallString) {
    #    $uninstallString = (Resolve-Path $uninstallstring).Path
    #    $uninstallString = "`"$uninstallString`""
    #}

    try {
        Invoke-Uninstall $uninstallString
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        #Try uninstall using WMI
        $wmiProgramEntry = Get-ProgramUsingWmi $Program.Name
        $wmiProgramEntry.Uninstall
    }
    }
}

#REG QUERY HKLM\SOFTWARE /f Uninstall /k /S /e

 Function Get-TempPath() {
        if(Test-Path "c:\Data\Temp") { 
            $tempPath = "C:\Data\Temp" 
        } 
        else { 
            $tempPath = $env:Temp
        }
        return $tempPath
}

    

if(Get-Command 'choco' -ErrorAction Ignore) {
    Function Install-WebDownload {
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [parameter(Mandatory=$true, Position=0)][string] $packageName,
            [parameter(Mandatory=$false, Position=1)]
            [alias("installerType","installType")][string] $fileType = 'exe',
            [parameter(Mandatory=$false, Position=2)][string[]] $silentArgs = '',
            [parameter(Mandatory=$false, Position=3)][string] $url = '',
            [parameter(Mandatory=$false, Position=4)]
            [alias("url64")][string] $url64bit = '',
            [parameter(Mandatory=$false)] $validExitCodes = @(0),
            [parameter(Mandatory=$false)][string] $checksum = '',
            [parameter(Mandatory=$false)][string] $checksumType = '',
            [parameter(Mandatory=$false)][string] $checksum64 = '',
            [parameter(Mandatory=$false)][string] $checksumType64 = '',
            [parameter(Mandatory=$false)][hashtable] $options = @{Headers=@{}},
            [alias("fileFullPath")][parameter(Mandatory=$false)][string] $file = '',
            [alias("fileFullPath64")][parameter(Mandatory=$false)][string] $file64 = '',
            [parameter(Mandatory=$false)]
            [alias("useOnlyPackageSilentArgs")][switch] $useOnlyPackageSilentArguments = $false,
            [parameter(Mandatory=$false)][switch]$useOriginalLocation,
            [parameter(ValueFromRemainingArguments = $true)][Object[]] $ignoredArguments
        )

        
        
        if($PSCmdlet.ShouldProcess('Install-ChocolateyPackage')) {    
            Set-WindowsDefaultSecurityProtocol
            Set-ChocolateyAllowEmptyChecksum -Value Disable
            ChocolateyInstaller\Install-ChocolateyPackage @PSBoundParameters
        }
    }

    Function Set-WindowsDefaultSecurityProtocol {
        [CmdletBinding()]
        param(
            [switch]$Persist=$false
        )
        
        if($Persist) {
            new-itemproperty -path "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" -name "SchUseStrongCrypto" -Value 1 -PropertyType "DWord";
            new-itemproperty -path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319" -name "SchUseStrongCrypto" -Value 1 -PropertyType "DWord"
        }

        # Sets the protocol temporarily (for the life of the PowerShell Session.)
        # To address the issue:"Invoke-WebRequest : The request was aborted: Could not create SSL/TLS secure channel."
        # https://stackoverflow.com/questions/28286086/default-securityprotocol-in-net-4-5/28502562#28502562
        # https://stackoverflow.com/questions/41618766/powershell-invoke-webrequest-fails-with-ssl-tls-secure-channel
        [Net.ServicePointManager]::SecurityProtocol =
        [Net.SecurityProtocolType]::Tls12 -bor `
        [Net.SecurityProtocolType]::Tls11 -bor `
        [Net.SecurityProtocolType]::Tls
    }


    Function Set-ChocolateyFeature {
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [Parameter(Mandatory,ValueFromPipeline)][string[]]$Feature,
            [ValidateSet('Enable','Disable')][Parameter(Mandatory)][string]$Value,
            [switch]$Persist
        )

    PROCESS {
            $Feature | ForEach-Object {
                if($PSCmdlet.ShouldProcess("$Value Chocolatey Feature $Feature")) {
                    Write-Progress -Activity 'Installing and Configuring Chocolatey' -Status "Configuring $_"
                    if($Persist) {
                        Write-Host "Configuring chocolatey with option $_"
                        choco feature enable -n $_
                    }
                    #Set environment variables so the above options are true when directly calling Chocolatey functions/commands:
                    [Environment]::SetEnvironmentVariable("Chocolatey$_", $true)
                }
            }
        }
    }

    Function Set-ChocolateyAllowEmptyChecksum {
        [CmdletBinding()]
        param(
            [ValidateSet('Enable','Disable')][Parameter(Mandatory)]$Value='Disable',
            [switch]$Persist=$false
        )
        
        'AllowEmptyChecksums', 'AllowEmptyChecksumsSecure' | Set-ChocolateyFeature -Value $Value -Persist:$Persist
    }
}
else {
    Function Install-WebDownload {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][alias("Uri")][string] $url, 
        [Parameter(Mandatory)][string] $PackageName, 
        [Parameter(ParameterSetName="CommandLine")] [string] $arguments = $null, 
        [Parameter(ParameterSetName="ScriptBlock")][ScriptBlock] $postDownloadScriptBlock, 
        [Parameter(ParameterSetName="UnattendedSilentSwitchFinder",
            HelpMessage="Lookup the unattended silent switch for the setup program.")][switch]$ussf,
        [string] $installFileName = [System.Management.Automation.WildcardPattern]::Escape((Split-Path $url -Leaf)),
        [switch]$forceDownload ) 

        Function Install-WebDownloadOfZip {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)][string] $PackageName, 
                [Parameter(Mandatory)][alias("Uri")][string] $url, 
                $UnzipLocation = "$env:ChocolateyInstall\lib\$PackageName"
            )

            Import-ChocolateyModule

            try {
                # Needed because Chocolatey is not setting up context.
                if(!(test-path variable:\helpersPath)) {
                    $setHelpersPath = $true
                    $global:helpersPath = $env:ChocolateyInstall
                }
                Install-ChocolateyZipPackage -packageName $PackageName -url $url -unzipLocation $UnzipLocation -specificFolder ''
                Get-ChildItem $UnzipLocation *.exe | %{ Install-BinFile -name TrayIt -path $_.FullName  }
            }
            finally {
                if($setHelpersPath) {
                    remove-item variable:\global:helpersPath
                }
            }
        }

        #TODO Switch to Get-ChocolateyWebFile and use Invoke-WebRequest as fallback.
        $tempPath = Get-TempPath

        if([IO.Path]::GetExtension($InstallFileName) -eq ".zip") {
            Install-WebDownloadOfZip -Uri $url -packageName $PackageName
        }
        else {
            $installFileName = Join-Path $tempPath $installFileName

            if($forceDownload -OR ($installFileName -eq "Setup.exe") -OR !(Test-Path $installFileName) ) {
                Invoke-WebRequest $url -OutFile $installFileName
            }

            if($ussf) {
                ussf $installFileName
            }
            else {
                If( ([string]::IsNullOrWhiteSpace($PsCmdlet.ParameterSetName)) -or ($PsCmdlet.ParameterSetName -eq "CommandLine") ) {
                    $postDownloadScriptBlock = [ScriptBlock] {
                        $process = Start-Process $installFileName $arguments -PassThru -wait  
                        return $process.ExitCode
                    }
                }
            }
            Write-Output (Invoke-Command $postDownloadScriptBlock)
        }
    }
}


Function InfInstall([Parameter(Mandatory)][string] $InfFilePath)
{
	[System.Diagnostics.Process]::Start($ENV:SystemRoot + "\System32\rundll32.exe", "setupapi,InstallHinfSection DefaultInstall 132 " + $InfFilePath) #> null
}

Function New-WindowsShortcut {
[CmdletBinding()] param(
    [String] $Path, 
    [string] $TargetPath, 
    [String] $Arguments = "", 
    [string]$Shorcutkey) 

    #TODO: See http://poshcode.org/2493 in combination with the following for administrator mode:
    #    $shortcut = Get-Link -Path '.\shortcut.lnk'
    #    $shortcut.Flags = $shortcut.Flags -bor [Huddled.Interop.ShellLinkFlags]::RunasUser
    #    $shortcut.Save()
    $WshShell = New-Object -ComObject Wscript.Shell
    if([io.path]::GetExtension($Path) -ne ".lnk") {
        $Path = "$Path" + ".lnk"
    }
    $shortcut = $WshShell.CreateShortcut($Path);
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.Hotkey = $Shorcutkey 
    Write-Warning "Shortcut keys not currently working." #TODO
    $shortcut.Save()
}

Function Expand-ZipFile {
        [CmdletBinding()] param(
        [Parameter(mandatory=$true, ValueFromPipeline=$true, ParameterSetName='FileInfo')][IO.FileInfo]$InputObject,
        [Parameter(mandatory=$true, ValueFromPipeline=$true, ParameterSetName='Path')][String]$Path,
        [Parameter(Position=2)][string]$outputPath = $pwd) 
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if($path) {
        $InputObject = Get-Item $path
    }
    if(!(Test-Path $InputObject)) {
        Throw "Unable to find file: '$inputObject'"
    }
    [System.IO.Compression.ZipArchive]$zipFile = [System.IO.Compression.ZipFile]::Open( $InputObject, "Read" )
    [System.IO.Compression.ZipFileExtensions]::ExtractToDirectory( $zipFile, $outputPath) 
    $zipFile.Dispose()
    Return (Get-Item $outputPath)
}
    
Function New-AppPath {
    [CmdletBinding()] param(
        [Alias("FullName")][Parameter(ValueFromPipelineByPropertyName)][string] $path, 
        [switch]$Force, 
        [switch]$Confirm) 
    $registryPath = "`"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$(Split-Path $path -Leaf)`""
    Write-Host "`$Path=$path, `$registryPath=$registryPath"
    Invoke-Expression "New-Item -Path $registryPath -Value $path $(if($force){'-Force'})$(if($Confirm){'-Confirm'})"
}
#dir 'C:\Program Files\sysinternals' 'zoomit.exe' | New-AppPath -Force

Function Remove-AppPath {
    [CmdletBinding()] param(
        [Parameter(ValueFromPipeline)][string] $path) 
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$(Split-Path $path -Leaf)"
    Remove-Item -Path $registryPath
}

#Doesn't work... why?
Function Select-AllButLast {
    [CmdletBinding()] param(
        [parameter(ValueFromPipeline=$true)]$inputObject, 
        [int]$n) 
    if($inputObject.PSObject.Properties.Match('Count')) {
        $count = $inputObject.Count;
    }
    else {
        $count = ($inputObject | Measure-Object).Count
    }
    Return $inputObject | Select-Object -First ($count-$n)
} 
<#
Describe "Select-AllButLast" {
    It "Return all lines" {
        $items = 0..9
        $result = Select-AllButLast -InputObject $items -n 0
        $result.Count | Should Be 10
        $Result -notcontains 9 | Should Be True
        $Result -contains 0 | Should Be True
    }
}
#>

<#
.SYNOPSIS
Executes a cmd.exe command that returns a PSCustomObject where <a>=<b>
.EXAMPLE
PS C:\> Invoke-CmdWithPairResultSplitWithEquals assoc .txt | write-host
Returns a PSCustomObject of @{First=.txt; Second=txtfile}
.EXAMPLE
PS C:\> Invoke-CmdWithPairResultSplitWithEquals ftype  | Select-Object -First 5

Returns All the ftype results as follows:
    First                                Second                                                                                               
    -----                                ------                                                                                               
    Access                               C:\Program Files\Microsoft Office 15\Root\Office15\protocolhandler.exe "%1"                          
    Access.ACCDAExtension.15             C:\Program Files\Microsoft Office 15\Root\Office15\MSACCESS.EXE /NOSTARTUP "%1"                      
    Access.ACCDCFile.15                  "C:\Program Files\Microsoft Office 15\Root\Office15\MSACCESS.EXE" /NOSTARTUP "%1"                    
    Access.ACCDEFile.15                  "C:\Program Files\Microsoft Office 15\Root\Office15\MSACCESS.EXE" /NOSTARTUP "%1" %2 %3 %4 %5 %6 %...
    Access.ACCDRFile.15                  "C:\Program Files\Microsoft Office 15\Root\Office15\MSACCESS.EXE" /RUNTIME "%1" %2 %3 %4 %5 %6 %7 ...
#>
Function script:Invoke-CmdWithPairResultSplitWithEquals {
    [CmdletBinding()] param (
        # The DOS command to execute.  The command must return an <a>=<b> result such as the assoc or ftype commands do. If there are multiple results, the must be on separate lines.
        [parameter(Mandatory)][string] $command,
        # The file extension(s) to retrieve.  If no period prefix, one is automatically added.
        [parameter(ValueFromPipeline)][string] $argumentList = ""
    )

    #Function Test-IgnoreAction() { $error.Clear();if(-not $?) {write-host "ERRORS"}; $PSDefaultParameterValues['*:ErrorAction']="SilentlyContinue"; $result = & cmd.exe /c assoc .MissingExtension;  };Test-IgnoreAction

    try {
        $result = & cmd.exe /c $command $argumentList 2>&1
    }
    catch { $result = $_ }

    if($result.GetType() -eq [System.Management.Automation.ErrorRecord]) {
        throw $result[0].Exception
    }
    else {
        $result | %{
            #Success
            $first,$second = ($_ -split '=')
            Write-Output ([PSCustomObject] @{
                First = $first;
                Second = $second
            })
        }

    }
}


#TODO Write Test
<#
.SYNOPSIS
Retrieve the file association for the specified extension(s).
.EXAMPLE
PS C:\> Get-FileAssociation .txt
Returns Text Document (txtfile).
#>
Function Get-FileAssociation {
    [CmdletBinding()] param (
        # The file extension(s) to retrieve.  If no period prefix, one is automatically added.
        [parameter(ValueFromPipeline)][string[]] $Extension
    )
    PROCESS {
        $Extension | %{ 

            $item = $_
            if(-not $item) { $item = "" }
            elseif(-not($item.StartsWith("."))){
                #Prefix with a period.
                $item = ".$_"
            }

            if([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($item)) {
                #Only perform a full lookup for the specified items (rather than all of them).
                Invoke-CmdWithPairResultSplitWithEquals assoc | ?{ 
                    $_.First -like $item 
                } | %{
                    Get-FileAssociation $_.First
                }
            }
            else {
                try{
                    #Note: $errorAction not working in advanced functions with PowerShell 4 (see https://connect.microsoft.com/PowerShell/feedback/details/763621/erroraction-ignore-is-broken-for-advanced-functions)
                    $fileAssociation = Invoke-CmdWithPairResultSplitWithEquals assoc $item
                    $fileAssociation | %{
                        $fileType = try{ Invoke-CmdWithPairResultSplitWithEquals "assoc" $_.Second } 
                            catch [System.Management.Automation.RuntimeException] { 
                                if($_.Exception.Message -like "File association not found for extension*") { <# ignore #> } 
                                else { throw }
                            }
                        try{ $fileTypeCommand = Invoke-CmdWithPairResultSplitWithEquals ftype $_.Second }
                            catch [System.Management.Automation.RuntimeException] { 
                                if($_.Exception.Message -like "File type * not found or no open command associated with it.") { <# ignore #> } 
                                else { throw }
                            }
                        Write-Output ([PSCustomObject]@{
                            Name = if($fileType){$fileType.Second};
                            Extension = $item;
                            FileType = $_.Second;
                            Command = if($fileTypeCommand) {$fileTypeCommand.Second};
                        })
                    }
                }
                catch [System.Management.Automation.RuntimeException] {
                    if($ErrorActionPreference -ne "Ignore") {
                        Throw $_.Exception.Message
                    }
                }
                #If there is still an error as a result... then give up (returning nothing).
            }
        }
    } 
}
Set-Alias Assoc Get-FileAssociation


<#
.SYNOPSIS
Creates an association between a file extension and a executable

.DESCRIPTION
Install-ChocolateyFileAssociation can associate a file extension 
with a downloaded application. Once this command has created an 
association, all invocations of files with the specified extension 
will be opened via the executable specified.

This command will run with elevated privileges.

.PARAMETER Extension
The file extension to be associated.

.PARAMETER Executable
The path to the application's executable to be associated.

.EXAMPLE
C:\PS>$sublimeDir = (Get-ChildItem $env:systemdrive\chocolatey\lib\sublimetext* | select $_.last)
C:\PS>$sublimeExe = "$sublimeDir\tools\sublime_text.exe"
C:\PS>Install-ChocolateyFileAssociation ".txt" $sublimeExe

This will create an association between Sublime Text 2 and all .txt files. Any .txt file opened will by default open with Sublime Text 2.
#>
Function Set-FileAssociation {
    # Started with (get-command Install-ChocolateyFileAssociation).Definition
    [CmdletBinding()] param (
        # The file extension (s) to retrieve
        [parameter(ValueFromPipeline,Mandatory)][string[]] $extension,
        [ValidateScript({Test-Path $_ -PathType Leaf})][parameter(ValueFromPipeline,Mandatory)][string[]] $executable
    )
  $extension=$extension.trim()
  if(-not($extension.StartsWith("."))) {
      $extension = ".$extension"
  }
  $fileType = Split-Path $executable -leaf
  $fileType = $fileType.Replace(" ","_")
  $elevated = [scriptblock]{ "cmd /c 'assoc $extension=$fileType';cmd /c 'ftype $fileType=\`"$executable\`" \`"%1\`" \`"%*\`"'" }
  Start-ProcessAsAdmin $elevated
}


Function Start-ProcessAsAdmin() {
param(
  [Parameter(ParameterSetName="Scriptblock")][string] $scriptBlock, 
  [ValidateScript({(Get-Command $_).CommandType -eq "Application"})][Parameter(ParameterSetName="Application")][string] $executable,
  [Parameter(ParameterSetName="Application")][string] $argumentList,
  [switch] $minimized,
  [switch] $noSleep,
  $validExitCodes = @(0)
) 
    # Started with (get-command Start-ChocolateyProcessAsAdminn).Definition

    if($PsCmdlet.ParameterSetName -eq "scritpblock") { 
        $executable = "PowerShell"
        $argumentList = "-command {$scriptBlock}" # Consider alternative: "-command `"& {$scriptBlock}`""
    }

    $filePath = (Get-Command $executable).Path
    $result = Write-Progress -activity "Elevating Permissions and running $filePath $wrappedStatements."

    $psi = new-object System.Diagnostics.ProcessStartInfo;
    $psi.FileName = $filePath;
    $psi.Arguments = "$argumentList";

    if ([Environment]::OSVersion.Version -ge (new-object 'Version' 6,0)){
      $psi.Verb = "runas";
    }

    $psi.WorkingDirectory = get-location;

    if ($minimized) {
      $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized;
    }
 
    $s = [System.Diagnostics.Process]::Start($psi);
    $s.WaitForExit();
    if ($validExitCodes -notcontains $s.ExitCode) {
      throw "[ERROR] Running $filePath with $statements was not successful. Exit code was `'$($s.ExitCode)`'."
    }
}

Function Optimize-ProgramEnvironmentPath {
    [CmdletBinding()]param(
    )
    $hklmPaths = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"  | 
        select -ExpandProperty Path) -split ';' |  
            %{ $_ -replace "WINDOWS","Windows" } | 
                select -unique | 
                    ?{ $_.Trim().Length -gt 0 }
    
    #Identify the older SQL Server paths
    $olderSqlPaths = $hklmPaths | ?{ $_ -like "$env:ProgramFiles\Microsoft SQL Server\*" } | sort -Descending | select -Skip 1 
    $hklmPaths = $hklmPaths | ?{ $_ -notin $olderSqlPaths }
    
    $hkcuPaths = (Get-ItemProperty "hkcu:\Environment" "Path"  | 
        select -ExpandProperty Path) -split ';' |  
            %{ $_ -replace "WINDOWS","Windows" } | 
                select -unique | 
                    ?{ $_.Trim().Length -gt 0 }

    $hklmPaths = { $hklmPaths }.Invoke() #Convert the collection to support Add()/Remove()
    $hkcuPaths = { $hkcuPaths }.Invoke() #Convert the collection to support Add()/Remove()
    $hkcuPaths = $hkcuPaths | ?{ 
        if($_ -like "*SysInternals*") { 
            $hklmPaths.Add($_)  #TODO: Remove potential that the item could be added more than once 
        }
        else { $true }
    }

    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path" -Value ($hklmPaths -join ';')
    Set-ItemProperty "hkcu:\Environment" "Path" -Value ($hkcuPaths -join ';')
}

Function Test-ProgramEnvironmentPath {
    [CmdletBinding()]param(
    )
    $result = $true;
    $paths = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment","hkcu:\Environment" "Path"  | 
        select -ExpandProperty Path) -split ';'
     
    $paths |  
            %{ $_ -replace "WINDOWS","Windows" } | 
                Group-Object | select name,count | 
                    ?{ $_.count -gt 1 } | 
                        %{ 
                            $result = $false
                            Write-Warning "$($_.Name) appears $($_.Count) times." 
                        } 
    $olderSqlPaths = $paths | ?{ $_ -like "$env:ProgramFiles\Microsoft SQL Server\*" }
    if(Compare-Object $olderSqlPaths ($olderSqlPaths | sort -Descending) -SyncWindow 0) {
        $result = $false
        Write-Warning "There are multiple SQL Server paths and they are not in descending order: `n`t$($olderSqlPaths -join "`n`t")"

    }
        
    return $result;
}