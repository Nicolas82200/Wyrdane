
import os, random, string

BASE_DIR = r"E:\card-game\resources\cards"

UNDEAD_DIR = os.path.join(BASE_DIR, "undead")
HUMAN_DIR = os.path.join(BASE_DIR, "human")

os.makedirs(UNDEAD_DIR, exist_ok=True)
os.makedirs(HUMAN_DIR, exist_ok=True)

print("Répertoire courant :", os.getcwd())
def uid():
    chars = string.ascii_lowercase + string.digits
    return "uid://" + "".join(random.choices(chars, k=13))

# Shared ext resource UIDs (stable)
CARDEFFECT_UID = "uid://ddqetdlahmfmu"
KEYWORDCHOICE_UID = "uid://cbo6rhh3g8djf"
CARDDATA_UID = "uid://bru7ohxxvloht"
TRIGGERTYPE_UID = "uid://ib4p8n6y0r0j"

KW_MAP = {
    "REMPART": "Rempart",
    "ASSAUT": "Assaut",
    "FRÉNÉSIE": "Frénésie",
    "RAVAGE": "Ravage",
    "AILES NOIRES": "Ailes noires",
    "MOISSON": "Moisson",
    "VENIN MORTEL": "Venin mortel",
    "ÉGIDE": "Égide",
    "DISCIPLINE": "Rempart",   # pas encore dans l'enum, on skip ou on mappe
    "FORMATION": "Rempart",    # idem
    "CONTRE-ATTAQUE": "Rempart",
    "COMMANDEMENT": "Rempart",
    "FORTIFICATION": "Rempart",
}

# Only real keywords in Keyword.Type enum
VALID_KW = {"Rempart", "Assaut", "Égide", "Moisson", "Frénésie", "Venin mortel", "Ravage", "Ailes noires"}

TRIGGER_MAP = {
    "Arrivée": "ONPLAY",
    "Dernier Souffle": "DEATHRATTLE",
    "Mort-rage": "OnDeathRage",
    "Blessure": "OnDamaged",
    "Exécution": "OnExecution",
    "Ralliement": "OnAttack",
    "Éveil": "OnAwaken",
    "Deuil": "OnGrief",
    "Carnage": "OnCarnage",
    "Sortilège": "OnSpell",
    "Appel": "OnSummon",
    "Présence": "OnAura",
    "Résonance": "OnAttack",
    "Sacrifice": "OnSacrifice",
}

UNIT_STYLE = {
    "ZOMBIE": 0, "MAJOR_ZOMBIE": 1, "ABOMINATION": 2,
    "SPECTRAL": 3, "DEATH_KNIGHT": 4,
    "KNIGHT": 5, "ARCHER": 6, "MAGE": 7, "PALADIN": 8,
}

RARITY_MAP = {"Commune": "Common", "Rare": "Rare", "Épique": "Epic", "Légendaire": "Legendary"}
RACE_UNDEAD = 4  # Race.Type.UNDEAD
RACE_HUMAN = 1   # Race.Type.HUMAN

def res_uid():
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=5))

def make_tres(filename, card_uid, race, unit_style_int,
              card_name, description, flavour_text,
              texture_path, cost, attack, health,
              card_type,  # "Minion","Instant","Ritual","Enchantment"
              keywords,   # list of str from VALID_KW
              triggers,   # list of str (TriggerType string)
              effects,    # list of dict {effect_id, target, value, value2, count, summon_path}
              rarity, board_position, requires_target=False):

    lines = []
    lines.append(f'[gd_resource type="Resource" script_class="CardData" format=3 uid="{card_uid}"]')
    lines.append("")

    # ext resources
    kw_id_str = None
    trig_id_str = None
    effect_id_strs = []

    has_effect = len(effects) > 0
    has_kw = len(keywords) > 0
    has_trig = len(triggers) > 0

    # Always include CardEffect script if effects
    n = 1
    effect_script_id = f"1_cardeffect"
    lines.append(f'[ext_resource type="Script" uid="{CARDEFFECT_UID}" path="res://scripts/card/CardEffect.gd" id="{effect_script_id}"]')
    n += 1

    kw_script_id = f"2_kw"
    lines.append(f'[ext_resource type="Script" uid="{KEYWORDCHOICE_UID}" path="res://scripts/card/KeywordChoice.gd" id="{kw_script_id}"]')
    n += 1

    tex_id = f"3_texture"
    lines.append(f'[ext_resource type="Texture2D" uid="{uid()}" path="{texture_path}" id="{tex_id}"]')
    n += 1

    cd_id = "4_carddata"
    lines.append(f'[ext_resource type="Script" uid="{CARDDATA_UID}" path="res://scripts/card/CardData.gd" id="{cd_id}"]')
    n += 1

    trig_id = "5_trig"
    lines.append(f'[ext_resource type="Script" uid="{TRIGGERTYPE_UID}" path="res://scripts/card/TriggerTypeChoice.gd" id="{trig_id}"]')

    # summon card ext resources
    summon_refs = {}
    summon_n = 6
    for eff in effects:
        sp = eff.get("summon_path")
        if sp and sp not in summon_refs:
            sid = f"{summon_n}_summon"
            summon_refs[sp] = sid
            lines.append(f'[ext_resource type="Resource" uid="{uid()}" path="{sp}" id="{sid}"]')
            summon_n += 1

    lines.append("")

    # sub_resources for keywords
    kw_sub_ids = []
    for kw in keywords:
        rid = f"Resource_{res_uid()}"
        kw_sub_ids.append((rid, kw))
        lines.append(f'[sub_resource type="Resource" id="{rid}"]')
        lines.append(f'script = ExtResource("{kw_script_id}")')
        lines.append(f'name_fr = "{kw}"')
        lines.append("")

    # sub_resources for triggers
    trig_sub_ids = []
    for t in triggers:
        rid = f"Resource_{res_uid()}"
        trig_sub_ids.append((rid, t))
        lines.append(f'[sub_resource type="Resource" id="{rid}"]')
        lines.append(f'script = ExtResource("{trig_id}")')
        lines.append(f'type = "{t}"')
        lines.append("")

    # sub_resources for effects
    eff_sub_ids = []
    for eff in effects:
        rid = f"Resource_{res_uid()}"
        eff_sub_ids.append(rid)
        lines.append(f'[sub_resource type="Resource" id="{rid}"]')
        lines.append(f'script = ExtResource("{effect_script_id}")')
        if eff.get("effect_id"):
            lines.append(f'effect_id = "{eff["effect_id"]}"')
        if eff.get("target"):
            lines.append(f'target = "{eff["target"]}"')
        if eff.get("value"):
            lines.append(f'value = {eff["value"]}')
        if eff.get("value2"):
            lines.append(f'value_2 = {eff["value2"]}')
        if eff.get("count") and eff["count"] != 1:
            lines.append(f'count = {eff["count"]}')
        if eff.get("summon_path"):
            lines.append(f'summon_card = ExtResource("{summon_refs[eff["summon_path"]]}")')
        lines.append(f'metadata/_custom_type_script = "{CARDEFFECT_UID}"')
        lines.append("")

    # main resource
    lines.append("[resource]")
    lines.append(f'script = ExtResource("{cd_id}")')
    lines.append(f'card_name = "{card_name}"')
    lines.append(f'description = "{description}"')
    if flavour_text:
        lines.append(f'flavour_text = "{flavour_text}"')
    lines.append(f'texture = ExtResource("{tex_id}")')
    lines.append(f'cost = {cost}')
    lines.append(f'race = {race}')
    lines.append(f'unit_style = {unit_style_int}')
    if card_type != "Minion":
        lines.append(f'card_type = "{card_type}"')
    lines.append(f'attack = {attack}')
    lines.append(f'health = {health}')
    if kw_sub_ids:
        kw_arr = ", ".join(f'SubResource("{r}")' for r, _ in kw_sub_ids)
        lines.append(f'keywords = Array[ExtResource("{kw_script_id}")]([{kw_arr}])')
    if trig_sub_ids:
        tr_arr = ", ".join(f'SubResource("{r}")' for r, _ in trig_sub_ids)
        lines.append(f'trigger_types = Array[ExtResource("{trig_id}")]([{tr_arr}])')
    if eff_sub_ids:
        ef_arr = ", ".join(f'SubResource("{r}")' for r in eff_sub_ids)
        lines.append(f'effects = Array[ExtResource("{effect_script_id}")]([{ef_arr}])')
    if requires_target:
        lines.append(f'requires_target = true')
    if rarity != "Common":
        lines.append(f'rarity = "{rarity}"')
    if board_position != "Front":
        lines.append(f'board_position = "{board_position}"')
    lines.append(f'metadata/_custom_type_script = "{CARDDATA_UID}"')

    content = "\n".join(lines) + "\n"
    path = os.path.join(OUT, filename)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    print(f"  ✅ {filename}")

# ─── MORT-VIVANTS ─────────────────────────────────────────────────────────────
print("\n=== MORT-VIVANTS ===")
DECAYING = "res://resources/cards/undead/decaying-crawler.tres"
WANDERING = "res://resources/cards/undead/wandering-corpse.tres"
MINOR_HORDE_SUMMON = "res://resources/cards/undead/minor-horde-summon.tres"

# 01 Rampant en Décomposition
make_tres("decaying-crawler.tres", uid(), RACE_UNDEAD, 0,
    "Rampant en Décomposition",
    "Dernier Souffle : infecte la carte du dessus du deck ennemi (entre en jeu comme Zombie 1/1 sous ton contrôle).",
    "Il ne sait plus pourquoi il avance. Il avance, c'est tout.",
    "res://assets/card_art/undead/decaying-crawler.jpg",
    1, 1, 1, "Minion", [], ["DEATHRATTLE"], [], "Common", "Front")

# 02 Goule Affamée
make_tres("famished-ghoul.tres", uid(), RACE_UNDEAD, 0,
    "Goule Affamée",
    "—",
    "La faim ne disparaît pas avec la mort. Elle empire.",
    "res://assets/card_art/undead/famished-ghoul.jpg",
    1, 2, 1, "Minion", [], [], [], "Common", "Front")

# 03 Cadavre Errant
make_tres("wandering-corpse.tres", uid(), RACE_UNDEAD, 0,
    "Cadavre Errant",
    "REMPART.",
    "Personne ne se souvient de son nom. Lui non plus.",
    "res://assets/card_art/undead/wandering-corpse.jpg",
    2, 1, 3, "Minion", ["Rempart"], [], [], "Common", "Hybrid")

# 04 Zombie Mineur
make_tres("minor-zombie.tres", uid(), RACE_UNDEAD, 0,
    "Zombie Mineur",
    "—",
    "Il était enfant. C'était avant.",
    "res://assets/card_art/undead/minor-zombie.jpg",
    2, 2, 2, "Minion", [], [], [], "Common", "Front")

# 05 Charognard Putride
make_tres("putrid-scavenger.tres", uid(), RACE_UNDEAD, 0,
    "Charognard Putride",
    "Dernier Souffle : inflige Infection à un serviteur ennemi adjacent.",
    "Même en tombant, il répand ce qui l'a tué.",
    "res://assets/card_art/undead/putrid-scavenger.jpg",
    2, 3, 1, "Minion", [], ["DEATHRATTLE"],
    [{"effect_id": "InfectAdjacent", "target": "Self"}], "Common", "Front")

