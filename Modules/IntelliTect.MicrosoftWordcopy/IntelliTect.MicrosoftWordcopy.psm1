
try {
    add-type -AssemblyName "Microsoft.Office.Interop.Word" 
}
catch {
    throw "Unable to find 'Microsoft.Office.Interop.Word' assembly."
}
########ooooogaSss
#TODO: Remove and use dependency on File.ps1 (module needed) instead.
Function Test-FileIsLocked {
    [CmdletBinding()]
    ## Attempts to open a file and trap the resulting error if the file is already open/locked
    param ([string]$filePath )
    $filelocked = $false
    try {
        $fileInfo = New-Object System.IO.FileInfo $filePath
        $fileStream = $fileInfo.Open( [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None )
    }
    catch {
        $filelocked = $true
    }
    finally {
        if ($fileStream) {
            $fileStream.Close()
        }
    }

    return $filelocked
}
<#

This document http://blogs.technet.com/b/heyscriptingguy/archive/2012/08/01/find-all-word-documents-that-contain-a-specific-phrase.aspx
describes word cleanup as:
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($range) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($document) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($application) | Out-Null
    Remove-Variable -Name application
    [gc]::collect()
    [gc]::WaitForPendingFinalizers()


See additional enums at the bottom.
#>


<#
    .SYNOPSIS 
      Provides a Using statement for PowerShell for COM objects specifically.

    .EXAMPLE
    Invoke-ComUsing ($application = $sr.Start-MicrosoftWord) { 
      $application.Visible = $false
    } 
    
    This command instantiates the Word Application, sets it to invisible, and then removes all COM references.
#>
Function script:Invoke-ComUsing {
    [CmdletBinding()] param (
        [ValidateScript( { [System.Runtime.InteropServices.Marshal]::IsComObject( $_) })][Parameter(Mandatory, ValueFromPipeline)][System.IDisposable] $inputObject,
        [Parameter(Mandatory, ValueFromPipeline)][ScriptBlock] $scriptBlock
    )
    # See http://weblogs.asp.net/adweigert/powershell-adding-the-using-statement
    # for original implementation

    # TODO: Create a Non-Com version of this that the Com version one then calls.

    try {
        &$scriptBlock
    } 
    finally {
        if ($inputObject -ne $null) {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($inputObject) | Out-Null
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            if ($inputObject.psbase -eq $null) {
                $inputObject.Dispose()
            }
            else {
                $inputObject.psbase.Dispose()
            }
        }
    }
}


Function Open-MicrosoftWord {
    [CmdletBinding()] param(
    )
    return new-object -ComObject Word.Application
}

Function Open-WordDocument {
    [CmdletBinding()] param(
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [Parameter(Mandatory, ValueFromPipeLine, ValueFromPipelineByPropertyName, Position)]
        [Alias("FullName", "InputObject")]
        [string[]]$Path,
        [switch]$ReadWrite,
        $WordApplication # An already open instance of the Microsoft Word application.
    )
    PROCESS {
        $Path | ForEach-Object {
            $eachDocumentPath = (Resolve-Path $_).Path
            [bool]$readOnly = ![bool]$ReadWrite.IsPresent  # TODO: Blog: switch and bool are not the same
            [bool]$ConfirmConversions = $false  # Optional Object. True to display the Convert File dialog box if the file isn't in Microsoft Word format.

            if (!$WordApplication) {
                $WordApplication = Open-MicrosoftWord
            }

            if (Test-FileIsLocked $eachDocumentPath) {
                throw "The $eachDocumentPath document is already opened."
            }

            $document = $WordApplication.Documents.Open($eachDocumentPath, $confirmConversions, $ReadOnly) #For additional parameters see https://msdn.microsoft.com/en-us/library/microsoft.office.interop.word.documents.open.aspx
            if ($readOnly) {
                # Used to avoid the error, "This method or property is not available because this command is not available for reading."
                # when using Find.Execute on the document
                # see http://blogs.msmvps.com/wordmeister/2013/02/22/word2013bug-not-available-for-reading/
                $document.ActiveWindow.View = [Microsoft.Office.Interop.Word.WdViewType]"wdPrintView"
            }

            #Add Text Property to Comment where the comment text is the Range.Text property on a comment.
            $comments = $document.Comments | ForEach-Object { Add-Member -InputObject $_ -MemberType ScriptProperty -Name Text -Value { $this.Range.Text } -PassThru } 
            Add-Member -InputObject $document -MemberType ScriptProperty -Name CommentsEx -Value { $comments } -Force

            return $document
        }
    }
}

Function Get-WordDocumentComment {
    [CmdletBinding()] param(
        [ValidateScript( { Test-Path $_ -PathType Leaf })][Parameter(Mandatory, ValueFromPipelineByPropertyName, Position)][Alias("FullName", "InputObject")]
        [string[]]$Path, #FullName alias added to support pipeline from Get-ChildItem

        [switch]$ReadWrite
    )
 
    PROCESS {
        [bool]$readOnly = ![bool]$ReadWrite.IsPresent  # TODO: Blog: switch and bool are not the same

        $Path | ForEach-Object {
            $document = Open-WordDocument -Path $_ -ReadWrite:(!$readOnly)
            $comments = $document.Comments | ForEach-Object { Add-Member -InputObject $_ -MemberType ScriptProperty -Name Text -Value { $this.Range.Text } -PassThru } 
            return $comments
        }
    }

}

Function Update-WordDocumentAcceptAllChanges {
    [CmdletBinding(SupportsShouldProcess)] param(
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position)]
        [Alias("FullName", "InputObject")]
        [string[]]$Path,
        [switch]$LeaveOpen
    )
    PROCESS {
        Write-Debug "Starting: Update-WordDocumentAcceptAllChanges '$path'"
        $Path | ForEach-Object {
            try {

                $eachDocumentPath = (Resolve-Path $_).Path
                $document = Open-WordDocument $eachDocumentPath -ReadWrite:(!$WhatIfPreference)
                $document.Application.Visible = $leaveOpen -or $PSCmdlet.MyInvocation.BoundParameters["Debug"]

                $document.AcceptAllRevisions()

            }
            finally {
                if ((Test-Path variable:document) -and ($document -ne $null) -and (!$LeaveOpen)) {
                    $application = $document.Application
                    try {
                        if ($PSCmdlet.ShouldProcess("Accept all changes in the document: $eachDocumentPath")) {
                            $document.Close() > $null
                        }
                        else {
                            # -WhatIf specified 
                            $document.Close([Microsoft.Office.Interop.Word.WdSaveOptions]::wdDoNotSaveChanges) > $null
                        }
                    }
                    finally {
                        $application.Quit()
                    }
                }
            }
        }
        Write-Debug "Stopping: Update-WordDocumentAcceptAllChanges '$path'"
    }
}

