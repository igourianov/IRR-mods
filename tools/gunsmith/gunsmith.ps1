<#
.SYNOPSIS
	Find each weapon's lowest-recoil and best-ergonomics full build, loud and suppressed, from the game's attachment slots.

.DESCRIPTION
	Reads every weapon and attachment definition and every slot and supported-items class from the game's own paks, and caches them as an index in tools\gunsmith\cache. The cache is rebuilt when a game pak or the usmap changes, or with -Refresh.
	Applies a pak mod's edit lists on top (stats, supported, retarget, clone, reclass), unless -Vanilla.
	A build is a tree: each slot holds at most one item that the slot accepts, and that item brings its own slots. The search picks the best item for every slot, so stacked parts (a chassis with its own stock slot, a suppressor on a flash hider) count as the game sums them.
	A loud build has no suppressor anywhere. A suppressed build has one in its muzzle chain.
	Recoil is the definition stat. A weapon with full auto also shows recoil per second of fire, stat × RPM / 700, so weapons at different fire rates compare.
	Needs repak and UAssetGUI in tools\ (build.ps1 fetches them on the first pak build) and the game's usmap in the UE4SS folder.

.EXAMPLE
	.\tools\gunsmith\gunsmith.ps1                        # every weapon with likhos-rearmed's edits
	.\tools\gunsmith\gunsmith.ps1 -Class Rifle, Smg      # by weapon class, after reclass.json
	.\tools\gunsmith\gunsmith.ps1 '*AK*' -Detail         # the parts of each build
	.\tools\gunsmith\gunsmith.ps1 -Vanilla               # the game's own values
	.\tools\gunsmith\gunsmith.ps1 -Refresh               # re-extract, e.g. after a game patch
#>
[CmdletBinding()]
param(
	# Weapon names as in their item definition without ID_ (e.g. Colt_M4A1). Wildcards allowed.
	[Parameter(Position = 0)] [string[]] $Weapons = '*',
	[string[]] $Class,
	# Attachment categories a build holds at most one of, overriding gunsmith.json. An empty string allows any number.
	[string[]] $Unique,
	[string] $Mod = 'likhos-rearmed',
	[switch] $Vanilla,
	[switch] $Detail,
	[switch] $Refresh,
	# Print every slot path from each selected weapon to the attachments matching this name, e.g. '*Foregrip*', instead of the builds.
	[string] $Trace
)

$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot)
$engineVersion = 'VER_UE5_6'

# ---------------------------------------------------------------- config
$buildCfgPath = Join-Path $root 'tools\build\build.config.json'
if (-not (Test-Path $buildCfgPath)) { Write-Error 'tools\build\build.config.json not found. Copy build.config.example.json and set your game path.' }
$buildCfg = Get-Content $buildCfgPath -Raw | ConvertFrom-Json
$module = $buildCfg.game.module
$paksDir = Join-Path $buildCfg.game.dir "$module\Content\Paks"
$ue4ssDir = Split-Path (Join-Path $buildCfg.game.dir $buildCfg.ue4ss.modsDir)
$cfg = Get-Content (Join-Path $PSScriptRoot 'gunsmith.json') -Raw | ConvertFrom-Json

$repak = Join-Path $root 'tools\repak\repak.exe'
$uassetGui = Join-Path $root 'tools\UAssetGUI\UAssetGUI.exe'
foreach ($exe in $repak, $uassetGui) { if (-not (Test-Path $exe)) { Write-Error "$exe not found. Run build.ps1 on a pak mod once to fetch it." } }

# ---------------------------------------------------------------- extract
$cacheDir = Join-Path $PSScriptRoot 'cache'
$indexPath = Join-Path $cacheDir 'index.json'
$stampPath = Join-Path $cacheDir 'stamp.txt'
$usmap = Get-ChildItem $ue4ssDir -Filter *.usmap -File | Sort-Object LastWriteTime | Select-Object -Last 1
if (-not $usmap) { Write-Error "No usmap in $ue4ssDir. Generate one in game with UE4SS's mappings dump key after every game patch." }
$gamePaks = @(Get-ChildItem $paksDir -Filter *.pak -File | Sort-Object Name)
$stamp = (@($gamePaks | ForEach-Object { "$($_.Name) $($_.Length) $($_.LastWriteTimeUtc.Ticks)" }) + "$($usmap.Name) $($usmap.Length)") -join "`n"