# 06 Infecté Récent
make_tres("recently-infected.tres", uid(), RACE_UNDEAD, 0,
    "Infecté Récent",
    "Mort-rage : +1/+1 par ennemi infecté en jeu.",
    "La morsure date d'hier. Il a encore ses yeux d'avant — mais plus rien derrière.",
    "res://assets/card_art/undead/recently-infected.jpg",
    2, 2, 2, "Minion", [], ["OnDeathRage"],
    [{"effect_id": "BuffIfCondition", "target": "PerInfectedEnemy", "value": 1, "value2": 1}],
    "Common", "Front")

# 07 Servant Décharné
make_tres("gaunt-servant.tres", uid(), RACE_UNDEAD, 1,
    "Servant Décharné",
    "Ralliement : tes serviteurs en rangée Avant ont +0/+1 HP.",
    "Il ne commande pas. Il pousse. Et ça suffit.",
    "res://assets/card_art/undead/gaunt-servant.jpg",
    3, 2, 4, "Minion", [], ["RALLY"],
    [{"effect_id": "Buff", "target": "AllAlliesFront", "value2": 1}],
    "Common", "Back")

# 08 Mâcheur d'Os
make_tres("bone-chewer.tres", uid(), RACE_UNDEAD, 2,
    "Mâcheur d'Os",
    "ASSAUT. Ralliement : inflige 1 dégât splash aux serviteurs adjacents à la cible.",
    "Le craquement des os est le seul son qu'il comprend encore.",
    "res://assets/card_art/undead/bone-chewer.jpg",
    3, 4, 2, "Minion", ["Assaut"], ["OnAttack"],
    [{"effect_id": "SplashDamage", "target": "EnemyMinion", "value": 1}],
    "Common", "Front")

# 09 Horde Mineure
make_tres("minor-horde.tres", uid(), RACE_UNDEAD, 0,
    "Horde Mineure",
    "Arrivée : invoque 2 Rampants 1/1 en rangée Avant.",
    "Un seul ne fait pas peur. Mais il n'est jamais seul.",
    "res://assets/card_art/undead/minor-horde.jpg",
    3, 1, 1, "Minion", [], ["ONPLAY"],
    [{"effect_id": "SummonMinion", "summon_path": DECAYING, "count": 2}],
    "Common", "Hybrid")

# 10 Mort-Vivant Enchaîné
make_tres("chained-undead.tres", uid(), RACE_UNDEAD, 0,
    "Mort-Vivant Enchaîné",
    "—",
    "Les chaînes ne le retiennent plus. Elles font partie de lui.",
    "res://assets/card_art/undead/chained-undead.jpg",
    3, 3, 3, "Minion", [], [], [], "Common", "Front")

# 11 Larve Cadavérique
make_tres("cadaverous-larva.tres", uid(), RACE_UNDEAD, 18,
    "Larve Cadavérique",
    "Dernier Souffle : le serviteur allié adjacent gagne +1/+1.",
    "Elle n'est pas née de la vie. Elle est née de ce qui reste.",
    "res://assets/card_art/undead/cadaverous-larva.jpg",
    1, 1, 1, "Minion", [], ["DEATHRATTLE"],
    [{"effect_id": "BuffAdjacent", "target": "Self", "value": 1, "value2": 1}],
    "Common", "Hybrid")

# 12 Pestilent
make_tres("pestilent-one.tres", uid(), RACE_UNDEAD, 0,
    "Pestilent",
    "Arrivée : inflige Infection à un serviteur ennemi ciblé.",
    "Son souffle est une condamnation à retardement.",
    "res://assets/card_art/undead/pestilent-one.jpg",
    2, 1, 2, "Minion", [], ["ONPLAY"],
    [{"effect_id": "InfectEnemy", "target": "EnemyMinion"}],
    "Rare", "Hybrid", True)

# 13 Zombie Bouclier
make_tres("shield-zombie.tres", uid(), RACE_UNDEAD, 0,
    "Zombie Bouclier",
    "REMPART. Blessure : réduit de 1 les dégâts reçus (minimum 1).",
    "Les lames s'enfoncent dans la chair morte et s'y perdent.",
    "res://assets/card_art/undead/shield-zombie.jpg",
    2, 1, 5, "Minion", ["Rempart"], ["OnDamaged"], [], "Rare", "Front")

# 14 Hurleur Nécrotique
make_tres("necrotic-howler.tres", uid(), RACE_UNDEAD, 0,
    "Hurleur Nécrotique",
    "Arrivée : serviteurs Mort-Vivants alliés en rangée Avant +1/+0 jusqu'à fin de tour.",
    "Son cri ne terrorise plus. Il réveille.",
    "res://assets/card_art/undead/necrotic-howler.jpg",
    3, 3, 2, "Minion", [], ["ONPLAY"],
    [{"effect_id": "Buff", "target": "AllAlliesFront", "value": 1}],
    "Rare", "Hybrid")

# 15 Rongeur de Chair
make_tres("flesh-gnawer.tres", uid(), RACE_UNDEAD, 0,
    "Rongeur de Chair",
    "Exécution : peut attaquer à nouveau une fois par tour.",
    "Il ne s'arrête pas quand la proie tombe. Il s'arrête quand il ne reste plus rien.",
    "res://assets/card_art/undead/flesh-gnawer.jpg",
    4, 5, 3, "Minion", [], ["OnExecution"], [], "Rare", "Front")

# 16 Cultiste Zombifié
make_tres("zombified-cultist.tres", uid(), RACE_UNDEAD, 1,
    "Cultiste Zombifié",
    "Dernier Souffle : invoque un Cadavre Errant en rangée Avant.",
    "Il a prié pour la mort éternelle. Il a été exaucé — à moitié.",
    "res://assets/card_art/undead/zombified-cultist.jpg",
    2, 1, 2, "Minion", [], ["DEATHRATTLE"],
    [{"effect_id": "SummonMinion", "summon_path": WANDERING}],
    "Rare", "Hybrid")

# 17 Géant Boursouflé
make_tres("bloated-giant.tres", uid(), RACE_UNDEAD, 2,
    "Géant Boursouflé",
    "Dernier Souffle : inflige 2 dégâts à tous les serviteurs ennemis en rangée Avant.",
    "Sa mort est plus dangereuse que sa vie.",
    "res://assets/card_art/undead/bloated-giant.jpg",
    5, 4, 6, "Minion", [], ["DEATHRATTLE"],
    [{"effect_id": "Damage", "target": "AllEnemiesFront", "value": 2}],
    "Rare", "Front")

# 18 Émissaire de la Peste
make_tres("plague-emissary.tres", uid(), RACE_UNDEAD, 1,
    "Émissaire de la Peste",
    "Arrivée : -2 ATK à un serviteur ennemi ciblé jusqu'à fin du tour adverse.",
    "Il ne vient pas combattre. Il vient annoncer.",
    "res://assets/card_art/undead/plague-emissary.jpg",
    4, 3, 4, "Minion", [], ["ONPLAY"],
    [{"effect_id": "DebuffATK", "target": "EnemyMinion", "value": 2}],
    "Rare", "Hybrid", True)

# 19 Soldat Réanimé
make_tres("reanimated-soldier.tres", uid(), RACE_UNDEAD, 0,
    "Soldat Réanimé",
    "Arrivée : si réanimé depuis le cimetière, entre avec +1/+1.",
    "La mort lui a appris ce que la guerre ne lui avait pas enseigné : la patience.",
    "res://assets/card_art/undead/reanimated-soldier.jpg",
    3, 4, 3, "Minion", [], ["ONPLAY"], [], "Rare", "Front")

# 20 Banshee Zombie
make_tres("zombie-banshee.tres", uid(), RACE_UNDEAD, 3,
    "Banshee Zombie",
    "Arrivée : silence un serviteur ennemi ciblé jusqu'à fin du prochain tour adverse.",
    "Elle hurle sans voix. Ceux qu'elle regarde oublient comment parler.",
    "res://assets/card_art/undead/banshee.jpg",
    4, 2, 5, "Minion", [], ["ONPLAY"],
    [{"effect_id": "Silence", "target": "EnemyMinion"}],
    "Rare", "Hybrid", True)

# 21 Possédé Hurlant
make_tres("screaming-possessed.tres", uid(), RACE_UNDEAD, 0,
    "Possédé Hurlant",
    "ASSAUT. VENIN MORTEL. Dernier Souffle : retiré du jeu (ne va pas au cimetière).",
    "Même les morts refusent de le reprendre.",
    "res://assets/card_art/undead/screaming-possessed.jpg",
    3, 5, 1, "Minion", ["Assaut", "Venin mortel"], ["DEATHRATTLE"], [],
    "Rare", "Front")

# 22 Cavalier Zombie
make_tres("zombie-rider.tres", uid(), RACE_UNDEAD, 4,
    "Cavalier Zombie",
    "ASSAUT. Arrivée : attaque immédiatement le serviteur ennemi le plus faible en HP.",
    "Le cheval est mort avant lui. Ni l'un ni l'autre ne s'en est rendu compte.",
    "res://assets/card_art/undead/zombie-rider.jpg",
    4, 4, 3, "Minion", ["Assaut"], ["ONPLAY", "OnAttack"], [], "Rare", "Front")

# 23 Garde du Charnier
make_tres("charnel-guard.tres", uid(), RACE_UNDEAD, 0,
    "Garde du Charnier",
    "REMPART. Dernier Souffle : pioche 1 carte.",
    "Il gardait les vivants. Il garde désormais ce qui reste.",
    "res://assets/card_art/undead/charnel-guard.jpg",
    2, 1, 4, "Minion", ["Rempart"], ["DEATHRATTLE"],
    [{"effect_id": "DrawCard", "value": 1}],
    "Rare", "Front")

# 24 Le Patient Zéro
make_tres("patient-zero.tres", uid(), RACE_UNDEAD, 1,
    "Le Patient Zéro",
    "Arrivée : inflige Infection à tous les serviteurs ennemis en jeu.",
    "On n'a jamais su d'où il venait. On a fini par ne plus chercher.",
    "res://assets/card_art/undead/patient-zero.jpg",
    4, 3, 3, "Minion", [], ["ONPLAY"],
    [{"effect_id": "InfectEnemy", "target": "AllEnemies"}],
    "Epic", "Hybrid")

# 25 Ravageur Putréfié
make_tres("putrefied-ravager.tres", uid(), RACE_UNDEAD, 2,
    "Ravageur Putréfié",
    "RAVAGE. Mort-rage : serviteurs Mort-Vivants alliés +2/+2.",
    "Chaque mort nourrit sa rage. Et il y a toujours de nouveaux morts.",
    "res://assets/card_art/undead/putrefied-ravager.jpg",
    5, 6, 4, "Minion", ["Ravage"], ["OnDeathRage"],
    [{"effect_id": "Buff", "target": "AllAllies", "value": 2, "value2": 2}],
    "Epic", "Front")

# 26 Architecte de la Horde
make_tres("horde-architect.tres", uid(), RACE_UNDEAD, 1,
    "Architecte de la Horde",
    "Ralliement : invoque un Rampant 1/1 en rangée Avant.",
    "Il ne construit pas d'armée. Il la sécrète.",
    "res://assets/card_art/undead/horde-architect.jpg",
    3, 2, 3, "Minion", [], ["RALLY"],
    [{"effect_id": "SummonMinion", "summon_path": DECAYING}],
    "Epic", "Back")