Function Set-WordDocumentTrackChanges {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position)]
        [Alias("FullName", "InputObject")]
        [string[]]$Path,
        [Parameter(Mandatory, Position)][bool]$Active,
        [switch]$LeaveOpen
    )

    PROCESS {
        $Path | ForEach-Object {
            try {
                $eachPath = $_
                # TODO: Change to not re-open the document
                if ((Get-WordDocumentTrackChanges -Path $eachPath) -ne $Active) {
                    $document = Open-WordDocument $_ -ReadWrite:(!$WhatIfPreference)
                    $document.Application.Visible = $leaveOpen -or $PSCmdlet.MyInvocation.BoundParameters["Debug"]

                    $document.TrackRevisions = $Active
                }
            }
            finally {
                if ((Test-Path variable:document) -and ($document -ne $null) -and (!$LeaveOpen)) {
                    $application = $document.Application
                    try {
                        if ($PSCmdlet.ShouldProcess("Set TrackChanges to $Active in '$eachPath'")) {
                            $document.Close() > $null
                        }
                        else {
                            # -WhatIf specified 
                            $document.Close([Microsoft.Office.Interop.Word.WdSaveOptions]::wdDoNotSaveChanges) > $null
                        }
                    }
                    finally {
                        $application.Quit()
                    }
                }
            }
        }
    }
}
Function Get-WordDocumentTrackChanges {
    [CmdletBinding()] 
    param(
        [ValidateScript( { Test-Path $_ -PathType Leaf })][Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position)][Alias("FullName", "InputObject")][string[]]$Path
    )

    PROCESS {
        $Path | ForEach-Object {
            try {
                $document = Open-WordDocument $_ -ReadWrite:$false

                Write-Output $document.TrackRevisions
                <#
                Write-Output @{ 
                    Document=$document;
                    TrackRevisions=$document.TrackRevisions
                }
                #>
            }
            finally {
                if ( (Test-Path variable:document) -and ($document -ne $null) ) {
                    $application = $document.Application
                    try {
                        $document.Close() > $null
                    }
                    finally {
                        $application.Quit()
                    }
                }
            }
        }
    }    
}

Function Set-WordDocumentProtection {
    [CmdletBinding(SupportsShouldProcess)] 
    param(
        [ValidateScript( { Test-Path $_ -PathType Leaf })][Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position)][Alias("FullName", "InputObject")][string[]]$Path,
        [ValidateSet("NoProtection", "AllowOnlyRevisions", "AllowOnlyComments", "AllowOnlyFormFields", "AllowOnlyReading")] $ProtectionType, #TODO: Restrict to possible values for Microsoft.Office.Interop.Word.WdProtectionType with Intellisense
        $Password,
        [switch]$LeaveOpen
    )
    PROCESS {
        $Path | ForEach-Object {
            try {
                $eachPath = $_
                $document = Open-WordDocument $eachPath -ReadWrite:(!$WhatIfPreference)
                $document.Application.Visible = $leaveOpen -or $PSCmdlet.MyInvocation.BoundParameters["Debug"]

                $protectionType = [Microsoft.Office.Interop.Word.WdProtectionType] "wd$protectionType"  #Add on wd to successfully convert.

                $document.Protect( $ProtectionType, [ref]$false, [ref]$Password, [ref]$false, [ref]$false)
            }
            finally {
                if ((Test-Path variable:document) -and ($document -ne $null) -and (!$LeaveOpen)) {
                    $application = $document.Application
                    try {
                        if ($PSCmdlet.ShouldProcess(
                                "Set the document protect to $ProtectionType on document '$eachPath'")) {
                            $document.Close() > $null
                        }
                        else {
                            # -WhatIf specified 
                            $document.Close([Microsoft.Office.Interop.Word.WdSaveOptions]::wdDoNotSaveChanges) > $null
                        }
                    }
                    finally {
                        $application.Quit()
                    }
                }
            }
        }
    }
}

