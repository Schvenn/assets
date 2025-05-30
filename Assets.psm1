function assets {# A suite of options to view or edit commands and scripts for the current profile.
param ([string]$resourcetype, [string]$action, [string]$resource, [switch]$help)
$script:powershell = Split-Path $profile

if ($help) {function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
""; Write-Host -f yellow ("-" * 100); $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -f yellow; Write-Host -f yellow ("-" * 100)
if ($lines.Count -gt 1) {$lines[1] | Out-String | Out-Host -Paging}; Write-Host -f yellow ("-" * 100)}
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -f cyan; scripthelp $sections[0].Groups[1].Value; ""; return}
$selection = $null
do {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help Sections:`n" -f cyan; for ($i = 0; $i -lt $sections.Count; $i++) {
"{0}: {1}" -f ($i + 1), $sections[$i].Groups[1].Value}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
$input = Read-Host "`nEnter a section number to view"
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

# Display the contents of a function with colored comments.
function details {param($command)
# Use last command if none was provided.
if (-not $command) {$history = Get-History -ErrorAction SilentlyContinue
if ($history -and $history.Count -gt 0 -and $history[-1].CommandLine) {$command = $history[-1].CommandLine} else {""; return}}
# Otherwise, resolve the command.
$cmd = Get-Command $command -ErrorAction SilentlyContinue
if (-not $cmd) {Write-Host -f green "$command is not a valid command, function, alias or cmdlet."; return}
$source = $cmd.Source; $callcommand = $command
if ($cmd.CommandType -eq 'Alias') {$callcommand = $cmd.displayname; $parent = Get-Command $cmd.Definition; $definition = $parent.Definition -split "`n"; $definition += "sal -Name $command -Value $($cmd.Definition)"}
else {$definition = $cmd.Definition -split "`n"}
""; Write-Host -f cyan "Command: " -n; Write-Host -f yellow $callcommand; Write-Host -f cyan "Source: " -n; Write-Host -f yellow $source; Write-Host -f yellow ("-"*100)
foreach ($line in $definition) {if ($line -match "^(.*?)(#.*)#?$") {Write-Host $matches[1] -f white -n; Write-Host $matches[2] -f yellow}
elseif ($line -match "(?i)^\s*(sal|set-alias)\b") {Write-Host $line -f cyan}
else {Write-Host $line -f white}}
Write-Host -f yellow ("-"*100); ""; return}

# Set Notepad++ to the default editor, if available and edit files passed to it.
function edit ($file){$script:edit = "notepad"; $npp = "Notepad++\notepad++.exe"; $paths = @("$env:ProgramFiles", "$env:ProgramFiles(x86)")
foreach ($path in $paths) {$test = Join-Path $path $npp; if (Test-Path $test) {$script:edit = $test; break}}
& $script:edit $file}

# Error checking.
if ($resourcetype -notmatch "(?i)^(cmd|script)$" -and $action -notmatch "(?i)^(view|edit)$") {Write-Host -f cyan "`nUsage: assets `"cmd/script`" `"view/edit`" `"resource`"`n"; return}

# Script path completion
if ($resourcetype -eq "script" -and $resource.length -ge 1 -and -not (Test-Path $resource -PathType Leaf)) {$priority = @('.psm1', '.ps1', '.psd1'); $candidates = Get-ChildItem -Path $powershell -Recurse -Include *.psm1, *.ps1, *.psd1 | Where-Object { $_.BaseName -match "(?i)^$resource$" }
if ($candidates) {$resource = $candidates | Sort-Object @{Expression = { $priority.IndexOf($_.Extension.ToLower()) }; Ascending = $true} | Select-Object -First 1; $resource = (Resolve-Path $resource).Path}
else {Write-Host -f yellow "`nUnable to locate a script with the name $resource`n"; return}}

# View scripts, whether specified or blank.
if ($resourcetype -eq "script" -and $action -eq "view") {if (-not $resource) {Write-Host -f yellow "`nAvailable Scripts:`n"; 
$ScriptFiles = Get-ChildItem -Path $powershell -Recurse | Where-Object {$_.Name -match '(?i)\.ps[dm]?1$'}
$ScriptFiles | ForEach-Object {$index = [Array]::IndexOf($ScriptFiles, $_) + 1; Write-Host -f cyan "$index. " -n
if ($_.FullName.Substring($powershell.Length + 1) -match "(?i)\.psm1$") {Write-Host ($_.FullName.Substring($powershell.Length + 1)) -f darkcyan}
elseif ($_.FullName.Substring($powershell.Length + 1) -match "(?i)\.psd1$") {Write-Host ($_.FullName.Substring($powershell.Length + 1)) -f darkgray}
else {Write-Host ($_.FullName.Substring($powershell.Length + 1)) -f white}}
""; Write-Host -f white "Select a script to " -n; [console]::foregroundcolor = "green"; $selection = Read-Host "VIEW"; [console]::foregroundcolor = "gray"
if ($selection -notmatch "^\d+$") {""; return}
if ([int]$selection -gt 0 -and [int]$selection -le $ScriptFiles.Count) {$resource = $ScriptFiles[$selection - 1].FullName}
else {""; return}}

# Build content, starting with the PSD1 file if it exists, then proceeding to the script content.
$configuration = [System.IO.Path]::Combine((Split-Path $resource), ([System.IO.Path]::GetFileNameWithoutExtension($resource)))+".psd1"
if ((Test-Path $configuration -ErrorAction SilentlyContinue) -and -not ([System.IO.Path]::GetExtension($resource) -match "\.psd1")) {$separator = "-" * 100; $configcontent = Get-Content $configuration; $resourcecontent = Get-Content $resource; $content = @(); $content += $configcontent; $content += $separator; $content += $resourcecontent}
else {$content = Get-Content $resource}

""; Write-Host -f green $resource; Write-Host -f yellow ("-"*100); $lineCount = 0; $pauseAfter = 30
foreach ($line in $content) {if ($line -match '^<?#') {Write-Host $line -f yellow}
elseif ($line -match '(?i)^function\s') {Write-Host $line -f cyan}
elseif ($line -match '(?i)^sal\s') {Write-Host $line -f green}
else {Write-Host $line -f white}
$lineCount++
if ($lineCount -ge $pauseAfter) {""; Write-Host -f green ("-"*100); [console]::foregroundcolor = "green"; $lineCount = 0; $input = Read-Host "Press [Enter] to continue, A to view the whole file, E to Edit or Q to quit"
switch -Regex ($input) {'^(?i)q$' {[console]::foregroundcolor = "gray"; ""; return}; '^(?i)a$' {$pauseAfter = 10000}; '^(?i)e$' {[console]::foregroundcolor = "gray"; ""; edit $resource; return}}}}
[console]::foregroundcolor = "gray"; Write-Host -f yellow ("-"*100); ""; return}

# View commands menu.
if ($resourcetype -eq "cmd" -and $action -eq "view" -and $resource.length -le 1) {Write-Host -f yellow "`nAvailable Functions`n"; $functions = Get-Command -CommandType Function; $filtered = $functions | Where-Object {$_.ScriptBlock.File -like "*Users*"}; $filtered | ForEach-Object {Write-Host -f cyan "$($filtered.IndexOf($_) + 1). " -n; Write-Host -f white "$($_.Name)"}; Write-Host -f white "`nSelect a function to " -n; [console]::foregroundcolor = "green"; $selection = Read-Host "VIEW"; [console]::foregroundcolor = "gray"
while ($selection -ne "Q") {if ($selection -match '^\d{1,2}$') {$index = [int]$selection; if ($index -gt 0 -and $index -le $filtered.Count) {$function = $filtered[$index - 1].Name; details $function; ""; return}
else {""; return}} else {""; return}};"" ; return}

# View specified command.
if ($resourcetype -eq "cmd" -and $action -eq "view" -and (Get-Command $resource -ErrorAction SilentlyContinue)) {""; details $resource; return}

# Edit commands menu.
if ($resourcetype -eq "cmd" -and $action -eq "edit" -and $resource.length -le 1) {Write-Host -f yellow "`nAvailable Functions`n"; $functions = Get-Command -CommandType Function; $filtered = $functions | Where-Object {$_.ScriptBlock.File -like "*Users*"}; $filtered | ForEach-Object {$i = $filtered.IndexOf($_) + 1; $mod = if ($_.Module) {$_.Module.Name.ToUpper()} else {"PROFILE"}; Write-Host -f cyan "$i. " -n; Write-Host -f darkcyan "$mod\" -n; Write-Host -f white "$($_.Name)"}; Write-Host -f white "`nSelect a function parent file to " -n; [console]::foregroundcolor = "red"; $selection = Read-Host "EDIT"; [console]::foregroundcolor = "gray"
while ($selection -ne "Q") {if ($selection -match '^\d{1,2}$') {$index = [int]$selection; if ($index -gt 0 -and $index -le $filtered.Count) {$filePath = $filtered[$index - 1].ScriptBlock.File; edit $filePath; ""; return}
else {""; return}} else {""; return}}}

# Edit specified command.
if ($resourcetype -eq "cmd" -and $action -eq "edit" -and (Get-Command $resource -ErrorAction SilentlyContinue)) {$command = Get-Command $resource -CommandType Function -ErrorAction SilentlyContinue; $filepath = $command.ScriptBlock.File; if ($filepath.length -ge 1) {edit $filepath}; return}

# Edit scripts menu.
if ($resourcetype -eq "script" -and $action -eq "edit" -and (($resource.length -le 1) -or (-not (Test-Path $resource -PathType Leaf)))) {Write-Host -f yellow "`nAvailable Scripts:`n"; $ScriptFiles = Get-ChildItem -Path $powershell -Recurse | Where-Object {$_.Name -match '(?i)\.ps[dm]?1$'}
$ScriptFiles | ForEach-Object {$index = [Array]::IndexOf($ScriptFiles, $_) + 1; Write-Host -f cyan "$index. " -n
if ($($_.FullName.Substring($powershell.Length + 1)) -match "(?i)\.psm1$") {Write-Host $($_.FullName.Substring($powershell.Length + 1)) -f darkcyan}
elseif ($($_.FullName.Substring($powershell.Length + 1)) -match "(?i)\.psd1$") {Write-Host $($_.FullName.Substring($powershell.Length + 1)) -f darkgray}
else {Write-Host $($_.FullName.Substring($powershell.Length + 1)) -f white}}; ""
Write-Host -f white "Select a script to " -n; [console]::foregroundcolor = "red"; $selection = Read-Host "EDIT"; [console]::foregroundcolor = "gray"
if ([int]$selection -gt 0 -and [int]$selection -le $ScriptFiles.Count) {$selectedFile = $ScriptFiles[$selection - 1]; edit $selectedFile.FullName}
else {[console]::foregroundcolor = "gray"; ""; return}}

# Edit specified script.
if ($resourcetype -eq "script" -and $action -eq "edit" -and (Test-Path $resource -PathType Leaf)) {edit $resource; return}}

# Edit custom commands.
function editcmd ($resource) {assets cmd edit $resource}
sal -name ec -value editcmd -scope global

# Create/edit a new or existing PowerShell module file.
function editmodule ($script) {if ($script.length -le 1) {assets script edit; return}
$path="$powershell\modules\$script\$script.psm1"
if (Test-Path $path) {edit "$path"}
if (!(Test-Path $path)) {Write-Host "`nPath '$path' does not exist." -f yellow; $response=Read-Host "Create it now? (Y/N)";
if ($response -match '^[Yy]') {New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($path)) -Force | Out-Null;
New-Item -ItemType File -Path $path -Force | Out-Null}; ""}}
sal -Name em -Value editmodule

