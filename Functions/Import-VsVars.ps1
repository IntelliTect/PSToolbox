#TODO: Move into a function file.
If($env:FrameworkDir = "") {
    switch -Wildcard ((Get-Item "env:vs*comntools" | select -last 1).Value) {
        "*10.0" { Import-VisualStudioVars 2008 }
        "*11.0*" { Import-VisualStudioVars 2010 }
        "*12.0*" { Import-VisualStudioVars 2012 }
    }
}