$resultTypeData = @{
    TypeName                  = "WordDocument.FindReplaceResult"
    DefaultDisplayPropertySet = 'FindResult', 'ReplaceResult', 'BeforeSnippet', 'AfterSnippet'
}
         
Update-TypeData @resultTypeData -Force
$resultTypeData = @{
    TypeName                  = "WordDocument.FindResult"
    DefaultDisplayPropertySet = 'FindResult', 'FindSnippet'
}
Update-TypeData @resultTypeData -Force

#TODO: Change to use parameter separate parameter set for Find.
Function script:Invoke-WordDocumentInternalFindReplace {
    [OutputType('WordDocument.FindReplaceResult')]
    [CmdletBinding(SupportsShouldProcess)] 
    param(
        [Parameter(Mandatory, ValueFromPipeline)]$Document,
        # The Microsoft Word Seach string - see https://support.office.com/en-us/article/Find-and-replace-text-and-other-data-in-a-Word-document-c6728c16-469e-43cd-afe4-7708c6c779b7
        [Parameter(Mandatory)][string[]]$FindValue,
        # Not strongly typed to string to avoid automatic coersion of $null to empty string (Arghhh!)
        [Parameter(ParameterSetName = 'MicrosoftWordReplace')]$ReplaceValue,
        # The regular expression to use to search after the $FindVaue is located
        [Parameter(Mandatory, ParameterSetName = 'RegExReplace')][string[]]$RegExFindValue,
        # The regular expression to replace with after the $FindValue is located
        [Parameter(ParameterSetName = 'RegExReplace')][string[]]$RegExReplaceValue,
        [bool]$MatchCase = $false,
        [bool]$MatchWholeWord = $false,
        [bool]$MatchWildcards = $false,
        [bool]$MatchSoundsLike = $false,
        [bool]$MatchAllWordForms = $false
    )

    [string] $whatIfMessage = $null
    [bool]$isActionReplacing = (($PSCmdlet.ParameterSetName -in 'MicrosoftWordReplace', 'RegExReplace') -and ((('ReplaceValue' -in $PSBoundParameters.Keys) -or ('RegExFindValue' -in $PSBoundParameters.Keys))) )
    $findValues = @($FindValue)
    $searchRegEx = 'RegExFindValue' -in $PSBoundParameters.Keys
    if ($searchRegEx) {
        $regExFindValues = @($RegExFindValue)
        if ($findValues.Length -ne $regExFindValues.Length) {
            throw "The number of items in FindValue is different from the number of items in RegExFindValue"
        }
    }
    
    if ($isActionReplacing) {
        $replaceValues = @($ReplaceValue)
        if ($FindValues.Length -ne $replaceValues.Length) {
            throw "The number of items in FindValue is different from the number of items in ReplaceValue"
        }
        if ($searchRegEx) {
            $regexReplaceValues = @($RegExReplaceValue)
            if ($replaceValues.Length -ne $regexReplaceValues.Length) {
                throw "The number of items in ReplaceValue is different from the number of items in RegExReplaceValue"
            }            
        }
        $whatIfMessage = "Replacing text in $Path"
    }
    else {        
        # $whatIfMessage is not needed for the find case since there is not change.
    }

    # Set the Find not to wrap back to the beginning of the document with wdFindStop
    $wdFindWrap = [Microsoft.Office.Interop.Word.WdFindWrap]::wdFindStop  # Other potential valudes: wdFindContinue, wdFindAsk, wdFindStop

    $forward = $True
    $format = $False

    $selection = $Document.Application.Selection

    for ($count = 0; $count -le $findValues.Length; $count++) {
        
        $eachFindValue = $findValues[$count]
        if ($searchRegEx) {
            $eachRegExFindValue = $regExFindValues[$count]
        }
        $eachReplaceValue = $null
        if ($isActionReplacing) {
            $eachReplaceValue = $replaceValues[$count]
            if ($searchRegEx) {
                $eachRegExReplaceValue = $regExReplaceValues[$count]
            }
            $whatIfMessage += "`n`t$eachFindValue => $eachReplaceValue"
        }

        $selection.SetRange(0, 0)
        Write-Debug -Message "Location $($Document.$BaseFileName): $($selection.Start)-$($selection.End)"
        # TODO: Change to use "Simple" for the display of track changes
        #       so that items that have been modified but changes tracked do not show
        #       up in search.
        while ($selection.Find.Execute($eachFindValue, $MatchCase,
                $MatchWholeWord, $MatchWildcards, $MatchSoundsLike,
                $MatchAllWordForms, $forward, $wdFindWrap, $format,
                $eachReplaceValue, [Microsoft.Office.Interop.Word.wdReplace]::wdReplaceNone)) {

            Write-Debug -Message "Location $($Document.$BaseFileName): $($selection.Start)-$($selection.End)"
            # Retrieve a snippet that contains the found text.
            Function Get-TextSnippet($foundSelection) {
                $start = $foundSelection.Start
                $end = $foundSelection.End
                try {
                    [int]$paragraphStart = $foundSelection.Paragraphs.First.Range.start                                                                                                                                                                                                   
                    [int]$paragraphEnd = $foundSelection.Paragraphs.First.Range.End    
                    $foundSelection.SetRange(
                        [Math]::Max($paragraphStart, $start - 100), 
                        [Math]::Min($paragraphEnd, $end + 100)
                    )
                    $foundSelection.SetRange(
                        $selection.Words.First.Start, 
                        $selection.Words.Last.End
                    )

                    $text = $foundSelection.Text
                    if ($paragraphStart -lt $foundSelection.Start) {
                        $text = "...$text"
                    }
                    if ($paragraphEnd -gt $foundSelection.End) {
                        $text = "$text..."
                    }
                }
                finally {
                    #Reselect the found text
                    $selection.SetRange($start, $end)                    
                }
                return $text
            }

            [string]$findResult = $null;

            if ($searchRegEx) {
                $findResult = $selection.Text
                if ($findResult -match $eachRegExFindValue) {
                    $findResult = $Matches.0
                }
                else {
                    Continue # Skip to the next item in the while loop
                }
            }
            else {
                $findResult = $selection.Text
            }
            [string]$before = Get-TextSnippet $selection
            [string]$after = $null
            if ($isActionReplacing) {
                
                if ($searchRegEx) {
                    if ($matchCase) {
                        $selection.Text = $selection.Text -replace "$eachRegExFindValue", "$eachRegExReplaceValue"
                    }
                    else {
                        $selection.Text = $selection.Text -creplace "$eachRegExFindValue", "$eachRegExReplaceValue"
                    }
                }
                else {
                    if (!$selection.Find.Execute($eachFindValue, $MatchCase,
                            $MatchWholeWord, $MatchWildcards, $MatchSoundsLike,
                            $MatchAllWordForms, $forward, $wdFindWrap, $format,
                            $eachReplaceValue, ([Microsoft.Office.Interop.Word.wdReplace]::wdReplaceOne))) {
                        throw "Search failed unexpectedly - since we already found the text in the previous search and now have it selected."
                    }
                }
                $replaceResult = $selection.Text
                $after = Get-TextSnippet $selection
                if ($PSCmdlet.ShouldProcess("`t`t$before => $After", "`n`t`t$before => $After", "Search/Replace")) {
                    # -Whatif NOT specified so sending the results to the output.
            
                    $result = [pscustomobject]@{
                        BeforeSnippet = $before.Trim(); 
                        AfterSnippet  = $after.Trim(); 
                        FindValue     = $eachFindValue; 
                        ReplaceValue  = $eachReplaceValue;  
                        FindResult    = $findResult;
                        ReplaceResult = $replaceResult;
                        PSTypeName    = "WordDocument.FindReplaceResult";
                        Path          = (Get-Item $Document.FullName)
                    }

                    Write-Output $result
                }
                else {
                    # -WhatIf specified

                    # Undo the replace
                    $selection.Text = $findResult

                    #$whatIfMessage += "`n`t`t$before => $After"

                    <# Possible alternat implementation
                    [int] $maxBeforeWidth = 0
                    [int] $maxAfterWidth = 0
                    [string] $messageLine = $null
                    $changes | ForEach-Object {
                        $maxBeforeWidth = [Math]::Max($maxBeforeWidth, $_.Before.Length)
                        $maxAfterWidth = [Math]::Max($maxAfterWidth, $_.After.Length)
                    }
                    $changes | ForEach-Object {
                        $messageLine += "`t`t{0,-$maxBeforeWidth}`t{1,-$maxAfterWidth}" -f $_.Before,$_.After
                    }
                    $process = $PSCmdlet.ShouldProcess("$messageLine", "$messageLine", "Search/Replace Listing")
                    #>
                }
            }
            else { 
                # Find Only
                $result = [pscustomobject]@{
                    FindSnippet = $before.Trim();
                    FindValue   = $eachFindValue;  
                    FindResult  = $findResult;
                    PSTypeName  = "WordDocument.FindResult";
                    Path        = (Get-Item $Document.FullName)
                }                

                Write-Output $result
                if (Test-Path Variable:PSDebugContext) {
                    # If we are debugging, display the updated text in word and pause
                    pause
                }
            }

            $selection.SetRange($selection.End, $selection.End)                
        }
    }

    #    if($isActionReplacing) {
    #        # Display What If Message
    #        $PSCmdlet.ShouldProcess($whatIfMessage) > $null
    #    }
}

