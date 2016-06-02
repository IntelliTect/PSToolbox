
##Contributing to PSToolbox

- First, make sure you have the required tools installed. If you have Windows 10, you already have them. Otherwise, see [here](https://www.powershellgallery.com/GettingStarted?section=Get%20Started) for instructions.

### General development procedures
- To import your module while developing, run `Import-Module .\IntelliTect.MyModule.psd1`
  - **This is essential** before you start running commands from your module. If a previous version of it is already installed from PowerShell Gallery, PowerShell will automatically load that old version of the module when you try to run a command that it provides unless you have explcitly imported your local development copy of the module.
- Make sure that you haven't already imported a previous version of the module that you're working on.
  - Run `Remove-Module IntelliTect.MyModule` to remove any versions of it from your current session.

### Creating a new Module
- Create a new directory in `Modules` with the name of your module. This name must be prefixed with `IntelliTect.`
- Create a PowerShell Module file (`.psm1`) that contains all of your module's functions.
  - This should be named the same as your module's directory, although this is not a requirement.
- Create a manifest file (`.psd1`) in this directory.
  - The manifest **must** have the same name as your module's directory.
  - You can do this easily by running `New-ModuleManifest IntelliTect.MyModule.psd1`
- Update the `CompanyName` and `Copyright` fields in the new manifest to include IntelliTect.
- Update the `Author` field to include yourself and anyone else who contributed.
- Uncomment and update the `Description` field in the manifest. This should include concise information on what your module does and how to use it.
- Uncomment and set the `RootModule` field to point to your primary `.psm1` file. This file should be in the same directory as the manifest.
  - If your module is written in C#, point this at the primary DLL instead. See IntelliTect.PSDropbin for an example.
- Update `FunctionsToExport`, `CmdletsToExport`, and any other relevant export fields to include the commands that your module provides.
- Add a new `.ps1` file to `Modules.Tests` that contains the tests for your module.
  - These tests use [Pester](https://github.com/pester/Pester). Look at the other tests in this directory for examples.

### Contributing to an existing module
- Make all your changes to the code as desired. Then,
- Increment the module's version in its manifest file (`.psd1`)
- Ensure that the various `Export` fields in the manifest reflect any new or removed functions in the module.
- If you're able to, push your changes to Github and then follow the deployment instructions below.
  - Otherwise, submit a pull request on Github with your changes. Whoever merges the pull request is responsible for publishing to PowerShell Gallery.


##Deploying to PowerShell Gallery

###Steps to Deploy
- Sign in to powershellgallery.com using the IntelliTect account, and then get the API key from the user profile page.
- Open a PowerShell window as administrator.
- Navigate to the root folder of the PowerShellGallery project.
- Run `.\publish.ps1`
  - Param: `Filter` - limit the modules that are evaluated for publishing
    - Ex. `.\publish.ps1 -Filter ‘*Azure*’`
  - Script will evaluate all sub-folders under Modules that have a name like ‘IntelliTect.*’
  - If the module passes all checks then it will be ready to publish.
  - When prompted, enter the API key
    - The script will look for a credential named `psgallery` in the Windows Credential manager. Add the API key as the password using IntelliTect.CredentialManager if desired.


###Module Requirements
- Must have Description and Author properties in the manifest.
- Must contain exported commands.
- Current version must not exist on powershellgallery.com.