$contentPrefix = "$module/Content/"
$assetPattern = "^$([regex]::Escape($contentPrefix))Blueprints/InventorySystem/(Items/(Weapons|Attachments)/.*/ID_[^/]*|Objects/InventorySupportedItems/.*/UISI_[^/]*|Objects/ItemContainers/.*/U_[^/]*)\.uasset$"

# Object references in UAssetGUI JSON: a positive value is a 1-based export index, a negative one an import.
function Get-RefClass {
	param($Json, [int] $Ref)
	if ($Ref -gt 0) {
		$export = $Json.Exports[$Ref - 1]
		return $Json.Imports[-1 - $export.ClassIndex].ObjectName
	}
	($Json.Imports[-1 - $Ref].ObjectName) -replace '^Default__', ''
}

function Get-Tags {
	param($Node)
	if ($Node -is [string]) { if ($Node -like 'Inventory.Items.*') { $Node }; return }
	if ($Node -is [array]) { foreach ($x in $Node) { Get-Tags $x }; return }
	if ($Node -is [pscustomobject]) { foreach ($p in $Node.PSObject.Properties) { if ($p.Name -ne '$type') { Get-Tags $p.Value } } }
}

# ItemRelations.ConflictingItemsQuery names items that can't be fitted together with this one.
function Get-ConflictTags {
	param($Node, [bool] $Inside)
	if ($Node -is [array]) { foreach ($x in $Node) { Get-ConflictTags $x $Inside }; return }
	if ($Node -isnot [pscustomobject]) { return }
	$here = $Inside -or $Node.Name -eq 'ConflictingItemsQuery'
	if ($here -and $Node.Name -eq 'TagName' -and $Node.Value -is [string]) { $Node.Value }
	foreach ($p in $Node.PSObject.Properties) { if ($p.Value -is [array] -or $p.Value -is [pscustomobject]) { Get-ConflictTags $p.Value $here } }
}

# A SupportedItems property holds either references to supported-items objects or, on a supported-items object itself, a tag container.
function Read-Supported {
	param($Json, $Property)
	$values = @($Property.Value)
	$refs = @($values | Where-Object { $_.Value -is [int] -or $_.Value -is [long] })
	if (-not $refs.Count) { return @{ Tags = @(Get-Tags $Property.Value); Lists = @() } }
	$tags = [System.Collections.Generic.List[string]]::new()
	$lists = [System.Collections.Generic.List[string]]::new()
	$inherit = $false
	foreach ($r in $refs) {
		$ref = [int] $r.Value
		if ($ref -eq 0) { continue }
		$own = if ($ref -gt 0) { @($Json.Exports[$ref - 1].Data | Where-Object Name -eq 'SupportedItems') } else { @() }
		$class = Get-RefClass $Json $ref
		if ($own.Count) { foreach ($t in Get-Tags $own[0].Value) { $tags.Add($t) } }
		# An inline supported-items object that sets nothing keeps its archetype's list, the container class's default.
		elseif ($class -eq 'InventorySupportedItems') { $inherit = $true }
		else { $lists.Add($class) }
	}
	@{ Tags = @($tags); Lists = @($lists); Inherit = $inherit -and -not $tags.Count -and -not $lists.Count }
}

