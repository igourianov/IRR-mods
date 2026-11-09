<#
.SYNOPSIS
	Stage the files of a pak mod from the edit lists in its folder.

.DESCRIPTION
	Extracts the game's own DefaultGameplayTags.ini and moves every weapon listed in reclass.json to its new class.
	A weapon's class is the parent of its item tag (Inventory.Items.Weapons.<Class>.<Name>), so a move renames the tag.
	The old tag leaves the tag list and a redirect maps it to the new one. The engine applies redirects when it loads cooked assets and saves, so every item definition, loadout and preset that names the old tag follows.
	Then stages a renamed copy of every cooked asset listed in clone.json, e.g. a mag well that takes 300 BLK mags instead of 5.56 ones.
	Then it extracts every cooked asset listed in retarget.json and points its references to one asset at another, e.g. a weapon's chamber from the 5.56 ammo set to the 300 BLK one.
	Then it extracts every item definition listed in stats.json and sets its stat values, e.g. the 7.62x39 HP round's damage or the adrenaline injector's stamina recovery.
	Then it extracts every stat config listed in effects.json and sets properties of the effect template its items' effects inherit from, e.g. the tags a painkiller dose grants.
	Then it extracts every NPC loadout preset listed in loadouts.json and sets the weapon pool it picks from: the part of its faction's weighted pool that the preset selects.
	Last, it extracts every loot container preset listed in loot.json and sets its loot generation settings, e.g. how many ammo stacks an ammo box holds.
	Every edit list must exist in the mod folder.
	Called by build.ps1, which packs the staged tree.
#>
[CmdletBinding()]
param(
	# The pak mod's folder, holding reclass.json, clone.json, retarget.json, stats.json, effects.json, loadouts.json and loot.json.
	[Parameter(Mandatory)] [string] $ModDir,
	[Parameter(Mandatory)] [string] $Repak,
	[Parameter(Mandatory)] [string] $UAssetGUI,
	# Names of copies of the game's usmap in UAssetGUI's mappings folder, one per parallel UAssetGUI instance.
	[Parameter(Mandatory)] [string[]] $Mappings,
	[Parameter(Mandatory)] [string] $PaksDir,
	[Parameter(Mandatory)] [string] $StageDir
)

$ErrorActionPreference = 'Stop'

$contentDir = 'Test_C/Content'
$iniPath = 'Test_C/Config/DefaultGameplayTags.ini'
$weaponsTag = 'Inventory.Items.Weapons'
$engineVersion = 'VER_UE5_6'

# ---------------------------------------------------------------- game paks
# Only the game's own paks are searched. A deployed copy of this mod in ~mods holds already edited files.
$paks = @{}
foreach ($pak in Get-ChildItem $PaksDir -Filter *.pak -File) {
	$paks[$pak.FullName] = [System.Collections.Generic.HashSet[string]]@(& $Repak list $pak.FullName)
}

function Find-GamePak {
	param([string] $Path)
	$found = @($paks.Keys | Where-Object { $paks[$_].Contains($Path) })
	if ($found.Count -ne 1) { Write-Error "Expected one game pak holding $Path, found $($found.Count): $(($found | Split-Path -Leaf) -join ', ')" }
	$found[0]
}

function Expand-GameFiles {
	param([string[]] $Paths, [string] $To = $StageDir)
	# Without an include, repak extracts everything.
	if (-not $Paths) { return }
	$Paths = @($Paths | Select-Object -Unique)
	$gamePaks = @($Paths | ForEach-Object { Find-GamePak $_ } | Select-Object -Unique)
	& $Repak unpack -q -f @($Paths | ForEach-Object { '-i'; $_ }) -o $To @gamePaks
	if ($LASTEXITCODE) { Write-Error "repak failed to extract $($Paths -join ', ') from $(($gamePaks | Split-Path -Leaf) -join ', ')." }
}

function Get-AssetPath {
	param([string] $Package)
	if (-not $Package.StartsWith('/Game/')) { Write-Error "$Package is not a /Game/ package." }
	"$contentDir/$($Package.Substring(6))"
}

# ---------------------------------------------------------------- reclass
Expand-GameFiles $iniPath
$file = Join-Path $StageDir $iniPath
$bytes = [System.IO.File]::ReadAllBytes($file)
$bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
$text = [System.IO.File]::ReadAllText($file)
$eol = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = [System.Collections.Generic.List[string]]($text -split $eol)

