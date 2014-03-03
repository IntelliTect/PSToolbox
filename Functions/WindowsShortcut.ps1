Function New-WindowsShortcut([String] $Path, [string] $TargetPath, [String] $Arguments = "") {
    $WshShell = New-Object -ComObject Wscript.Shell
    $shortcut = $WshShell.CreateShortcut($TargetPath);
    if([io.path]::GetExtension($Path) -ne ".lnk") {
        $Path = "$Path" + ".lnk"
    }
    $shortcut.TargetPath = $Path
    $shortcut.Arguments = $Arguments
    $shortcut.Save()
}