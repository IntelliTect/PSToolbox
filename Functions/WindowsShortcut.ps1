Function New-WindowsShortcut([String] $Path, [string] $TargetPath, [String] $Arguments = "") {
    $WshShell = New-Object -ComObject Wscript.Shell
    if([io.path]::GetExtension($Path) -ne ".lnk") {
        $Path = "$Path" + ".lnk"
    }
    $shortcut = $WshShell.CreateShortcut($Path);
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.Save()
}