function Find-Lines {
	param([string] $Pattern)
	@(for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $Pattern) { $i } })
}

function Find-Tag {
	param([string] $Tag)
	Find-Lines "^\+GameplayTagList=\(Tag=`"$([regex]::Escape($Tag))`","
}

$reclass = Get-Content (Join-Path $ModDir 'reclass.json') -Raw | ConvertFrom-Json
foreach ($entry in $reclass.PSObject.Properties) {
	$name = ($entry.Name -split '\.', 2)[1]
	$old = "$weaponsTag.$($entry.Name)"
	$new = "$weaponsTag.$($entry.Value).$name"

	if (-not $name) { Write-Error "reclass.json key '$($entry.Name)' is not <Class>.<Name>." }
	if ((Find-Tag "$weaponsTag.$($entry.Value)").Count -ne 1) { Write-Error "Unknown weapon class '$($entry.Value)' for $old." }
	if ((Find-Tag $new).Count) { Write-Error "$new already exists." }
	# A tag that is also a redirect source is rejected by the engine. A game redirect from the new tag to the old one is the developers' own reclass being reverted, so it goes.
	$reverse = Find-Lines "^\+GameplayTagRedirects=\(OldTagName=`"$([regex]::Escape($new))`",NewTagName=`"$([regex]::Escape($old))`"\)$"
	foreach ($i in $reverse) { $lines.RemoveAt($i) }
	if ((Find-Lines "^\+GameplayTagRedirects=\(OldTagName=`"$([regex]::Escape($new))`"").Count) { Write-Error "$new is already redirected elsewhere." }

	$at = Find-Tag $old
	if ($at.Count -ne 1) { Write-Error "$old is not in the game's tag list." }
	$lines[$at[0]] = $lines[$at[0]].Replace("Tag=`"$old`"", "Tag=`"$new`"")

	$redirects = Find-Lines '^\+GameplayTagRedirects='
	$insertAt = if ($redirects.Count) { $redirects[-1] + 1 } else { (Find-Lines '^\+GameplayTagList=')[0] }
	$lines.Insert($insertAt, "+GameplayTagRedirects=(OldTagName=`"$old`",NewTagName=`"$new`")")

	Write-Host "  $($entry.Name) -> $($entry.Value)"
}

[System.IO.File]::WriteAllText($file, ($lines -join $eol), [System.Text.UTF8Encoding]::new($bom))

# ---------------------------------------------------------------- assets
# Cooked assets are edited as UAssetGUI JSON. Without a usmap their exports stay raw bytes, so only the name map and the import and export tables are touched.
# With -Parse the usmap turns exports into properties, whose names are no longer name map indexes, so renaming a name map entry would leave them behind. Only the stats stage parses.
$work = Join-Path ([System.IO.Path]::GetTempPath()) "$(Split-Path $ModDir -Leaf).$([System.IO.Path]::GetRandomFileName().Split('.')[0])"
New-Item -ItemType Directory $work | Out-Null

function Invoke-UAssetGUI {
	param([hashtable[]] $Calls)
	# Every launch starts .NET and loads the usmap, so the calls run in parallel, one per usmap copy.
	# Parallel instances reading one usmap file often skip it silently and leave exports unparsed.
	# Call i reuses the copy of call i - N, so it waits for that one first.
	$processes = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
	for ($i = 0; $i -lt $Calls.Count; $i++) {
		if ($i -ge $Mappings.Count) { $processes[$i - $Mappings.Count].WaitForExit() }
		$arguments = $Calls[$i].Arguments + @(if ($Calls[$i].Parse) { $Mappings[$i % $Mappings.Count] })
		# A GUI executable: the call operator wouldn't wait for it.
		$process = Start-Process $UAssetGUI -ArgumentList ($arguments | ForEach-Object { "`"$_`"" }) -NoNewWindow -PassThru
		# Without a handle taken while it runs, ExitCode reads null after exit.
		$null = $process.Handle
		$processes.Add($process)
	}
	foreach ($process in $processes) { $process.WaitForExit() }
	for ($i = 0; $i -lt $Calls.Count; $i++) {
		if ($processes[$i].ExitCode) { Write-Error "UAssetGUI $($Calls[$i].Arguments[0..1] -join ' ') failed with exit code $($processes[$i].ExitCode)." }
	}
}

# UAssetGUI writes are queued and run together by Save-QueuedAssets.
$writes = [System.Collections.Generic.List[hashtable]]::new()

function Save-Asset {
	param($Data, [string] $Path, [switch] $Parse, [string] $Original)
	$json = Join-Path $work "$([System.IO.Path]::GetRandomFileName()).json"
	[System.IO.File]::WriteAllText($json, ($Data | ConvertTo-Json -Depth 100), [System.Text.UTF8Encoding]::new($false))
	Remove-Item $Path, ($Path -replace '\.uasset$', '.uexp') -ErrorAction SilentlyContinue
	New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
	$writes.Add(@{ Arguments = @('fromjson', $json, $Path); Parse = [bool] $Parse; Path = $Path; Original = $Original })
}

function Save-QueuedAssets {
	Invoke-UAssetGUI $writes
	foreach ($write in $writes) {
		# UAssetGUI exits 0 without writing anything when the JSON names an FName that isn't in the name map.
		if (-not (Test-Path $write.Path)) { Write-Error "UAssetGUI wrote no $($write.Path). A name the edit uses may be missing from the name map." }
		if (-not $write.Original) { continue }
		foreach ($ext in 'uasset', 'uexp') {
			if ((Get-FileHash ($write.Original -replace '\.uasset$', ".$ext")).Hash -ne (Get-FileHash ($write.Path -replace '\.uasset$', ".$ext")).Hash) {
				Write-Error "UAssetGUI doesn't round-trip $($write.Original -replace '\.uasset$', ".$ext") unchanged."
			}
		}
	}
}

function Read-Assets {
	param([string[]] $Packages, [switch] $Parse)
	$reads = @(foreach ($package in $Packages) {
		$path = Get-AssetPath $package
		@{ Path = $path; Uasset = Join-Path $work "$path.uasset"; Json = Join-Path $work "$([System.IO.Path]::GetRandomFileName()).json" }
	})
	Expand-GameFiles @($reads | ForEach-Object { "$($_.Path).uasset"; "$($_.Path).uexp" }) $work
	Invoke-UAssetGUI @($reads | ForEach-Object { @{ Arguments = @('tojson', $_.Uasset, $_.Json, $engineVersion); Parse = [bool] $Parse } })

	foreach ($read in $reads) {
		$data = Get-Content $read.Json -Raw | ConvertFrom-Json
		if ($Parse -and -not @($data.Exports | Where-Object '$type' -notlike 'UAssetAPI.ExportTypes.RawExport,*').Count) { Write-Error "UAssetGUI left every export of $($read.Path) unparsed. The usmap didn't load." }
		# An unedited round trip through UAssetGUI and ConvertTo-Json must reproduce the game's bytes, or the edited asset can't be trusted.
		Save-Asset $data ($read.Json -replace '\.json$', '.uasset') -Parse:$Parse -Original $read.Uasset
		$data
	}
}

function Get-AssetNames {
	param([string] $Old, [string] $New)
	# A package holds an object named after it, a Blueprint package also its class and class default object.
	$oldName = ($Old -split '/')[-1]
	$newName = ($New -split '/')[-1]
	@{ $Old = $New; $oldName = $newName; "${oldName}_C" = "${newName}_C"; "Default__${oldName}_C" = "Default__${newName}_C" }
}

# ---------------------------------------------------------------- clone
$cloned = [System.Collections.Generic.HashSet[string]]::new()
$clone = Get-Content (Join-Path $ModDir 'clone.json') -Raw | ConvertFrom-Json
$entries = @($clone.PSObject.Properties)
$assets = @(Read-Assets $entries.Value.from)
for ($n = 0; $n -lt $entries.Count; $n++) {
	$entry = $entries[$n]
	$data = $assets[$n]
	$new = $entry.Name
	$source = $entry.Value.from
	$path = Get-AssetPath $new
	if (@($paks.Values | Where-Object { $_.Contains("$path.uasset") }).Count) { Write-Error "$new already exists in the game's paks." }

	$names = Get-AssetNames $source $new
	foreach ($name in $entry.Value.names.PSObject.Properties) {
		if ($data.NameMap -notcontains $name.Name) { Write-Error "$source has no name $($name.Name)." }
		$names[$name.Name] = $name.Value
	}

	# The raw export data refers to names by their index in the name map, so renaming an entry renames every use.
	$data.NameMap = @($data.NameMap | ForEach-Object { $name = $names[$_]; if ($name) { $name } else { $_ } })
	foreach ($object in @($data.Exports) + @($data.Imports)) {
		$name = $names[$object.ObjectName]
		if ($name) { $object.ObjectName = $name }
	}
	$data.FolderName = $new

	Save-Asset $data (Join-Path $StageDir "$path.uasset")
	$cloned.Add($new) | Out-Null
	Write-Host "  $(($new -split '/')[-1]): copy of $(($source -split '/')[-1])"
}

# ---------------------------------------------------------------- retarget
$retarget = Get-Content (Join-Path $ModDir 'retarget.json') -Raw | ConvertFrom-Json
$entries = @($retarget.PSObject.Properties)
$assets = @(Read-Assets $entries.Name)
for ($n = 0; $n -lt $entries.Count; $n++) {
	$entry = $entries[$n]
	$asset = $entry.Name
	$data = $assets[$n]
	$imports = $data.Imports
	foreach ($ref in $entry.Value.PSObject.Properties) {
		$old = $ref.Name
		$new = $ref.Value
		if (-not $cloned.Contains($new)) { Find-GamePak "$(Get-AssetPath $new).uasset" | Out-Null }

		$at = @(for ($i = 0; $i -lt $imports.Count; $i++) { if ($imports[$i].ClassName -eq 'Package' -and $imports[$i].ObjectName -eq $old) { $i } })
		if ($at.Count -ne 1) { Write-Error "$asset doesn't import $old." }
		$outer = -1 - $at[0]

		$names = Get-AssetNames $old $new
		$used = [System.Collections.Generic.List[string]]@($new)

		$imports[$at[0]].ObjectName = $new
		foreach ($import in $imports) {
			if ($import.OuterIndex -eq $outer) {
				$name = $names[$import.ObjectName]
				if (-not $name) { Write-Error "$asset imports $($import.ObjectName) from $old, which has no counterpart in $new." }
				$import.ObjectName = $name
				$used.Add($name)
			}
			if ($import.ClassPackage -eq $old) {
				$name = $names[$import.ClassName]
				if (-not $name) { Write-Error "$asset imports an object of class $($import.ClassName) from $old, which has no counterpart in $new." }
				$import.ClassPackage = $new
				$import.ClassName = $name
			}
		}

		foreach ($name in $used) { if ($data.NameMap -notcontains $name) { $data.NameMap += $name } }
		Write-Host "  $(($asset -split '/')[-1]): $(($old -split '/')[-1]) -> $(($new -split '/')[-1])"
	}

	Save-Asset $data (Join-Path $StageDir "$(Get-AssetPath $asset).uasset")
}

# ---------------------------------------------------------------- stats
# An item definition's ItemStats entry holds the value and references a stat object exported by the same asset. Only the stat object's class tells entries apart, since their order differs between items.
function Find-Stat {
	param([string] $Name)
	$class = "U_${Name}_C"
	$found = @($items | Where-Object {
		$config = ($_.Value | Where-Object Name -eq 'StatItemConfig').Value
		$config -gt 0 -and $data.Imports[-1 - $exports[$config - 1].ClassIndex].ObjectName -eq $class
	})
	if ($found.Count -ne 1) { Write-Error "$asset has $($found.Count) $class stat entries, expected one." }
	$found[0]
}

# Some values aren't ItemStats values. They live on the effect object that the stat object's StatEffect points at, exported by the same asset.
function Find-StatEffect {
	param([string] $Name)
	$config = ((Find-Stat $Name).Value | Where-Object Name -eq 'StatItemConfig').Value
	$effect = ($exports[$config - 1].Data | Where-Object Name -eq 'StatEffect').Value
	if ($effect -le 0) { Write-Error "$asset's $Name stat has no effect in the asset." }
	$exports[$effect - 1]
}

# Unversioned exports serialize property names by schema position, but FName values by name map index.
function Get-NameValues {
	param($Property)
	if ($Property.'$type' -like 'UAssetAPI.PropertyTypes.Objects.NamePropertyData,*') { $Property.Value }
	elseif ($Property.Value -is [array]) { foreach ($inner in $Property.Value) { Get-NameValues $inner } }
}

$stats = Get-Content (Join-Path $ModDir 'stats.json') -Raw | ConvertFrom-Json
$entries = @($stats.PSObject.Properties)
$assets = @(Read-Assets $entries.Name -Parse)
for ($n = 0; $n -lt $entries.Count; $n++) {
	$entry = $entries[$n]
	$asset = $entry.Name
	# Both stages start from the game's copy, so the second write would drop the first one's edits.
	if ($retarget.PSObject.Properties[$asset]) { Write-Error "$asset is listed in both retarget.json and stats.json." }

	$data = $assets[$n]
	$exports = $data.Exports
	$definition = @($exports | Where-Object ObjectName -eq ($asset -split '/')[-1])
	if ($definition.Count -ne 1) { Write-Error "$asset has no item definition export." }
	$items = @(($definition[0].Data | Where-Object Name -eq 'ItemStats').Value)


	foreach ($stat in $entry.Value.PSObject.Properties) {
		if ($stat.Name -eq 'BleedingChance') {
			$property = @((Find-StatEffect 'ChanceToWound').Data | Where-Object Name -eq 'BleedingChance')
		} elseif ($stat.Name -in 'RecoverMultiplier', 'DrainMultiplier') {
			# Stamina multipliers live in the Influence struct of the StaminaBoost stat's effect.
			# An effect that keeps its template's Influence has none in the asset. A struct override replaces the whole inherited struct, so the template's one is copied in first.
			$effect = Find-StatEffect 'StaminaBoost'
			$influence = @($effect.Data | Where-Object Name -eq 'Influence')
			if (-not $influence.Count) {
				if ($effect.TemplateIndex -ge 0) { Write-Error "$asset's StaminaBoost effect has no imported template." }
				# The template is the effect's counterpart under an object of another package, e.g. the stat class's default object.
				$import = $data.Imports[-1 - $effect.TemplateIndex]
				$owner = $data.Imports[-1 - $import.OuterIndex]
				$package = $owner
				while ($package.OuterIndex) { $package = $data.Imports[-1 - $package.OuterIndex] }
				$source = @(Read-Assets $package.ObjectName -Parse)[0]
				$template = @($source.Exports | Where-Object { $_.ObjectName -eq $import.ObjectName -and $_.OuterIndex -gt 0 -and $source.Exports[$_.OuterIndex - 1].ObjectName -eq $owner.ObjectName })
				if ($template.Count -ne 1) { Write-Error "$($package.ObjectName) has no $($owner.ObjectName).$($import.ObjectName)." }
				$influence = @($template[0].Data | Where-Object Name -eq 'Influence')
				if ($influence.Count -ne 1) { Write-Error "$asset's StaminaBoost effect inherits no Influence from $($package.ObjectName)." }
				# UAssetAPI writes unversioned properties in schema order, so appending is safe.
				$effect.Data = @($effect.Data) + $influence
				foreach ($name in Get-NameValues $influence[0]) { if ($data.NameMap -notcontains $name) { $data.NameMap += $name } }
			}
			$property = @($influence[0].Value | Where-Object Name -eq $stat.Name)
		} else {
			$property = @((Find-Stat $stat.Name).Value | Where-Object Name -eq 'Value')
		}
		if ($property.Count -ne 1 -or $property[0].'$type' -notlike 'UAssetAPI.PropertyTypes.Objects.FloatPropertyData,*') { Write-Error "$asset's $($stat.Name) has no float value." }

		$old = $property[0].Value
		$property[0].Value = [double] $stat.Value
		# An unversioned property flagged zero is left out of the export, so a value that stops or starts being zero flips the flag.
		$property[0].IsZero = $stat.Value -eq 0
		Write-Host "  $(($asset -split '/')[-1]): $($stat.Name) $old -> $($stat.Value)"
	}

	Save-Asset $data (Join-Path $StageDir "$(Get-AssetPath $asset).uasset") -Parse
}

# ---------------------------------------------------------------- effects
# A stat config's default object points through StatEffect at the effect every item's effect of that stat takes as its template, exported by the same asset.
# An item effect inherits every value it doesn't set, so a template edit reaches every item that leaves the value alone.
# A value of the form Enum::Member sets an enum property, an array of strings a gameplay tag container. A property the template doesn't set yet is added.
function New-Property {
	param([string] $Type, [string] $Name, [System.Collections.Specialized.OrderedDictionary] $Fields, $Value)
	# UAssetGUI reads $type only as the first key, so the fields keep the order the game's own assets have.
	$property = [ordered]@{ '$type' = "UAssetAPI.PropertyTypes.$Type, UAssetAPI" }
	foreach ($key in $Fields.Keys) { $property[$key] = $Fields[$key] }
	$property.Name = $Name
	$property.ArrayIndex = 0
	$property.PropertyGuid = $null
	$property.IsZero = $false
	$property.PropertyTagFlags = 'None'
	$property.PropertyTypeName = $null
	$property.PropertyTagExtensions = 'NoExtension'
	$property.Value = $Value
	[pscustomobject] $property
}

$effects = Get-Content (Join-Path $ModDir 'effects.json') -Raw | ConvertFrom-Json
$entries = @($effects.PSObject.Properties)
$assets = @(Read-Assets $entries.Name -Parse)
for ($n = 0; $n -lt $entries.Count; $n++) {
	$entry = $entries[$n]
	$asset = $entry.Name
	$name = ($asset -split '/')[-1]
	if ($retarget.PSObject.Properties[$asset] -or $stats.PSObject.Properties[$asset]) { Write-Error "$asset is listed in effects.json and another stage." }

	$data = $assets[$n]
	$default = @($data.Exports | Where-Object ObjectName -eq "Default__${name}_C")
	if ($default.Count -ne 1) { Write-Error "$asset has no Default__${name}_C export." }
	$pointer = @($default[0].Data | Where-Object Name -eq 'StatEffect')
	if ($pointer.Count -ne 1 -or $pointer[0].Value -le 0) { Write-Error "$asset's default object has no StatEffect in the asset." }
	$effect = $data.Exports[$pointer[0].Value - 1]

	foreach ($field in $entry.Value.PSObject.Properties) {
		if ($field.Value -is [string] -and $field.Value -match '^(\w+)::(\w+)$') {
			$property = New-Property 'Objects.EnumPropertyData' $field.Name ([ordered]@{ EnumType = $Matches[1]; InnerType = 'ByteProperty' }) $Matches[2]
			$names = @($Matches[1], $Matches[2], 'ByteProperty', 'EnumProperty')
			$shown = $Matches[2]
		} elseif ($field.Value -is [array] -and -not @($field.Value | Where-Object { $_ -isnot [string] }).Count) {
			$inner = New-Property 'Structs.GameplayTagContainerPropertyData' $field.Name ([ordered]@{}) @($field.Value)
			$property = New-Property 'Structs.StructPropertyData' $field.Name ([ordered]@{ StructType = 'GameplayTagContainer'; SerializeNone = $true; StructGUID = '{00000000-0000-0000-0000-000000000000}'; SerializationControl = 'NoExtension'; Operation = 'None' }) @($inner)
			$names = @('GameplayTagContainer', 'StructProperty') + @($field.Value)
			$shown = "[$($field.Value -join ', ')]"
		} else {
			Write-Error "$($field.Name) in effects.json for $asset is neither Enum::Member nor an array of tags."
		}

		# UAssetAPI writes unversioned properties in schema order, so a property added at the end lands in place.
		$old = @($effect.Data | Where-Object Name -eq $field.Name)
		$was = if ($old.Count) { ($old[0].Value | ConvertTo-Json -Compress -Depth 10) } else { 'inherited' }
		$effect.Data = @(@($effect.Data | Where-Object Name -ne $field.Name) + $property)
		foreach ($needed in $names) { if ($data.NameMap -notcontains $needed) { $data.NameMap += $needed } }
		Write-Host "  ${name}: $($field.Name) $was -> $shown"
	}

	Save-Asset $data (Join-Path $StageDir "$(Get-AssetPath $asset).uasset") -Parse
}

# ---------------------------------------------------------------- presets
# A loadout or loot container preset fills each of its ContainerSlots from the LootGenerationSettings object the slot references, exported by the same asset.
function Get-SlotSettings {
	param($Data, [string] $Asset)
	$preset = @($Data.Exports | Where-Object ObjectName -eq ($Asset -split '/')[-1])
	if ($preset.Count -ne 1) { Write-Error "$Asset has no preset export." }
	foreach ($slot in @(($preset[0].Data | Where-Object Name -eq 'ContainerSlots').Value)) {
		$settings = ($slot.Value | Where-Object Name -eq 'LootSettings').Value
		if ($settings -gt 0) { $Data.Exports[$settings - 1] }
	}
}

# ---------------------------------------------------------------- loadouts
# A faction's pool is the only place weapon weights are set. Each of its presets carries the pool weapons its selection names by class (Smg) or by weapon (Rifle.AK-103), at their pool weights.
# An NPC preset rolls its weapon from the one slot whose ItemTypeSpawnWeights map weapon tags to weights. The preset's pool replaces that map whole.
# Tags are the staged ini's, reclass applied, so the presets don't depend on tag redirects reaching them.
function Select-Weapons {
	param($Weapons, [string[]] $Prefixes)
	$Weapons | Where-Object { $name = $_.Name; @($Prefixes | Where-Object { $name -eq $_ -or $name.StartsWith("$_.") }).Count }
}

# Keyed by preset path, so the loot stage can tell a preset is taken.
$loadouts = [pscustomobject]@{}
foreach ($faction in (Get-Content (Join-Path $ModDir 'loadouts.json') -Raw | ConvertFrom-Json).PSObject.Properties) {
	$weapons = @($faction.Value.pool.PSObject.Properties)
	$selected = [System.Collections.Generic.HashSet[string]]::new()
	foreach ($preset in $faction.Value.presets.PSObject.Properties) {
		foreach ($prefix in $preset.Value) {
			if (-not @(Select-Weapons $weapons $prefix).Count) { Write-Error "$prefix in $($preset.Name)'s selection matches no $($faction.Name) weapon." }
		}
		if ($loadouts.PSObject.Properties[$preset.Name]) { Write-Error "$($preset.Name) is listed under two factions in loadouts.json." }
		$carried = @(Select-Weapons $weapons $preset.Value)
		foreach ($weapon in $carried) { $null = $selected.Add($weapon.Name) }
		$loadouts | Add-Member $preset.Name $carried
	}
	foreach ($weapon in $weapons) {
		if (-not $selected.Contains($weapon.Name)) { Write-Error "$($weapon.Name) in the $($faction.Name) pool is selected by no preset." }
	}
}
$entries = @($loadouts.PSObject.Properties)
$assets = @(Read-Assets $entries.Name -Parse)
for ($n = 0; $n -lt $entries.Count; $n++) {
	$entry = $entries[$n]
	$asset = $entry.Name
	if ($retarget.PSObject.Properties[$asset] -or $stats.PSObject.Properties[$asset] -or $effects.PSObject.Properties[$asset]) { Write-Error "$asset is listed in loadouts.json and another stage." }

	$data = $assets[$n]
	$pools = @(foreach ($settings in Get-SlotSettings $data $asset) {
		$weights = @($settings.Data | Where-Object Name -eq 'ItemTypeSpawnWeights')
		if (-not $weights.Count -or -not $weights[0].Value.Count) { continue }
		$keys = @($weights[0].Value | ForEach-Object { ($_[0].Value | Where-Object Name -eq 'TagName').Value })
		if (-not @($keys | Where-Object { -not "$_".StartsWith("$weaponsTag.") }).Count) { $weights[0] }
	})
	if ($pools.Count -ne 1) { Write-Error "$asset has $($pools.Count) weapon pools, expected one." }
	$pool = $pools[0]

	$template = $pool.Value[0] | ConvertTo-Json -Depth 100
	$pool.Value = @(foreach ($weapon in $entry.Value) {
		$tag = "$weaponsTag.$($weapon.Name)"
		if ((Find-Tag $tag).Count -ne 1) { Write-Error "$tag in loadouts.json is not in the staged tag list." }
		if ($data.NameMap -notcontains $tag) { $data.NameMap += $tag }
		$pair = $template | ConvertFrom-Json
		($pair[0].Value | Where-Object Name -eq 'TagName').Value = $tag
		$pair[1].Value = [double] $weapon.Value
		$pair[1].IsZero = $weapon.Value -eq 0
		# A bare pair would be unrolled into the outer array.
		, $pair
	})

	Save-Asset $data (Join-Path $StageDir "$(Get-AssetPath $asset).uasset") -Parse
	$total = ($entry.Value | Measure-Object Value -Sum).Sum
	Write-Host "  $(($asset -split '/')[-1]): $(($entry.Value | ForEach-Object { '{0} {1:0.#}%' -f $_.Name, (100 * $_.Value / $total) }) -join ', ')"
}

# ---------------------------------------------------------------- loot
# A loot container rolls its contents from the loot settings of its one slot. A listed int or bool field is set, a listed map field has the value of each listed key set.
# An int or bool field at its class default is absent from the asset, so it is written in, typed by its JSON value.
# Only keys the preset already has are set, since a new key would need its tag added to the name map.
$loot = Get-Content (Join-Path $ModDir 'loot.json') -Raw | ConvertFrom-Json
$entries = @($loot.PSObject.Properties)
$assets = @(Read-Assets $entries.Name -Parse)
for ($n = 0; $n -lt $entries.Count; $n++) {
	$entry = $entries[$n]
	$asset = $entry.Name
	$name = ($asset -split '/')[-1]
	if ($retarget.PSObject.Properties[$asset] -or $stats.PSObject.Properties[$asset] -or $effects.PSObject.Properties[$asset] -or $loadouts.PSObject.Properties[$asset]) { Write-Error "$asset is listed in loot.json and another stage." }

	$data = $assets[$n]
	$settings = @(Get-SlotSettings $data $asset)
	if ($settings.Count -ne 1) { Write-Error "$asset has $($settings.Count) slots with loot settings, expected one." }
	$settings = $settings[0]

	foreach ($field in $entry.Value.PSObject.Properties) {
		$property = @($settings.Data | Where-Object Name -eq $field.Name)
		if (-not $property.Count -and ($field.Value -is [bool] -or $field.Value -is [long])) {
			$bool = $field.Value -is [bool]
			$property = @([pscustomobject]@{ '$type' = "UAssetAPI.PropertyTypes.Objects.$(if ($bool) { 'Bool' } else { 'Int' })PropertyData, UAssetAPI"; Name = $field.Name; ArrayIndex = 0; PropertyGuid = $null; IsZero = $true; PropertyTagFlags = 'None'; PropertyTypeName = $null; PropertyTagExtensions = 'NoExtension'; Value = if ($bool) { $false } else { 0 } })
			$settings.Data = @($settings.Data) + $property
			if ($data.NameMap -notcontains $field.Name) { $data.NameMap += $field.Name }
		}
		if ($property.Count -ne 1) { Write-Error "$asset has no $($field.Name) loot setting." }
		$property = $property[0]

		switch -Wildcard ($property.'$type') {
			{ $_ -like 'UAssetAPI.PropertyTypes.Objects.IntPropertyData,*' -or $_ -like 'UAssetAPI.PropertyTypes.Objects.BoolPropertyData,*' } {
				$old = $property.Value
				$property.Value = if ($field.Value -is [bool]) { $field.Value } else { [int] $field.Value }
				$property.IsZero = -not $field.Value
				Write-Host "  ${name}: $($field.Name) $old -> $($field.Value)"
			}
			'UAssetAPI.PropertyTypes.Objects.MapPropertyData,*' {
				foreach ($key in $field.Value.PSObject.Properties) {
					$value = $null
					foreach ($pair in $property.Value) {
						if (($pair[0].Value | Where-Object Name -eq 'TagName').Value -eq $key.Name) { $value = $pair[1] }
					}
					if (-not $value) { Write-Error "$asset's $($field.Name) has no $($key.Name) key." }

					if ($value.'$type' -like 'UAssetAPI.PropertyTypes.Objects.FloatPropertyData,*') {
						$old = $value.Value
						$value.Value = [double] $key.Value
						$value.IsZero = $key.Value -eq 0
					} elseif ($value.StructType -eq 'Vector2D') {
						$range = @($key.Value)
						if ($range.Count -ne 2) { Write-Error "$($field.Name).$($key.Name) in loot.json is not a [min, max] pair." }
						$vector = $value.Value[0]
						$old = "[$($vector.Value.X), $($vector.Value.Y)]"
						$vector.Value.X = [double] $range[0]
						$vector.Value.Y = [double] $range[1]
						$vector.IsZero = $range[0] -eq 0 -and $range[1] -eq 0
					} else {
						Write-Error "$asset's $($field.Name) values are neither floats nor Vector2D."
					}
					Write-Host "  ${name}: $($field.Name)[$($key.Name)] $old -> $($key.Value | ConvertTo-Json -Compress)"
				}
			}
			default { Write-Error "$asset's $($field.Name) is not an int, bool or map." }
		}
	}

	Save-Asset $data (Join-Path $StageDir "$(Get-AssetPath $asset).uasset") -Parse
}

Save-QueuedAssets
Remove-Item $work -Recurse -Force