function Update-Index {
	$raw = Join-Path $cacheDir 'raw'
	if (Test-Path $raw) { Remove-Item $raw -Recurse -Force }
	New-Item -ItemType Directory -Force $raw | Out-Null

	$assets = [System.Collections.Generic.List[string]]::new()
	foreach ($pak in $gamePaks) {
		$list = @(& $repak list $pak.FullName | Where-Object { $_ -match $assetPattern })
		# Batched to stay under the command line length limit.
		for ($i = 0; $i -lt $list.Count; $i += 100) {
			$batch = $list[$i..([math]::Min($i + 99, $list.Count - 1))]
			& $repak unpack -q -f @($batch | ForEach-Object { '-i'; $_; '-i'; ($_ -replace '\.uasset$', '.uexp') }) -o $raw $pak.FullName
			if ($LASTEXITCODE) { Write-Error "repak failed to extract from $($pak.Name)." }
		}
		foreach ($a in $list) { $assets.Add($a) }
	}
	Write-Host "extracted $($assets.Count) assets"

	# UAssetGUI reads a usmap only from its own mappings folder, by name. Parallel instances sharing one usmap file often skip it silently, so each gets its own copy.
	$mappingsDir = Join-Path $env:LOCALAPPDATA 'UAssetGUI\Mappings'
	New-Item -ItemType Directory -Force $mappingsDir | Out-Null
	$mappings = @(foreach ($i in 1..[Environment]::ProcessorCount) {
		$name = "$module-$i"
		Copy-Item $usmap.FullName (Join-Path $mappingsDir "$name.usmap") -Force
		$name
	})
	$processes = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
	for ($i = 0; $i -lt $assets.Count; $i++) {
		if ($i -ge $mappings.Count) { $processes[$i - $mappings.Count].WaitForExit() }
		$uasset = Join-Path $raw $assets[$i]
		$arguments = @('tojson', $uasset, ($uasset -replace '\.uasset$', '.json'), $engineVersion, $mappings[$i % $mappings.Count])
		# A GUI executable: the call operator wouldn't wait for it.
		$process = Start-Process $uassetGui -ArgumentList ($arguments | ForEach-Object { "`"$_`"" }) -NoNewWindow -PassThru
		$null = $process.Handle
		$processes.Add($process)
	}
	foreach ($process in $processes) { $process.WaitForExit() }

	$classes = @{}
	$items = @{}
	foreach ($asset in $assets) {
		$jsonPath = Join-Path $raw ($asset -replace '\.uasset$', '.json')
		if (-not (Test-Path $jsonPath)) { Write-Error "UAssetGUI wrote no JSON for $asset." }
		$j = Get-Content $jsonPath -Raw | ConvertFrom-Json
		$package = '/Game/' + ($asset.Substring($contentPrefix.Length) -replace '\.uasset$', '')
		$base = ($package -split '/')[-1]

		if ($base -notlike 'ID_*') {
			$classExport = @($j.Exports | Where-Object ObjectName -eq "${base}_C")
			$cdo = @($j.Exports | Where-Object ObjectName -eq "Default__${base}_C")
			if (-not $classExport.Count -or -not $cdo.Count) { continue }
			$parent = if ($classExport[0].SuperIndex -lt 0) { $j.Imports[-1 - $classExport[0].SuperIndex].ObjectName } else { $null }
			$prop = @($cdo[0].Data | Where-Object Name -eq 'SupportedItems')
			$supported = if ($prop.Count) { Read-Supported $j $prop[0] } else { @{ Tags = @(); Lists = @(); Inherit = $true } }
			$classes["${base}_C"] = [ordered]@{ Parent = $parent; Has = -not $supported.Inherit; Tags = $supported.Tags; Lists = $supported.Lists }
			continue
		}

		$def = @($j.Exports | Where-Object ObjectName -eq $base)
		if ($def.Count -ne 1 -or -not $def[0].Data) { Write-Error "$package has no parsed item definition. The usmap may not have loaded." }
		$data = $def[0].Data
		$tag = (($data | Where-Object Name -eq 'ItemIdentifier').Value | Where-Object Name -eq 'TagName').Value
		$stats = @{}
		foreach ($it in @(($data | Where-Object Name -eq 'ItemStats').Value)) {
			$config = ($it.Value | Where-Object Name -eq 'StatItemConfig').Value
			if ($config -le 0) { continue }
			$statClass = $j.Imports[-1 - $j.Exports[$config - 1].ClassIndex].ObjectName -replace '^U_|_C$', ''
			$value = ($it.Value | Where-Object Name -eq 'Value').Value
			if ($null -ne $value) { $stats[$statClass] = [double] $value }
		}
		$slots = foreach ($c in @(($data | Where-Object Name -eq 'ItemContainers').Value)) {
			$ref = [int] $c.Value
			if ($ref -le 0) { continue }
			$container = $j.Exports[$ref - 1]
			$prop = @($container.Data | Where-Object Name -eq 'SupportedItems')
			$supported = if ($prop.Count) { Read-Supported $j $prop[0] } else { @{ Tags = @(); Lists = @(); Inherit = $true } }
			[ordered]@{ Export = $container.ObjectName; Container = (Get-RefClass $j $ref); Own = -not $supported.Inherit; Tags = $supported.Tags; Lists = $supported.Lists }
		}
		$category = if ($package -match '/Items/Attachments/([^/]+)/') { $Matches[1] } else { 'Weapon' }
		$items[$base] = [ordered]@{
			Path = $package; Tag = $tag; Category = $category
			Recoil = $stats['Recoil']; Ergo = $stats['Ergonomics']; Rpm = $stats['RoundsPerMinute']
			Modes = @($j.NameMap | Where-Object { $_ -like 'Weapon.FireMode.*' } | ForEach-Object { $_ -replace '^Weapon\.FireMode\.', '' })
			Conflicts = @(Get-ConflictTags $j.Exports $false | Select-Object -Unique)
			Slots = @($slots)
		}
	}

	[ordered]@{ Classes = $classes; Items = $items } | ConvertTo-Json -Depth 10 -Compress | Set-Content $indexPath -Encoding utf8
	Set-Content $stampPath $stamp -NoNewline -Encoding utf8
	Remove-Item $raw -Recurse -Force
	Write-Host "indexed $($items.Count) items and $($classes.Count) classes"
}

if ($Refresh -or -not (Test-Path $indexPath) -or -not (Test-Path $stampPath) -or (Get-Content $stampPath -Raw) -ne $stamp) {
	New-Item -ItemType Directory -Force $cacheDir | Out-Null
	Update-Index
}
$index = Get-Content $indexPath -Raw | ConvertFrom-Json

# ---------------------------------------------------------------- model
$classes = @{}
foreach ($p in $index.Classes.PSObject.Properties) { $classes[$p.Name] = $p.Value }
$items = @{}
foreach ($p in $index.Items.PSObject.Properties) {
	$v = $p.Value
	$items[$p.Name] = [pscustomobject]@{
		Id = $p.Name; Name = $p.Name.Substring(3); Path = $v.Path; Tag = $v.Tag; Category = $v.Category
		Recoil = [double] $v.Recoil; Ergo = [double] $v.Ergo; Rpm = [double] $v.Rpm
		Modes = @($v.Modes); Conflicts = @($v.Conflicts)
		Slots = @($v.Slots | ForEach-Object { [pscustomobject]@{ Export = $_.Export; Container = $_.Container; Own = $_.Own; Tags = @($_.Tags); Lists = @($_.Lists) } })
		Suppressor = $v.Category -eq 'Muzzle' -and $p.Name -match 'Suppressor|Silencer'
		Class = $null
	}
}
$byPath = @{}
foreach ($it in $items.Values) { $byPath[$it.Path] = $it }

# ---------------------------------------------------------------- mod edits
$modDir = Join-Path $root $Mod
function Read-EditList {
	param([string] $Name)
	$path = Join-Path $modDir "$Name.json"
	if (-not $Vanilla -and (Test-Path $path)) { Get-Content $path -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
}
function Get-ClassName { param([string] $Package) "$(($Package -split '/')[-1])_C" }

# A clone is a renamed copy of a class whose tags are renamed too.
foreach ($e in (Read-EditList 'clone').PSObject.Properties) {
	$source = $classes[(Get-ClassName $e.Value.from)]
	if (-not $source) { continue }
	$names = @{}; foreach ($n in $e.Value.names.PSObject.Properties) { $names[$n.Name] = $n.Value }
	$classes[(Get-ClassName $e.Name)] = [pscustomobject]@{ Parent = $source.Parent; Has = $source.Has; Tags = @($source.Tags | ForEach-Object { if ($names[$_]) { $names[$_] } else { $_ } }); Lists = $source.Lists }
}

foreach ($e in (Read-EditList 'retarget').PSObject.Properties) {
	$it = $byPath[$e.Name]
	if (-not $it) { continue }
	foreach ($r in $e.Value.PSObject.Properties) {
		$old = Get-ClassName $r.Name; $new = Get-ClassName $r.Value
		foreach ($s in $it.Slots) {
			if ($s.Container -eq $old) { $s.Container = $new }
			$s.Lists = @($s.Lists | ForEach-Object { if ($_ -eq $old) { $new } else { $_ } })
		}
	}
}

foreach ($e in (Read-EditList 'stats').PSObject.Properties) {
	$it = $byPath[$e.Name]
	if (-not $it) { continue }
	if ($null -ne $e.Value.Recoil) { $it.Recoil = [double] $e.Value.Recoil }
	if ($null -ne $e.Value.Ergonomics) { $it.Ergo = [double] $e.Value.Ergonomics }
}

# A weapon's class is the parent of its tag, Inventory.Items.Weapons.<Class>.<Name>.
$reclass = Read-EditList 'reclass'
foreach ($it in $items.Values | Where-Object Category -eq 'Weapon') {
	if ($it.Tag -notmatch '^Inventory\.Items\.Weapons\.([^.]+)\.(.+)$') { continue }
	$moved = $reclass.PSObject.Properties["$($Matches[1]).$($Matches[2])"]
	$it.Class = if ($moved) { $moved.Value } else { $Matches[1] }
}

# ---------------------------------------------------------------- slots
$byTag = @{}
foreach ($it in $items.Values) { if ($it.Tag) { $byTag[$it.Tag] = $it } }

function Get-ClassTags {
	param([string] $Name, $Seen)
	$c = $classes[$Name]
	if (-not $c -or -not $Seen.Add($Name)) { return }
	if (-not $c.Has) { if ($c.Parent) { Get-ClassTags $c.Parent $Seen }; return }
	$c.Tags
	foreach ($l in $c.Lists) { Get-ClassTags $l $Seen }
}

# A slot that sets no SupportedItems takes its container class's.
function Get-SlotTags {
	param($Slot)
	$seen = [System.Collections.Generic.HashSet[string]]::new()
	if ($Slot.Own) { @($Slot.Tags) + @($Slot.Lists | ForEach-Object { Get-ClassTags $_ $seen }) } else { @(Get-ClassTags $Slot.Container $seen) }
}

# supported.json, the way pak.ps1 applies it: every result comes from the game's lists, so all are worked out before any is set.
$changes = foreach ($e in (Read-EditList 'supported').PSObject.Properties) {
	foreach ($edit in $e.Value.PSObject.Properties) {
		$listClass = $null; $slot = $null
		if ($edit.Name -like 'Default__*') { $listClass = $edit.Name.Substring(9); $current = @(Get-ClassTags $listClass ([System.Collections.Generic.HashSet[string]]::new())) }
		else {
			$it = $byPath[$e.Name]
			if (-not $it) { continue }
			$slot = @($it.Slots | Where-Object Export -eq $edit.Name)[0]
			if (-not $slot) { Write-Warning "$($e.Name) has no slot $($edit.Name)."; continue }
			if ($edit.Value.unlink) {
				$drop = @($edit.Value.unlink | ForEach-Object { "$_`_C" })
				$slot.Lists = @($slot.Lists | Where-Object { $_ -notin $drop })
				continue
			}
			$current = @(Get-SlotTags $slot)
		}
		$tags = if ($edit.Value.from) { @(Get-ClassTags (Get-ClassName $edit.Value.from) ([System.Collections.Generic.HashSet[string]]::new())) } else { $current }
		if ($edit.Value.keep) { $tags = @($tags | Where-Object { $t = $_; @($edit.Value.keep | Where-Object { $t -like $_ }).Count }) }
		if ($edit.Value.remove) { $tags = @($tags | Where-Object { $t = $_; -not @($edit.Value.remove | Where-Object { $t -like $_ }).Count }) }
		$tags = @(@($tags) + @($edit.Value.add | Where-Object { $_ }) | Select-Object -Unique)
		[pscustomobject]@{ Class = $listClass; Slot = $slot; Tags = $tags }
	}
}
foreach ($c in $changes) {
	if ($c.Class) { $classes[$c.Class] = [pscustomobject]@{ Parent = $null; Has = $true; Tags = $c.Tags; Lists = @() } }
	else { $c.Slot.Own = $true; $c.Slot.Tags = $c.Tags; $c.Slot.Lists = @() }
}