# 27 Colosse Décomposé
make_tres("decayed-colossus.tres", uid(), RACE_UNDEAD, 2,
    "Colosse Décomposé",
    "REMPART. Blessure : les dégâts excédentaires ne se propagent pas.",
    "Les lames disparaissent dans sa masse. Il continue d'avancer.",
    "res://assets/card_art/undead/decayed-colossus.jpg",
    6, 7, 7, "Minion", ["Rempart"], ["OnDamaged"], [], "Epic", "Front")

# 28 Esprit Vorace
make_tres("voracious-spirit.tres", uid(), RACE_UNDEAD, 3,
    "Esprit Vorace",
    "MOISSON. Arrivée : vole 2 HP au héros ennemi.",
    "Il ne prend pas ta vie. Il la déplace — dans les mauvaises mains.",
    "res://assets/card_art/undead/voracious-spirit.jpg",
    4, 4, 4, "Minion", ["Moisson"], ["ONPLAY"],
    [{"effect_id": "StealHealth", "target": "EnemyHero", "value": 2}],
    "Epic", "Hybrid")

# 29 Nuée d'Insectes Cadavériques
make_tres("cadaverous-insect-swarm.tres", uid(), RACE_UNDEAD, 17,
    "Nuée d'Insectes Cadavériques",
    "Arrivée : inflige 1 dégât à tous les serviteurs ennemis en jeu.",
    "Là où elle passe, rien ne guérit vraiment.",
    "res://assets/card_art/undead/cadaverous-insect-swarm.jpg",
    3, 1, 2, "Minion", [], ["ONPLAY"],
    [{"effect_id": "Damage", "target": "AllEnemies", "value": 1}],
    "Epic", "Hybrid")

# 30 Faucheur de la Plaie
make_tres("plague-reaper.tres", uid(), RACE_UNDEAD, 1,
    "Faucheur de la Plaie",
    "Arrivée : détruit un serviteur ennemi ayant 3 HP ou moins.",
    "Il ne choisit pas les plus forts. Il choisit les presque morts — pour finir le travail.",
    "res://assets/card_art/undead/plague-reaper.jpg",
    5, 5, 5, "Minion", [], ["ONPLAY"],
    [{"effect_id": "DestroyLowHP", "target": "AllEnemies", "value": 3}],
    "Epic", "Front")

# 31 Nécromancien Putride
make_tres("putrid-necromancer.tres", uid(), RACE_UNDEAD, 1,
    "Nécromancien Putride",
    "Arrivée : ressuscite le dernier Mort-Vivant allié mort avec 1 HP en rangée Avant.",
    "\"Je ne ressuscite personne. Je refuse simplement qu'ils s'arrêtent.\"",
    "res://assets/card_art/undead/putrid-necromancer.jpg",
    4, 2, 4, "Minion", [], ["ONPLAY"],
    [{"effect_id": "ResurrectLast", "target": "Self"}],
    "Epic", "Back")

# 32 Assassin Décharné
make_tres("gaunt-assassin.tres", uid(), RACE_UNDEAD, 1,
    "Assassin Décharné",
    "AILES NOIRES. Ne peut pas être ciblé par sorts ennemis jusqu'à son premier Assaut.",
    "On ne le voit pas venir. On ne le voit que partir.",
    "res://assets/card_art/undead/gaunt-assassin.jpg",
    3, 4, 2, "Minion", ["Assaut", "Ailes noires"], ["OnAttack"], [],
    "Epic", "Front", True)

# 33 Berserker Infecté
make_tres("infected-berserker.tres", uid(), RACE_UNDEAD, 1,
    "Berserker Infecté",
    "FRÉNÉSIE. Mort-rage : +3/+0, revient en jeu avec 1 HP.",
    "La fièvre l'a tué. Ce qui reste est plus rapide.",
    "res://assets/card_art/undead/infected-berserker.jpg",
    4, 5, 4, "Minion", ["Frénésie"], ["OnDeathRage"],
    [{"effect_id": "SummonSelf", "count": 1}],
    "Epic", "Front")

# 34 Tombeau Ambulant
make_tres("walking-tomb.tres", uid(), RACE_UNDEAD, 2,
    "Tombeau Ambulant",
    "REMPART. Dernier Souffle : invoque 3 Rampants 1/1 en rangée Avant.",
    "Il n'était pas un monstre. Il était une fosse commune.",
    "res://assets/card_art/undead/walking-tomb.jpg",
    5, 3, 8, "Minion", ["Rempart"], ["DEATHRATTLE"],
    [{"effect_id": "SummonMinion", "summon_path": DECAYING, "count": 3}],
    "Epic", "Front")

# 35 Le Médecin de la Peste
make_tres("the-plague-doctor.tres", uid(), RACE_UNDEAD, 1,
    "Le Médecin de la Peste",
    "Éveil : invoque un Mort-Vivant aléatoire de coût ≤3 en rangée Avant.",
    "Il soignait les vivants autrefois. Il a simplement changé de patientèle.",
    "res://assets/card_art/undead/plague-emissary.jpg",
    6, 0, 4, "Minion", [], ["OnAwaken"],
    [{"effect_id": "SummonRandom", "count": 1}],
    "Legendary", "Back")

# 36 Roi Liche Zombie
make_tres("zombie-lich-king.tres", uid(), RACE_UNDEAD, 1,
    "Roi Liche Zombie",
    "Arrivée : ressuscite les 3 derniers Mort-Vivants alliés morts ce match avec 1 HP en rangée Avant.",
    "Son royaume n'a pas de frontières. Il s'étend à mesure que ses sujets meurent.",
    "res://assets/card_art/undead/zombie-lich-king.jpg",
    7, 6, 8, "Minion", [], ["ONPLAY"],
    [{"effect_id": "Resurrect", "count": 3}],
    "Legendary", "Front")

# 37 Apocalypse Zombie
make_tres("zombie-apocalypse.tres", uid(), RACE_UNDEAD, 1,
    "Apocalypse Zombie",
    "Arrivée : transforme tous les serviteurs adverses en jeu en Zombies 1/1 sous ton contrôle.",
    "Ce n'était pas une invasion. C'était une conversion.",
    "res://assets/card_art/undead/zombie-apocalypse.jpg",
    8, 9, 9, "Minion", [], ["ONPLAY"],
    [{"effect_id": "Transform", "target": "AllEnemies"}],
    "Legendary", "Front")

# 38 Léviathan Putréfié
make_tres("putrefied-leviathan.tres", uid(), RACE_UNDEAD, 2,
    "Léviathan Putréfié",
    "REMPART. Arrivée : serviteurs Mort-Vivants alliés +2/+2.",
    "Les mers l'ont recraché. Elles non plus ne voulaient plus de lui.",
    "res://assets/card_art/undead/putrefied-leviathan.jpg",
    7, 8, 10, "Minion", ["Rempart"], ["ONPLAY"],
    [{"effect_id": "Buff", "target": "AllAllies", "value": 2, "value2": 2}],
    "Legendary", "Front")

# 39 La Faucheuse
make_tres("the-reaper.tres", uid(), RACE_UNDEAD, 1,
    "La Faucheuse",
    "Arrivée : détruit un serviteur ennemi ciblé et le ressuscite sous ton contrôle sans ses effets.",
    "Elle ne prend pas les âmes. Elle redistribue les corps.",
    "res://assets/card_art/undead/the-reaper.jpg",
    7, 7, 6, "Minion", [], ["ONPLAY"],
    [{"effect_id": "Destroy", "target": "EnemyMinion"},
     {"effect_id": "StealMinion", "target": "EnemyMinion"}],
    "Legendary", "Front", True)

# ─── ÉPHÉMÈRES MORT-VIVANTS ───
# 40 Souffle Nécrotique
make_tres("necrotic-breath.tres", uid(), RACE_UNDEAD, 0,
    "Souffle Nécrotique",
    "2 dégâts à un serviteur ennemi ciblé.",
    "Ce n'est pas du vent. C'est ce qui reste quand les poumons ne servent plus à rien.",
    "res://assets/card_art/undead/necrotic-breath.jpg",
    2, 0, 0, "Instant", [], [],
    [{"effect_id": "Damage", "target": "EnemyMinion", "value": 2}],
    "Common", "Front", True)

# 41 Réveil Soudain
make_tres("sudden-awakening.tres", uid(), RACE_UNDEAD, 0,
    "Réveil Soudain",
    "Ressuscite le dernier Mort-Vivant allié mort avec 1 HP en rangée Avant.",
    "Il n'y a pas de repos pour ceux qu'on rappelle.",
    "res://assets/card_art/undead/sudden-awakening.jpg",
    1, 0, 0, "Instant", [], [],
    [{"effect_id": "ResurrectLast", "target": "Self"}],
    "Common", "Front")

# 42 Vague de Putréfaction
make_tres("wave-of-putrefaction.tres", uid(), RACE_UNDEAD, 0,
    "Vague de Putréfaction",
    "1 dégât à tous les serviteurs ennemis en rangée Avant.",
    "La peste ne choisit pas. Elle couvre.",
    "res://assets/card_art/undead/wave-of-putrefaction.jpg",
    3, 0, 0, "Instant", [], [],
    [{"effect_id": "Damage", "target": "AllEnemiesFront", "value": 1}],
    "Common", "Front")

# 43 Don de Chair
make_tres("gift-of-flesh.tres", uid(), RACE_UNDEAD, 0,
    "Don de Chair",
    "Sacrifice (un serviteur allié) : inflige 3 dégâts au héros ennemi.",
    "Il a donné son corps. Il n'avait plus besoin de consentir.",
    "res://assets/card_art/undead/gift-of-flesh.jpg",
    2, 0, 0, "Instant", [], ["OnSacrifice"],
    [{"effect_id": "Damage", "target": "EnemyHero", "value": 3}],
    "Rare", "Front")

# 44 Étreinte Glaciale
make_tres("icy-embrace.tres", uid(), RACE_UNDEAD, 0,
    "Étreinte Glaciale",
    "Gèle un serviteur ennemi ciblé un tour. (L'Infection continue.)",
    "Le froid stoppe les gestes. Pas le mal qui ronge de l'intérieur.",
    "res://assets/card_art/undead/icy-embrace.jpg",
    2, 0, 0, "Instant", [], [],
    [{"effect_id": "Freeze", "target": "EnemyMinion", "value": 1}],
    "Common", "Front", True)

# 45 Morsure Infectieuse
make_tres("infectious-bite.tres", uid(), RACE_UNDEAD, 0,
    "Morsure Infectieuse",
    "Transforme un serviteur ennemi non-Légendaire en Zombie 1/1 sous ton contrôle.",
    "Une seule morsure suffit. Le reste, c'est une question de temps.",
    "res://assets/card_art/undead/infectious-bite.jpg",
    3, 0, 0, "Instant", [], [],
    [{"effect_id": "Transform", "target": "EnemyMinion"}],
    "Rare", "Front", True)

# 46 Cri des Damnés
make_tres("cry-of-the-damned.tres", uid(), RACE_UNDEAD, 0,
    "Cri des Damnés",
    "Mort-Vivants alliés +1/+0 ce tour. Si 5 ou plus en jeu : +2/+0 à la place.",
    "Plus ils sont nombreux à hurler, moins le cri ressemble à quelque chose d'humain.",
    "res://assets/card_art/undead/cry-of-the-damned.jpg",
    3, 0, 0, "Instant", [], [],
    [{"effect_id": "Buff", "target": "AllAllies", "value": 1}],
    "Rare", "Front")

