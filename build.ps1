<#
.SYNOPSIS
    Deploy mods from this workspace into the game's UE4SS Mods folder.

.DESCRIPTION
    Symlinks mode is the default for development: edit here, hot-reload in game
    with Ctrl+R in the UE4SS console. Use -Copy for a clean install test.

.EXAMPLE
    .\build.ps1                      # deploy all mods as symlinks
    .\build.ps1 likhos-point-and-shoot      # deploy one mod
    .\build.ps1 -Copy                # real copies instead of symlinks
    .\build.ps1 -Unlink              # remove deployed mods from the game
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]] $Mods,
    [switch]   $Copy,
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
foreach ($m in $Mods) {
    $src  = Join-Path $root $m
    $dest = Join-Path $modsDir $m

    if (Test-Path $dest) {
        $item = Get-Item $dest -Force
        if ($item.LinkType) { $item.Delete() }
        else { Remove-Item $dest -Recurse -Force }
    }

    if ($Copy) {
        Copy-Item $src $dest -Recurse -Force
        Write-Host "copied   $m  -> $dest" -ForegroundColor Green
    } else {
        try {
            New-Item -ItemType SymbolicLink -Path $dest -Target $src -Force | Out-Null
            Write-Host "linked   $m  -> $dest" -ForegroundColor Green
        } catch {
            Write-Warning @"
Symlink failed. Either run this shell as Administrator, or enable
Windows Developer Mode (Settings > System > For developers), or use -Copy.
"@
            throw
        }
    }
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