$ignore = @{}
foreach ($p in $cfg.ignore.PSObject.Properties) { $ignore[$p.Name] = @($p.Value) }
$skip = @($cfg.skip)
$required = @($cfg.required)
$unique = if ($PSBoundParameters.ContainsKey('Unique')) { @($Unique | Where-Object { $_ }) } else { @($cfg.unique) }

foreach ($it in $items.Values) {
	foreach ($s in $it.Slots) {
		$tags = Get-SlotTags $s
		$blocked = @($ignore[$it.Id])
		$children = @($tags | Select-Object -Unique | Where-Object { $_ -ne $it.Tag -and $_ -notin $it.Conflicts } | Where-Object {
			$t = $_; -not @($blocked | Where-Object { $t -like $_ }).Count
		} | ForEach-Object { $byTag[$_] } | Where-Object { $_ -and $_.Category -ne 'Weapon' -and $_.Category -notin $skip })
		$s | Add-Member Children $children
		$mustFill = @($required) + @($cfg.requiredSlots.($it.Id))
		$s | Add-Member Required ([bool] @($children | Where-Object Category -in $mustFill).Count)
	}
}

# ---------------------------------------------------------------- search
# Lower is better. The ranked stat counts first, the other one breaks ties.
$scoreOf = @{
	Recoil = { param($i) $i.Recoil * 1000 - $i.Ergo }
	Ergo   = { param($i) -$i.Ergo * 1000 + $i.Recoil }
}

