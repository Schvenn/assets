# Assets
Powershell module to manage custom scripts and functions with several options to view and edit.

This function allows you to manage custom user content in your PowerShell environment with a myriad of options:

To see the basic syntax type the following:

	assets
 
		• Usage: assets "cmd/script" "view/edit" "resource"

To view commands or scripts on screen in a contextualized format use:

	assets cmd view "resource"
 
		• If no "resource" is specified, the function will display a menu of available functions from which to choose.
  
	assets script view "resource"
 
		• If no "resource" is specified, the function will display a menu of available scripts from which to choose.
  
		• While viewing long scripts, the output will be broken into pages, with options including:
  
			Press [Enter] to continue, A to view the whole file, to Edit or Q to quit

To edit commands or scripts use:

	assets cmd edit "resource"
 
		• If no "resource" is specified, the function will display a menu of available functions from which to choose.
  
	assets script edit "resource"
 
		• If no "resource" is specified, the function will display a menu of available scripts from which to choose.
