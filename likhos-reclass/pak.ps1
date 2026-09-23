<#
.SYNOPSIS
    Stage the files of the Likho's Reclass pak.

.DESCRIPTION
    Extracts the game's own DefaultGameplayTags.ini and moves every weapon listed in reclass.json to its new class.
    A weapon's class is the parent of its item tag (Inventory.Items.Weapons.<Class>.<Name>), so a move renames the tag.
    The old tag leaves the tag list and a redirect maps it to the new one. The engine applies redirects when it loads cooked assets and saves, so every item definition, loadout and preset that names the old tag follows.
    Then extracts every cooked asset listed in retarget.json and points its references to one game asset at another, e.g. a weapon's chamber from the 5.56 ammo set to the 300 BLK one.
    Called by build.ps1, which packs the staged tree.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Repak,
    [Parameter(Mandatory)] [string] $UAssetGUI,
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
    param([string] $Path)
    $pak = Find-GamePak $Path
    & $Repak unpack -q -f -i $Path -o $StageDir $pak
    if ($LASTEXITCODE) { Write-Error "repak failed to extract $Path from $(Split-Path $pak -Leaf)." }
    Join-Path $StageDir $Path
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

# ---------------------------------------------------------------- retarget
# Cooked assets are edited as UAssetGUI JSON. Without a usmap their exports stay raw bytes, so only the name map and the import table are touched.
$work = Join-Path ([System.IO.Path]::GetTempPath()) "likhos-reclass.$([System.IO.Path]::GetRandomFileName().Split('.')[0])"
New-Item -ItemType Directory $work | Out-Null
$json = Join-Path $work 'asset.json'

function Invoke-UAssetGUI {
    param([string[]] $Arguments)
    # A GUI executable: the call operator wouldn't wait for it.
    $process = Start-Process $UAssetGUI -ArgumentList ($Arguments | ForEach-Object { "`"$_`"" }) -Wait -NoNewWindow -PassThru
    if ($process.ExitCode) { Write-Error "UAssetGUI $($Arguments[0]) failed with exit code $($process.ExitCode)." }
}

function Save-Asset {
    param($Data, [string] $Path)
    [System.IO.File]::WriteAllText($json, ($Data | ConvertTo-Json -Depth 100), [System.Text.UTF8Encoding]::new($false))
    Remove-Item $Path, ($Path -replace '\.uasset$', '.uexp') -ErrorAction SilentlyContinue
    Invoke-UAssetGUI 'fromjson', $json, $Path
    # UAssetGUI exits 0 without writing anything when the JSON names an FName that isn't in the name map.
    if (-not (Test-Path $Path)) { Write-Error "UAssetGUI wrote no $Path. A name the edit uses may be missing from the name map." }
}

$retarget = Get-Content (Join-Path $PSScriptRoot 'retarget.json') -Raw | ConvertFrom-Json
foreach ($entry in $retarget.PSObject.Properties) {
    $asset = $entry.Name
    $path = Get-AssetPath $asset
    $uasset = Expand-GameFile "$path.uasset"
    Expand-GameFile "$path.uexp" | Out-Null

    Invoke-UAssetGUI 'tojson', $uasset, $json, $engineVersion
    $data = Get-Content $json -Raw | ConvertFrom-Json

    # An unedited round trip through UAssetGUI and ConvertTo-Json must reproduce the game's bytes, or the edited asset can't be trusted.
    $check = Join-Path $work 'check.uasset'
    Save-Asset $data $check
    foreach ($ext in 'uasset', 'uexp') {
        if ((Get-FileHash (Join-Path $StageDir "$path.$ext")).Hash -ne (Get-FileHash ($check -replace '\.uasset$', ".$ext")).Hash) {
            Write-Error "UAssetGUI doesn't round-trip $asset.$ext unchanged."
        }
    }

    $imports = $data.Imports
    foreach ($ref in $entry.Value.PSObject.Properties) {
        $old = $ref.Name
        $new = $ref.Value
        Find-GamePak "$(Get-AssetPath $new).uasset" | Out-Null

        $at = @(for ($i = 0; $i -lt $imports.Count; $i++) { if ($imports[$i].ClassName -eq 'Package' -and $imports[$i].ObjectName -eq $old) { $i } })
        if ($at.Count -ne 1) { Write-Error "$asset doesn't import $old." }
        $outer = -1 - $at[0]

        # A Blueprint is imported as its class and class default object, any other asset as its object.
        $oldName = ($old -split '/')[-1]
        $newName = ($new -split '/')[-1]
        $names = @{ $oldName = $newName; "${oldName}_C" = "${newName}_C"; "Default__${oldName}_C" = "Default__${newName}_C" }
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
        Write-Host "  $(($asset -split '/')[-1]): $oldName -> $newName"
    }

    Save-Asset $data $uasset
}

Remove-Item $work -Recurse -Force
