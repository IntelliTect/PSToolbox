Function Get-ToDoItems () {
    dir *.ps1 -Recurse | get-content | ?{ $_ -match "TODO:" } | %{$_.Trim() }
}