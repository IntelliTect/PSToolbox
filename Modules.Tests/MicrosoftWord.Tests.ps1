Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common -Force
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.File -Force

Import-Module $PSScriptRoot\..\Modules\IntelliTect.MicrosoftWord\IntelliTect.MicrosoftWord.psd1 -Force


Function Get-TempWordDocument {
    [CmdletBinding()]
    param (
        $WordApplication
    )

    # Instantiate a FileInfo object that has a Dispose method.
    [System.IO.FileInfo]$file = Get-TempFile # -Name "$([System.IO.Path]::GetRandomFileName()).docx"
    #Delete the actual file since New-WordDocument will create one.
    Remove-Item $file

    $tempDocument = New-WordDocument -Path $file -WordApplication $WordApplication

    # TODO: Figure out a way to combine ScriptBlocgs without making them strings.
    #$tempDocument | Add-Member -MemberType ScriptMethod -Name 'InternalWordDocumentDispose' -Value $tempDocument.Dispose.Script
    #$tempDocument | Add-Member -MemberType ScriptMethod -Name 'InternalFileDispose' -Value $file.Dispose.Script
    # [ScriptBlock]$wordDocumentDisposeScript = [ScriptBlock]::Create( $tempDocument.Dispose.Script )
    # [ScriptBlock]$tempFileDisposeScript = [ScriptBlock]::Create( $file.Dispose.Script )
    # $tempDocument | Add-DisposeScript -DisposeScript {
    #     $this.InternalWordDocumentDispose()
    #     $this.InternalFileDispose()
    # } -Force

    [ScriptBlock]$disposeScript = [ScriptBlock]::Create(
        "
        `$path = `$this.FullName
        $($tempDocument.Dispose.Script)
        $($file.Dispose.Script -replace '\$this\.FullName','$path' )
        "
    )

    $tempDocument | Add-DisposeScript -DisposeScript $disposeScript -Force

    return $tempDocument
}

