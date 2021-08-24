Dropbox Provider for PowerShell
=========
###### by IntelliTect

This PowerShell module permits you to access Dropbox as if it were a local drive.

### Usage:
1. Run `Import-Module .\IntelliTect.PSDropbin.psd1`.
2. After importing the module, run `New-DropboxDrive Dbx` (you can name it however you like)
   *  The first time that you mount a given drive, your browser will open and prompt for access.
3. After mounting the drive, simply `cd Dbx:` and start using it!
4. To unmount a drive, run `Remove-PSDrive -Name Dbx`.
5. To remove access tokens, run `Remove-DropboxCredential -Name Dbx`.
5. If you would like for your Dropbox drive to always be available, consider adding these commands to your [PowerShell user profile](https://technet.microsoft.com/en-us/library/bb613488%28v=vs.85%29.aspx).


### To Do:

* ~~Make credential setup easy.~~
* ~~Improve `Copy-Item` proxy functions.~~
	* ~~Implement multi-file transfers.~~
	* ~~Permit a destination *directory* to be specified rather than an entire filepath.~~
* ~~Implement `Move-Item` — will require proxy functions.~~
* ~~Revise setup. Make it simpler.~~
* ~~Create a [Chocolatey](https://chocolatey.org) or [PsGet](http://psget.net) package or [PowerShellGallery](https://www.powershellgallery.com/)~~.

### Future Goal:
Use this Dropbox implementation to extract a more generic codebase. Due to the structure of the abstract `NavigationCmdletProvider` class, this may be fairly difficult. However, this could allow for the creation of additional cloud drive providers for services such as **Google Drive**, **OneDrive** and **Box**.


### Dev Setup
- Install Dropbox on your machine and log in.

Unit Tests require a user token for a drive called "DropboxTestDrive", So before running them do the following to get a user token stored so that the tests can run:
1. Run `Import-Module .\IntelliTect.PSDropbin.psd1` from the repo root.
2. After importing the module, run `New-DropboxDrive DropboxTestDrive`
   * your browser will open and prompt for access.
   * paste the token back into the prompt and press the enter key
   * The token will now be available when you go to run tests.

When done with dev work you can remove the access token and unmount the test drive: 
- To remove access tokens, run `Remove-DropboxCredential -Name DropboxTestDrive`.
- To unmount a drive, run `Remove-PSDrive -Name DropboxTestDrive`.