<#
    .SYNOPSIS 
      Search and replace text within a word document.

    .EXAMPLE
    <missing>
     
    Description missing

    .LINK
    https://support.office.com/en-gb/article/Find-and-replace-text-and-other-data-in-a-Word-document-c6728c16-469e-43cd-afe4-7708c6c779b7 

    .NOTES

    The following escape sequences have special meaning.
        ^p - Paragraph Mark
        ^t - Tab Character
        ^? - Any Character
        ^# - Any Digit
        ^$ - Any Letter
        ^^ - Caret Character
        ^u - Section Character
        ^v - Paragraph Character
        ^c - Clipboard Contents
        ^n - Column Break
        ^+ - Em Dash
        ^= - En Dash
        ^e - Endnote Mark
        ^d - Field
        ^& - Find What Text
        ^f - Footnote Mark
        ^g - Graphic
        ^l - Manual Line Break
        ^m - Manual Page Break
        ^~ - Nonbreaking Hyphen
        ^s - Nonbreaking Space
        ^- - Optional Hyphen
        ^b - Section Break
        ^w - White Space
#>
Function Invoke-WordDocumentFindReplace {
    [OutputType('WordDocument.FindReplaceResult')]
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'MicrosoftWordReplace')] 
    param(
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("FullName", "InputObject")]
        [string[]]$Path, #FullName alias added to support pipeline from Get-ChildItem
        # The Microsoft Word Seach string - see https://support.office.com/en-us/article/Find-and-replace-text-and-other-data-in-a-Word-document-c6728c16-469e-43cd-afe4-7708c6c779b7
        [Parameter(Mandatory)][string[]]$FindValue,
        # Not strongly typed to string to avoid automatic coersion of $null to empty string (Arghhh!)
        [Parameter(ParameterSetName = 'MicrosoftWordReplace')]$ReplaceValue,
        # The regular expression to use to search after the $FindVaue is located
        [Parameter(ParameterSetName = 'RegExReplace')][string[]]$RegExFindValue,
        # The regular expression to replace with after the $FindValue is located
        [Parameter(ParameterSetName = 'RegExReplace')][string[]]$RegExReplaceValue,
        [switch]$LeaveOpen,
        [switch]$MatchCase = $false,
        [switch]$MatchWholeWord = $false,
        [switch]$MatchWildcards = $false,
        [switch]$MatchSoundsLike = $false,
        [switch]$MatchAllWordForms = $false
    )
    #TODO: Change to support reusing the same file (such as when searching for different things in the same file) and leaving the file open.

    PROCESS {

        Write-Debug "Starting: Invoke-WordDocumentFindReplace '$Path': $FindValue => $ReplaceValue"
        Write-Progress -Activity "Invoke-WordDocumentFindReplace" -PercentComplete 0
 
        $Path | ForEach-Object {

            Write-Progress -Activity "Invoke-WordDocumentFindReplace" -Status $_
            Write-Progress -Activity "Invoke-WordDocumentFindReplace" -Status $_ -CurrentOperation "$FindValue => $ReplaceValue"
 
            [bool]$fileChanged = $false
            try {
                $document = Open-WordDocument $Path -ReadWrite:(!$WhatIfPreference)
                $document.Application.Visible = $leaveOpen -or $PSCmdlet.MyInvocation.BoundParameters["Debug"]

                if ($PSCmdlet.ParameterSetName -eq 'MicrosoftWordReplace') {
                    $findReplaceResult = script:Invoke-WordDocumentInternalFindReplace -document $document -FindValue $FindValue -ReplaceValue $ReplaceValue `
                        -matchCase $matchCase -matchWholeWord $matchWholeWord -matchWildcards $matchWildcards `
                        -matchSoundsLike $matchSoundsLike -matchAllWordForms $matchAllWordForms
                }
                else {
                    $findReplaceResult = script:Invoke-WordDocumentInternalFindReplace -document $document -FindValue $FindValue `
                        -RegExFindValue $RegExFindValue -RegExReplaceValue $RegExReplaceValue `
                        -matchCase $matchCase -matchWholeWord $matchWholeWord -matchWildcards $matchWildcards `
                        -matchSoundsLike $matchSoundsLike -matchAllWordForms $matchAllWordForms                    
                }

                if (@($findReplaceResult).Count -gt 0) {
                    $fileChanged = $true                    
                    $findReplaceResult | Write-Output
                } 
            }
            finally {
                if ( (Test-Path variable:document) -and ($document -ne $null) -and (!$LeaveOpen) ) {
                    $application = $document.Application
                    try {
                        if ($fileChanged -and $PSCmdlet.ShouldProcess("Save changes to Word Document: $Path")) {
                            $document.Close() > $null
                        }
                        else {
                            # -WhatIf specified 
                            $document.Close([Microsoft.Office.Interop.Word.WdSaveOptions]::wdDoNotSaveChanges)
                        }
                    }
                    finally {
                        $application.Quit()
                    }
                }
            }
        }
        Write-Progress -Activity "Invoke-WordDocumentFindReplace" -Completed
        Write-Debug "Stopping: Invoke-WordDocumentFindReplace '$path': $FindValue => $ReplaceValue"
    }
}



<#
    .SYNOPSIS 
      Displays a list text snippets within the document that contain
      the value searched for.

    .EXAMPLE
    Get-ChildItem C:\data\EssentialCSharp *.docx | Invoke-WordDocumentFind -value "Chapter" | Write-Host
     
    Returns the find value and the text snippet containing the specific word.

    .EXAMPLE
    Invoke-WordDocumentFind Document.docx -value "<Output[ $([char]160)]14.[0-9]{1,2}>" -matchWildcards

    Searches for Output followed by either a space or a no-break space (character code 160) and then 1-2 digits

    .LINK
    https://support.office.com/en-gb/article/Find-and-replace-text-and-other-data-in-a-Word-document-c6728c16-469e-43cd-afe4-7708c6c779b7 

    .NOTES

    The following escape sequences have special meaning.
        ^p - Paragraph Mark
        ^t - Tab Character
        ^? - Any Character
        ^# - Any Digit
        ^$ - Any Letter
        ^^ - Caret Character
        ^u - Section Character
        ^v - Paragraph Character
        ^c - Clipboard Contents
        ^n - Column Break
        ^+ - Em Dash
        ^= - En Dash
        ^e - Endnote Mark
        ^d - Field
        ^& - Find What Text
        ^f - Footnote Mark
        ^g - Graphic
        ^l - Manual Line Break
        ^m - Manual Page Break
        ^~ - Nonbreaking Hyphen
        ^s - Nonbreaking Space
        ^- - Optional Hyphen
        ^b - Section Break
        ^w - White Space
#>
Function Invoke-WordDocumentFind {
    [OutputType('WordDocument.FindResult')]
    [CmdletBinding()] param(
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position)]
        [Alias("FullName", "InputObject")]
        [string[]]$Path, #FullName alias added to support pipeline from Get-ChildItem
        [Parameter(Mandatory)][string]$value,
        [switch]$LeaveOpen,
        [switch]$matchCase = $false,
        [switch]$matchWholeWord = $false,
        [switch]$matchWildcards = $false,
        [switch]$matchSoundsLike = $false,
        [switch]$matchAllWordForms = $false
    )

    PROCESS {

        Write-Progress -Activity "Invoke-WordDocumentFind" -PercentComplete 0
        $Path | ForEach-Object {

            Write-Progress -Activity "Invoke-WordDocumentFind" -Status $_
            Write-Progress -Activity "Invoke-WordDocumentFind" -Status $_ -CurrentOperation "Find: $Value"

            $document = $null
            try {
                $documentPath = $_
                $document = Open-WordDocument $documentPath -ReadWrite:(!$LeaveOpen)
                $document.Application.Visible = $leaveOpen -or $PSCmdlet.MyInvocation.BoundParameters["Debug"]

                <#
                    BLOG-THIS: 
                    We wasnt to set visible to true when debugging or when -Debug specified.
                    Unfortunately, the following doesn't work:
                        $debugging = Get-Member -InputObject $PSCmdlet.MyInvocation.BoundParameters -Name Debug) -and $PSCmdlet.MyInvocation.BoundParameters.Debug.IsPresent) -or (Test-Path variable:PSDebugContext)
                    1. If you place the above in a separate function then BoundParameters doesn't contain a debug item.
                    2. BoundParameters["Debug"] does not appear to be tasked to called functions or even set (even with the CmdletBinding attribute.
                    3. Leveraging Write-Debug "$($debugging = $true)" also fails since the string evaluates before invoking Write-Debug.
                        Assign the value in Write-Debug (possibly with an optional message):
                            Write-Debug "Optional message: $($debugging = $true)"
                    4. You can't provide an explicit debug parameter because "A parameter with the name 'Debug' was defined multiple times for the command."
                    5. You can't check $PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent because if "Debug" isn't present an exception will throw.
                    
                    Solution = Assign $PSCmdlet.MyInvocation.BoundParameters["Debug"] to a boolean.  (Note that $PSCmdlet.MyInvocation.BoundParameters["FiddleSticks"] will resolve to $false.)
                #>
                

                # Use empty string for replace value since we are not replacing with anything.
                $findResults = script:Invoke-WordDocumentInternalFindReplace -document $document -findValue $value `
                    -matchCase $matchCase -matchWholeWord $matchWholeWord -matchWildcards $matchWildcards -matchSoundsLike $matchSoundsLike -matchAllWordForms $matchAllWordForms

                if (@($findResults).Count -gt 0) {
                    #$result = ([pscustomobject]@{Document = Get-Item $documentPath; Snippets = $textSnippets.Before})
                    #$textSnippets | Get-Member
                    $findResults | Write-Output
                }
            }
            finally {
                if ((Test-Path variable:document) -and ($document -ne $null) -and (!$leaveOpen) ) {

                    $application = $document.Application
                    try {
                        #TODO: Add support to close only if the document wasn't open prior to calling this method.
                        $document.Close()
                    }
                    finally {
                        $application.Quit()
                    }
                    
                }
            }
        }
        Write-Progress -Activity "Invoke-WordDocumentFind" -Completed
    }
}

