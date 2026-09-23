<#
.SYNOPSIS
    Copy mods from this workspace into the game's UE4SS Mods folder, or build and install pak mods.

.DESCRIPTION
    A build bumps the patch segment of the mod's version in mod.txt when the mod folder has uncommitted changes.
    A mod whose mod.txt names a pak is a pak mod. Its pak.ps1 stages the files, repak packs them into dist\<pak> and the pak is copied into Content\Paks\~mods.
    repak is downloaded into tools\repak on first use.
    Packaging and release live in publish.ps1.

.EXAMPLE
    .\build.ps1                             # deploy all mods
    .\build.ps1 likhos-point-and-shoot      # deploy one mod
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]] $Mods
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

$paksDir = Join-Path $gameDir "$($cfg.game.module)\Content\Paks"
$distDir = Join-Path $root 'dist'

# ---------------------------------------------------------------- repak
# Pinned so a pak build is reproducible. $pakVersion must match the game's own paks (repak info on a game pak).
$repakVersion = 'v0.2.3'
$repakSha256 = '6720d602144d75df477a99d5bedb6ea780997546afc335901d4937cafeaa73fa'
$pakVersion = 'V11'

function Get-Repak {
    $dir = Join-Path $root 'tools\repak'
    $exe = Join-Path $dir 'repak.exe'
    if (Test-Path $exe) { return $exe }

    $zip = Join-Path $root "tmp.$([System.IO.Path]::GetRandomFileName().Split('.')[0]).zip"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest "https://github.com/trumank/repak/releases/download/$repakVersion/repak_cli-x86_64-pc-windows-msvc.zip" -OutFile $zip
    $hash = (Get-FileHash $zip -Algorithm SHA256).Hash
    if ($hash -ne $repakSha256) { Write-Error "repak $repakVersion download has SHA256 $hash, expected $repakSha256. Left at $zip." }
    Expand-Archive $zip $dir -Force
    Remove-Item $zip
    Write-Host "fetched  repak $repakVersion -> $dir"
    return $exe
}

# ---------------------------------------------------------------- discover
function Get-WorkspaceMods {
    Get-ChildItem -Path $root -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'mod.txt') } |
        Select-Object -ExpandProperty Name
}

if (-not $Mods -or $Mods.Count -eq 0) { $Mods = Get-WorkspaceMods }
if (-not $Mods) { Write-Error 'No mods found (a mod folder must contain mod.txt).' }

# ---------------------------------------------------------------- validate
# A tab-completed argument like .\likhos-point-and-shoot\ would otherwise leak into deploy paths.
$Mods = $Mods | ForEach-Object { Split-Path $_.TrimEnd('\', '/') -Leaf }
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

    $label = if ($version) { "$m v$version" } else { $m }
    $pakMatch = [regex]::Match($text, '(?m)^\s*pak\s*=\s*"([^"]+)"')

    if ($pakMatch.Success) {
        $pak = $pakMatch.Groups[1].Value
        $repak = Get-Repak
        $stage = Join-Path ([System.IO.Path]::GetTempPath()) "$m.$([System.IO.Path]::GetRandomFileName().Split('.')[0])"
        New-Item -ItemType Directory $stage | Out-Null
        & (Join-Path $src 'pak.ps1') -Repak $repak -PaksDir $paksDir -StageDir $stage

        New-Item -ItemType Directory -Force $distDir | Out-Null
        $pakPath = Join-Path $distDir $pak
        & $repak pack -q --version $pakVersion --mount-point '../../../' $stage $pakPath
        if ($LASTEXITCODE) { Write-Error "repak failed to pack $pakPath from $stage." }
        Remove-Item $stage -Recurse -Force

        $pakDest = Join-Path $paksDir '~mods'
        New-Item -ItemType Directory -Force $pakDest | Out-Null
        Copy-Item $pakPath $pakDest -Force
        Write-Host "packed   $label  -> $(Join-Path $pakDest $pak)" -ForegroundColor Green
    } else {
        if (Test-Path $dest) {
            # A deploy from an older symlink build is removed as a link, so the workspace it points at survives.
            $item = Get-Item $dest -Force
            if ($item.LinkType) { $item.Delete() }
            else { Remove-Item $dest -Recurse -Force }
        }

        Copy-Item $src $dest -Recurse -Force
        Write-Host "copied   $label  -> $dest" -ForegroundColor Green
    }
}

Write-Host ''
Write-Host 'Done. Launch the game; the UE4SS console should log the mod loading.'
