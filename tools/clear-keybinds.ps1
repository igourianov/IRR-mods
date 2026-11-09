<#
.SYNOPSIS
	List or remove key mappings saved in the game's Enhanced Input user settings.

.DESCRIPTION
	Edits EnhancedInputUserSettings.sav directly. The game must not be running.
	Without -Unused or -Name it lists the saved mappings and changes nothing.
	A mod mapping (name starting with Likhos) is unused when no likhos-*\Scripts\*.lua in this repo mentions its name.
	The whole file is parsed before anything is written, and the write is refused if any part of it does not match the known layout.
	The original is copied next to it as <file>.<yyyy-MM-dd.HHmmss>.bak.
	A removed mapping falls back to its default key, or disappears if nothing registers it any more.
	Layout: docs/solutions/clear-keybinds.md.

.EXAMPLE
	.\tools\clear-keybinds.ps1                          # list saved mappings, marking unused mod mappings
	.\tools\clear-keybinds.ps1 -Unused                  # remove unused mod mappings
	.\tools\clear-keybinds.ps1 -Name LikhosQuickUse     # remove mappings by name, wildcards allowed
#>
[CmdletBinding()]
param(
	[switch] $Unused,
	[string[]] $Name,
	[string] $Path = (Join-Path $env:LOCALAPPDATA 'Test_C\Saved\SaveGames\EnhancedInputUserSettings.sav')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$bytes = [IO.File]::ReadAllBytes($Path)
$pos = 0

# ---------------------------------------------------------------- reader
function Fail([string] $What) {
	Write-Error ('{0} at offset 0x{1:X}: {2}. Nothing was written.' -f $Path, $script:pos, $What)
}

function Skip([int] $Count) {
	if ($script:pos + $Count -gt $bytes.Length) { Fail 'unexpected end of file' }
	$script:pos += $Count
}

function Read-Int32 {
	$at = $script:pos
	Skip 4
	[BitConverter]::ToInt32($bytes, $at)
}

function Read-Byte {
	$at = $script:pos
	Skip 1
	$bytes[$at]
}

# FString: int32 length with terminator, negative for UTF-16.
function Read-FString {
	$len = Read-Int32
	$enc = if ($len -lt 0) { [Text.Encoding]::Unicode } else { [Text.Encoding]::Latin1 }
	$size = if ($len -lt 0) { -2 * $len } else { $len }
	$at = $script:pos
	Skip $size
	if ($size -eq 0) { return '' }
	$s = $enc.GetString($bytes, $at, $size)
	if ($s[-1] -ne [char]0) { Fail 'string without terminator' }
	$s.Substring(0, $s.Length - 1)
}

# Complete property type name (UE 5.4+): name, int32 parameter count, parameters.
function Skip-TypeName {
	[void](Read-FString)
	$params = Read-Int32
	for ($i = 0; $i -lt $params; $i++) { Skip-TypeName }
}

# Tagged properties up to None: name, type name, int32 size, uint8 flags, value.
# Every observed tag has flags 0. Other flags add tag data this reader does not handle.
function Skip-Properties {
	while (($prop = Read-FString) -ne 'None') {
		Skip-TypeName
		$size = Read-Int32
		if ((Read-Byte) -ne 0) { Fail "property $prop has tag flags" }
		Skip $size
	}
}

# Serialization control byte, tagged properties, int32 trailer.
function Skip-Object {
	if ((Read-Byte) -ne 0) { Fail 'serialization control byte is not 0' }
	Skip-Properties
	if ((Read-Int32) -ne 0) { Fail 'object trailer is not 0' }
}

# ---------------------------------------------------------------- parse
Skip 4
if ([Text.Encoding]::ASCII.GetString($bytes, 0, 4) -ne 'GVAS') { Fail 'not a GVAS save' }
if ((Read-Int32) -ne 3) { Fail 'save game version is not 3' }
Skip 18 # UE4 and UE5 package versions, engine major, minor, patch, changelist
[void](Read-FString) # engine branch
if ((Read-Int32) -ne 3) { Fail 'custom version format is not 3' }
Skip (20 * (Read-Int32)) # custom versions: GUID, int32
if ((Read-FString) -ne '/Script/EnhancedInput.EnhancedInputUserSettings') { Fail 'not an Enhanced Input user settings save' }
Skip-Object
if ((Read-Int32) -ne 2) { Fail 'key profile block does not start with 2' }

$entries = [Collections.Generic.List[object]]::new()
$profiles = Read-Int32
for ($p = 0; $p -lt $profiles; $p++) {
	[void](Read-FString) # profile class
	[void](Read-FString) # profile object name
	$countAt = $pos
	$count = Read-Int32
	for ($i = 0; $i -lt $count; $i++) {
		$start = $pos
		$mapping = Read-FString
		$key = Read-FString
		[void](Read-FString) # hardware device input class
		[void](Read-FString) # hardware device identifier
		Skip 6
		$entries.Add([pscustomobject]@{ CountAt = $countAt; Start = $start; End = $pos; Name = $mapping; Key = $key; Unused = $false; Remove = $false })
	}
	[void](Read-FString) # profile identifier tag
	Skip-Object
	if ((Read-FString) -ne 'ObjectEnd') { Fail 'profile does not end with ObjectEnd' }
}
if ($pos -ne $bytes.Length) { Fail 'data after the last profile' }

# ---------------------------------------------------------------- select
$lua = (Get-ChildItem (Join-Path $root 'likhos-*\Scripts\*.lua') | Get-Content -Raw) -join "`n"
foreach ($e in $entries) {
	$e.Unused = $e.Name.StartsWith('Likhos') -and $lua -notmatch "\b$([regex]::Escape($e.Name))\b"
	$e.Remove = ($Unused -and $e.Unused) -or @($Name).Where({ $e.Name -like $_ }).Count -gt 0
}

$width = ($entries.Name | Measure-Object -Property Length -Maximum).Maximum
foreach ($e in $entries) {
	$mark = if ($e.Remove) { 'remove' } elseif ($e.Unused) { 'unused' } else { '' }
	Write-Host ('{0}  {1,-14}  {2}' -f $e.Name.PadRight($width), $e.Key, $mark)
}

if (-not $Unused -and -not $Name) { return }
$drop = @($entries | Where-Object Remove)
if (-not $drop) {
	Write-Host 'Nothing to remove.'
	return
}

# ---------------------------------------------------------------- write
$cfgPath = Join-Path $root 'build.config.json'
if (Test-Path $cfgPath) {
	$gameDir = (Get-Content $cfgPath -Raw | ConvertFrom-Json).game.dir
	if (Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($gameDir, 'OrdinalIgnoreCase') }) {
		Write-Error 'The game is running. Close it first: it holds the settings in memory and saves over the file.'
	}
}

foreach ($g in $entries | Group-Object CountAt) {
	$kept = @($g.Group | Where-Object { -not $_.Remove }).Count
	[BitConverter]::GetBytes([int32] $kept).CopyTo($bytes, [int] $g.Name)
}
$out = [IO.MemoryStream]::new()
$at = 0
foreach ($e in $drop) {
	$out.Write($bytes, $at, $e.Start - $at)
	$at = $e.End
}
$out.Write($bytes, $at, $bytes.Length - $at)

$backup = "$Path.$(Get-Date -Format 'yyyy-MM-dd.HHmmss').bak"
Copy-Item $Path $backup
[IO.File]::WriteAllBytes($Path, $out.ToArray())
Write-Host "Removed $($drop.Count) mapping(s). Backup: $backup"
