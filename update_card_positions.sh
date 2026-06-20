#!/bin/bash

# Update board_position for all .tres card files

declare -A LANES=(
    ["Rampant en Décomposition"]="Front"
    ["Goule Affamée"]="Front"
    ["Cadavre Errant"]="Hybrid"
    ["Zombie Mineur"]="Front"
    ["Charognard Putride"]="Front"
    ["Infecté Récent"]="Front"
    ["Servant Décharné"]="Back"
    ["Mâcheur d'Os"]="Front"
    ["Horde Mineure"]="Front"
    ["Mort-Vivant Enchaîné"]="Front"
    ["Larve Cadavérique"]="Hybrid"
    ["Pestilent"]="Hybrid"
    ["Zombie Bouclier"]="Front"
    ["Hurleur Nécrotique"]="Hybrid"
    ["Rongeur de Chair"]="Front"
    ["Cultiste Zombifié"]="Hybrid"
    ["Géant Boursouflé"]="Front"
    ["Émissaire de la Peste"]="Hybrid"
    ["Soldat Réanimé"]="Front"
    ["Banshee Zombie"]="Back"
    ["Possédé Hurlant"]="Front"
    ["Cavalier Zombie"]="Front"
    ["Garde du Charnier"]="Front"
    ["Le Patient Zéro"]="Hybrid"
    ["Ravageur Putréfié"]="Front"
    ["Architecte de la Horde"]="Back"
    ["Colosse Décomposé"]="Front"
    ["Esprit Vorace"]="Hybrid"
    ["Nuée d'Insectes Cadavériques"]="Hybrid"
    ["Faucheur de la Plaie"]="Front"
    ["Nécromancien Putride"]="Back"
    ["Assassin Décharné"]="Front"
    ["Berserker Infecté"]="Front"
    ["Tombeau Ambulant"]="Front"
    ["Le Médecin de la Peste"]="Back"
    ["Roi Liche Zombie"]="Front"
    ["Apocalypse Zombie"]="Front"
    ["Léviathan Putréfié"]="Front"
    ["La Faucheuse"]="Front"
)

cd "e:/card-game"

updated=0
not_found=0

for file in resources/cards/undead/*.tres; do
    # Extract card name
    card_name=$(grep -o 'card_name = "[^"]*"' "$file" | sed 's/card_name = "//;s/"$//')

    if [ -z "$card_name" ]; then
        echo "✗ Could not extract name from $(basename $file)"
        not_found=$((not_found + 1))
        continue
    fi

    lane_type="${LANES[$card_name]}"

    if [ -z "$lane_type" ]; then
        echo "✗ No lane type for '$card_name'"
        not_found=$((not_found + 1))
        continue
    fi

    # Check if board_position exists
    if grep -q "^board_position = " "$file"; then
        # Replace existing
        sed -i "s/^board_position = .*/board_position = \"$lane_type\"/" "$file"
    else
        # Add after card_name line
        sed -i "/^card_name = /a board_position = \"$lane_type\"" "$file"
    fi

    echo "✓ $(basename $file): $card_name → $lane_type"
    updated=$((updated + 1))
done

echo ""
echo "$updated files updated"
if [ $not_found -gt 0 ]; then
    echo "$not_found cards not found"
fi
