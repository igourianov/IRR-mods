<#
.SYNOPSIS
    Package a mod as dist\<mod>.zip and upload it to Nexus Mods as a new version of an existing mod file.

.DESCRIPTION
    Zips the mod folder from this workspace, then publishes it through the Nexus v3 upload
    API under the version in its mod.txt. The zip holds the bare mod folder, so extracting
    it into ue4ss\Mods installs the mod. A pak mod's zip holds ~mods\<pak> from the last
    build.ps1 run instead, so extracting it into Content\Paks installs the mod.

    Needs publish.config.json (mod_id and file_id per mod) and a personal API key in
    nexus-api.key. The mod file must already exist on Nexus: upload the first file by
    hand, then take its file_id from the Files tab URL.

.EXAMPLE
    .\publish.ps1                                   # publish the only configured mod
    .\publish.ps1 likhos-point-and-shoot            # publish one mod
    .\publish.ps1 likhos-point-and-shoot -DryRun    # pack the zip, show the request, upload nothing
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Mod,
    [string] $ApiKey,
    [ValidateSet('main', 'optional', 'miscellaneous')]
    [string] $Category,
    [switch] $NoArchive,
    [switch] $NoBumpModVersion,
    [switch] $Force,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = $PSScriptRoot

$apiRoot = 'https://api.nexusmods.com/v3'
# Anything larger needs a multipart upload, which this script does not implement.
$maxSizeBytes = 100MB

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ---------------------------------------------------------------- helpers
function Get-ApiKey {
    if ($ApiKey) { return $ApiKey }

    $keyPath = Join-Path $root 'nexus-api.key'
    if (-not (Test-Path $keyPath -PathType Leaf)) {
        Write-Error @"
nexus-api.key not found.
Create it next to publish.ps1 holding your personal key from https://www.nexusmods.com/settings/api-keys, or pass -ApiKey.
(It is gitignored - it is a credential.)
"@
    }

    $key = [System.IO.File]::ReadAllText($keyPath).Trim()
    if (-not $key) { Write-Error 'nexus-api.key is empty.' }
    return $key
}

