
Function Get-HostsFilePath() {
    return "$ENV:WinDir\System32\Drivers\etc\HOSTS"
}

Add-Type -Language CSharp -TypeDefinition @"
    namespace IntelliTect.Net
    {
        public class HostsFileEntry
        {
            public HostsFileEntry(System.Net.IPAddress ipAddress, string dnsName, string comment = null, bool isCommentedOut=false)
            {
                IPAddress = ipAddress;
                DnsName = dnsName;
                Comment = comment;
                IsCommentedOut = isCommentedOut;
            }
            public System.Net.IPAddress IPAddress {get; private set;}
            public string DnsName {get; private set;}
            public string Comment {get; private set;}
            public bool IsCommentedOut {get; private set;}
            public override string ToString () { return string.Format("{0}({1})", DnsName, IPAddress); }
        }
    }
"@

#ToDo: Publish: Mandatory on a string checks for null or empty string.

Function New-HostsFileEntry(
    [Parameter(ValueFromPipeline=$true)][string] $line) {
    if(![string]::IsNullOrWhiteSpace($line)) {
        $IPAddress,$DnsName = $line.Split();
        if(![string]::IsNullOrWhiteSpace($DnsName) ) {
            $DnsName,$Comment = $DnsName.Split("#") | ?{ ![string]::IsNullOrWhiteSpace($_) } | %{ $_.Trim() }
        }
        [bool] $IsCommentedOut = $IPAddress.StartsWith("#");
        $IPAddress = $IPAddress.TrimStart("#"); #This line is commented out.
        $isValid = $false;
        if( ($IPAddress -match 
                "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$") -AND
            ($DnsName -match 
                "^(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*\.?$") ) { 
            $isValid = $true;
        }
    }
    $result = $null;
    if($isValid -AND (!$_.IsCommentedOut -OR $IncludedCommentedOutEntries)) {
        $result = New-Object IntelliTect.Net.HostsFileEntry($IPAddress,$DnsName,$Comment,$IsCommentedOut)
    }
    return $result; 
}

Function Get-HostsFileEntry([string] $Entry, [bool] $IncludedCommentedOutEntries=$false) {
    Get-Content (Get-HostsFilePath) | ?{ $_ -like "*$Entry*" } | %{
        New-HostsFileEntry $_
    } | ?{ $_ -ne $null }
}

Function Add-HostsFileEntry {
[CmdletBinding(
    SupportsShouldProcess=$true #Tells the shell that your function supports both -confirm and -whatif.
    ,ConfirmImpact="Medium" #Causes Confirm prompt when $ConfirmPreference is "High"
)]
param
(
    [Parameter(Mandatory, Position = 0)][string]$IPAddress,
    [Parameter(Mandatory, Position = 1)][string]$DnsName,
    [Parameter(Position = 2)][switch]$Force=$false,
    [Parameter(Position = 3)][switch]$PassThru=$false
)

    [IntelliTect.Net.HostsFileEntry]$currentHostEntries = Get-HostsFileEntry $DnsName

    If(!$currentHostEntries) {
        if($pscmdlet.ShouldProcess("Append $DnsName with IP Address $IPAddress to HOSTS file ('$hostFilePath')") ) {
            Add-Content -Path (Get-HostsFilePath) -Value "$IPAddress`t`t$DnsName"
            if($PassThru) {
                Write-Output (Get-HostsFileEntry $DnsName)
            }
        }
    }
    else {
        $currentHostEntries | %{
            #TODO Write Tests and implementation.
            if( ($_.IsCommentedOut -and $_.IPAddress -eq $IPAddress) ) {
                Write-Verbose "Uncommenting existing entry"
                throw "Not yet implmented."  #TODO: Implement uncomment
            }
            # TODO: Verify the entry value is the same.
            if($_.IPAddress -eq $IPAddress) {
                Write-Verbose ("Hosts entry for '{0}' as '{1}' already exists." -f $_.IPAddress, $_.$DnsName)
            }
            else {
                if($force) {
                    throw "Not yet implmented."  #TODO: Update entry
                }
                else {
                    Write-Error ("Hosts file entry '{0}' already exists.  Use -Force to override." -f $DnsName)
                }
            }
        }
    }
}

Function Remove-HostsFileEntry {
[CmdletBinding(
    SupportsShouldProcess=$true #Tells the shell that your function supports both -confirm and -whatif.
    ,ConfirmImpact="Medium" #Causes Confirm prompt when $ConfirmPreference is "High"
)]
param
(
    [Parameter(Position = 0)][string]$IPAddress,
    [Parameter(Position = 1)][string]$DnsName,
    [Parameter(Position = 2)][bool]$PassThru=$false
)
    if([string]::IsNullOrWhiteSpace($IPAddress) -and [string]::IsNullOrWhiteSpace($DnsName)) {
        throw "Either or both `$IPAddress or `$DnsName are required.";
    }

    $tempFile = [IO.Path]::GetTempFileName();
    
    [bool]$itemRemoved = $false;
    Get-Content (Get-HostsFilePath) | ?{ 
        $entryFound = $false;
        Write-Verbose $_;
        $entry = New-HostsFileEntry $_;
        if($entry) {
            $ipAddressFound = $IPAddress -eq $entry.IPAddress
            $dnsNameFound = $DnsName -eq $entry.DnsName;
            #The item if is found if both IPAddress and DnsName are specified and found or exclusively one (or the other) is specified and found.
            $entryFound = (![string]::IsNullOrWhiteSpace($IPAddress) -and $ipAddressFound -and ![string]::IsNullOrWhiteSpace($DnsName) -and $dnsNameFound) -or
                ([string]::IsNullOrWhiteSpace($IPAddress) -and $dnsNameFound ) -or
                ([string]::IsNullOrWhiteSpace($DnsName) -and $ipAddressFound);
        }
        $entryFound = $entry -and $entryFound -and
                    $pscmdlet.ShouldProcess("Remove $_.DnsName with IP Address $_.IPAddress from HOSTS file ('$hostFilePath')");
        $itemRemoved = $itemRemoved -or $entryFound; # Save an indicator that an item was removed.
        return !$entryFound;
    } | Set-Content $tempFile;
    
    if($itemRemoved) {
        Move-Item $tempFile (Get-HostsFilePath) -force
    }
}