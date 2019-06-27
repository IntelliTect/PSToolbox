Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common

Import-Module $PSScriptRoot\..\Modules\IntelliTect.MicrosoftWord\IntelliTect.MicrosoftWord.psd1 -Force

Describe "New-WordDocument" {
    It "Create Word Document Leave Open"{
        $path = "$PSScriptRoot\MicrosoftWord.NewFile.docx"
        $newDocument = New-WordDocument $path -LeaveOpen

        Test-Path $path | should be $true
        $newDocument.FullName | Should be $path
        $newDocument.Application.Quit()
        Start-Sleep 1
        Remove-Item $path -Force
    }

    It "Create Word Document With Content"{
        $path = "$PSScriptRoot\MicrosoftWord.NewFile.docx"
        $content = "This is my content"
        New-WordDocument $path -Content $content

        $newDocument = Open-WordDocument $path
        $newDocument.FullName | Should be $path
        $allComparedText = @()
        $newDocument.paragraphs | ForEach-Object {
            $allComparedText += "$($_.Range.Text)"
        }
        $allComparedText[0] | Should Match $content
        $newDocument.Application.Quit()
        Start-Sleep 1
        Remove-Item $path -Force
    }
}

Describe "Compare-WordDocument" {
    It "The comparison word document is returned"{
        $nl = [System.Environment]::NewLine
        $path1 = "$PSScriptRoot\MicrosoftWord.Test1.docx"
        $path2 = "$PSScriptRoot\MicrosoftWord.Test2.docx"
        New-WordDocument $path1 -Content "test$($nl)2$($nl)3$($nl)4"
        New-WordDocument $path2 -Content "test$($nl)1$($nl)Different$($nl)Text$($nl)4"

        $compareDoc = Compare-WordDocument $path1 $path2
        $word = $compareDoc.Application
        $paragraphs = $compareDoc.Paragraphs
        $allComparedText = @()
        $paragraphs | ForEach-Object {
            $allComparedText += "$($_.Range.Text)"
        }
        $expectedLines = @("test*","1*","Different*","Text*","4*")
        for($i = 0; $i -lt $allComparedText.Count; $i++){
            $allComparedText[$i] | Should Match $expectedLines[$i]
        }
        $word.Quit()
        Start-Sleep 1 # to give time for Word to close
        Remove-Item -Path $path1 -Force
        Remove-Item -Path $path2 -Force
    }

    It "The comparison word document is saved"{
        $nl = [System.Environment]::NewLine
        $path1 = "$PSScriptRoot\MicrosoftWord.Test1.docx"
        $path2 = "$PSScriptRoot\MicrosoftWord.Test2.docx"
        $savePath = "$PSScriptRoot\MicrosoftWord.CompareTest.docx"
        New-WordDocument $path1 -Content "test$($nl)2$($nl)3$($nl)4"
        New-WordDocument $path2 -Content "test$($nl)1$($nl)Different$($nl)Text$($nl)4"

        Compare-WordDocument $path1 $path2 $savePath
        $compareDoc = Open-WordDocument $savePath
        $word = $compareDoc.Application
        $paragraphs = $compareDoc.Paragraphs
        $allComparedText = @()
        $paragraphs | ForEach-Object {
            $allComparedText += "$($_.Range.Text)"
        }
        $expectedLines = @("test*","1*","Different*","Text*","4*")
        for($i = 0; $i -lt $allComparedText.Count; $i++){
            $allComparedText[$i] | Should Match $expectedLines[$i]
        }
        $word.Quit()
        Start-Sleep 1 # to give time for Word to close
        Remove-Item -Path $path1 -Force
        Remove-Item -Path $path2 -Force
        Remove-Item -Path $savePath -Force
    }
}

Describe "Open-WordDocument" {
    It "The word document is Opened"{
        $path = "$PSScriptRoot\MicrosoftWord.NewFile.docx"
        $content = "This is my content"
        New-WordDocument $path -Content $content

        $document = Open-WordDocument $path
        $allComparedText = @()
        $document.paragraphs | ForEach-Object {
            $allComparedText += "$($_.Range.Text)"
        }
        $allComparedText[0] | Should Match $content

        $document.Application.Quit()
        Start-Sleep 1
        Remove-Item -Path $path -Force
    }
}

