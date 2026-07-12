#!/usr/bin/env python3
import re
import os
from pathlib import Path

# Mapping des noms de cartes à leurs lane types basé sur CARDS.md
CARD_LANE_MAP = {
    # Communes
    "Rampant en Décomposition": "Front",
    "Goule Affamée": "Front",
    "Cadavre Errant": "Hybrid",
    "Zombie Mineur": "Front",
    "Charognard Putride": "Front",
    "Infecté Récent": "Front",
    "Servant Décharné": "Back",
    "Mâcheur d'Os": "Front",
    "Horde Mineure": "Front",
    "Mort-Vivant Enchaîné": "Front",
    "Larve Cadavérique": "Hybrid",
    # Rares
    "Pestilent": "Hybrid",
    "Zombie Bouclier": "Front",
    "Hurleur Nécrotique": "Hybrid",
    "Rongeur de Chair": "Front",
    "Cultiste Zombifié": "Hybrid",
    "Géant Boursouflé": "Front",
    "Émissaire de la Peste": "Hybrid",
    "Soldat Réanimé": "Front",
    "Banshee Zombie": "Back",
    "Possédé Hurlant": "Front",
    "Cavalier Zombie": "Front",
    "Garde du Charnier": "Front",
    # Épiques
    "Le Patient Zéro": "Hybrid",
    "Ravageur Putréfié": "Front",
    "Architecte de la Horde": "Back",
    "Colosse Décomposé": "Front",
    "Esprit Vorace": "Hybrid",
    "Nuée d'Insectes Cadavériques": "Hybrid",
    "Faucheur de la Plaie": "Front",
    "Nécromancien Putride": "Back",
    "Assassin Décharné": "Front",
    "Berserker Infecté": "Front",
    "Tombeau Ambulant": "Front",
    # Légendaires
    "Le Médecin de la Peste": "Back",
    "Roi Liche Zombie": "Front",
    "Apocalypse Zombie": "Front",
    "Léviathan Putréfié": "Front",
    "La Faucheuse": "Front",
}

def get_card_name_from_tres(file_path):
    """Extract card name from .tres file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            match = re.search(r'card_name = "([^"]+)"', content)
            if match:
                return match.group(1)
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
    return None

def update_tres_file(file_path, lane_type):
    """Add or update board_position in .tres file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Check if board_position already exists
        if 'board_position = ' in content:
            # Replace existing
            content = re.sub(
                r'board_position = "[^"]+"',
                f'board_position = "{lane_type}"',
                content
            )
        else:
            # Add new line after card_name
            content = re.sub(
                r'(card_name = "[^"]+")',
                rf'\1\nboard_position = "{lane_type}"',
                content
            )

        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)

        return True
    except Exception as e:
        print(f"Error updating {file_path}: {e}")
        return False

def main():
    card_dir = Path("resources/cards/undead")
    tres_files = sorted(card_dir.glob("*.tres"))

    updated = 0
    not_found = []

    for tres_file in tres_files:
        card_name = get_card_name_from_tres(tres_file)

        if card_name is None:
            print(f"✗ Could not extract name from {tres_file.name}")
            not_found.append(tres_file.name)
            continue

        lane_type = CARD_LANE_MAP.get(card_name)

        if lane_type is None:
            print(f"✗ No lane type found for '{card_name}' ({tres_file.name})")
            not_found.append(card_name)
            continue

        if update_tres_file(tres_file, lane_type):
            print(f"✓ {tres_file.name}: {card_name} → {lane_type}")
            updated += 1
        else:
            print(f"✗ Failed to update {tres_file.name}")

    print(f"\n{updated} files updated successfully")

    if not_found:
        print(f"\n{len(not_found)} cards not updated:")
        for card in not_found:
            print(f"  - {card}")

if __name__ == "__main__":
    main()
