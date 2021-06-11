Install-PackageProvider -Name NuGet -Force
Install-Module -Name Pester -Force

$testResults = Invoke-Pester -Script .\Modules.Tests\  -OutputFile .\Test-Pester.XML -OutputFormat NUnitXML -PassThru
if($testResults.FailedCount -ne 0) { 
     Write-Error "$($testResults.FailedCount) test failed."
     exit $LASTEXITCODE 
}