# Each category in $unique gets a bit. A subtree's allowance is a mask of the bits it may still use, at most one item each.
$uniqueBit = @{}
for ($i = 0; $i -lt $unique.Count; $i++) { $uniqueBit[$unique[$i]] = 1 -shl $i }
$allUnique = (1 -shl $unique.Count) - 1

function Get-Subsets {
	param([int] $Mask)
	$s = $Mask
	while ($true) { $s; if ($s -eq 0) { break }; $s = ($s - 1) -band $Mask }
}

# Sup: 1 needs exactly one suppressor in the subtree, 0 allows none.
function Find-Best {
	param($Item, [int] $Sup, [int] $Allow)
	$key = "$($Item.Id)|$Sup|$Allow"
	if ($memo.ContainsKey($key)) { return $memo[$key] }
	if (-not $stack.Add($Item.Id)) { return $null }
	$result = $null
	$ok = $true
	if ($Item.Suppressor) { if ($Sup -eq 1) { $Sup = 0 } else { $ok = $false } }
	$bit = $uniqueBit[$Item.Category]
	if ($bit) { if ($Allow -band $bit) { $Allow = $Allow -bxor $bit } else { $ok = $false } }
	if ($ok) {
		# Slots are combined one by one. A state is how much of the suppressor need and of the allowance earlier slots took.
		$table = @{ '0|0' = [pscustomobject]@{ Score = (& $score $Item); Parts = @($Item) } }
		foreach ($slot in $Item.Slots) {
			$next = @{}
			foreach ($state in $table.Keys) {
				$usedSup, $usedAllow = [int[]] ($state -split '\|')
				$partial = $table[$state]
				foreach ($s in @(0, 1)) {
					if ($usedSup + $s -gt $Sup) { continue }
					foreach ($a in Get-Subsets ($Allow -band -bnot $usedAllow)) {
						$pick = Find-Slot $slot $s $a
						if (-not $pick) { continue }
						$k = "$($usedSup + $s)|$($usedAllow -bor $a)"
						$total = $partial.Score + $pick.Score
						if (-not $next[$k] -or $total -lt $next[$k].Score) { $next[$k] = [pscustomobject]@{ Score = $total; Parts = @($partial.Parts) + @($pick.Parts) } }
					}
				}
			}
			$table = $next
		}
		foreach ($state in $table.Keys) {
			if ([int] ($state -split '\|')[0] -ne $Sup) { continue }
			if (-not $result -or $table[$state].Score -lt $result.Score) { $result = $table[$state] }
		}
	}
	$stack.Remove($Item.Id) | Out-Null
	$memo[$key] = $result
	$result
}