# Original pulled from https://github.com/ForNeVeR/ExtDiff
Function Compare-WordDocument {
    [CmdletBinding()]
    param(
        $BaseFileName,
        $ChangedFileName
    )

    $ErrorActionPreference = 'Stop'

    # Remove the readonly attribute because Word is unable to compare readonly
    # files:
    $baseFile = Get-ChildItem $BaseFileName
    if ($baseFile.IsReadOnly) {
        Throw "Error: $BaseFileName is marked as read-only."
    }

    # Constants
    $wdDoNotSaveChanges = 0
    $wdCompareTargetNew = 2

    $document = Open-WordDocument $baseFile -ReadWrite:$false
    $document.Application.Visible = $true
    $document.Compare($ChangedFileName, [ref]"Comparison", [ref]$wdCompareTargetNew, [ref]$true, [ref]$true)

    $document.Application.ActiveDocument.Saved = 1    

    # Now close the document so only compare results window persists:
    $document.Close([ref]$wdDoNotSaveChanges)
}

Function Script:Get-InternalWordDocumentProperty {
    [CmdletBinding()]
    param(
        $property, # A collection of one or more document properties
        [string]$name
    )
    PROCESS {
        if ($name) {
            # Retrieve the single item requested by name.
            try {
                $propertyItem = [System.__ComObject].Invokemember("Item",
                    [System.Reflection.BindingFlags]::GetProperty, $null, $property, $name)
                Script:Get-InternalWordDocumentProperty $propertyItem
            }
            catch {
                throw "The property, `'$name`', does not exist or was not found'"
            }
        }
        else {
            # Retrieve the names and values for all the properties specified.
            $property | ForEach-Object {
                try {
                    $name = [System.__ComObject].Invokemember("Name",
                        [System.Reflection.BindingFlags]::GetProperty, $null, $_, $null)
                    $value = [System.__ComObject].Invokemember("Value",
                        [System.Reflection.BindingFlags]::GetProperty, $null, $_, $null)
                    [PSCustomObject] @{ Name = $name; Value = $value; Property = $_ }
                }
                catch {
                    Write-Verbose "Value note found for $name"
                }
            }
        }
    }
}