# 47 Poigne du Cimetière
make_tres("grip-of-the-graveyard.tres", uid(), RACE_UNDEAD, 0,
    "Poigne du Cimetière",
    "Renvoie un serviteur ennemi de 3 HP ou moins dans la main de son propriétaire.",
    "Les morts n'oublient pas ceux qui les ont enterrés.",
    "res://assets/card_art/undead/grip-of-the-graveyard.jpg",
    2, 0, 0, "Instant", [], [],
    [{"effect_id": "ReturnToHand", "target": "EnemyMinion"}],
    "Rare", "Front", True)

# 48 Exhalation Toxique
make_tres("toxic-exhalation.tres", uid(), RACE_UNDEAD, 0,
    "Exhalation Toxique",
    "1 dégât à tous les serviteurs en jeu.",
    "Même ses alliés évitent de respirer trop près.",
    "res://assets/card_art/undead/toxic-exhalation.jpg",
    1, 0, 0, "Instant", [], [],
    [{"effect_id": "DamageAllMinions", "value": 1}],
    "Common", "Front")

# 49 Dernier Soupir
make_tres("last-breath.tres", uid(), RACE_UNDEAD, 0,
    "Dernier Soupir",
    "Carnage : pioche 1 carte par Mort-Vivant allié mort ce tour (max 3).",
    "Leurs voix ne portent plus. Mais leurs secrets, si.",
    "res://assets/card_art/undead/last-breath.jpg",
    3, 0, 0, "Instant", [], ["OnCarnage"],
    [{"effect_id": "DrawCard", "value": 1}],
    "Epic", "Front")

# 50 Éclat de Putréfaction
make_tres("shard-of-putrefaction.tres", uid(), RACE_UNDEAD, 0,
    "Éclat de Putréfaction",
    "Détruit un enchantement ou équipement ennemi. Si enchantement : invoque un Rampant 1/1.",
    "La corruption ne respecte pas la magie. Elle la digère.",
    "res://assets/card_art/undead/shard-of-putrefaction.jpg",
    2, 0, 0, "Instant", [], [],
    [{"effect_id": "Destroy", "target": "EnemyMinion"}],
    "Rare", "Front", True)

# 51 Souffle du Charnier
make_tres("breath-of-the-charnel-house.tres", uid(), RACE_UNDEAD, 0,
    "Souffle du Charnier",
    "Un Mort-Vivant allié ciblé gagne +0/+2.",
    "Ce qui ne peut pas mourir davantage peut encore endurcir.",
    "res://assets/card_art/undead/breath-of-the-charnel-house.jpg",
    1, 0, 0, "Instant", [], [],
    [{"effect_id": "Buff", "target": "AllyMinion", "value2": 2}],
    "Common", "Front", True)

# 52 Doigt Décharné
make_tres("gaunt-finger.tres", uid(), RACE_UNDEAD, 0,
    "Doigt Décharné",
    "Pioche 1 carte. Si c'est un Mort-Vivant, il coûte 1 de moins ce tour.",
    "Il désigne. Quelque chose, quelque part, répond.",
    "res://assets/card_art/undead/gaunt-finger.jpg",
    1, 0, 0, "Instant", [], ["OnSpell"],
    [{"effect_id": "DrawCard", "value": 1}],
    "Rare", "Front")

# ─── RITUELS MORT-VIVANTS ───
# 53 Rituel de Résurrection
make_tres("resurrection-ritual.tres", uid(), RACE_UNDEAD, 0,
    "Rituel de Résurrection",
    "2 tours : Éveil : ressuscite un Mort-Vivant allié mort aléatoire avec 1 HP en rangée Avant.",
    "Le cercle ne ferme jamais complètement. C'est voulu.",
    "res://assets/card_art/undead/resurection-ritual.jpg",
    5, 0, 0, "Ritual", [], ["OnAwaken"],
    [{"effect_id": "ResurrectLast"}],
    "Epic", "Front")

# 54 Pacte Sanglant
make_tres("blood-pact.tres", uid(), RACE_UNDEAD, 0,
    "Pacte Sanglant",
    "Sacrifice (jusqu'à 4 serviteurs à 2 HP ou moins) : invoque un Mort-Vivant X/X (X = sacrifiés × 2).",
    "Quatre cadavres pour en faire un seul. Le calcul semble simple. Il ne l'est pas.",
    "res://assets/card_art/undead/blood-pact.jpg",
    4, 0, 0, "Ritual", [], ["OnSacrifice"],
    [{"effect_id": "SummonMinion"}],
    "Epic", "Front")

# 55 Cercle de Convocation
make_tres("circle-of-summoning.tres", uid(), RACE_UNDEAD, 0,
    "Cercle de Convocation",
    "3 tours : Éveil : invoque un Mort-Vivant aléatoire de coût ≤2 gratuitement.",
    "Le cercle appelle. Les morts n'ont pas appris à décliner.",
    "res://assets/card_art/undead/circle-of-summoning.jpg",
    5, 0, 0, "Ritual", [], ["OnAwaken"],
    [{"effect_id": "SummonRandom"}],
    "Epic", "Front")

# 56 Communion avec les Morts
make_tres("communion-with-the-dead.tres", uid(), RACE_UNDEAD, 0,
    "Communion avec les Morts",
    "Deuil : pioche 1 carte par Mort-Vivant allié mort ce match (max 4).",
    "Chaque mort laisse quelque chose derrière lui. Il suffit de savoir écouter.",
    "res://assets/card_art/undead/communion-with-the-death.jpg",
    3, 0, 0, "Ritual", [], ["OnGrief"],
    [{"effect_id": "DrawCard", "value": 1}],
    "Rare", "Front")

# 57 Rituel d'Exhumation
make_tres("ritual-of-exhumation.tres", uid(), RACE_UNDEAD, 0,
    "Rituel d'Exhumation",
    "Ramène en main un serviteur Mort-Vivant ciblé depuis ton cimetière.",
    "On ne l'enterre pas. On l'entrepose.",
    "res://assets/card_art/undead/ritual-of-the-exhumation.jpg",
    4, 0, 0, "Ritual", [], [],
    [{"effect_id": "ReturnFromGrave"}],
    "Rare", "Front")

# 58 Cercle de Sacrifice
make_tres("circle-of-sacrifice.tres", uid(), RACE_UNDEAD, 0,
    "Cercle de Sacrifice",
    "Sacrifice (exactement 2 serviteurs) : tes serviteurs restants gagnent +ATK/+HP égal aux stats combinées des sacrifiés ce tour.",
    "Deux morts pour que les autres survivent — un peu plus longtemps.",
    "res://assets/card_art/undead/circle-of-sacrifice.jpg",
    6, 0, 0, "Ritual", [], ["OnSacrifice"],
    [{"effect_id": "Buff", "target": "AllAllies", "value": 2, "value2": 2}],
    "Legendary", "Front")

# 59 Rituel du Lien Funeste
make_tres("ritual-of-the-doomed-bond.tres", uid(), RACE_UNDEAD, 0,
    "Rituel du Lien Funeste",
    "3 tours : Deuil : inflige 2 dégâts au héros ennemi.",
    "Chaque allié qui tombe tire un fil. L'ennemi finit par sentir la traction.",
    "res://assets/card_art/undead/ritual-of-the-dommed-bond.jpg",
    4, 0, 0, "Ritual", [], ["OnGrief"],
    [{"effect_id": "Damage", "target": "EnemyHero", "value": 2}],
    "Epic", "Front")

# 60 Arrivée de Masse
make_tres("mass-invocation.tres", uid(), RACE_UNDEAD, 0,
    "Arrivée de Masse",
    "Invoque 4 Mort-Vivants aléatoires de coût ≤4. Coûte 6 si tu as 3 serviteurs ou moins en jeu.",
    "Il n'a pas ouvert une porte. Il a retiré le mur.",
    "res://assets/card_art/undead/mass-invocation.jpg",
    7, 0, 0, "Ritual", [], [],
    [{"effect_id": "SummonRandom", "count": 4}],
    "Legendary", "Front")

# 61 Rituel de l'Éclipse
make_tres("ritual-of-the-eclipse.tres", uid(), RACE_UNDEAD, 0,
    "Rituel de l'Éclipse",
    "2 tours : Sortilège ennemi : annulé s'il cible un de tes Mort-Vivants.",
    "Sous l'éclipse, la magie adverse perd ses repères. Les morts, eux, n'en ont plus besoin.",
    "res://assets/card_art/undead/ritual-of-the-eclipse.jpg",
    6, 0, 0, "Ritual", [], ["OnSpell"],
    [{"effect_id": "Buff", "target": "AllAllies"}],
    "Legendary", "Front")

# 62 Rituel de la Fosse Sans Fond
make_tres("ritual-of-the-bottomless-pit.tres", uid(), RACE_UNDEAD, 0,
    "Rituel de la Fosse Sans Fond",
    "Sacrifice (tous tes serviteurs) : pioche 1 carte par sacrifié.",
    "Il a tout donné. Il savait exactement ce que ça valait.",
    "res://assets/card_art/undead/ritual-of-the-bottomless-pit.jpg",
    6, 0, 0, "Ritual", [], ["OnSacrifice"],
    [{"effect_id": "DrawCard"}],
    "Epic", "Front")

# 63 Épidémie
make_tres("epidemic.tres", uid(), RACE_UNDEAD, 0,
    "Épidémie",
    "Ce tour : Serviteurs non Mort-Vivants ennemis -2/-2. Ceux réduits à 0 HP ne vont pas dans le cimetière adverse.",
    "Elle ne tue pas. Elle prépare.",
    "res://assets/card_art/undead/epidemic.jpg",
    4, 0, 0, "Ritual", [], [],
    [{"effect_id": "Debuff", "target": "AllEnemies", "value": 2, "value2": 2}],
    "Epic", "Front")

# 64 Grand Rituel Nécrotique
make_tres("grand-necrotic-ritual.tres", uid(), RACE_UNDEAD, 0,
    "Grand Rituel Nécrotique",
    "Ramène en main tous les Mort-Vivants alliés morts ce match (max 5).",
    "\"Je n'ai perdu personne. Je les ai simplement prêtés au sol.\"",
    "res://assets/card_art/undead/grand-necrotic-ritual.jpg",
    8, 0, 0, "Ritual", [], [],
    [{"effect_id": "DrawCard", "value": 5}],
    "Legendary", "Front")

# ─── ENCHANTEMENTS MORT-VIVANTS ───
# 65 Autel des Damnés
make_tres("altar-of-the-damned.tres", uid(), RACE_UNDEAD, 0,
    "Autel des Damnés",
    "Deuil : pioche 1 carte.",
    "Chaque mort nourrit l'autel. L'autel, lui, ne se souvient d'aucun nom.",
    "res://assets/card_art/undead/altar-of-the-damned.jpg",
    3, 0, 0, "Enchantment", [], ["OnGrief"],
    [{"effect_id": "DrawCard", "value": 1}],
    "Rare", "Front")

# 66 Fosse Commune
make_tres("mass-grave.tres", uid(), RACE_UNDEAD, 0,
    "Fosse Commune",
    "Appel : si 3 Mort-Vivants alliés ou plus sont en jeu, invoque un Rampant 1/1.",
    "Plus elle se remplit, plus elle déborde.",
    "res://assets/card_art/undead/mass-grave.jpg",
    4, 0, 0, "Enchantment", [], ["OnSummon"],
    [{"effect_id": "SummonMinion", "summon_path": DECAYING}],
    "Rare", "Front")

