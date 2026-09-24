<#
.SYNOPSIS
    Incrémente le numéro de version du jeu (VERSION.txt) et synchronise
    les métadonnées de l'exe Windows dans export_presets.cfg.

.DESCRIPTION
    Source unique de vérité : VERSION.txt (semver "MAJOR.MINOR.PATCH").
    Ce script incrémente une des trois parties, réécrit VERSION.txt, puis
    met à jour application/file_version et application/product_version
    dans export_presets.cfg (format Windows "MAJOR.MINOR.PATCH.0").

    A lancer manuellement avant chaque export/build Steam, depuis la racine
    du dépôt (pas depuis un worktree) :

        .\tools\bump_version.ps1                # bump patch (0.1.0 -> 0.1.1)
        .\tools\bump_version.ps1 -Part minor     # bump minor (0.1.0 -> 0.2.0)
        .\tools\bump_version.ps1 -Part major     # bump major (0.1.0 -> 1.0.0)

.NOTES
    Le nouveau numéro est affiché en fin de script : c'est aussi ce qui
    apparaît en jeu (menu principal) et permet de connaître la version
    sans lancer Godot (contenu de VERSION.txt).
#>

param(
    [ValidateSet("major", "minor", "patch")]
    [string]$Part = "patch"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$versionFile = Join-Path $repoRoot "VERSION.txt"
$exportPresetsFile = Join-Path $repoRoot "export_presets.cfg"

if (-not (Test-Path $versionFile)) {
    throw "VERSION.txt introuvable a la racine du depot ($versionFile)"
}

$current = (Get-Content $versionFile -Raw).Trim()
if ($current -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
    throw "Format de version invalide dans VERSION.txt : '$current' (attendu MAJOR.MINOR.PATCH)"
}

[int]$major = $Matches[1]
[int]$minor = $Matches[2]
[int]$patch = $Matches[3]

switch ($Part) {
    "major" { $major++; $minor = 0; $patch = 0 }
    "minor" { $minor++; $patch = 0 }
    "patch" { $patch++ }
}

$newVersion = "$major.$minor.$patch"
$newVersionWindows = "$major.$minor.$patch.0"

Set-Content -Path $versionFile -Value $newVersion -Encoding utf8 -NoNewline
Add-Content -Path $versionFile -Value "`n" -Encoding utf8

if (Test-Path $exportPresetsFile) {
    $content = Get-Content $exportPresetsFile -Raw
    $content = $content -replace 'application/file_version="[^"]*"', "application/file_version=`"$newVersionWindows`""
    $content = $content -replace 'application/product_version="[^"]*"', "application/product_version=`"$newVersionWindows`""
    Set-Content -Path $exportPresetsFile -Value $content -Encoding utf8 -NoNewline
    Write-Host "export_presets.cfg mis a jour (file_version/product_version = $newVersionWindows)"
} else {
    Write-Warning "export_presets.cfg introuvable, metadonnees de l'exe non mises a jour"
}

Write-Host "Version : $current -> $newVersion"
