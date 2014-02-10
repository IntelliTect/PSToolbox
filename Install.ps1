
$outputFile = [IO.Path]::GetTempFileName() + ".zip"
Invoke-WebRequest -Uri "https://www.dropbox.com/s/yw703um9iufg5ll/PSIdeation.4.0.20140113.nupkg?dl=1" -OutFile $outputFile
Add-Type -AssemblyName System.IO.Compression.FileSystem
#[System.IO.Compression.ZipFile]::ExtractToDirectory($outputFile, 
#return $outputFile