# 67 Aura de Décrépitude
make_tres("aura-of-decrepitude.tres", uid(), RACE_UNDEAD, 0,
    "Aura de Décrépitude",
    "Résonance : ce serviteur Mort-Vivant attaquant gagne +1/+0 de façon permanente.",
    "La décrépitude n'est pas une faiblesse. C'est une accumulation.",
    "res://assets/card_art/undead/aura-of-decrepitude.jpg",
    3, 0, 0, "Enchantment", [], ["OnAttack"],
    [{"effect_id": "Buff", "target": "AllAllies", "value": 1}],
    "Rare", "Front")

# 68 Cimetière Vivant
make_tres("living-cemetery.tres", uid(), RACE_UNDEAD, 0,
    "Cimetière Vivant",
    "Deuil : ce Mort-Vivant revient en jeu à la fin du tour avec 1 HP. (Une seule fois par serviteur.)",
    "Le sol ici ne garde rien. Il régurgite.",
    "res://assets/card_art/undead/living-cemetery.jpg",
    5, 0, 0, "Enchantment", [], ["OnGrief"],
    [{"effect_id": "ReturnToHand", "target": "AllyMinion"}],
    "Epic", "Front")

# 69 Brouillard Pestilentiel
make_tres("pestilential-fog.tres", uid(), RACE_UNDEAD, 0,
    "Brouillard Pestilentiel",
    "Présence : à chaque début du tour adverse, les serviteurs ennemis infectés perdent 1 HP supplémentaire.",
    "On ne le voit pas. On ne le sent même plus, après un moment.",
    "res://assets/card_art/undead/pestilential-fog.jpg",
    3, 0, 0, "Enchantment", [], ["OnDecline"],
    [{"effect_id": "Damage", "target": "AllEnemies", "value": 1}],
    "Rare", "Front")

# 70 Symbiose Cadavérique
make_tres("cadaverous-symbiosis.tres", uid(), RACE_UNDEAD, 0,
    "Symbiose Cadavérique",
    "Présence : tes serviteurs en rangée Arrière gagnent +0/+1 par serviteur allié en rangée Avant.",
    "Les morts de devant protègent les morts de derrière. C'est le seul lien qui reste.",
    "res://assets/card_art/undead/cadaverous-simbiosis.jpg",
    5, 0, 0, "Enchantment", [], ["OnAura"],
    [{"effect_id": "Buff", "target": "AllAlliesBack", "value2": 1}],
    "Epic", "Front")

# 71 Idole de l'Apocalypse
make_tres("idol-of-the-apocalypse.tres", uid(), RACE_UNDEAD, 0,
    "Idole de l'Apocalypse",
    "Résonance : le Mort-Vivant attaquant inflige 1 dégât splash aux serviteurs adjacents à la cible.",
    "On ne l'a pas sculpté. On l'a trouvé ainsi, debout, au milieu des ruines.",
    "res://assets/card_art/undead/idol-of-the-apocalypse.jpg",
    6, 0, 0, "Enchantment", [], ["OnAttack"],
    [{"effect_id": "SplashDamage", "target": "EnemyMinion", "value": 1}],
    "Legendary", "Front")

# 72 Sanctuaire Nécrotique
make_tres("necrotic-sanctuary.tres", uid(), RACE_UNDEAD, 0,
    "Sanctuaire Nécrotique",
    "Présence : les sorts alliés coûtent 1 de moins (min 1).",
    "Dans ses murs, la magie de mort coule comme de l'eau froide — naturellement.",
    "res://assets/card_art/undead/necrotic-sanctuary.jpg",
    4, 0, 0, "Enchantment", [], ["OnAura"],
    [{"effect_id": "Buff", "target": "Self", "value": -1}],
    "Epic", "Front")

# 73 Vortex des Âmes
make_tres("vortex-of-souls.tres", uid(), RACE_UNDEAD, 0,
    "Vortex des Âmes",
    "Carnage : gagne 1 mana temporaire ce tour.",
    "Les âmes qui s'y perdent alimentent quelque chose que personne ne comprend vraiment.",
    "res://assets/card_art/undead/vortex-of-souls.jpg",
    6, 0, 0, "Enchantment", [], ["OnCarnage"],
    [{"effect_id": "HealHero", "target": "OwnerHero", "value": 1}],
    "Legendary", "Front")

# 74 Monument aux Morts
make_tres("monument-to-the-dead.tres", uid(), RACE_UNDEAD, 0,
    "Monument aux Morts",
    "Deuil : invoque 2 Mort-Vivants aléatoires de coût ≤3.",
    "On l'a érigé pour honorer les disparus. Il préfère les renvoyer.",
    "res://assets/card_art/undead/monument-of-death.jpg",
    5, 0, 0, "Enchantment", [], ["OnGrief"],
    [{"effect_id": "SummonRandom", "count": 2}],
    "Epic", "Front")

# 75 Murmure Funeste
make_tres("doomed-whisper.tres", uid(), RACE_UNDEAD, 0,
    "Murmure Funeste",
    "Présence : le premier Mort-Vivant joué chaque tour coûte 1 de moins (min 1).",
    "On ne l'entend pas. On sent juste que quelque chose a dit oui.",
    "res://assets/card_art/undead/doomed-whisper.jpg",
    1, 0, 0, "Enchantment", [], ["OnAura"],
    [{"effect_id": "Buff", "target": "Self", "value": -1}],
    "Rare", "Front")

# ─── HUMAINS ──────────────────────────────────────────────────────────────────
print("\n=== HUMAINS ===")

def human_tex(name): return f"res://assets/card_art/human/{name}.jpg"

# H01 Conscrit
make_tres("conscrit.tres", uid(), RACE_HUMAN, 5,
    "Conscrit", "—",
    "Il n'a pas choisi de venir. Il est venu quand même.",
    human_tex("conscrit"), 1, 1, 2, "Minion", [], [], [], "Common", "Front")

# H02 Milicien du Bourg
make_tres("militia-man.tres", uid(), RACE_HUMAN, 5,
    "Milicien du Bourg",
    "Dernier Souffle : invoque un Éclaireur 1/1.",
    "Il est tombé en gardant la route ouverte. C'est tout ce qu'il avait demandé.",
    human_tex("militia-man"), 1, 2, 1, "Minion", [], ["DEATHRATTLE"],
    [{"effect_id": "SummonMinion"}], "Common", "Front")

# H03 Porteur de Bouclier
make_tres("shield-bearer.tres", uid(), RACE_HUMAN, 5,
    "Porteur de Bouclier", "REMPART.",
    "Le bouclier a des marques de griffes. Il ne les compte plus.",
    human_tex("shield-bearer"), 2, 1, 4, "Minion", ["Rempart"], [], [], "Common", "Front")

# H04 Fantassin Aguerri
make_tres("seasoned-footman.tres", uid(), RACE_HUMAN, 5,
    "Fantassin Aguerri",
    "FORMATION : tant qu'un allié est adjacent, gagne +1/+1.",
    "Seul, il tient. Ensemble, ils avancent.",
    human_tex("seasoned-footman"), 2, 2, 2, "Minion", [], ["OnAura"], [], "Common", "Front")

# H05 Archer de Guet
make_tres("watch-archer.tres", uid(), RACE_HUMAN, 6,
    "Archer de Guet",
    "Éveil : inflige 1 dégât à un serviteur ennemi en rangée Avant ciblé.",
    "Il ne rate pas. Il attend juste le bon moment.",
    human_tex("watch-archer"), 2, 2, 1, "Minion", [], ["OnAwaken"],
    [{"effect_id": "Damage", "target": "EnemyMinion", "value": 1}],
    "Common", "Back", True)

# H06 Éclaireur Rapide
make_tres("swift-scout.tres", uid(), RACE_HUMAN, 6,
    "Éclaireur Rapide",
    "ASSAUT. Arrivée : pioche 1 carte si la rangée Avant ennemie a 3 serviteurs ou plus.",
    "Il revient toujours avec de mauvaises nouvelles. Il revient, c'est ce qui compte.",
    human_tex("swift-scout"), 1, 1, 1, "Minion", ["Assaut"], ["ONPLAY"],
    [{"effect_id": "DrawCard", "value": 1}], "Common", "Front")

# H07 Vétéran des Marches
make_tres("march-veteran.tres", uid(), RACE_HUMAN, 5,
    "Vétéran des Marches",
    "Blessure : gagne +1/+0 de façon permanente.",
    "Chaque cicatrice lui a appris quelque chose. Il en a beaucoup appris.",
    human_tex("march-veteran"), 3, 2, 4, "Minion", [], ["OnDamaged"],
    [{"effect_id": "Buff", "target": "Self", "value": 1}], "Common", "Front")

# H08 Frère d'Armes
make_tres("brother-in-arms.tres", uid(), RACE_HUMAN, 5,
    "Frère d'Armes",
    "Ralliement : le serviteur allié adjacent gagne +0/+1.",
    "Il ne combat pas pour la victoire. Il combat pour que l'homme à sa gauche rentre chez lui.",
    human_tex("brother-in-arms"), 3, 3, 2, "Minion", [], ["OnAttack"],
    [{"effect_id": "BuffAdjacent", "target": "Self", "value2": 1}], "Common", "Front")

# H09 Lancier en Ligne
make_tres("line-lancer.tres", uid(), RACE_HUMAN, 5,
    "Lancier en Ligne",
    "FORMATION : inflige 1 dégât supplémentaire si un allié est adjacent.",
    "La ligne tient ou la ligne tombe. Il n'y a pas d'entre-deux.",
    human_tex("line-lancer"), 2, 3, 1, "Minion", [], ["OnAura"], [], "Common", "Front")

# H10 Guérisseur de Camp
make_tres("camp-healer.tres", uid(), RACE_HUMAN, 7,
    "Guérisseur de Camp",
    "Éveil : restaure 1 HP à un serviteur Humain allié ciblé.",
    "Il n'a jamais tenu d'épée. Ses mains ont pourtant sauvé plus de vies que n'importe quelle lame.",
    human_tex("camp-healer"), 3, 0, 3, "Minion", [], ["OnAwaken"],
    [{"effect_id": "Heal", "target": "AllyMinion", "value": 1}], "Common", "Back", True)

# H11 Sergent de Troupe
make_tres("troop-sergeant.tres", uid(), RACE_HUMAN, 5,
    "Sergent de Troupe",
    "Arrivée : les serviteurs Humains alliés en rangée Avant gagnent +0/+1 jusqu'à fin de tour.",
    "Sa voix porte plus loin que le bruit du combat. C'est pour ça qu'il est encore en vie.",
    human_tex("troop-sergeant"), 3, 2, 3, "Minion", [], ["ONPLAY"],
    [{"effect_id": "Buff", "target": "AllAlliesFront", "value2": 1}], "Common", "Hybrid")

# H12 Chevalier du Mur
make_tres("wall-knight.tres", uid(), RACE_HUMAN, 5,
    "Chevalier du Mur",
    "REMPART. CONTRE-ATTAQUE.",
    "Il a juré de ne pas reculer. Il a tenu sa parole à un prix qu'il ne mentionne jamais.",
    human_tex("wall-knight"), 3, 2, 5, "Minion", ["Rempart"], ["OnDamaged"], [], "Rare", "Front")