function Find-Slot {
	param($Slot, [int] $Sup, [int] $Allow)
	$best = if ($Sup -eq 0 -and -not $Slot.Required) { [pscustomobject]@{ Score = 0.0; Parts = @() } } else { $null }
	foreach ($c in $Slot.Children) {
		if ($banned.Contains($c.Id)) { continue }
		$r = Find-Best $c $Sup $Allow
		if ($r -and (-not $best -or $r.Score -lt $best.Score)) { $best = $r }
	}
	$best
}

# ---------------------------------------------------------------- report
$selected = @($items.Values | Where-Object Category -eq 'Weapon' | Where-Object {
	$n = $_.Name; @($Weapons | Where-Object { $n -like $_ }).Count
} | Where-Object { -not $Class -or $_.Class -in $Class } | Sort-Object Class, Name)
if (-not $selected.Count) { Write-Error "No weapon matches $($Weapons -join ', ')$(if ($Class) { " in class $($Class -join ', ')" })." }

if ($Trace) {
	foreach ($w in $selected) {
		Write-Host $w.Name -ForegroundColor Cyan
		$found = [System.Collections.Generic.HashSet[string]]::new()
		$queue = [System.Collections.Generic.Queue[object]]::new()
		$queue.Enqueue(@($w))
		$seen = [System.Collections.Generic.HashSet[string]]::new(); $seen.Add($w.Id) | Out-Null
		while ($queue.Count) {
			$path = $queue.Dequeue()
			foreach ($s in $path[-1].Slots) {
				foreach ($c in $s.Children) {
					if ($c.Name -like $Trace -and $found.Add("$($path[-1].Id)|$($c.Id)")) { Write-Host ('  ' + ((@($path) + $c | ForEach-Object Name) -join ' > ')) }
					if ($seen.Add($c.Id)) { $queue.Enqueue(@($path) + $c) }
				}
			}
		}
	}
	return
}

