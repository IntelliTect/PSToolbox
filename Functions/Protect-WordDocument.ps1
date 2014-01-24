
Function Protect-WordDocument(
    $path,
    $protectionType,
    $password
    ) {
        $wordApplication = new-object -ComObject Word.Application

        $protectionType = [Microsoft.Office.Interop.Word.WdProtectionType]$protectionType

        $doc = $wordApplication.Documents.Open($path)

        $doc.Protect( $protectionType, [ref]$false, [ref]$password, [ref]$false, [ref]$false)

        $doc.Close()

        $wordApplication.Quit()
}