Function Get-WordDocumentProperty {
    [CmdletBinding()]
    param(
        [ValidateScript( { Test-Path $_ })][Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)][string[]]$path,
        $name
    )
    PROCESS {
        [object[]]$properties = $null;
        Get-Item $path | ForEach-Object {
            try {
                $document = Open-WordDocument $_.FullName -ReadWrite:(!$WhatIfPreference)
                $properties = Script:Get-InternalWordDocumentProperty $document.BuiltInDocumentProperties
                $properties += Script:Get-InternalWordDocumentProperty $document.CustomDocumentProperties
                $result = @{ }
                $properties | ForEach-Object {
                    $result."$($_.Name)" = $_.Value
                }
                if ($name) {
                    $result."$name"
                }
                else {
                    Write-Output $result
                }
            }
            finally {
                if ((Test-Path variable:document) -and ($document -ne $null) ) {
                    $application = $document.Application
                    try {
                        #TODO: Add support to close only if the document wasn't open prior to calling this method.
                        $document.Close()
                    }
                    finally {
                        $application.Quit()
                    }
                    
                }
            }
        }
    }
}

Function Set-WordDocumentProperty {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [ValidateScript( { Test-Path $_ })][Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)][string[]]$path,
        [Parameter(Mandatory)]$name,
        [Parameter(Mandatory)]$value,
        [Microsoft.Office.Core.MsoDocProperties]$propertyType = 'msoPropertyTypeString'
    )
    BEGIN {

    }
    
    PROCESS {
        Get-Item $path | ForEach-Object {
            try {
                $eachPath = $_;
                $document = Open-WordDocument $eachPath -ReadWrite
                $property = $null
                $property = Script:Get-InternalWordDocumentProperty $document.BuiltInDocumentProperties $name -ErrorAction Ignore
                if (!$property) {
                    Write-Debug "Unable to find build in property: $name"
                    $property = Script:Get-InternalWordDocumentProperty $document.CustomDocumentProperties $name -ErrorAction Ignore
                }
                if ($property) {
                    Write-Debug "Property was found: $name"
                    [System.__ComObject].InvokeMember( `
                            'Value', [System.Reflection.BindingFlags]::SetProperty, `
                            $null, $property.Property, $value)
                }
                else {
                    Write-Debug "Property not found so adding a new one: $name"
                    [Array]$invokeArgs = $name, $false, $propertyType, $Value
                    [System.__ComObject].InvokeMember( `
                            'Add', [System.Reflection.BindingFlags]::SetProperty, `
                            $null, $document.CustomDocumentProperties, $invokeArgs)
                }    
            }
            finally {
                if ((Test-Path variable:document) -and ($document -ne $null) ) {
                    $application = $document.Application
                    try {
                        if ($PSCmdlet.ShouldProcess("Set property `'$name`' property to `'$value`' on document `'$document`'")) {
                            $document.Close() > $null
                        }
                        else {
                            # -WhatIf specified 
                            $document.Close([Microsoft.Office.Interop.Word.WdSaveOptions]::wdDoNotSaveChanges) > $null
                        }
                    }
                    finally {
                        $application.Quit()
                    }
                }
            }

        }
    }
}