Describe "Get-TempWordDocument" {
    It "Verify the temporary word document has a dispose method that closes the document and deletes the file."{
        $wordApplicationInstances = @(Get-Process -Name 'WinWord' -ErrorAction Ignore).Length

        $tempDocument = Get-TempWordDocument
        $path = $tempDocument
        Register-AutoDispose -InputObject $tempDocument -ScriptBlock {<# No op #> }
        Test-Path $path | Should Be $false

        # Verify the Microsoft word application is closed.
        @(Get-Process -Name 'WinWord' -ErrorAction Ignore).Length | Should Be $wordApplicationInstances
    }
}

Describe "New-WordDocument" {
    It "Create a new word document and verify both document and Microsoft Word Application (WinWord) are closed."{
        $file = Get-TempFile
        Remove-Item $file

        $wordApplicationInstances = @(Get-Process -Name 'WinWord' -ErrorAction Ignore).Length

        Register-AutoDispose -InputObject $file -ScriptBlock {
            $newDocument = New-WordDocument -Path $file.fullName
            Register-AutoDispose -InputObject $newDocument -ScriptBlock {
                Test-Path $file.FullName | should be $true
                $newDocument.FullName | Should be $file.fullName
            } | Should Be $null
        } | Should Be $null

        # Verify the Microsoft word application is closed.
        @(Get-Process -Name 'WinWord' -ErrorAction Ignore).Length | Should Be $wordApplicationInstances

        # Verify the document has been deleted (and therefore is no longer open by Microsoft word.)
        Test-Path $file.FullName | Should Be $false
    }
}

Describe "Compare-WordDocument" {
    It "The comparison word document is returned"{

        Register-AutoDispose -InputObject ($wordApplication = Open-MicrosoftWord) {
            Function New-DocmentWithContent {
                [OutputType([System.IO.FileInfo])]
                [CmdletBinding(SupportsShouldProcess)]
                param(
                    [string]$Content
                )
                [System.IO.FileInfo]$file = Get-TempFile
                Remove-Item -Path $file.FullName  # Now that we have a document (that supports dispose) let's remove the document
                                            # so that New-WordDocument can create a word document.
                $tempDocument = New-WordDocument -Path $file.FullName -WordApplication $WordApplication
                Register-AutoDispose -InputObject $tempDocument {
                    $tempDocument.Application.Selection.TypeText($Content)
                    $tempDocument.Save()
                }

                Write-Debug $file.GetType()
                return $file
            }

            [System.IO.FileInfo]$file1 = New-DocmentWithContent "test`n2`n3`n4"
            [System.IO.FileInfo]$file2 = New-DocmentWithContent "test`n1`nDifferent`nText`n4"

            $file1,$file2 |  Register-AutoDispose -ScriptBlock `
            {

                Register-AutoDispose -InputObject  ($compareDoc = Compare-WordDocument $file1.FullName $file2.FullName) {
                    $paragraphs = $compareDoc.Paragraphs
                    $allComparedText = @()
                    $paragraphs | ForEach-Object {
                        $allComparedText += "$($_.Range.Text)"
                    }
                    $expectedLines = @("test*","1*","Different*","Text*","4*")
                    for($i = 0; $i -lt $allComparedText.Count; $i++){
                        $allComparedText[$i] | Should Match $expectedLines[$i]
                    }
                }
            }
        }

    # It "The comparison word document is saved"{
    #     $nl = [System.Environment]::NewLine
    #     $path1 = [System.IO.FileInfo]"$PSScriptRoot\MicrosoftWord.Test1.docx"
    #     $path2 = [System.IO.FileInfo]"$PSScriptRoot\MicrosoftWord.Test2.docx"
    #     $savePath = [System.IO.FileInfo]"$PSScriptRoot\MicrosoftWord.CompareTest.docx"

    #     Add-DisposeScript -InputObject $path1 -DisposeScript $(Script:GetFileDispose($path1.fullName))
    #     Add-DisposeScript -InputObject $path2 -DisposeScript $(Script:GetFileDispose($path2.fullName))
    #     Add-DisposeScript -InputObject $savePath -DisposeScript $(Script:GetFileDispose($savePath.fullName))

    #     Register-AutoDispose -InputObject $path1 -ScriptBlock {
    #         Register-AutoDispose -InputObject $path2 -ScriptBlock {
    #             Register-AutoDispose -InputObject $savePath -ScriptBlock {

    #                 New-WordDocument $path1.fullName -Content "test$($nl)2$($nl)3$($nl)4"
    #                 New-WordDocument $path2.fullName -Content "test$($nl)1$($nl)Different$($nl)Text$($nl)4"

    #                 Compare-WordDocument $path1.fullName $path2.fullName $savePath.fullName
    #                 $compareDoc = Open-WordDocument $savePath.fullName
    #                 $word = $compareDoc.Application
    #                 $paragraphs = $compareDoc.Paragraphs
    #                 $allComparedText = @()
    #                 $paragraphs | ForEach-Object {
    #                     $allComparedText += "$($_.Range.Text)"
    #                 }
    #                 $expectedLines = @("test*","1*","Different*","Text*","4*")
    #                 for($i = 0; $i -lt $allComparedText.Count; $i++){
    #                     $allComparedText[$i] | Should Match $expectedLines[$i]
    #                 }
    #                 $word.Quit()
    #             }
    #         }
    #     }
    }
}

Describe "Get-WordDocumentTrackChanges" {
    It "The word document is not tracking changes"{
        $path = [System.IO.FileInfo]"$PSScriptRoot\MicrosoftWord.NewFile.docx"

        Add-DisposeScript -InputObject $path -DisposeScript $(Script:GetFileDispose($path.fullName))

        Register-AutoDispose -InputObject $path -ScriptBlock {
            New-WordDocument $path.fullName
            $tracksChanges = Get-WordDocumentTrackChanges $path.fullName
            $tracksChanges | Should Be $false
        }
    }

    It "The word document is tracking changes"{
        $path = [System.IO.FileInfo]"$PSScriptRoot\MicrosoftWord.NewFile.docx"

        Add-DisposeScript -InputObject $path -DisposeScript $(Script:GetFileDispose($path.fullName))

        Register-AutoDispose -InputObject $path -ScriptBlock {
            New-WordDocument $path.fullName
            Set-WordDocumentTrackChanges -Path $path.fullName -Active $true
            $tracksChanges = Get-WordDocumentTrackChanges $path.fullName
            $tracksChanges | Should Be $true
        }
    }
}

Describe "Set-WordDocumentTrackChanges" {
    It "The word document starts tracking changes"{
        $path = [System.IO.FileInfo]"$PSScriptRoot\MicrosoftWord.NewFile.docx"

        Add-DisposeScript -InputObject $path -DisposeScript $(Script:GetFileDispose($path.FullName))

        Register-AutoDispose -InputObject $path -ScriptBlock {
            New-WordDocument $path.fullName
            Get-WordDocumentTrackChanges $path.fullName | Should Be $false
            Set-WordDocumentTrackChanges -Path $path.fullName -Active $true
            Get-WordDocumentTrackChanges $path.fullName | Should Be $true
        }
    }
}

Describe "Update-WordDocumentAcceptAllChanges" {
    It "The word document accepts tracked changes"{
        $path = [System.IO.FileInfo]"$PSScriptRoot\MicrosoftWord.TrackFile.docx"
        $content = "this is the initial content."

        Add-DisposeScript -InputObject $path -DisposeScript $(Script:GetFileDispose($path.fullName))

        Register-AutoDispose -InputObject $path -ScriptBlock {
            New-WordDocument $path.fullName -Content $content

            Set-WordDocumentTrackChanges -Path $path.fullName -Active $true

            $document = Open-WordDocument -Path $path.fullName -ReadWrite
            $word = $document.Application
            $selection = $word.Selection
            $selection.TypeText("Some New Text")
            $selection.TypeParagraph()
            $numberOfRevisions = $document.Revisions.Count
            $document.Close([Microsoft.Office.Interop.Word.WdSaveOptions]::wdSaveChanges)
            $word.Quit()

            $numberOfRevisions | Should Be 1

            Update-WordDocumentAcceptAllChanges -Path $path.fullName

            $document = Open-WordDocument -Path $path.fullName
            $word = $document.Application
            $newRevisionCount = $document.revisions.Count
            $word.Quit()

            $newRevisionCount | Should Be 0
        }
    }
}

Describe "Get-WordDocumentComment" {
    It "The word document's comments are returned"{
        $path = "$PSScriptRoot\MicrosoftWord.CommentFile.docx"
        $content = "this is the initial content."

        Add-DisposeScript -InputObject $path -DisposeScript $(Script:GetFileDispose($path.fullName))

        Register-AutoDispose -InputObject $path -ScriptBlock {
            $document = New-WordDocument $path.fullName -Content $content -LeaveOpen
            $initialNumComments = $document.Comments.Count
            $initialNumComments | Should Be 0

            $word = $document.Application
            $section = $document.sections.item(1)
            $range = $section.Range
            $document.Comments.Add($range,"This is a fantastic comment!")
            $document.Save()
            $document.Close()
            $word.Quit()

            $comment = Get-WordDocumentComment $path.fullName
            $comment.Range.Text | Should Be "This is a fantastic comment!"
            $word = $comment.Application
            $word.Quit()
        }
    }
}

Describe "Invoke-WordDocumentFindReplace" {
    It "The word document's text is replaced"{
        $path = "$PSScriptRoot\MicrosoftWord.FindAndReplace.docx"
        $content = "This is some data: 123`nThis is text: some text`nThis is nothing:"

        
        Add-DisposeScript -InputObject $path -DisposeScript $(Script:GetFileDispose($path.fullName))

        Register-AutoDispose -InputObject $path -ScriptBlock {
            New-WordDocument -Path $path.fullName -Content $content

            Invoke-WordDocumentFindReplace -Path $path.fullName -FindValue 'This' -ReplaceValue 'That'   #######################This wont replace the first line unless changed

            $document = Open-WordDocument -Path $path.fullName
            $word = $document.Application
            $selection = $word.Selection

            $selection.SetRange($document.Words.First.Start, $document.Words.Last.End)
            $text = $selection.Text
            $word.Quit()
        }
    }
}

Describe "Invoke-WordDocumentFind" {
    It "The word document's found text is returned"{
        $path = "$PSScriptRoot\MicrosoftWord.Find.docx"
        $content = "This is some data: 123`nThis is text: some text`nThis is nothing:"

        Add-DisposeScript -InputObject $path -DisposeScript $(Script:GetFileDispose($path.fullName))

        Register-AutoDispose -InputObject $path -ScriptBlock {
            New-WordDocument -Path $path.fullName -Content $content
            $found = Invoke-WordDocumentFind -Path $path.fullName -value 'This'
            $found.Length | Should Be 3
            $found[0].FindSnippet | Should Be "This is some data: 123"
            $found[1].FindSnippet | Should Be "This is text: some text"
        }
    }
}

Describe "Get-WordDocumentProperty" {
    It "The word document's number of words property is returned"{
        $path = "$PSScriptRoot\MicrosoftWord.GetProperty.docx"
        $content = "This is a word doc`nhow many words`nare in here?"

        Add-DisposeScript -InputObject $path -DisposeScript $(Script:GetFileDispose($path.fullName))

        Register-AutoDispose -InputObject $path -ScriptBlock {
            New-WordDocument -Path $path.fullName -Content $content
            $numWords = Get-WordDocumentProperty -Path $path.fullName -name "Number of words"
            $numWords | Should Be 11
        }
    }

    It "The word document's number of lines property is returned"{
        $path = "$PSScriptRoot\MicrosoftWord.GetProperty.docx"
        $content = "This is`n a word doc`nhow many`n characters`nare in here?"

        Add-DisposeScript -InputObject $path -DisposeScript $(Script:GetFileDispose($path.fullName))

        Register-AutoDispose -InputObject $path -ScriptBlock {
            New-WordDocument -Path $path.fullName -Content $content
            $numWords = Get-WordDocumentProperty -Path $path.fullName -name "Number of lines"
            $numWords | Should Be 5
        }
    }
}

# need to figure out why Microsoft.Office.Core.MsoDocProperties reference cannot be found on all machines
# Describe "Set-WordDocumentProperty"{
#     It "The Author gets set"{
#         $path = "$PSScriptRoot\MicrosoftWord.SetProperty.docx"
#         $content = "This is to test the Set-WordDocumentProperty method"
#         New-WordDocument -Path $path -Content $content

#         Set-WordDocumentProperty -Path $path -name "Author" -value "Inigo Montoya"

#         $author = Get-WordDocumentProperty -Path $path -name "Author"
#         $author | Should Be "Inigo Montoya" 
#         Start-Sleep 1
#         Remove-Item -Path $path -Force
#     }
# }

Describe "Get-WordDocumentTemplate"{
    It "The word document template is returned"{
        $path = "$PSScriptRoot\MicrosoftWord.GetTemplate.docx"
        $content = "This is to test the Get-WordDocumentTemplate method"

        Add-DisposeScript -InputObject $path -DisposeScript $(Script:GetFileDispose($path.fullName))

        Register-AutoDispose -InputObject $path -ScriptBlock {
            New-WordDocument -Path $path.fullName -Content $content

            $out = Get-WordDocumentTemplate -Path $path.fullName
            $file =  [System.IO.FileInfo] $out

            $file.Name | Should Be "normal.dotm"
        }
    }
}