# Edit this Powershell profile.
function editprofile{& edit $profile}
sal -Name ep -Value editprofile

# Edit custom scripts.
function editscript ($resource) {assets script edit $resource}
sal -name es -value editscript -scope global

# View custom command details.
function seecmd ($resource) {assets "cmd" "view" "$resource"}
sal -name see -value seecmd -scope global

# View custom script details.
function seescript ($resource) {assets script view $resource}
sal -name ss -value seescript -scope global

Export-ModuleMember -Function assets, editcmd, editmodule, editprofile, editscript, seecmd, seescript
Export-ModuleMember -Alias ec, em, ep, es, see, ss

<#
## Assets

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
			Press [Enter] to continue, A to view the whole file, E to Edit or Q to quit

To edit commands or scripts use:
	assets cmd edit "resource"
		• If no "resource" is specified, the function will display a menu of available functions from which to choose.
	assets script edit "resource"
		• If no "resource" is specified, the function will display a menu of available scripts from which to choose.
## Other Commands

Macros and aliases have been created for common functions within the Assets framework, in order to expedite common tasks:

	• editprofile/ep - Edit this user's Powershell profile.

Other commands, with an optional "resource" parameter:

• Usage: <command> "resource"
	• editcmd/ec 	 - Edit the script that hosts the command.
	• editmodule/em  - Edit the module specified, or ask to create it, if it doesn't already exist.
	• editscript/es	 - Edit a specific script.
	• seecmd/see	 - View a specific command.
	• seescript/ss	 - View a specific script.

If no resource is provided at the command line, a menu will be presented for each of the above options.
In the case of editmodule, this will consist of PSM1 and PSD1 files, but the editscript menu will also include PS1 files.
##>
