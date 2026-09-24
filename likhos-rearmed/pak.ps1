<#
.SYNOPSIS
    Stage the files of the Likho's Rearmed pak.

.DESCRIPTION
    Extracts the game's own DefaultGameplayTags.ini and moves every weapon listed in reclass.json to its new class.
    A weapon's class is the parent of its item tag (Inventory.Items.Weapons.<Class>.<Name>), so a move renames the tag.
    The old tag leaves the tag list and a redirect maps it to the new one. The engine applies redirects when it loads cooked assets and saves, so every item definition, loadout and preset that names the old tag follows.
    Then stages a renamed copy of every cooked asset listed in clone.json, e.g. a mag well that takes 300 BLK mags instead of 5.56 ones.
    Then it extracts every cooked asset listed in retarget.json and points its references to one asset at another, e.g. a weapon's chamber from the 5.56 ammo set to the 300 BLK one.
    Then it extracts every item definition listed in stats.json and sets its stat values, e.g. the 7.62x39 HP round's damage.
    Last, it extracts every NPC loadout preset listed in loadouts.json and sets the weapon pool it picks from.
    Called by build.ps1, which packs the staged tree.
#>
[CmdletBinding()]
param(
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

$reclass = Get-Content (Join-Path $PSScriptRoot 'reclass.json') -Raw | ConvertFrom-Json
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
$work = Join-Path ([System.IO.Path]::GetTempPath()) "likhos-rearmed.$([System.IO.Path]::GetRandomFileName().Split('.')[0])"
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
$clone = Get-Content (Join-Path $PSScriptRoot 'clone.json') -Raw | ConvertFrom-Json
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
$retarget = Get-Content (Join-Path $PSScriptRoot 'retarget.json') -Raw | ConvertFrom-Json
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

$stats = Get-Content (Join-Path $PSScriptRoot 'stats.json') -Raw | ConvertFrom-Json
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
        # Bleeding chance isn't an ItemStats value. It lives on the wound effect that the ChanceToWound stat object points at.
        if ($stat.Name -eq 'BleedingChance') {
            $config = ((Find-Stat 'ChanceToWound').Value | Where-Object Name -eq 'StatItemConfig').Value
            $effect = ($exports[$config - 1].Data | Where-Object Name -eq 'StatEffect').Value
            if ($effect -le 0) { Write-Error "$asset's ChanceToWound stat has no wound effect in the asset." }
            $property = @($exports[$effect - 1].Data | Where-Object Name -eq 'BleedingChance')
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

# ---------------------------------------------------------------- loadouts
# An NPC preset rolls its weapon from the one container whose ItemSpawnChances map weapon tags to weights. The listed pool replaces that map whole.
# Tags are the staged ini's, reclass applied, so the presets don't depend on tag redirects reaching them.
$loadouts = Get-Content (Join-Path $PSScriptRoot 'loadouts.json') -Raw | ConvertFrom-Json
$entries = @($loadouts.PSObject.Properties)
$assets = @(Read-Assets $entries.Name -Parse)
for ($n = 0; $n -lt $entries.Count; $n++) {
    $entry = $entries[$n]
    $asset = $entry.Name
    if ($retarget.PSObject.Properties[$asset] -or $stats.PSObject.Properties[$asset]) { Write-Error "$asset is listed in loadouts.json and another stage." }

    $data = $assets[$n]
    $containers = @((@($data.Exports | Where-Object ObjectName -eq ($asset -split '/')[-1])[0].Data | Where-Object Name -eq 'DefaultItemsContainers').Value)
    $pools = @(foreach ($container in $containers) {
        $parameters = @($container.Value | Where-Object Name -eq 'RandomItemParameters')
        $chances = @($parameters.Value | Where-Object Name -eq 'ItemSpawnChances')
        if (-not $chances.Count -or -not $chances[0].Value.Count) { continue }
        $keys = @($chances[0].Value | ForEach-Object { ($_[0].Value | Where-Object Name -eq 'TagName').Value })
        if (-not @($keys | Where-Object { -not "$_".StartsWith("$weaponsTag.") }).Count) { $chances[0] }
    })
    if ($pools.Count -ne 1) { Write-Error "$asset has $($pools.Count) weapon containers, expected one." }
    $pool = $pools[0]

    $template = $pool.Value[0] | ConvertTo-Json -Depth 100
    $pool.Value = @(foreach ($weapon in $entry.Value.PSObject.Properties) {
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
    Write-Host "  $(($asset -split '/')[-1]): $($pool.Value.Count) weapons"
}

Save-QueuedAssets
Remove-Item $work -Recurse -Force
