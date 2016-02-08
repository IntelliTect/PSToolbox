If(!(Test-Path variable:\psise)) { Return; }

#See http://rnicholson.net/powershell-ise-formating-the-document/
Function Format-Document
{
    Param([int]$space=4)
    $tab = " " * $space
    $numtab = 0
       
    $text = $psISE.CurrentFile.editor.Text
    foreach ($l in $text -split [environment]::newline)
    {
        $line = $l.Trim()
        if ($line.StartsWith("}") -or $line.EndsWith("}"))
        {
            $numtab -= 1
        }
        $tab = " " * (($space) * $numtab)
        if($line.StartsWith(".") -or $line.StartsWith("< #") -or $line.StartsWith("#>"))
        {
            $tab = $tab.Substring(0, $tab.Length - 1)
        }
        $newText += "{0}{1}" -f (($tab) + $line),[environment]::newline
        if ($line.StartsWith("{") -or $line.EndsWith("{"))
        {
            $numtab += 1
        }
        if ($numtab -lt 0)
        {
            $numtab = 0
        }
    }
    $psISE.CurrentFile.Editor.Clear()
    $psISE.CurrentFile.Editor.InsertText($newText)
}