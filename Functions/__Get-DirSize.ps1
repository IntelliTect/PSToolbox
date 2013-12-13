function Get-DirSize
{
  param ($dir)
  $bytes = 0
  $count = 0

  Get-Childitem $dir | Foreach-Object {
    if ($_ -is [System.IO.FileInfo])
    {
      $bytes += $_.Length
      $count++
    }
  }

  Write-Host "`n    " -NoNewline

  if ($bytes -ge 1KB -and $bytes -lt 1MB)
  {
    Write-Host ("" + [Math]::Round(($bytes / 1KB), 2) + " KB") -ForegroundColor "White" -NoNewLine
  }
  elseif ($bytes -ge 1MB -and $bytes -lt 1GB)
  {
    Write-Host ("" + [Math]::Round(($bytes / 1MB), 2) + " MB") -ForegroundColor "White" -NoNewLine
  }
  elseif ($bytes -ge 1GB)
  {
    Write-Host ("" + [Math]::Round(($bytes / 1GB), 2) + " GB") -ForegroundColor "White" -NoNewLine
  }
  else
  {
    Write-Host ("" + $bytes + " bytes") -ForegroundColor "White" -NoNewLine
  }
  Write-Host " in " -NoNewline
  Write-Host $count -ForegroundColor "White" -NoNewline
  Write-Host " files"

}

