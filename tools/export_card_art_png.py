#!/usr/bin/env python3
"""Exporte tous les visuels de cartes (assets/card_art/**/*.jpg) en PNG haute qualité.

Usage:
    python tools/export_card_art_png.py [--output DOSSIER] [--race RACE ...]

Par défaut, écrit dans export/card_art_png/<race>/<slug>.png en conservant
la résolution d'origine (aucun redimensionnement, PNG sans perte).
"""

import argparse
import sys
from pathlib import Path

from PIL import Image

SOURCE_DIR = Path(__file__).resolve().parent.parent / "assets" / "card_art"
DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent.parent / "export" / "card_art_png"


def export_card_art(source_dir: Path, output_dir: Path, races: list[str] | None) -> int:
    if not source_dir.is_dir():
        print(f"Dossier source introuvable : {source_dir}", file=sys.stderr)
        return 0

    race_dirs = sorted(p for p in source_dir.iterdir() if p.is_dir())
    if races:
        wanted = {r.lower() for r in races}
        race_dirs = [p for p in race_dirs if p.name.lower() in wanted]

    exported = 0
    for race_dir in race_dirs:
        jpg_files = sorted(race_dir.glob("*.jpg"))
        if not jpg_files:
            continue

        target_dir = output_dir / race_dir.name
        target_dir.mkdir(parents=True, exist_ok=True)

        for jpg_path in jpg_files:
            png_path = target_dir / (jpg_path.stem + ".png")
            with Image.open(jpg_path) as img:
                img.convert("RGB").save(png_path, format="PNG", optimize=True)
            exported += 1
            print(f"  {jpg_path.relative_to(source_dir)} -> {png_path.relative_to(output_dir)}")

    return exported


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"Dossier de sortie (défaut : {DEFAULT_OUTPUT_DIR})",
    )
    parser.add_argument(
        "--race",
        action="append",
        help="Ne traiter que cette race (répétable). Défaut : toutes.",
    )
    args = parser.parse_args()

    print(f"Source : {SOURCE_DIR}")
    print(f"Sortie : {args.output}")
    count = export_card_art(SOURCE_DIR, args.output, args.race)
    print(f"\n{count} visuel(s) exporté(s) en PNG.")


if __name__ == "__main__":
    main()