# H13 Inquisiteur de Fer
make_tres("iron-inquisitor.tres", uid(), RACE_HUMAN, 7,
    "Inquisiteur de Fer",
    "Arrivée : silence un serviteur ennemi ciblé jusqu'à fin du prochain tour adverse.",
    "Il ne cherche pas la vérité. Il coupe ce qui parle à la place d'elle.",
    human_tex("iron-inquisitor"), 3, 3, 2, "Minion", [], ["ONPLAY"],
    [{"effect_id": "Silence", "target": "EnemyMinion"}], "Rare", "Hybrid", True)

# H14 Capitaine de Milice
make_tres("militia-captain.tres", uid(), RACE_HUMAN, 5,
    "Capitaine de Milice",
    "COMMANDEMENT. Arrivée : invoque un Milicien 2/1 en rangée Avant.",
    "Il n'avait pas prévu de commander. Mais quelqu'un devait le faire.",
    human_tex("militia-captain"), 4, 3, 3, "Minion", [], ["ONPLAY"],
    [{"effect_id": "SummonMinion"}], "Rare", "Hybrid")

# H15 Briseur de Horde
make_tres("horde-breaker.tres", uid(), RACE_HUMAN, 5,
    "Briseur de Horde",
    "Assaut : si la cible est un Mort-Vivant, inflige 2 dégâts supplémentaires.",
    "Il a perdu son village à la première vague. Il n'a pas perdu la rage.",
    human_tex("horde-breaker"), 4, 4, 3, "Minion", [], ["OnAttack"],
    [{"effect_id": "Damage", "target": "EnemyMinion", "value": 2}], "Rare", "Front")

# H16 Sentinelle des Remparts
make_tres("rampart-sentinel.tres", uid(), RACE_HUMAN, 5,
    "Sentinelle des Remparts",
    "REMPART. FORTIFICATION.",
    "On a essayé de le faire reculer. On a essayé de le renvoyer. On a abandonné.",
    human_tex("rampart-sentinel"), 2, 1, 5, "Minion", ["Rempart"], [], [], "Rare", "Front")

# H17 Archer d'Élite
make_tres("elite-archer.tres", uid(), RACE_HUMAN, 6,
    "Archer d'Élite",
    "Assaut : peut cibler n'importe quel serviteur ennemi (Avant ou Arrière).",
    "La rangée Avant n'est pas un obstacle. C'est un couloir.",
    human_tex("elite-archer"), 3, 3, 2, "Minion", ["Ailes noires"], ["OnAttack"], [], "Rare", "Back")

# H18 Prêtre de Guerre
make_tres("war-priest.tres", uid(), RACE_HUMAN, 7,
    "Prêtre de Guerre",
    "Éveil : restaure 2 HP à un serviteur Humain allié ciblé. Dernier Souffle : invoque un Éclaireur 1/1.",
    "Il priait pour les vivants. À la fin, il a prié pour quelque chose de plus modeste : du temps.",
    human_tex("war-priest"), 4, 1, 4, "Minion", [], ["OnAwaken", "DEATHRATTLE"],
    [{"effect_id": "Heal", "target": "AllyMinion", "value": 2},
     {"effect_id": "SummonMinion"}], "Rare", "Back", True)

# H19 Lame-Jurée
make_tres("oath-blade.tres", uid(), RACE_HUMAN, 5,
    "Lame-Jurée",
    "DISCIPLINE. Exécution : gagne +1/+1 de façon permanente.",
    "Elle a juré sur sa lame. La lame, elle, a juré de le mériter.",
    human_tex("oath-blade"), 3, 4, 2, "Minion", ["Égide"], ["OnExecution"],
    [{"effect_id": "Buff", "target": "Self", "value": 1, "value2": 1}], "Rare", "Front")

# H20 Défenseur Juré
make_tres("sworn-defender.tres", uid(), RACE_HUMAN, 5,
    "Défenseur Juré",
    "REMPART. Blessure : les dégâts reçus sont réduits de 1 (minimum 1).",
    "Il n'esquive pas. Il absorbe. Ce n'est pas pareil.",
    human_tex("sworn-defender"), 2, 1, 4, "Minion", ["Rempart"], ["OnDamaged"], [], "Rare", "Front")

# H21 Éclaireur Infiltré
make_tres("infiltrator-scout.tres", uid(), RACE_HUMAN, 6,
    "Éclaireur Infiltré",
    "Arrivée : révèle tous les serviteurs ennemis en rangée Arrière. Ils ne peuvent pas être ciblés par effets ce tour.",
    "Il est allé voir. Il est revenu. Pas tout le monde n'en peut dire autant.",
    human_tex("infiltrator-scout"), 3, 3, 2, "Minion", [], ["ONPLAY"], [], "Rare", "Front")

# H22 Fantassin de Contre-Choc
make_tres("counter-shock-footman.tres", uid(), RACE_HUMAN, 5,
    "Fantassin de Contre-Choc",
    "CONTRE-ATTAQUE. Blessure : gagne REMPART jusqu'à fin de tour.",
    "Chaque coup reçu lui rappelle pourquoi il tient encore debout.",
    human_tex("counter-shock-footman"), 4, 3, 4, "Minion", [], ["OnDamaged"], [], "Rare", "Front")

# H23 Soldat de la Foi
make_tres("soldier-of-faith.tres", uid(), RACE_HUMAN, 5,
    "Soldat de la Foi",
    "ÉGIDE. Dernier Souffle : invoque un Milicien 2/1 en rangée Avant.",
    "Il croyait en quelque chose. Ce quelque chose l'a protégé — une fois.",
    human_tex("soldier-of-faith"), 3, 2, 3, "Minion", ["Égide"], ["DEATHRATTLE"],
    [{"effect_id": "SummonMinion"}], "Rare", "Front")

# H24 Maréchal de Campagne
make_tres("field-marshal.tres", uid(), RACE_HUMAN, 5,
    "Maréchal de Campagne",
    "COMMANDEMENT. Éveil : tous les serviteurs Humains alliés gagnent +1/+0 jusqu'à fin de tour.",
    "Il ne crie pas les ordres. Il les dit une fois, calmement. Ça suffit.",
    human_tex("field-marshal"), 5, 2, 5, "Minion", [], ["OnAwaken"],
    [{"effect_id": "Buff", "target": "AllAllies", "value": 1}], "Epic", "Back")

# H25 Champion du Peuple
make_tres("peoples-champion.tres", uid(), RACE_HUMAN, 5,
    "Champion du Peuple",
    "Exécution : soigne le héros allié de 2 HP.",
    "Il se bat pour des gens qu'il ne connaît pas. C'est pour ça qu'il gagne.",
    human_tex("peoples-champion"), 4, 5, 4, "Minion", [], ["OnExecution"],
    [{"effect_id": "HealHero", "target": "OwnerHero", "value": 2}], "Epic", "Front")

# H26 Paladin de l'Aube
make_tres("dawn-paladin.tres", uid(), RACE_HUMAN, 8,
    "Paladin de l'Aube",
    "ÉGIDE. MOISSON. Arrivée : invoque un Éclaireur 1/1 en rangée Avant.",
    "Il arrive à l'aube. Les morts reculent à la lumière. Lui aussi en a été surpris, la première fois.",
    human_tex("dawn-paladin"), 5, 4, 5, "Minion", ["Égide", "Moisson"], ["ONPLAY"],
    [{"effect_id": "SummonMinion"}], "Epic", "Front")

# H27 Brise-Mort
make_tres("death-breaker.tres", uid(), RACE_HUMAN, 5,
    "Brise-Mort",
    "Arrivée : détruit un serviteur ennemi ressuscité ou réanimé depuis le cimetière ciblé.",
    "\"Tu es déjà mort une fois. Je vais m'assurer que tu ne l'oublies pas.\"",
    human_tex("death-breaker"), 4, 4, 3, "Minion", [], ["ONPLAY"],
    [{"effect_id": "Destroy", "target": "EnemyMinion"}], "Epic", "Front", True)

# H28 Mur de Lances
make_tres("spear-wall.tres", uid(), RACE_HUMAN, 5,
    "Mur de Lances",
    "REMPART. FORMATION. Carnage ennemi : inflige 1 dégât à tous les serviteurs ennemis en rangée Avant.",
    "Ils ne bougent pas. La ligne tient. Les lances, elles, trouvent toujours quelque chose à traverser.",
    human_tex("spear-wall"), 4, 1, 6, "Minion", ["Rempart"], ["OnCarnage"],
    [{"effect_id": "Damage", "target": "AllEnemiesFront", "value": 1}], "Epic", "Front")

# H29 Stratège Royal
make_tres("royal-strategist.tres", uid(), RACE_HUMAN, 5,
    "Stratège Royal",
    "Ralliement : place le serviteur allié invoqué dans la rangée de ton choix, même si elle est pleine (échange avec un autre).",
    "Il ne voit pas un champ de bataille. Il voit un problème à résoudre.",
    human_tex("royal-strategist"), 4, 2, 4, "Minion", [], ["OnAttack"], [], "Epic", "Back")

# H30 Exécuteur de l'Ordre
make_tres("order-enforcer.tres", uid(), RACE_HUMAN, 5,
    "Exécuteur de l'Ordre",
    "VENIN MORTEL. DISCIPLINE. Ne peut attaquer que les serviteurs (jamais le héros directement).",
    "Il n'a pas de haine. Il a des instructions. C'est pire.",
    human_tex("order-enforcer"), 5, 5, 4, "Minion", ["Venin mortel", "Égide"], [], [], "Epic", "Front")

# H31 Porte-Étendard
make_tres("standard-bearer.tres", uid(), RACE_HUMAN, 5,
    "Porte-Étendard",
    "Ralliement : invoque un Éclaireur 1/1 en rangée Avant pour chaque Humain déjà en jeu (max 3).",
    "L'étendard ne se rend pas. Tant qu'il tient, les autres tiennent aussi.",
    human_tex("standard-bearer"), 3, 1, 4, "Minion", [], ["OnAttack"],
    [{"effect_id": "SummonMinion", "count": 1}], "Epic", "Back")

# H32 Chevalier de la Contre-Marche
make_tres("counter-march-knight.tres", uid(), RACE_HUMAN, 5,
    "Chevalier de la Contre-Marche",
    "CONTRE-ATTAQUE. ASSAUT. Blessure : gagne +2/+0 jusqu'à fin de tour.",
    "Il charge. Il encaisse. Il charge encore. C'est tout ce qu'il sait faire — et c'est suffisant.",
    human_tex("counter-march-knight"), 5, 4, 5, "Minion", ["Assaut"], ["OnDamaged"],
    [{"effect_id": "Buff", "target": "Self", "value": 2}], "Epic", "Front")

# H33 Inquisiteur Suprême
make_tres("supreme-inquisitor.tres", uid(), RACE_HUMAN, 7,
    "Inquisiteur Suprême",
    "DISCIPLINE. Arrivée : annule tous les effets Infection sur tes serviteurs alliés. Immunise tes serviteurs à l'Infection ce tour.",
    "La corruption s'arrête là où il pose le regard.",
    human_tex("supreme-inquisitor"), 5, 3, 5, "Minion", ["Égide"], ["ONPLAY"], [], "Epic", "Hybrid")

