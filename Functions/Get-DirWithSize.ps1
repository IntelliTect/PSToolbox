function Get-DirWithSize
{
  param ($dir)
  Get-Childitem $dir
  Get-DirSize $dir
}