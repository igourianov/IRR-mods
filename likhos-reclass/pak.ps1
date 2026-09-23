<#
.SYNOPSIS
    Stage the files of the Likho's Reclass pak.

.DESCRIPTION
    Extracts the game's own DefaultGameplayTags.ini and moves every weapon listed in reclass.json to its new class.
    A weapon's class is the parent of its item tag (Inventory.Items.Weapons.<Class>.<Name>), so a move renames the tag.
    The old tag leaves the tag list and a redirect maps it to the new one. The engine applies redirects when it loads cooked assets and saves, so every item definition, loadout and preset that names the old tag follows.
    Called by build.ps1, which packs the staged tree.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Repak,
    [Parameter(Mandatory)] [string] $PaksDir,
    [Parameter(Mandatory)] [string] $StageDir
)

$ErrorActionPreference = 'Stop'

$iniPath = 'Test_C/Config/DefaultGameplayTags.ini'
$weaponsTag = 'Inventory.Items.Weapons'

# ---------------------------------------------------------------- extract
# Only the game's own paks are searched. A deployed copy of this mod in ~mods holds an already edited ini.
$sources = @(Get-ChildItem $PaksDir -Filter *.pak -File | Where-Object { (& $Repak list $_.FullName) -contains $iniPath })
if ($sources.Count -ne 1) {
    Write-Error "Expected one game pak holding $iniPath, found $($sources.Count): $($sources.Name -join ', ')"
}

& $Repak unpack -q -f -i $iniPath -o $StageDir $sources[0].FullName
if ($LASTEXITCODE) { Write-Error "repak failed to extract $iniPath from $($sources[0].Name)." }

# ---------------------------------------------------------------- edit
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
