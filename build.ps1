<#
.SYNOPSIS
    Copy mods from this workspace into the game's UE4SS Mods folder.

.DESCRIPTION
    A build bumps the patch segment of the mod's version in mod.txt when the mod folder has uncommitted changes.

.EXAMPLE
    .\build.ps1                             # deploy all mods
    .\build.ps1 likhos-point-and-shoot      # deploy one mod
    .\build.ps1 -Unlink                     # remove deployed mods from the game
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]] $Mods,
    [switch]   $Unlink
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# ---------------------------------------------------------------- config
$cfgPath = Join-Path $root 'build.config.json'
if (-not (Test-Path $cfgPath)) {
    Write-Error @"
build.config.json not found.
Copy build.config.example.json to build.config.json and set your game path.
(It is gitignored - it holds a machine-specific path.)
"@
}
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json

$gameDir = $cfg.game.dir
if (-not (Test-Path $gameDir)) { Write-Error "Game dir not found: $gameDir" }

$modsDir = Join-Path $gameDir $cfg.ue4ss.modsDir
if (-not (Test-Path $modsDir)) {
    Write-Error @"
UE4SS Mods folder not found: $modsDir
Install UE4SS first, launch the game once, and confirm UE4SS.log appears.
"@
}

# ---------------------------------------------------------------- discover
function Get-WorkspaceMods {
    Get-ChildItem -Path $root -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'mod.txt') } |
        Select-Object -ExpandProperty Name
}

if (-not $Mods -or $Mods.Count -eq 0) { $Mods = Get-WorkspaceMods }
if (-not $Mods) { Write-Error 'No mods found (a mod folder must contain mod.txt).' }

# ---------------------------------------------------------------- unlink
if ($Unlink) {
    foreach ($m in $Mods) {
        $dest = Join-Path $modsDir $m
        if (Test-Path $dest) {
            $item = Get-Item $dest -Force
            if ($item.LinkType) { $item.Delete() }
            else { Remove-Item $dest -Recurse -Force }
            Write-Host "removed  $m" -ForegroundColor Yellow
        }
    }
    return
}

# ---------------------------------------------------------------- validate
foreach ($m in $Mods) {
    if (-not (Test-Path (Join-Path $root $m))) { Write-Error "No such mod: $m" }
}

# ---------------------------------------------------------------- deploy
# A version is bumped only when its mod folder has uncommitted changes, so rebuilding unchanged code keeps its version.
# The bumped mod.txt keeps the folder dirty, so later builds bump again until it is committed.
$gitAvailable = (Get-Command git -ErrorAction SilentlyContinue) -and (git -C $root rev-parse --is-inside-work-tree 2>$null) -eq 'true'
if (-not $gitAvailable) { Write-Warning 'Git not available. Every build bumps the version.' }
$versionPattern = '(?m)^(\s*version\s*=\s*")(\d+)\.(\d+)\.(\d+)(")'

foreach ($m in $Mods) {
    $src    = Join-Path $root $m
    $dest   = Join-Path $modsDir $m
    $modTxt = Join-Path $src 'mod.txt'

    $text = [System.IO.File]::ReadAllText($modTxt)
    $match = [regex]::Match($text, $versionPattern)
    $version = $null
    if ($match.Success) {
        $g = $match.Groups
        $majorMinor = "$($g[2].Value).$($g[3].Value)"
        $version = "$majorMinor.$($g[4].Value)"
        if (-not $gitAvailable -or (git -C $root status --porcelain -- $m)) {
            $version = "$majorMinor.$([int]$g[4].Value + 1)"
            $text = $text.Remove($match.Index, $match.Length).Insert($match.Index, "$($g[1].Value)$version$($g[5].Value)")
            [System.IO.File]::WriteAllText($modTxt, $text, [System.Text.UTF8Encoding]::new($false))
        }
    } else {
        Write-Warning "${m}: mod.txt has no version=`"major.minor.patch`" line. Deploying without a version bump."
    }

    if (Test-Path $dest) {
        # A deploy from an older symlink build is removed as a link, so the workspace it points at survives.
        $item = Get-Item $dest -Force
        if ($item.LinkType) { $item.Delete() }
        else { Remove-Item $dest -Recurse -Force }
    }

    Copy-Item $src $dest -Recurse -Force
    $label = if ($version) { "$m v$version" } else { $m }
    Write-Host "copied   $label  -> $dest" -ForegroundColor Green
}

# ---------------------------------------------------------------- mods.txt
# UE4SS reads Mods/mods.txt for load order. Ensure each mod has an entry.
$modsTxt = Join-Path $modsDir 'mods.txt'
$lines = if (Test-Path $modsTxt) { Get-Content $modsTxt } else { @() }
$changed = $false
foreach ($m in $Mods) {
    if (-not ($lines | Where-Object { $_ -match "^\s*$([regex]::Escape($m))\s*:" })) {
        $lines += "$m : 1"
        $changed = $true
    }
}
if ($changed) {
    Set-Content -Path $modsTxt -Value $lines -Encoding ASCII
    Write-Host "mods.txt updated" -ForegroundColor Green
}

Write-Host ''
Write-Host 'Done. Launch the game; the UE4SS console should log the mod loading.'