function Get-ModInfo {
    param([string] $Path)

    $text = [System.IO.File]::ReadAllText($Path)
    $info = @{}
    foreach ($key in @('id', 'version')) {
        $m = [regex]::Match($text, "(?m)^\s*$key\s*=\s*`"([^`"]+)`"")
        if (-not $m.Success) { Write-Error "$Path has no $key entry." }
        $info[$key] = $m.Groups[1].Value
    }
    return $info
}

function New-ModArchive {
    param([string] $Source, [string] $Path, [string] $Folder = (Split-Path $Source -Leaf))

    if (Test-Path $Path) { Remove-Item $Path -Force }
    $base = if (Test-Path $Source -PathType Leaf) { Split-Path $Source } else { $Source }

    # Entries are written one by one so their names use '/'. Backslash names extract as flat files outside Windows Explorer.
    $zip = [System.IO.Compression.ZipFile]::Open($Path, 'Create')
    try {
        foreach ($file in Get-ChildItem $Source -Recurse -File) {
            $entry = "$Folder/" + ($file.FullName.Substring($base.Length + 1) -replace '\\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entry) | Out-Null
        }
    } finally {
        $zip.Dispose()
    }
}

function Get-ProblemDetail {
    param($ErrorRecord)

    $response = $ErrorRecord.Exception.Response
    if (-not $response) { return $ErrorRecord.Exception.Message }

    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }

    if (-not $body) { return $ErrorRecord.Exception.Message }
    return "$([int]$response.StatusCode) $body"
}

function Invoke-NexusApi {
    param([string] $Method, [string] $Path, $Body)

    $request = @{
        Method  = $Method
        Uri     = "$apiRoot$Path"
        Headers = @{ apikey = $script:apiKey }
    }
    if ($Body) {
        $request.Body = ($Body | ConvertTo-Json -Depth 4 -Compress)
        $request.ContentType = 'application/json'
    }

    try { $response = Invoke-RestMethod @request }
    catch { Write-Error "$Method $Path failed: $(Get-ProblemDetail $_)" }
    return $response.data
}

function Assert-NewerVersion {
    param([string] $FileId, [string] $Version)

    $live = (Invoke-NexusApi -Method Get -Path "/mod-files/$FileId/versions").versions |
        Where-Object { $_.category -notin @('archived', 'old_version', 'removed') } |
        Select-Object -First 1
    if (-not $live) { return }

    if ($live.version -eq $Version) {
        Write-Error "$Version is already published on mod file $FileId. Build a new version or pass -Force."
    }

    $published = New-Object Version
    $staged = New-Object Version
    if ([Version]::TryParse($live.version, [ref]$published) -and [Version]::TryParse($Version, [ref]$staged) -and $staged -lt $published) {
        Write-Error "$Version is older than the published $($live.version). Pass -Force to publish it anyway."
    }

    Write-Host "replacing $($live.version) -> $Version" -ForegroundColor Yellow
}

# ---------------------------------------------------------------- config
$cfgPath = Join-Path $root 'publish.config.json'
if (-not (Test-Path $cfgPath)) { Write-Error 'publish.config.json not found.' }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json

$entries = $cfg.mods.PSObject.Properties
if (-not $Mod) {
    if (@($entries).Count -ne 1) { Write-Error "Specify a mod. publish.config.json lists: $(($entries | ForEach-Object Name) -join ', ')" }
    $Mod = @($entries)[0].Name
}
# A tab-completed argument like .\likhos-point-and-shoot\ would otherwise miss its config entry.
$Mod = Split-Path $Mod.TrimEnd('\', '/') -Leaf

$entry = $entries[$Mod]
if (-not $entry) { Write-Error "No entry for $Mod in publish.config.json." }
$settings = $entry.Value

$fileId = $settings.file_id
if (-not $fileId) {
    Write-Error @"
No file_id for $Mod in publish.config.json.
Upload the mod's first file on Nexus by hand, then copy file_id out of the Files tab URL:
https://www.nexusmods.com/$($cfg.nexus.game)/mods/$($settings.mod_id)?tab=files
"@
}

# ---------------------------------------------------------------- package
$src = Join-Path $root $Mod
$modTxt = Join-Path $src 'mod.txt'
if (-not (Test-Path $modTxt)) { Write-Error "No such mod: $src (a mod folder must contain mod.txt)." }

$modInfo = Get-ModInfo -Path $modTxt
$modId = $modInfo.id
$version = $modInfo.version

if ($modId -ne $Mod) { Write-Error "$modTxt holds mod id '$modId', not '$Mod'." }
if ($version -notmatch '^[a-zA-Z0-9.-]+$' -or $version.Length -gt 50) {
    Write-Error "Version '$version' is rejected by Nexus. Allowed: letters, digits and .- up to 50 chars."
}

$distDir = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $distDir | Out-Null
$archivePath = Join-Path $distDir "$Mod.zip"
$pakMatch = [regex]::Match([System.IO.File]::ReadAllText($modTxt), '(?m)^\s*pak\s*=\s*"([^"]+)"')
if ($pakMatch.Success) {
    # build.ps1 bumps mod.txt before it packs, so a pak older than any mod file predates the last change.
    $pakPath = Join-Path $distDir $pakMatch.Groups[1].Value
    $newest = Get-ChildItem $src -Recurse -File | Sort-Object LastWriteTime | Select-Object -Last 1
    if (-not (Test-Path $pakPath) -or (Get-Item $pakPath).LastWriteTime -lt $newest.LastWriteTime) {
        Write-Error "$pakPath is missing or older than $($newest.Name). Run .\build.ps1 $Mod first."
    }
    New-ModArchive -Source $pakPath -Path $archivePath -Folder '~mods'
} else {
    New-ModArchive -Source $src -Path $archivePath
}
Write-Host "packed $Mod v$version -> $archivePath" -ForegroundColor Green

$sizeBytes = (Get-Item $archivePath).Length
if ($sizeBytes -gt $maxSizeBytes) {
    Write-Error "$Mod.zip is $([math]::Round($sizeBytes / 1MB, 1)) MiB. Files over 100 MiB need a multipart upload, which this script does not implement."
}

# ---------------------------------------------------------------- publish
$uploadName = "$modId.zip"
$fileCategory = if ($Category) { $Category } elseif ($settings.category) { $settings.category } else { 'main' }
$bumpModVersion = if ($NoBumpModVersion) { $false } elseif ($null -ne $settings.update_mod_version) { [bool]$settings.update_mod_version } else { $true }

$versionRequest = @{
    upload_id                    = $null
    name                         = $uploadName
    version                      = $version
    file_category                = $fileCategory
    archive_existing_file        = (-not $NoArchive)
    update_mod_version           = $bumpModVersion
    primary_mod_manager_download = ($fileCategory -eq 'main')
}

Write-Host "publishing $modId v$version -> mod file $fileId ($fileCategory, $([math]::Round($sizeBytes / 1MB, 2)) MiB)"

if ($DryRun) {
    Write-Host "dry run. POST /mod-files/$fileId/versions would send:" -ForegroundColor Yellow
    Write-Host ($versionRequest | ConvertTo-Json -Depth 4)
    return
}

$script:apiKey = Get-ApiKey
if (-not $Force) { Assert-NewerVersion -FileId $fileId -Version $version }

$upload = Invoke-NexusApi -Method Post -Path '/uploads' -Body @{ size_bytes = $sizeBytes; filename = $uploadName }

# Both headers are part of the presigned signature and must match exactly.
try {
    Invoke-WebRequest -Method Put -Uri $upload.presigned_url -InFile $archivePath -ContentType 'application/octet-stream' `
        -Headers @{ 'Content-Disposition' = "attachment; filename=`"$uploadName`"" } -UseBasicParsing | Out-Null
} catch {
    Write-Error "Upload of $archivePath failed: $(Get-ProblemDetail $_)"
}

$state = (Invoke-NexusApi -Method Post -Path "/uploads/$($upload.id)/finalise").state
$attempts = 0
while ($state -ne 'available') {
    if ($attempts -ge 60) { Write-Error "Upload $($upload.id) is still '$state' after 2 minutes." }
    Start-Sleep -Seconds 2
    $attempts++
    $state = (Invoke-NexusApi -Method Get -Path "/uploads/$($upload.id)").state
}

$versionRequest.upload_id = $upload.id
$created = Invoke-NexusApi -Method Post -Path "/mod-files/$fileId/versions" -Body $versionRequest

Write-Host "published version $($created.version.id)" -ForegroundColor Green
Write-Host "https://www.nexusmods.com/$($cfg.nexus.game)/mods/$($settings.mod_id)"