# Parts that list another part of the same build as conflicting, and those other parts.
function Get-Clashes {
	param($Parts)
	$tags = @{}; foreach ($p in $Parts) { if ($p.Tag) { $tags[$p.Tag] = $p } }
	$clash = @{}
	foreach ($p in $Parts) { foreach ($t in $p.Conflicts) { if ($tags[$t]) { $clash[$p.Id] = $p; $clash[$tags[$t].Id] = $tags[$t] } } }
	@($clash.Values | Where-Object Category -ne 'Weapon')
}

# The game refuses parts that conflict, so a build with a conflict is searched again with each of its clashing parts banned in turn.
function Find-Valid {
	param($Weapon, [int] $Sup, [string[]] $Ban, [int] $Depth)
	$banned = [System.Collections.Generic.HashSet[string]]::new([string[]] @($Ban | Where-Object { $_ }))
	$memo = @{}; $stack = [System.Collections.Generic.HashSet[string]]::new()
	$build = Find-Best $Weapon $Sup $allUnique
	if (-not $build) { return $null }
	$clashes = @(Get-Clashes $build.Parts)
	if (-not $clashes.Count) { return $build }
	if ($Depth -ge 4) { return $null }
	$best = $null
	foreach ($c in $clashes) {
		$r = Find-Valid $Weapon $Sup (@($Ban) + $c.Id) ($Depth + 1)
		if ($r -and (-not $best -or $r.Score -lt $best.Score)) { $best = $r }
	}
	$best
}