# H34 Général de Brigade
make_tres("brigade-general.tres", uid(), RACE_HUMAN, 5,
    "Général de Brigade",
    "COMMANDEMENT. Éveil : invoque un Chevalier 2/2 en rangée Avant si tu as 4 Humains ou plus en jeu.",
    "Une armée n'est pas un nombre. C'est une volonté. La sienne.",
    human_tex("brigade-general"), 5, 3, 4, "Minion", [], ["OnAwaken"],
    [{"effect_id": "SummonMinion"}], "Epic", "Back")

# H35 Le Roi Soldat
make_tres("the-soldier-king.tres", uid(), RACE_HUMAN, 5,
    "Le Roi Soldat",
    "COMMANDEMENT. ÉGIDE. Arrivée : tous les serviteurs Humains alliés gagnent +2/+2 de façon permanente.",
    "Il n'a pas pris la couronne. On la lui a posée sur le champ de bataille, entre deux assauts.",
    human_tex("the-soldier-king"), 7, 6, 8, "Minion", ["Égide"], ["ONPLAY"],
    [{"effect_id": "Buff", "target": "AllAllies", "value": 2, "value2": 2}], "Legendary", "Front")

# H36 La Grande Inquisitrice
make_tres("the-grand-inquisitor.tres", uid(), RACE_HUMAN, 7,
    "La Grande Inquisitrice",
    "DISCIPLINE. Éveil : détruit un enchantement ou rituel ennemi actif au choix.",
    "Elle ne combat pas la magie ennemie. Elle la refuse.",
    human_tex("the-grand-inquisitor"), 6, 3, 6, "Minion", ["Égide"], ["OnAwaken"],
    [{"effect_id": "Destroy", "target": "EnemyMinion"}], "Legendary", "Back", True)

# H37 Le Rempart Vivant
make_tres("the-living-wall.tres", uid(), RACE_HUMAN, 5,
    "Le Rempart Vivant",
    "REMPART. FORTIFICATION. CONTRE-ATTAQUE. Blessure : invoque un Bouclier Brisé 0/3 REMPART adjacent.",
    "On lui a demandé combien de temps il pouvait tenir. Il n'a pas répondu. Il tient encore.",
    human_tex("the-living-wall"), 6, 4, 10, "Minion", ["Rempart", "Égide"], ["OnDamaged"],
    [{"effect_id": "SummonMinion"}], "Legendary", "Front")

# H38 Commandant des Derniers
make_tres("commander-of-the-last.tres", uid(), RACE_HUMAN, 5,
    "Commandant des Derniers",
    "COMMANDEMENT. Dernier Souffle : ressuscite tous les serviteurs Humains alliés morts ce tour avec 1 HP en rangée Avant.",
    "Sa mort n'est pas une fin. C'est un dernier ordre.",
    human_tex("commander-of-the-last"), 7, 5, 6, "Minion", [], ["DEATHRATTLE"],
    [{"effect_id": "Resurrect", "count": 5}], "Legendary", "Front")

# H39 L'Éternel Gardien
make_tres("the-eternal-guardian.tres", uid(), RACE_HUMAN, 5,
    "L'Éternel Gardien",
    "REMPART. ÉGIDE. DISCIPLINE. Arrivée : tous les serviteurs ennemis perdent leurs mots-clés jusqu'à la fin du prochain tour adverse.",
    "Il n'a pas survécu à toutes ces guerres par chance. Il a survécu parce que rien de ce que l'ennemi fait ne le surprend.",
    human_tex("the-eternal-guardian"), 8, 7, 9, "Minion", ["Rempart", "Égide"], ["ONPLAY"],
    [{"effect_id": "Silence", "target": "AllEnemies"}], "Legendary", "Front")

# ─── ÉPHÉMÈRES HUMAINS ───
# H40 Cri de Ralliement
make_tres("rally-cry.tres", uid(), RACE_HUMAN, 0,
    "Cri de Ralliement",
    "Humains alliés +0/+1 jusqu'à fin de tour.",
    "Un seul cri. Toute la ligne se souvient pourquoi elle est là.",
    human_tex("rally-cry"), 1, 0, 0, "Instant", [], [],
    [{"effect_id": "Buff", "target": "AllAllies", "value2": 1}], "Common", "Front")

# H41 Frappe Coordonnée
make_tres("coordinated-strike.tres", uid(), RACE_HUMAN, 0,
    "Frappe Coordonnée",
    "Deux serviteurs Humains alliés ciblés attaquent immédiatement le même serviteur ennemi ciblé.",
    "Deux hommes, un seul endroit. L'ennemi n'a pas le temps de choisir lequel regarder.",
    human_tex("coordinated-strike"), 2, 0, 0, "Instant", [], [], [], "Common", "Front")

# H42 Purification
make_tres("purification.tres", uid(), RACE_HUMAN, 0,
    "Purification",
    "Annule tous les effets Infection et marqueurs négatifs sur un serviteur allié ciblé.",
    "Le mal recule. Pas loin. Mais pour l'instant, ça suffit.",
    human_tex("purification"), 2, 0, 0, "Instant", [], [],
    [{"effect_id": "Silence", "target": "AllyMinion"}], "Common", "Front", True)

# H43 Repli Tactique
make_tres("tactical-retreat.tres", uid(), RACE_HUMAN, 0,
    "Repli Tactique",
    "Déplace un serviteur allié de la rangée Avant vers la rangée Arrière (ou inversement). Il conserve ses effets.",
    "Reculer n'est pas fuir. C'est choisir où mourir.",
    human_tex("tactical-retreat"), 1, 0, 0, "Instant", [], [], [], "Common", "Front")

# H44 Volée de Flèches
make_tres("arrow-volley.tres", uid(), RACE_HUMAN, 0,
    "Volée de Flèches",
    "Inflige 1 dégât à tous les serviteurs ennemis en rangée Avant. Si 4 ou plus en rangée Avant : 2 dégâts à la place.",
    "Plus ils sont nombreux, plus ça fait de cibles.",
    human_tex("arrow-volley"), 3, 0, 0, "Instant", [], [],
    [{"effect_id": "Damage", "target": "AllEnemiesFront", "value": 1}], "Common", "Front")

# H45 Bouclier de Foi
make_tres("shield-of-faith.tres", uid(), RACE_HUMAN, 0,
    "Bouclier de Foi",
    "Donne ÉGIDE à un serviteur Humain allié ciblé jusqu'à fin du prochain tour adverse.",
    "La foi ne rend pas invulnérable. Elle donne juste le temps d'encaisser le premier coup.",
    human_tex("shield-of-faith"), 1, 0, 0, "Instant", [], [],
    [{"effect_id": "Buff", "target": "AllyMinion"}], "Rare", "Front", True)

# H46 Jugement Divin
make_tres("divine-judgment.tres", uid(), RACE_HUMAN, 0,
    "Jugement Divin",
    "Détruit un serviteur ennemi ayant 2 ATK ou moins.",
    "Le verdict est rendu avant même que l'accusé comprenne qu'il était jugé.",
    human_tex("divine-judgment"), 3, 0, 0, "Instant", [], [],
    [{"effect_id": "DestroyLowHP", "target": "AllEnemies", "value": 2}], "Rare", "Front")

# H47 Ordre d'Avancer
make_tres("advance-order.tres", uid(), RACE_HUMAN, 0,
    "Ordre d'Avancer",
    "Tous les serviteurs Humains alliés en rangée Arrière gagnent ASSAUT ce tour et peuvent attaquer depuis la Arrière.",
    "L'ordre est arrivé. Il n'y avait pas de question à poser.",
    human_tex("advance-order"), 2, 0, 0, "Instant", [], [],
    [{"effect_id": "Buff", "target": "AllAlliesBack", "value": 1}], "Rare", "Front")

# H48 Contre-Offensive
make_tres("counter-offensive.tres", uid(), RACE_HUMAN, 0,
    "Contre-Offensive",
    "Exécution ce tour : chaque serviteur Humain allié qui tue un ennemi peut attaquer à nouveau immédiatement.",
    "La victoire s'enchaîne quand on ne lui laisse pas le temps de s'arrêter.",
    human_tex("counter-offensive"), 3, 0, 0, "Instant", [], [], [], "Rare", "Front")

# H49 Appel aux Armes
make_tres("call-to-arms.tres", uid(), RACE_HUMAN, 0,
    "Appel aux Armes",
    "Invoque 2 Miliciens 2/1 en rangée Avant. Si ta rangée Avant est vide : invoque 3 Miliciens à la place.",
    "Quand la ligne est vide, ceux qui restent n'ont plus à réfléchir. Ils avancent.",
    human_tex("call-to-arms"), 4, 0, 0, "Instant", [], [],
    [{"effect_id": "SummonMinion", "count": 2}], "Rare", "Front")

# H50 Bénédiction de Guerre
make_tres("war-blessing.tres", uid(), RACE_HUMAN, 0,
    "Bénédiction de Guerre",
    "Un serviteur Humain allié ciblé gagne +2/+2 et DISCIPLINE jusqu'à fin de tour.",
    "Ce n'est pas de la magie. C'est la conviction que quelqu'un a mis dans ses mains.",
    human_tex("war-blessing"), 2, 0, 0, "Instant", [], [],
    [{"effect_id": "Buff", "target": "AllyMinion", "value": 2, "value2": 2}], "Epic", "Front", True)

# H51 Massacre Sacré
make_tres("sacred-slaughter.tres", uid(), RACE_HUMAN, 0,
    "Massacre Sacré",
    "Inflige 3 dégâts à tous les serviteurs Mort-Vivants ennemis en jeu.",
    "La lumière ne guérit pas les morts. Elle les brûle. C'est mieux.",
    human_tex("sacred-slaughter"), 4, 0, 0, "Instant", [], [],
    [{"effect_id": "Damage", "target": "AllEnemies", "value": 3}], "Epic", "Front")

# H52 Formation Défensive
make_tres("defensive-formation.tres", uid(), RACE_HUMAN, 0,
    "Formation Défensive",
    "Tous tes serviteurs en rangée Avant gagnent REMPART et +0/+2 jusqu'à fin du tour adverse.",
    "Ils se serrent. La ligne devient un mur. Le mur ne bouge pas.",
    human_tex("defensive-formation"), 3, 0, 0, "Instant", [], [],
    [{"effect_id": "Buff", "target": "AllAlliesFront", "value2": 2}], "Epic", "Front")

# ─── RITUELS HUMAINS ───
# H53 Ordre de Tenir
make_tres("hold-the-line.tres", uid(), RACE_HUMAN, 0,
    "Ordre de Tenir",
    "2 tours : Éveil : tes serviteurs en rangée Avant ne peuvent pas être renvoyés en main ni déplacés par des effets ennemis.",
    "L'ordre est simple. Les hommes, eux, sont compliqués. Mais ils obéissent.",
    human_tex("hold-the-line"), 3, 0, 0, "Ritual", [], ["OnAwaken"], [], "Common", "Front")

# H54 Hymne de Guerre
make_tres("war-hymn.tres", uid(), RACE_HUMAN, 0,
    "Hymne de Guerre",
    "3 tours : Ralliement : le serviteur Humain invoqué gagne +1/+1.",
    "Le chant ne les rend pas invincibles. Il leur rappelle qu'ils ne sont pas seuls.",
    human_tex("war-hymn"), 4, 0, 0, "Ritual", [], ["OnAttack"],
    [{"effect_id": "Buff", "target": "Self", "value": 1, "value2": 1}], "Rare", "Front")

