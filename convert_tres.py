#!/usr/bin/env python3
import re
import os
import json
from pathlib import Path

# Mapping keywords français → Keyword.Type
KEYWORD_MAP = {
    "REMPART": 0,
    "ASSAUT": 1,
    "PROTECTION": 2,
    "MOISSON": 3,
    "FRÉNÉSIE": 4,
    "VENIN MORTEL": 5,
    "RAVAGE": 6,
    "AILES NOIRES": 7,
    "ÉGIDE": 8,
}

KEYWORD_NAMES = {
    0: "Rempart",
    1: "Assaut",
    2: "Protection",
    3: "Moisson",
    4: "Frénésie",
    5: "Venin mortel",
    6: "Ravage",
    7: "Ailes noires",
    8: "Égide",
}

# Mapping triggers
TRIGGER_MAP = {
    "INVOCATION": "ONPLAY",
    "DERNIER SOUFFLE": "DEATHRATTLE",
    "ASSAUT": "OnAttack",
    "BLESSURE": "OnDamaged",
    "ÉVEIL": "OnAwaken",
    "DÉCLIN": "OnDecline",
    "RALLIEMENT": "RALLY",
    "DEUIL": "MOURNING",
    "SORTILÈGE": "SPELLCAST",
    "SACRIFICE": "SACRIFICE",
    "EXÉCUTION": "OnExecution",
    "CARNAGE": "CARNAGE",
    "MORT-RAGE": "DEATHRATTLE",
}

def extract_keywords_from_desc(desc: str) -> list:
    """Extract keywords from card description."""
    keywords = []
    desc_upper = desc.upper()
    for kw, idx in KEYWORD_MAP.items():
        if kw in desc_upper:
            keywords.append(idx)
    return keywords

def extract_triggers_from_desc(desc: str) -> list:
    """Extract triggers from card description."""
    triggers = []
    desc_upper = desc.upper()
    for kw, trigger in TRIGGER_MAP.items():
        if kw in desc_upper:
            if trigger not in triggers:
                triggers.append(trigger)
    return triggers

def load_tres_file(path: str) -> dict:
    """Load .tres file and parse it."""
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    data = {
        'card_name': '',
        'description': '',
        'cost': 0,
        'attack': 0,
        'health': 0,
        'card_type': 'Minion',
        'rarity': 'Common',
        'board_position': 'Front',
        'keywords': [],
        'trigger_types': [],
        'effects': [],
    }

    # Extract existing data
    patterns = {
        'card_name': r'card_name = "(.*?)"',
        'description': r'description = "(.*?)"',
        'cost': r'cost = (\d+)',
        'attack': r'attack = (\d+)',
        'health': r'health = (\d+)',
        'card_type': r'card_type = "(.*?)"',
        'rarity': r'rarity = "(.*?)"',
        'board_position': r'board_position = "(.*?)"',
    }

    for key, pattern in patterns.items():
        match = re.search(pattern, content)
        if match:
            if key in ['cost', 'attack', 'health']:
                data[key] = int(match.group(1))
            else:
                data[key] = match.group(1)

    return data

def create_tres_content(card_data: dict, card_file: str) -> str:
    """Create .tres file content with KeywordChoice and TriggerTypeChoice."""

    keywords_content = ""
    if card_data['keywords']:
        keyword_resources = []
        for i, kw_idx in enumerate(card_data['keywords']):
            kw_name = KEYWORD_NAMES.get(kw_idx, "")
            keyword_resources.append(f"""[sub_resource type="Resource" script_class="KeywordChoice" id="Keyword_{i}"]
script = ExtResource("KeywordChoice_uid")
name_fr = "{kw_name}"
""")

        keywords_content = "\n".join(keyword_resources)
        keyword_refs = ", ".join([f"SubResource(\"Keyword_{i}\")" for i in range(len(card_data['keywords']))])
    else:
        keyword_refs = ""

    triggers_content = ""
    if card_data['trigger_types']:
        trigger_resources = []
        for i, trigger in enumerate(card_data['trigger_types']):
            trigger_resources.append(f"""[sub_resource type="Resource" script_class="TriggerTypeChoice" id="Trigger_{i}"]
script = ExtResource("TriggerTypeChoice_uid")
type = "{trigger}"
""")

        triggers_content = "\n".join(trigger_resources)
        trigger_refs = ", ".join([f"SubResource(\"Trigger_{i}\")" for i in range(len(card_data['trigger_types']))])
    else:
        trigger_refs = ""

    # Escape description for .tres format
    desc = card_data['description'].replace('"', '\\"')

    board_pos = card_data['board_position']

    tres_content = f"""[gd_resource type="Resource" script_class="CardData" format=3]

[ext_resource type="Script" path="res://scripts/card/CardData.gd" id="CardData_script"]
[ext_resource type="Script" path="res://scripts/card/KeywordChoice.gd" id="KeywordChoice_uid"]
[ext_resource type="Script" path="res://scripts/card/TriggerTypeChoice.gd" id="TriggerTypeChoice_uid"]

{keywords_content}

{triggers_content}

[resource]
script = ExtResource("CardData_script")
card_name = "{card_data['card_name']}"
description = "{desc}"
cost = {card_data['cost']}
attack = {card_data['attack']}
health = {card_data['health']}
card_type = "{card_data['card_type']}"
rarity = "{card_data['rarity']}"
board_position = "{board_pos}"
keywords = [{keyword_refs}]
trigger_types = [{trigger_refs}]
effects = []
"""

    return tres_content.strip()

# Process all .tres files
cards_dir = Path("resources/cards/undead")
converted = 0
errors = []

for tres_file in sorted(cards_dir.glob("*.tres")):
    try:
        card_data = load_tres_file(str(tres_file))

        # Extract keywords and triggers from description
        card_data['keywords'] = extract_keywords_from_desc(card_data['description'])
        card_data['trigger_types'] = extract_triggers_from_desc(card_data['description'])

        # Create new content
        new_content = create_tres_content(card_data, tres_file.name)

        # Write file
        with open(tres_file, 'w', encoding='utf-8') as f:
            f.write(new_content + "\n")

        converted += 1
        print(f"✅ {tres_file.name}")

    except Exception as e:
        errors.append((tres_file.name, str(e)))
        print(f"❌ {tres_file.name}: {e}")

print(f"\n📊 Résultats:")
print(f"✅ Converties: {converted}")
if errors:
    print(f"❌ Erreurs: {len(errors)}")
    for fname, err in errors:
        print(f"  - {fname}: {err}")