Describe "Open-WordDocument" {
    It "The word document is Opened"{
        $path = "$PSScriptRoot\MicrosoftWord.NewFile.docx"
        $content = "This is my content"
        New-WordDocument $path -Content $content

        $document = Open-WordDocument $path
        $allComparedText = @()
        $document.paragraphs | ForEach-Object {
            $allComparedText += "$($_.Range.Text)"
        }
        $allComparedText[0] | Should Match $content

        $document.Application.Quit()
        Start-Sleep 1
        Remove-Item -Path $path -Force
    }
}

Describe "Get-WordDocumentTrackChanges" {
    It "The word document is not tracking changes"{
        $path = "$PSScriptRoot\MicrosoftWord.NewFile.docx"
        New-WordDocument $path

        $tracksChanges = Get-WordDocumentTrackChanges $path

        $tracksChanges | Should Be $false
        Start-Sleep 1
        Remove-Item -Path $path -Force
    }

    It "The word document is tracking changes"{
        $path = "$PSScriptRoot\MicrosoftWord.NewFile.docx"
        New-WordDocument $path

        Set-WordDocumentTrackChanges -Path $path -Active $true

        $tracksChanges = Get-WordDocumentTrackChanges $path

        $tracksChanges | Should Be $true
        Start-Sleep 1
        Remove-Item -Path $path -Force
    }
}

Describe "Get-WordDocumentTrackChanges" {
    It "The word document starts tracking changes"{
        $path = "$PSScriptRoot\MicrosoftWord.NewFile.docx"
        New-WordDocument $path

        Get-WordDocumentTrackChanges $path | Should Be $false

        Set-WordDocumentTrackChanges -Path $path -Active $true

        Get-WordDocumentTrackChanges $path | Should Be $true

        Start-Sleep 1
        Remove-Item -Path $path -Force
    }
}

Describe "Update-WordDocumentAcceptAllChanges" {
    It "The word document accepts tracked changes"{
        $path = "$PSScriptRoot\MicrosoftWord.TrackFile.docx"
        $content = "this is the initial content."
        New-WordDocument $path -Content $content

        Set-WordDocumentTrackChanges -Path $path -Active $true

        $document = Open-WordDocument -Path $path -ReadWrite
        $word = $document.Application
        $selection = $word.Selection
        $selection.TypeText("Some New Text")
        $selection.TypeParagraph()
        $numberOfRevisions = $document.Revisions.Count
        $document.Close([Microsoft.Office.Interop.Word.WdSaveOptions]::wdSaveChanges)
        $word.Quit()

        $numberOfRevisions | Should Be 1

        Update-WordDocumentAcceptAllChanges -Path $path

        $document = Open-WordDocument -Path $path
        $word = $document.Application
        $newRevisionCount = $document.revisions.Count
        $word.Quit()

        $newRevisionCount | Should Be 0
        Start-Sleep 1
        Remove-Item -Path $path -Force
    }
}

Describe "Get-WordDocumentComment" {
    It "The word document's comments are returned"{
        $path = "$PSScriptRoot\MicrosoftWord.CommentFile.docx"
        $content = "this is the initial content."
        $document = New-WordDocument $path -Content $content -LeaveOpen
        $initialNumComments = $document.Comments.Count
        $initialNumComments | Should Be 0

        $word = $document.Application
        $section = $document.sections.item(1)
        $range = $section.Range
        $document.Comments.Add($range,"This is a fantastic comment!")
        $document.Save()
        $document.Close()
        $word.Quit()

        $comment = Get-WordDocumentComment $path
        $comment.Range.Text | Should Be "This is a fantastic comment!"
        $word = $comment.Application
        $word.Quit()

        Start-Sleep 1
        Remove-Item -Path $path -Force
    }
}

