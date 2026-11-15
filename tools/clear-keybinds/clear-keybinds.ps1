<#
.SYNOPSIS
	List or remove key mappings saved in the game's Enhanced Input user settings.

.DESCRIPTION
	Edits EnhancedInputUserSettings.sav directly. The game must not be running.
	Without -Unused, -Reset or -Unbind it lists the saved mappings and changes nothing.
	A mod mapping (name starting with Likhos) is unused when no .lua file under likhos-*\Scripts in this repo mentions its name.
	The whole file is parsed before anything is written, and the write is refused if any part of it does not match the known layout.
	The original is copied next to it as <file>.<yyyy-MM-dd.HHmmss>.bak.
	The save holds only mappings changed from the game's defaults. The listing adds the rest, marked default, read from the game's mapping context asset (cached in tools\clear-keybinds\cache).
	-Unbind saves an exact mapping name, saved or default, with the key None, replacing any saved entry. Use it to clear a default key such as a mouse button.
	A removed mapping falls back to its default key, or disappears if nothing registers it any more.
	Layout: docs/solutions/clear-keybinds.md.

.EXAMPLE
	.\tools\clear-keybinds\clear-keybinds.ps1                          # list saved mappings, marking unused mod mappings
	.\tools\clear-keybinds\clear-keybinds.ps1 -Unused                  # remove unused mod mappings
	.\tools\clear-keybinds\clear-keybinds.ps1 -Reset LikhosQuickUse    # delete saved mappings by name, restoring defaults, wildcards allowed
	.\tools\clear-keybinds\clear-keybinds.ps1 -Unbind IA_ToggleAttachmentMenu   # clear the key of a mapping, including a default one
#>
[CmdletBinding()]
param(
	[switch] $Unused,
	[string[]] $Reset,
	[string[]] $Unbind,
	[string] $Path = (Join-Path $env:LOCALAPPDATA 'Test_C\Saved\SaveGames\EnhancedInputUserSettings.sav')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot)
# .NET resolves relative paths against the process directory, not the PowerShell location.
$Path = (Resolve-Path $Path).ProviderPath
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
$entriesEnd = @{} # profile entry count offset to the offset just after its last entry
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
	$entriesEnd[$countAt] = $pos
	[void](Read-FString) # profile identifier tag
	Skip-Object
	if ((Read-FString) -ne 'ObjectEnd') { Fail 'profile does not end with ObjectEnd' }
}
if ($pos -ne $bytes.Length) { Fail 'data after the last profile' }

