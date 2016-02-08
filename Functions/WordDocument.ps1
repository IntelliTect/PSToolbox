
add-type -AssemblyName "Microsoft.Office.Interop.Word" 

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
        [ValidateScript({[System.Runtime.InteropServices.Marshal]::IsComObject( $_)})][Parameter(Mandatory,ValueFromPipeline)][System.IDisposable] $inputObject,
        [Parameter(Mandatory,ValueFromPipeline)][ScriptBlock] $scriptBlock
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
            } else {
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
        [ValidateScript({Test-Path $_ -PathType Leaf})][Parameter(Mandatory, ValueFromPipeLine, ValueFromPipelineByPropertyName, Position)][Alias("FullName","InputObject")][string[]]$wordDocumentPath,
        [switch]$ReadOnly = $true
    )
    PROCESS {
        $WordDocumentPath | %{
            $eachDocumentPath = (Resolve-Path $_).Path
            [bool]$readOnly = [bool]$ReadOnly.IsPresent  # TODO: Blog: switch and bool are not the same
            [bool]$ConfirmConversions = $false  # Optional Object. True to display the Convert File dialog box if the file isn't in Microsoft Word format.

            $wordApplication = Open-MicrosoftWord
            $document = $wordApplication.Documents.Open($eachDocumentPath, $confirmConversions, $ReadOnly) #For additional parameters see https://msdn.microsoft.com/en-us/library/microsoft.office.interop.word.documents.open.aspx
            if($ReadOnly) {
                # Used to avoid the error, "This method or property is not available because this command is not available for reading."
                # when using Find.Execute on the document
                # see http://blogs.msmvps.com/wordmeister/2013/02/22/word2013bug-not-available-for-reading/
                $document.ActiveWindow.View = [Microsoft.Office.Interop.Word.WdViewType]"wdPrintView"
            }

            #Add Text Property to Comment where the comment text is the Range.Text property on a comment.
            $comments = $document.Comments | %{ Add-Member -InputObject $_ -MemberType ScriptProperty -Name Text -Value { $this.Range.Text} -PassThru } 
            Add-Member -InputObject $document -MemberType ScriptProperty -Name CommentsEx -Value { $comments } -Force

            return $document
        }
    }
}

Function Get-WordDocumentComment {
    [CmdletBinding()] param(
        [ValidateScript({Test-Path $_ -PathType Leaf})][Parameter(Mandatory, ValueFromPipelineByPropertyName, Position)][Alias("FullName","InputObject")]
        [string[]]$wordDocumentPath,  #FullName alias added to support pipeline from Get-ChildItem

        [switch]$ReadOnly = $true
    )
 
    PROCESS {
        [bool]$readOnly = [bool]$ReadOnly.IsPresent  # TODO: Blog: switch and bool are not the same

        $wordDocumentPath | %{
            $document = Open-WordDocument -wordDocumentPath $_ -ReadOnly:$ReadOnly
            $comments = $document.Comments | %{ Add-Member -InputObject $_ -MemberType ScriptProperty -Name Text -Value { $this.Range.Text} -PassThru } 
            return $comments
        }
    }

}

