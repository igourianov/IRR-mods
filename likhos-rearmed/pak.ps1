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
    # Name of the game's usmap in UAssetGUI's mappings folder.
    [Parameter(Mandatory)] [string] $Mappings,
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

function Expand-GameFile {
    param([string] $Path, [string] $To = $StageDir)
    $pak = Find-GamePak $Path
    & $Repak unpack -q -f -i $Path -o $To $pak
    if ($LASTEXITCODE) { Write-Error "repak failed to extract $Path from $(Split-Path $pak -Leaf)." }
    Join-Path $To $Path
}

function Get-AssetPath {
    param([string] $Package)
    if (-not $Package.StartsWith('/Game/')) { Write-Error "$Package is not a /Game/ package." }
    "$contentDir/$($Package.Substring(6))"
}

# ---------------------------------------------------------------- reclass
$file = Expand-GameFile $iniPath
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
$json = Join-Path $work 'asset.json'

function Invoke-UAssetGUI {
    param([string[]] $Arguments)
    # A GUI executable: the call operator wouldn't wait for it.
    $process = Start-Process $UAssetGUI -ArgumentList ($Arguments | ForEach-Object { "`"$_`"" }) -Wait -NoNewWindow -PassThru
    if ($process.ExitCode) { Write-Error "UAssetGUI $($Arguments[0]) failed with exit code $($process.ExitCode)." }
}

function Save-Asset {
    param($Data, [string] $Path, [switch] $Parse)
    [System.IO.File]::WriteAllText($json, ($Data | ConvertTo-Json -Depth 100), [System.Text.UTF8Encoding]::new($false))
    Remove-Item $Path, ($Path -replace '\.uasset$', '.uexp') -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
    Invoke-UAssetGUI (@('fromjson', $json, $Path) + @(if ($Parse) { $Mappings }))
    # UAssetGUI exits 0 without writing anything when the JSON names an FName that isn't in the name map.
    if (-not (Test-Path $Path)) { Write-Error "UAssetGUI wrote no $Path. A name the edit uses may be missing from the name map." }
}

function Read-Asset {
    param([string] $Package, [switch] $Parse)
    $path = Get-AssetPath $Package
    $uasset = Expand-GameFile "$path.uasset" $work
    Expand-GameFile "$path.uexp" $work | Out-Null

    Invoke-UAssetGUI (@('tojson', $uasset, $json, $engineVersion) + @(if ($Parse) { $Mappings }))
    $data = Get-Content $json -Raw | ConvertFrom-Json

    # An unedited round trip through UAssetGUI and ConvertTo-Json must reproduce the game's bytes, or the edited asset can't be trusted.
    $check = Join-Path $work 'check.uasset'
    Save-Asset $data $check -Parse:$Parse
    foreach ($ext in 'uasset', 'uexp') {
        if ((Get-FileHash (Join-Path $work "$path.$ext")).Hash -ne (Get-FileHash ($check -replace '\.uasset$', ".$ext")).Hash) {
            Write-Error "UAssetGUI doesn't round-trip $Package.$ext unchanged."
        }
    }
    $data
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
foreach ($entry in $clone.PSObject.Properties) {
    $new = $entry.Name
    $source = $entry.Value.from
    $path = Get-AssetPath $new
    if (@($paks.Values | Where-Object { $_.Contains("$path.uasset") }).Count) { Write-Error "$new already exists in the game's paks." }

    $data = Read-Asset $source
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
foreach ($entry in $retarget.PSObject.Properties) {
    $asset = $entry.Name
    $data = Read-Asset $asset
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
foreach ($entry in $stats.PSObject.Properties) {
    $asset = $entry.Name
    # Both stages start from the game's copy, so the second write would drop the first one's edits.
    if ($retarget.PSObject.Properties[$asset]) { Write-Error "$asset is listed in both retarget.json and stats.json." }

    $data = Read-Asset $asset -Parse
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
foreach ($entry in $loadouts.PSObject.Properties) {
    $asset = $entry.Name
    if ($retarget.PSObject.Properties[$asset] -or $stats.PSObject.Properties[$asset]) { Write-Error "$asset is listed in loadouts.json and another stage." }

    $data = Read-Asset $asset -Parse
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

Remove-Item $work -Recurse -Force