# ---------------------------------------------------------------- defaults
# The save holds only mappings changed from the game's defaults, so the defaults come from the game's own mapping context asset.
# Row name: the mapping's PlayerMappableKeySettings name, else its action name. Cached in tools\clear-keybinds\cache\defaults.json, rebuilt when a game pak or the usmap changes.
function Get-Defaults {
	$cfgPath = Join-Path $root 'tools\build\build.config.json'
	$repak = Join-Path $root 'tools\repak\repak.exe'
	$uassetGui = Join-Path $root 'tools\UAssetGUI\UAssetGUI.exe'
	if (-not (Test-Path $cfgPath) -or -not (Test-Path $repak) -or -not (Test-Path $uassetGui)) {
		Write-Warning 'Default keys not listed: tools\build\build.config.json, repak or UAssetGUI is missing.'
		return @()
	}
	$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
	$module = $cfg.game.module
	$paksDir = Join-Path $cfg.game.dir "$module\Content\Paks"
	$ue4ssDir = Split-Path (Join-Path $cfg.game.dir $cfg.ue4ss.modsDir)
	$usmap = Get-ChildItem $ue4ssDir -Filter *.usmap -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
	if (-not $usmap) {
		Write-Warning "Default keys not listed: no usmap in $ue4ssDir."
		return @()
	}

	$cacheDir = Join-Path $PSScriptRoot 'cache'
	$cachePath = Join-Path $cacheDir 'defaults.json'
	$stamp = (@(Get-ChildItem $paksDir -Filter *.pak -File | Sort-Object Name | ForEach-Object { "$($_.Name) $($_.Length) $($_.LastWriteTimeUtc.Ticks)" }) + "$($usmap.Name) $($usmap.Length)") -join "`n"
	if (Test-Path $cachePath) {
		$cached = Get-Content $cachePath -Raw | ConvertFrom-Json
		if ($cached.stamp -eq $stamp) { return @($cached.defaults) }
	}

	Write-Host 'Reading default keys from the game paks...'
	$asset = "$module/Content/Blueprints/InputSystem/IM_PlayerEnhancedInputMapping.uasset"
	$raw = Join-Path $cacheDir 'raw'
	if (Test-Path $raw) { Remove-Item $raw -Recurse -Force }
	New-Item -ItemType Directory -Force $raw | Out-Null
	foreach ($pak in Get-ChildItem $paksDir -Filter *.pak -File | Sort-Object Name) {
		if (@(& $repak list $pak.FullName) -contains $asset) {
			& $repak unpack -q -f -i $asset -i ($asset -replace '\.uasset$', '.uexp') -o $raw $pak.FullName
			break
		}
	}
	$uasset = Join-Path $raw $asset
	if (-not (Test-Path $uasset)) { Fail "$asset not found in the game paks" }

	# UAssetGUI reads a usmap only from its own mappings folder, by name.
	$mappingsDir = Join-Path $env:LOCALAPPDATA 'UAssetGUI\Mappings'
	New-Item -ItemType Directory -Force $mappingsDir | Out-Null
	Copy-Item $usmap.FullName (Join-Path $mappingsDir "$module-clear-keybinds.usmap") -Force
	$jsonPath = Join-Path $raw 'imc.json'
	$arguments = @('tojson', $uasset, $jsonPath, 'VER_UE5_6', "$module-clear-keybinds")
	# A GUI executable: the call operator wouldn't wait for it.
	Start-Process $uassetGui -ArgumentList ($arguments | ForEach-Object { "`"$_`"" }) -NoNewWindow -Wait
	if (-not (Test-Path $jsonPath)) { Fail 'UAssetGUI wrote no JSON for the mapping context' }

	$j = Get-Content $jsonPath -Raw | ConvertFrom-Json
	$mappings = @($j.Exports[0].Data | Where-Object Name -eq 'Mappings')
	if (-not $mappings.Count) { Fail 'mapping context has no Mappings property' }
	$defaults = foreach ($m in $mappings[0].Value) {
		$action = ($m.Value | Where-Object Name -eq 'Action').Value
		$settings = ($m.Value | Where-Object Name -eq 'PlayerMappableKeySettings').Value
		$settingsName = if ($settings -gt 0) { ($j.Exports[$settings - 1].Data | Where-Object Name -eq 'Name').Value }
		[pscustomobject]@{
			Name = if ($settingsName) { $settingsName } else { $j.Imports[-1 - $action].ObjectName }
			Key = ($m.Value | Where-Object Name -eq 'Key').Value[0].Value
		}
	}
	Remove-Item $raw -Recurse -Force
	@{ stamp = $stamp; defaults = @($defaults) } | ConvertTo-Json -Depth 4 | Set-Content $cachePath -Encoding utf8
	@($defaults)
}

# ---------------------------------------------------------------- select
$saved = [Collections.Generic.HashSet[string]]::new([string[]]@($entries.Name))
$defaults = @(Get-Defaults | Where-Object { -not $saved.Contains($_.Name) -and $_.Key })
$known = [Collections.Generic.HashSet[string]]::new([string[]](@($entries.Name) + @($defaults.Name)))
foreach ($n in $Unbind) { if (-not $known.Contains($n)) { Fail "unknown mapping $n. It is neither saved nor a default key" } }
$scriptDirs = Get-ChildItem $root -Directory -Filter 'likhos-*' | ForEach-Object { Join-Path $_.FullName 'Scripts' } | Where-Object { Test-Path $_ }
$lua = ($scriptDirs | ForEach-Object { Get-ChildItem $_ -Recurse -Filter *.lua -File } | Get-Content -Raw) -join "`n"
foreach ($e in $entries) {
	$e.Unused = $e.Name.StartsWith('Likhos') -and $lua -notmatch "\b$([regex]::Escape($e.Name))\b"
	$e.Remove = ($Unused -and $e.Unused) -or @($Reset).Where({ $e.Name -like $_ }).Count -gt 0 -or @($Unbind) -contains $e.Name
}

$width = (@($entries.Name) + @($defaults.Name) | Measure-Object -Property Length -Maximum).Maximum
foreach ($e in $entries) {
	$mark = if (@($Unbind) -contains $e.Name) { 'unbind' } elseif ($e.Remove) { 'remove' } elseif ($e.Unused) { 'unused' } else { '' }
	Write-Host ('{0}  {1,-18}  {2}' -f $e.Name.PadRight($width), $e.Key, $mark)
}
foreach ($d in $defaults) {
	$mark = if (@($Unbind) -contains $d.Name) { 'unbind' } else { 'default' }
	Write-Host ('{0}  {1,-18}  {2}' -f $d.Name.PadRight($width), $d.Key, $mark)
}

if (-not $Unused -and -not $Reset -and -not $Unbind) { return }
$drop = @($entries | Where-Object Remove)
if (-not $drop -and -not $Unbind) {
	Write-Host 'Nothing to remove.'
	return
}

# ---------------------------------------------------------------- write
$cfgPath = Join-Path $root 'tools\build\build.config.json'
if (Test-Path $cfgPath) {
	$gameDir = (Get-Content $cfgPath -Raw | ConvertFrom-Json).game.dir
	if (Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($gameDir, 'OrdinalIgnoreCase') }) {
		Write-Error 'The game is running. Close it first: it holds the settings in memory and saves over the file.'
	}
}

# An unbound entry is the mapping name, then key, device class and device identifier all "None", then 6 zero bytes. It goes into the first profile.
$firstCountAt = ($entries | Select-Object -First 1).CountAt
$none = [byte[]]([byte[]](5, 0, 0, 0) + [Text.Encoding]::ASCII.GetBytes('None') + [byte]0)
$added = [Collections.Generic.List[byte]]::new()
foreach ($n in $Unbind) {
	$nameBytes = [byte[]]([Text.Encoding]::ASCII.GetBytes($n) + [byte]0)
	$added.AddRange([BitConverter]::GetBytes([int32] $nameBytes.Length))
	$added.AddRange($nameBytes)
	1..3 | ForEach-Object { $added.AddRange($none) }
	$added.AddRange([byte[]]::new(6))
}

foreach ($g in $entries | Group-Object CountAt) {
	$kept = @($g.Group | Where-Object { -not $_.Remove }).Count
	if ($g.Name -eq $firstCountAt) { $kept += @($Unbind).Count }
	[BitConverter]::GetBytes([int32] $kept).CopyTo($bytes, [int] $g.Name)
}
$out = [IO.MemoryStream]::new()
$at = 0
foreach ($e in $drop) {
	$out.Write($bytes, $at, $e.Start - $at)
	$at = $e.End
}
$insertAt = $entriesEnd[$firstCountAt]
$out.Write($bytes, $at, $insertAt - $at)
$out.Write($added.ToArray(), 0, $added.Count)
$out.Write($bytes, $insertAt, $bytes.Length - $insertAt)

$backup = "$Path.$(Get-Date -Format 'yyyy-MM-dd.HHmmss').bak"
Copy-Item $Path $backup
[IO.File]::WriteAllBytes($Path, $out.ToArray())
Write-Host "Removed $($drop.Count) and added $(@($Unbind).Count) unbound entries. Backup: $backup"
