##Deploying to PowerShellGallery

###Steps to Deploy
- Sign in to powershellgallery.com using the IntelliTect account and get the API key.
- Open a PowerShell window as administrator.
- Navigate to the root folder of the PowerShellGallery project.
- .\publish.ps1
- Param: Filter - limit the modules that are evaluated for publishing
  - Ex. .\publish.ps1 -Filter ‘*Azure*’
- Param: WhatIf - run the checks to see what will be published, but don’t do the publish
- Script will evaluate all sub-folders under Modules that have a name like ‘IntelliTect.*’
- If the module passes all checks then it will be ready to publish.
- When prompted, enter the API key


###Module Requirements
- Must have Description and Author properties in the manifest.
- Must contain exported commands.
- Current version must not exist on powershellgallery.com.