Function Get-WordDocumentTemplate {
    [CmdletBinding()] 
    param(
        [ValidateScript( { Test-Path $_ -PathType Leaf })][Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position)][Alias("FullName", "InputObject")][string[]]$Path
    )

    PROCESS {
        $Path | ForEach-Object {
            try {
                $document = Open-WordDocument $_ -ReadWrite:$false

                Write-Output $document.AttachedTemplate.FullName
            }
            finally {
                if ( (Test-Path variable:document) -and ($document -ne $null) ) {
                    $application = $document.Application
                    try {
                        $document.Close() > $null
                    }
                    finally {
                        $application.Quit()
                    }
                }
            }
        }
    }
}


Function Set-WordDocumentTemplate {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position)]
        [Alias("FullName", "InputObject")]
        [string[]]$Path,
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [Parameter(Mandatory, Position)][string]$TemplatePath,
        [switch]$LeaveOpen
    )

    PROCESS {
        $Path | ForEach-Object {
            try {
                $eachPath = $_
                # TODO: Change to not re-open the document
                if ((Get-WordDocumentTemplate -Path $eachPath).AttachedTemplate.FullName -ne $templatePath) {
                    $document = Open-WordDocument $_ -ReadWrite:(!$WhatIfPreference)
                    $document.Application.Visible = $leaveOpen -or $PSCmdlet.MyInvocation.BoundParameters["Debug"]

                    $template = Open-WordDocument -Path $TemplatePath -ReadWrite:$false -WordApplication $document.Application

                    if ($document.AttachedTemplate) {
                        Write-Verbose "Previous template was '$($document.AttachedTemplate.FullName)'."
                    }
                    $document.AttachedTemplate = $template
                }
            }
            finally {
                if ((Test-Path variable:document) -and ($document -ne $null) -and (!$LeaveOpen)) {
                    $application = $document.Application
                    try {
                        if ($PSCmdlet.ShouldProcess("Set Template on '$eachPath' to '$TemplatePath'")) {
                            $document.Close() > $null
                        }
                        else {
                            # -WhatIf specified 
                            $document.Close([Microsoft.Office.Interop.Word.WdSaveOptions]::wdDoNotSaveChanges) > $null
                        }
                    }
                    finally {
                        $application.Quit()
                    }
                }
            }
        }
    }
}
<#