# H55 Fortification des Lignes
make_tres("line-fortification.tres", uid(), RACE_HUMAN, 0,
    "Fortification des Lignes",
    "Permanent : Éveil : si ta rangée Avant a 5 serviteurs ou plus, ils gagnent tous REMPART jusqu'à fin de tour.",
    "Cinq hommes côte à côte. Ça devient quelque chose d'autre. Quelque chose qui ne cède pas.",
    human_tex("line-fortification"), 5, 0, 0, "Ritual", [], ["OnAwaken"],
    [{"effect_id": "Buff", "target": "AllAlliesFront"}], "Rare", "Front")

# H56 Serment du Sang
make_tres("blood-oath.tres", uid(), RACE_HUMAN, 0,
    "Serment du Sang",
    "3 tours : Deuil : quand un Humain allié meurt, le serviteur allié adjacent gagne +1/+1.",
    "Le serment survit à celui qui l'a fait. C'est l'idée.",
    human_tex("blood-oath"), 4, 0, 0, "Ritual", [], ["OnGrief"],
    [{"effect_id": "BuffAdjacent", "target": "Self", "value": 1, "value2": 1}], "Rare", "Front")

# H57 Marche Forcée
make_tres("forced-march.tres", uid(), RACE_HUMAN, 0,
    "Marche Forcée",
    "2 tours : Éveil : invoque un Éclaireur 1/1 en rangée Avant gratuitement.",
    "Pas de repos. Pas d'arrêt. La ligne avance parce que s'arrêter, c'est mourir.",
    human_tex("forced-march"), 3, 0, 0, "Ritual", [], ["OnAwaken"],
    [{"effect_id": "SummonMinion"}], "Rare", "Front")

# H58 Contre-Attaque Générale
make_tres("general-counter-attack.tres", uid(), RACE_HUMAN, 0,
    "Contre-Attaque Générale",
    "2 tours : Blessure : chaque serviteur Humain allié qui subit des dégâts et survit inflige son ATK en retour à l'attaquant.",
    "Chaque coup reçu est une réponse en attente.",
    human_tex("general-counter-attack"), 5, 0, 0, "Ritual", [], ["OnDamaged"], [], "Epic", "Front")

# H59 Code du Chevalier
make_tres("knights-code.tres", uid(), RACE_HUMAN, 0,
    "Code du Chevalier",
    "3 tours : Assaut : chaque serviteur Humain allié qui attaque inflige 1 dégât supplémentaire.",
    "L'honneur ne protège pas. Mais il donne un tranchant supplémentaire.",
    human_tex("knights-code"), 5, 0, 0, "Ritual", [], ["OnAttack"],
    [{"effect_id": "Buff", "target": "AllAllies", "value": 1}], "Epic", "Front")

# H60 Mur Infranchissable
make_tres("impassable-wall.tres", uid(), RACE_HUMAN, 0,
    "Mur Infranchissable",
    "2 tours : Sortilège ennemi : annulé s'il cible un serviteur Humain allié en rangée Avant.",
    "La magie s'arrête là où la volonté commence.",
    human_tex("impassable-wall"), 6, 0, 0, "Ritual", [], ["OnSpell"], [], "Epic", "Front")

# H61 Bannière du Roi
make_tres("kings-banner.tres", uid(), RACE_HUMAN, 0,
    "Bannière du Roi",
    "Permanent : Éveil : si tu as un Humain Légendaire en jeu, invoque un Chevalier 2/2 en rangée Avant.",
    "Sous cette bannière, on ne compte plus les morts. On compte ceux qui restent debout.",
    human_tex("kings-banner"), 5, 0, 0, "Ritual", [], ["OnAwaken"],
    [{"effect_id": "SummonMinion"}], "Epic", "Front")

# H62 Résistance Acharnée
make_tres("stubborn-resistance.tres", uid(), RACE_HUMAN, 0,
    "Résistance Acharnée",
    "3 tours : Carnage allié : quand un Humain allié meurt, le héros allié gagne 1 HP.",
    "Chaque mort laisse quelque chose aux vivants. Quelque chose de dur, de têtu — de précieux.",
    human_tex("stubborn-resistance"), 4, 0, 0, "Ritual", [], ["OnCarnage"],
    [{"effect_id": "HealHero", "target": "OwnerHero", "value": 1}], "Epic", "Front")

# H63 Purge Sainte
make_tres("holy-purge.tres", uid(), RACE_HUMAN, 0,
    "Purge Sainte",
    "Détruit tous les serviteurs Mort-Vivants ennemis ayant 3 HP ou moins.",
    "Ce n'est pas une prière. C'est une déclaration.",
    human_tex("holy-purge"), 6, 0, 0, "Ritual", [], [],
    [{"effect_id": "DestroyLowHP", "target": "AllEnemies", "value": 3}], "Legendary", "Front")

# H64 Grande Mobilisation
make_tres("great-mobilization.tres", uid(), RACE_HUMAN, 0,
    "Grande Mobilisation",
    "Invoque 4 Humains aléatoires de coût ≤4 en rangée Avant. Coûte 7 si ta rangée Avant est vide.",
    "Quand tout le reste a échoué, il reste les hommes. Il y en a toujours assez pour une dernière fois.",
    human_tex("great-mobilization"), 8, 0, 0, "Ritual", [], [],
    [{"effect_id": "SummonRandom", "count": 4}], "Legendary", "Front")

# ─── ENCHANTEMENTS HUMAINS ───
# H65 Citadelle des Hommes
make_tres("citadel-of-men.tres", uid(), RACE_HUMAN, 0,
    "Citadelle des Hommes",
    "Présence : tes serviteurs en rangée Avant ont +0/+1 HP de façon permanente.",
    "Ces murs n'ont pas été construits pour durer. Ils ont duré quand même.",
    human_tex("citadel-of-men"), 4, 0, 0, "Enchantment", [], ["OnAura"],
    [{"effect_id": "Buff", "target": "AllAlliesFront", "value2": 1}], "Rare", "Front")

# H66 Lignée des Braves
make_tres("lineage-of-the-brave.tres", uid(), RACE_HUMAN, 0,
    "Lignée des Braves",
    "Deuil : quand un Humain allié meurt, pioche 1 carte.",
    "Chaque nom gravé est aussi une leçon. Il suffit de savoir la lire.",
    human_tex("lineage-of-the-brave"), 3, 0, 0, "Enchantment", [], ["OnGrief"],
    [{"effect_id": "DrawCard", "value": 1}], "Rare", "Front")

# H67 Pacte de Résistance
make_tres("resistance-pact.tres", uid(), RACE_HUMAN, 0,
    "Pacte de Résistance",
    "Présence : les serviteurs Humains alliés reçoivent 1 dégât de moins de toute source (minimum 1).",
    "Ils ont signé ensemble. Aucun d'eux ne s'en souvient exactement. Tous s'en souviennent suffisamment.",
    human_tex("resistance-pact"), 3, 0, 0, "Enchantment", [], ["OnAura"], [], "Rare", "Front")

# H68 Temple de Guerre
make_tres("war-temple.tres", uid(), RACE_HUMAN, 0,
    "Temple de Guerre",
    "Appel : chaque Humain invoqué gagne FORMATION de façon permanente.",
    "On ne vient pas y prier. On vient y apprendre à tenir sa place dans la ligne.",
    human_tex("war-temple"), 5, 0, 0, "Enchantment", [], ["OnSummon"],
    [{"effect_id": "Buff", "target": "Self", "value": 1, "value2": 1}], "Epic", "Front")

# H69 Cercle de Commandement
make_tres("circle-of-command.tres", uid(), RACE_HUMAN, 0,
    "Cercle de Commandement",
    "Éveil : si tu as un Commandant en jeu (carte avec COMMANDEMENT), tous les Humains alliés gagnent +1/+0 ce tour.",
    "Un commandant suffit. Le cercle fait le reste.",
    human_tex("circle-of-command"), 4, 0, 0, "Enchantment", [], ["OnAwaken"],
    [{"effect_id": "Buff", "target": "AllAllies", "value": 1}], "Epic", "Front")

# H70 Forteresse Imprenable
make_tres("impregnable-fortress.tres", uid(), RACE_HUMAN, 0,
    "Forteresse Imprenable",
    "Carnage ennemi : chaque fois qu'un serviteur ennemi meurt, tes serviteurs en rangée Avant gagnent +0/+1 jusqu'à fin de tour.",
    "Chaque ennemi abattu consolide ce qui reste debout.",
    human_tex("impregnable-fortress"), 5, 0, 0, "Enchantment", [], ["OnCarnage"],
    [{"effect_id": "Buff", "target": "AllAlliesFront", "value2": 1}], "Epic", "Front")

# H71 Bouclier de la Foi
make_tres("shield-of-the-faith.tres", uid(), RACE_HUMAN, 0,
    "Bouclier de la Foi",
    "Sortilège ennemi : la première fois par tour qu'un sort ennemi affecte un de tes serviteurs, réduit ses dégâts de 2 (minimum 0).",
    "La foi ne comprend pas la magie. Elle n'a pas besoin de la comprendre pour la freiner.",
    human_tex("shield-of-the-faith"), 4, 0, 0, "Enchantment", [], ["OnSpell"], [], "Epic", "Front")

# H72 Ordre des Anciens
make_tres("order-of-ancients.tres", uid(), RACE_HUMAN, 0,
    "Ordre des Anciens",
    "Éveil : si tu as 5 Humains ou plus en jeu, invoque un Héros Tombé 3/3 en rangée Avant.",
    "Les anciens ne reviennent pas par magie. Ils reviennent parce qu'on a encore besoin d'eux.",
    human_tex("order-of-ancients"), 5, 0, 0, "Enchantment", [], ["OnAwaken"],
    [{"effect_id": "SummonMinion"}], "Epic", "Front")

# H73 Mémorial des Héros
make_tres("heroes-memorial.tres", uid(), RACE_HUMAN, 0,
    "Mémorial des Héros",
    "Dernier Souffle : quand un Humain Légendaire allié meurt, invoque immédiatement un Chevalier 2/2 et un Milicien 2/1 en rangée Avant.",
    "On grave les noms pour ne pas oublier. On continue pour la même raison.",
    human_tex("heroes-memorial"), 4, 0, 0, "Enchantment", [], ["DEATHRATTLE"],
    [{"effect_id": "SummonMinion", "count": 2}], "Epic", "Front")

# H74 Décret Royal
make_tres("royal-decree.tres", uid(), RACE_HUMAN, 0,
    "Décret Royal",
    "Éveil : tous tes serviteurs Humains gagnent +1/+1. (S'accumule chaque tour.)",
    "Le décret n'a pas de date d'expiration. La guerre non plus.",
    human_tex("royal-decree"), 6, 0, 0, "Enchantment", [], ["OnAwaken"],
    [{"effect_id": "Buff", "target": "AllAllies", "value": 1, "value2": 1}], "Legendary", "Front")

# H75 Aegis de l'Empire
make_tres("aegis-of-the-empire.tres", uid(), RACE_HUMAN, 0,
    "Aegis de l'Empire",
    "Présence : tes serviteurs Humains en rangée Avant sont immunisés à l'Infection. Les marqueurs Infection déjà présents sont retirés à la fin de chaque tour.",
    "L'Empire ne cède pas à la pourriture. Ce n'est pas de l'orgueil. C'est de l'obstination.",
    human_tex("aegis-of-the-empire"), 5, 0, 0, "Enchantment", [], ["OnAura"], [], "Legendary", "Front")

print(f"\n✅ Terminé ! Fichiers générés dans : {OUT}")
