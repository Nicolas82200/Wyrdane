#!/usr/bin/env bash
#
# Incrémente le numéro de version du jeu (VERSION.txt) et synchronise
# les métadonnées de l'exe Windows dans export_presets.cfg.
#
# Equivalent bash de bump_version.ps1 (mêmes fichiers, même logique) —
# pratique quand PowerShell est bloqué (politique d'exécution) ou pour
# lancer le bump directement depuis Git Bash.
#
# Source unique de vérité : VERSION.txt (semver "MAJOR.MINOR.PATCH").
#
# Usage (depuis la racine du dépôt, pas depuis un worktree) :
#   ./tools/bump_version.sh          # bump patch (0.1.0 -> 0.1.1)
#   ./tools/bump_version.sh minor    # bump minor (0.1.0 -> 0.2.0)
#   ./tools/bump_version.sh major    # bump major (0.1.0 -> 1.0.0)

set -euo pipefail

part="${1:-patch}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version_file="$repo_root/VERSION.txt"
export_presets_file="$repo_root/export_presets.cfg"

if [[ "$part" != "major" && "$part" != "minor" && "$part" != "patch" ]]; then
	echo "Erreur : argument invalide '$part' (attendu major, minor ou patch)" >&2
	exit 1
fi

if [[ ! -f "$version_file" ]]; then
	echo "Erreur : VERSION.txt introuvable a la racine du depot ($version_file)" >&2
	exit 1
fi

current="$(tr -d '[:space:]' < "$version_file")"

if [[ ! "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
	echo "Erreur : format de version invalide dans VERSION.txt : '$current' (attendu MAJOR.MINOR.PATCH)" >&2
	exit 1
fi

major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"

case "$part" in
	major) major=$((major + 1)); minor=0; patch=0 ;;
	minor) minor=$((minor + 1)); patch=0 ;;
	patch) patch=$((patch + 1)) ;;
esac

new_version="$major.$minor.$patch"
new_version_windows="$major.$minor.$patch.0"

printf '%s\n' "$new_version" > "$version_file"

if [[ -f "$export_presets_file" ]]; then
	sed -i \
		-e "s/application\/file_version=\"[^\"]*\"/application\/file_version=\"$new_version_windows\"/" \
		-e "s/application\/product_version=\"[^\"]*\"/application\/product_version=\"$new_version_windows\"/" \
		"$export_presets_file"
	echo "export_presets.cfg mis a jour (file_version/product_version = $new_version_windows)"
else
	echo "Attention : export_presets.cfg introuvable, metadonnees de l'exe non mises a jour" >&2
fi

echo "Version : $current -> $new_version"