Function Update-WordDocumentAcceptAllChanges {
    [CmdletBinding()] param(
        [ValidateScript({Test-Path $_ -PathType Leaf})][Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position)][Alias("FullName","InputObject")][string[]]$WordDocumentPath
    )
    PROCESS {
        $WordDocumentPath | %{
            try {
                
                $eachDocumentPath = (Resolve-Path $_).Path
                $document = Open-WordDocument $eachDocumentPath -ReadOnly:$false

                if([bool]$PSCmdlet.MyInvocation.BoundParameters["Debug"]) {
                    $document.Application.Visible = $true # Yes, I realize this is dumb (why not just assign it) but it doesn't seem to work (perhaps a COM conversion problem?)
                }
                $document.AcceptAllRevisions()

            }
            finally {
                if((Test-Path variable:document) -and ($document -ne $null)) {
                    $application = $document.Application
                    try {
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

Function Protect-WordDocument {
    [CmdletBinding()] param(
        [ValidateScript({Test-Path $_ -PathType Leaf})][Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position)][Alias("FullName","InputObject")][string[]]$wordDocumentPath,
        [ValidateSet("NoProtection","AllowOnlyRevisions","AllowOnlyComments","AllowOnlyFormFields","AllowOnlyReading")] $protectionType, #TODO: Restrict to possible values for Microsoft.Office.Interop.Word.WdProtectionType with Intellisense
        $password
    )
    PROCESS {
        $WordDocumentPath | %{
            try {
                $document = Open-WordDocument $_

                $protectionType = [Microsoft.Office.Interop.Word.WdProtectionType] "wd$protectionType"  #Add on wd to successfully convert.

                $document.Protect( $protectionType, [ref]$false, [ref]$password, [ref]$false, [ref]$false)
            }
            finally {
                if($document -ne $null) {
                    $application = $document.Application
                    try {
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

#TODO: Change to use parameter separate parameter set for Find.
Function script:Invoke-WordDocumentFind {
    [CmdletBinding()] param(
        [Parameter(Mandatory, ValueFromPipeline)]$document,
        [Parameter(Mandatory)][string[]]$findValue,
        [string]$replaceValue,
        [bool]$matchCase = $true,
        [bool]$matchWholeWord = $false,
        [bool]$matchWildcards = $false,
        [bool]$matchSoundsLike = $false,
        [bool]$matchAllWordForms = $false,
        [ValidateSet("ReplaceNone", "ReplaceOne", "ReplaceAll")][string]$replace = "ReplaceAll"
    )

    $wdReplace = [Microsoft.Office.Interop.Word.wdReplace] "wd$replace"

    if( ($wdReplace -ne [Microsoft.Office.Interop.Word.wdReplace]::wdReplaceNone) -and (!$replaceValue)) {
        throw "`$newValue is a required parameter when `$replace is not set to 'ReplaceNone'"
    }

    # Set the Find not to wrap back to the beginning of the document with wdFindStop
    $wdFindWrap =  [Microsoft.Office.Interop.Word.WdFindWrap] "wdFindStop"  # Other potential valudes: wdFindContinue, wdFindAsk, wdFindStop

    $selection = $document.Application.Selection

    $Forward = $True
    $Format = $False

    foreach($eachFindValue in $findValue) {
        while($selection.Find.Execute($eachFindValue,$matchCase,
                $matchWholeWord,$matchWildcards,$matchSoundsLike,
                $matchAllWordForms,$Forward,$wdFindWrap,$Format,
                $replaceValue,$wdReplace)) {

            $wdLine = [Microsoft.Office.Interop.Word.WdUnits]"wdLine"

            #$selection.Expand($wdLine) | Out-Null
            $start = $selection.Start
            $end = $selection.End

            [int]$paragraphStart = $selection.Paragraphs.First.Range.start                                                                                                                                                                                                   
            [int]$paragraphEnd = $selection.Paragraphs.First.Range.End    
            $selection.SetRange(
                [Math]::Max($paragraphStart, $start-100), 
                [Math]::Min($paragraphEnd, $end+100)
                )
            $selection.SetRange(
                $selection.Words.First.Start, 
                $selection.Words.Last.End
                )

            $text = $selection.Text
            if($paragraphStart -lt $selection.Start) {
                $text = "...$text"
            }
            if($paragraphEnd -gt $selection.End) {
                $text = "$text..."
            }

            Write-Output $text

            $selection.SetRange($selection.End, $selection.End);
        }
    }
        
}

#TODO: Change to use parameter separate parameter set for Find.
Function Replace-WordDocumentWord {
    [CmdletBinding()] param(
        [ValidateScript({Test-Path $_ -PathType Leaf})][Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)][Alias("FullName","InputObject")][string[]]$wordDocumentPath, #FullName alias added to support pipeline from Get-ChildItem
        [Parameter(Mandatory, Position=0)][string]$findValue,
        [Parameter(Mandatory)][string]$replaceValue,
        [switch]$leaveOpen,
        [switch]$matchCase = $true,
        [switch]$matchWholeWord = $false,
        [switch]$matchWildcards = $false,
        [switch]$matchSoundsLike = $false,
        [switch]$matchAllWordForms = $false,
        [ValidateSet("ReplaceOne", "ReplaceAll")][string]$replace = "ReplaceAll"
    )

PROCESS {
        Write-Progress -Activity "Find-WordDocumentWord" -PercentComplete 0
        $wordDocumentPath | %{

            Write-Progress -Activity "Find-WordDocumentWord" -Status $_
            $result = $null
            $document = $null
            $wdReplace = [Microsoft.Office.Interop.Word.wdReplace] "wd$replace"
 
            try
            {
                $document = Open-WordDocument $wordDocumentPath -ReadOnly:$false
                $visible = $leaveOpen
                $document.Application.Visible = $visible -or $PSCmdlet.MyInvocation.BoundParameters["Debug"]


                $textSnippets = script:Invoke-WordDocumentFind -document $document -findValue $findValue -replaceValue $replaceValue -replace ReplaceAll `
                    -matchCase $matchCase -matchWholeWord $matchWholeWord -matchWildcards $matchWildcards -matchSoundsLike $matchSoundsLike -matchAllWordForms $matchAllWordForms

                if(@($textSnippets).Count -gt 0) {
                    $result = ([pscustomobject]@{Chapter = Get-Item $documentPath; Snippets = $textSnippets.Trim()})
                    Write-Output $result
                }
            }
            finally {
                if(($document -ne $null) -and !$leaveOpen -and $result) {
                    $application = $document.Application
                    try {
                        $document.Close()
                    }
                    finally {
                        $application.Quit()
                    }
                }
            }
        }
        Write-Progress -Activity "Find-WordDocumentWord" -Completed
    }
}

<#
    .SYNOPSIS 
      Displays a list text snippets within the document that contain
      the value searched for.

    .EXAMPLE
    Get-ChildItem C:\data\EssentialCSharp *.docx | Find-WordDocumentWord -value "Chapter" | Write-Host
     
    Returns text snippets containing the specific word.  The Write-Host invocation at the end causes
    the output to wrap.  Note that "Chapter" must be exiplicitly identified as the -value parameter (TODO remove the restriction)
#>
Function Find-WordDocumentWord {
    [CmdletBinding()] param(
        [ValidateScript({Test-Path $_ -PathType Leaf})][Parameter(Mandatory, ValueFromPipelineByPropertyName,Position)][Alias("FullName","InputObject")][string[]]$wordDocumentPath,  #FullName alias added to support pipeline from Get-ChildItem
        [Parameter(Mandatory, Position=0)][string[]]$value,
        [switch]$leaveOpen,
        [switch]$matchCase = $true,
        [switch]$matchWholeWord = $false,
        [switch]$matchWildcards = $false,
        [switch]$matchSoundsLike = $false,
        [switch]$matchAllWordForms = $false
    )

PROCESS {

        Write-Progress -Activity "Find-WordDocumentWord" -PercentComplete 0
        $wordDocumentPath | %{

            Write-Progress -Activity "Find-WordDocumentWord" -Status $_
            $result = $null
            $document = $null
            try {
                $documentPath = $_
                $document = Open-WordDocument $documentPath -ReadOnly:$leaveOpen
                $visible = $leaveOpen
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
                $document.Application.Visible = $visible -or $PSCmdlet.MyInvocation.BoundParameters["Debug"]
                

                # Use empty string for replace value since we are not replacing with anything.
                $textSnippets = script:Invoke-WordDocumentFind -document $document -findValue $value -replaceValue "" -replace ReplaceNone `
                    -matchCase $matchCase -matchWholeWord $matchWholeWord -matchWildcards $matchWildcards -matchSoundsLike $matchSoundsLike -matchAllWordForms $matchAllWordForms

                
                if(@($textSnippets).Count -gt 0) {
                    $result = ([pscustomobject]@{Chapter = Get-Item $documentPath; Snippets = $textSnippets.Trim()})
                    Write-Output $result
                }
            }
            finally {
                if($document -ne $null) {
                    if( !$result -or ($result -and !$leaveOpen) ) {
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
        Write-Progress -Activity "Find-WordDocumentWord" -Completed
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