function Get-Total {
	param($Build, $Weapon)
	if (-not $Build) { return $null }
	$parts = @($Build.Parts)
	$recoil = ($parts | Measure-Object Recoil -Sum).Sum
	$auto = 'Auto' -in $Weapon.Modes
	$tags = @($parts | ForEach-Object Tag)
	$clash = @($parts | Where-Object { $c = $_.Conflicts; @($tags | Where-Object { $_ -in $c }).Count })
	[pscustomobject]@{
		Recoil = $recoil; Ergo = ($parts | Measure-Object Ergo -Sum).Sum
		Text = if ($auto) { '{0:0.#} ({1:0.#}/s)' -f $recoil, ($recoil * $Weapon.Rpm / 700) } else { '{0:0.#}' -f $recoil }
		Parts = @($parts | Select-Object -Skip 1); Clash = $clash.Count -gt 0
	}
}

$rows = foreach ($w in $selected) {
	$builds = @{}
	foreach ($mode in 'Recoil', 'Ergo') {
		$score = $scoreOf[$mode]
		$builds["$mode|Loud"] = Get-Total (Find-Valid $w 0 @() 0) $w
		$builds["$mode|Sup"] = Get-Total (Find-Valid $w 1 @() 0) $w
	}
	$mark = { param($t) if (-not $t) { '-' } elseif ($t.Clash) { "$($t.Text)!" } else { $t.Text } }
	$ergo = { param($t) if (-not $t) { '-' } else { '{0:0.#}' -f $t.Ergo } }
	[pscustomobject]@{
		Weapon = $w.Name; Class = $w.Class
		Fire = if ('Auto' -in $w.Modes) { "auto $([int] $w.Rpm)" } else { 'semi' }
		Base = '{0:0.#} / {1:0.#}' -f $w.Recoil, $w.Ergo
		'Loud' = & $mark $builds['Recoil|Loud']; 'Loud ergo' = & $ergo $builds['Recoil|Loud']
		'Sup' = & $mark $builds['Recoil|Sup']; 'Sup ergo' = & $ergo $builds['Recoil|Sup']
		# A weapon that can't fire without its suppressor has only suppressed builds.
		'Best ergo' = & $ergo $(if ($builds['Ergo|Loud']) { $builds['Ergo|Loud'] } else { $builds['Ergo|Sup'] })
		'Its recoil' = & $mark $(if ($builds['Ergo|Loud']) { $builds['Ergo|Loud'] } else { $builds['Ergo|Sup'] })
		_Builds = $builds
	}
}

$label = if ($Vanilla) { 'vanilla' } else { $Mod }
Write-Host "Lowest-recoil builds (Loud, Sup) and best-ergonomics build, $label. Builds avoid parts that conflict; ! marks one that couldn't." -ForegroundColor Cyan
$rows | Select-Object * -ExcludeProperty _Builds | Format-Table -AutoSize | Out-String -Width 300 | Write-Host

if ($Detail) {
	$fmt = { param($t) if (-not $t) { 'none' } else { ($t.Parts | ForEach-Object { '{0} {1:0.#}/{2:0.#}' -f $_.Name, $_.Recoil, $_.Ergo }) -join ' + ' } }
	foreach ($r in $rows) {
		Write-Host $r.Weapon -ForegroundColor Cyan
		foreach ($k in 'Recoil|Loud', 'Recoil|Sup', 'Ergo|Loud', 'Ergo|Sup') { Write-Host ("  {0,-12} {1}" -f $k.Replace('|', ' '), (& $fmt $r._Builds[$k])) }
	}
}