Enums we may need:


Microsoft.Office.Interop.Word.WdViewType
    wdNormalView A normal view. 
    wdOutlineView An outline view. 
    wdPrintView A print view. 
    wdPrintPreview A print preview view. 
    wdMasterView A master view. 
    wdWebView A Web view. 
    wdReadingView A reading view. 
    wdConflictView 



Microsoft.Office.Interop.Word.WdGoToItem
    wdGoToBookmark A bookmark. 
    wdGoToSection A section. 
    wdGoToPage A page. 
    wdGoToTable A table. 
    wdGoToLine A line. 
    wdGoToFootnote A footnote. 
    wdGoToEndnote An endnote. 
    wdGoToComment A comment. 
    wdGoToField A field. 
    wdGoToGraphic A graphic. 
    wdGoToObject An object. 
    wdGoToEquation An equation. 
    wdGoToHeading A heading. 
    wdGoToPercent A percent. 
    wdGoToSpellingError A spelling error. 
    wdGoToGrammaticalError A grammatical error. 
    wdGoToProofreadingError A proofreading error. 



Microsoft.Office.Interop.Word.WdGoToDirection
    wdGoToFirst The first instance of the specified object. 
    wdGoToLast The last instance of the specified object. 
    wdGoToNext The next instance of the specified object. 
    wdGoToRelative A position relative to the current position. 
    wdGoToPrevious The previous instance of the specified object. 
    wdGoToAbsolute An absolute position. 


Microsoft.Office.Interop.Word.WdUnits
    wdCharacter A character. 
    wdWord A word. 
    wdSentence A sentence. 
    wdParagraph A paragraph. 
    wdLine A line. 
    wdStory A story. 
    wdScreen The screen dimensions. 
    wdSection A section. 
    wdColumn A column. 
    wdRow A row. 
    wdWindow A window. 
    wdCell A cell. 
    wdCharacterFormatting Character formatting. 
    wdParagraphFormatting Paragraph formatting. 
    wdTable A table. 
    wdItem The selected item. 


#>

# TODO
# Blog: https://stackoverflow.com/questions/6403342/how-to-validate-powershell-function-parameters-allowing-empty-strings
# Blog: https://stackoverflow.com/questions/226596/powershell-array-initialization