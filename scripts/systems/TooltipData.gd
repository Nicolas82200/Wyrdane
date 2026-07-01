# TooltipData.gd
# Autoload : Project > Project Settings > Autoload > ajouter sous le nom "TooltipData"
extends Node

# ─── Données descriptives ─────────────────────────────────────────────────────

const KEYWORD_DESCRIPTIONS := {
	Keyword.Type.TAUNT: {
		"title": "Rempart",
		"desc": "Doit être attaqué en priorité par les serviteurs ennemis."
	},
	Keyword.Type.AEGIS: {
		"title": "Égide",
		"desc": "Absorbe la prochaine source de dégâts. Le bouclier disparaît ensuite."
	},
	Keyword.Type.CHARGE: {
		"title": "Assaut",
		"desc": "Peut attaquer dès le tour où elle est invoquée."
	},
	Keyword.Type.LIFESTEAL: {
		"title": "Moisson",
		"desc": "Les dégâts infligés soignent votre héros d'autant."
	},
	Keyword.Type.FURY: {
		"title": "Frénésie",
		"desc": "Peut attaquer deux fois par tour."
	},
	Keyword.Type.DEADLY_POISON: {
		"title": "Venin mortel",
		"desc": "Toute blessure infligée par ce serviteur détruit la cible, quelle que soit sa vie restante."
	},
	Keyword.Type.RAVAGE: {
		"title": "Ravage",
		"desc": "Les dégâts excédentaires sont infligés directement au héros adverse."
	},
	Keyword.Type.BLACK_WINGS: {
		"title": "Ailes noires",
		"desc": "Ignore la rangée Avant ennemie ; peut cibler directement la rangée Arrière ou le héros."
	},
}

const KEYWORD_HUMAN_DESCRIPTIONS := {
	KeywordHuman.Type.DISCIPLINE: {
		"title": "Discipline",
		"desc": "Immunisé aux effets de silence, contrôle mental et peur ennemis."
	},
	KeywordHuman.Type.FORMATION: {
		"title": "Formation",
		"desc": "Tant qu'un serviteur allié est adjacent, ce serviteur gagne +1/+1."
	},
	KeywordHuman.Type.CONTRE_ATTAQUE: {
		"title": "Contre-attaque",
		"desc": "Blessure : si ce serviteur survit, inflige son ATK en retour à l'attaquant."
	},
	KeywordHuman.Type.COMMANDEMENT: {
		"title": "Commandement",
		"desc": "Les serviteurs Humains alliés invoqués après lui gagnent +1/+0 de façon permanente."
	},
	KeywordHuman.Type.FORTIFICATION: {
		"title": "Fortification",
		"desc": "Ne peut pas être déplacé, renvoyé en main ou transformé par des effets ennemis."
	},
}

# Toutes les valeurs "trigger_name" (String) doivent correspondre EXACTEMENT
# aux chaînes utilisées dans TriggerType.get_name() / le champ trigger.type de CardData.
const TRIGGER_DESCRIPTIONS := {
	"ONPLAY":       { "title": "Arrivée",          "desc": "Déclenché lorsque ce serviteur arrive sur le champ de bataille." },
	"DEATHRATTLE":  { "title": "Dernier souffle",  "desc": "Déclenché quand ce serviteur meurt." },
	"CHARGE":       { "title": "Assaut",           "desc": "Peut attaquer dès le tour où elle est invoquée." },
	"OnDamaged":    { "title": "Blessure",         "desc": "Déclenché quand ce serviteur reçoit des dégâts." },
	"OnAwaken":     { "title": "Éveil",            "desc": "Déclenché au début de votre tour." },
	"OnDecline":    { "title": "Déclin",           "desc": "Déclenché au début du tour ennemi." },
	"OnRally":      { "title": "Ralliement",       "desc": "Déclenché quand ce serviteur attaque." },
	"OnGrief":      { "title": "Deuil",            "desc": "Déclenché quand un serviteur allié meurt." },
	"OnSpell":      { "title": "Sortilège",        "desc": "Déclenché quand l'adversaire joue un sort." },
	"OnSacrifice":  { "title": "Sacrifice",        "desc": "Sacrifie un ou plusieurs serviteur en cout supplémentaire" },
	"OnExecution":  { "title": "Exécution",        "desc": "Déclenché quand ce serviteur tue un ennemi en attaquant." },
	"OnCarnage":    { "title": "Carnage",          "desc": "Déclenché quand un serviteur ennemi meurt." },
	"OnAttack":     { "title": "Attaque",          "desc": "Déclenché quand ce serviteur attaque." },
	"OnTurnStart":  { "title": "Début de tour",    "desc": "Déclenché au début de chaque tour." },
	"OnTurnEnd":    { "title": "Fin de tour",      "desc": "Déclenché à la fin de chaque tour." },
	"OnDeathRage":  { "title": "Mort-rage",        "desc": "Déclenché quand un serviteur ennemi meurt." },
	"OnAura":       { "title": "Présence",         "desc": "Effet passif continu actif tant que l'enchantement est en jeu." },
	"OnSummon":     { "title": "Appel",            "desc": "Déclenché chaque fois qu'un serviteur allié entre en jeu." },
	"OnResonance":  { "title": "Résonance",        "desc": "Déclenché quand un serviteur allié attaque." },
}

const RACE_DESCRIPTIONS := {
	Race.Type.UNDEAD: "Mort-Vivant",
	Race.Type.HUMAN:  "Humain",
	Race.Type.ELF:    "Elfe",
	Race.Type.DWARF:  "Nain",
	Race.Type.DEMON:  "Démon",
}

const COLOR_KEYWORD       := Color(0.15, 0.28, 0.48, 1.0)  # Mort-Vivant / partagé
const COLOR_KEYWORD_HUMAN := Color(0.55, 0.42, 0.10, 1.0)  # Humain
const COLOR_TRIGGER       := Color(0.38, 0.22, 0.06, 1.0)
const COLOR_EFFECT        := Color(0.18, 0.32, 0.18, 1.0)

# ─── Génération de la description d'un effet ─────────────────────────────────
# Portée volontairement limitée : Gel, Infection, Transformation, Silence, Vol de serviteur.
# Tout autre effect_id renvoie une chaîne vide (aucun panel généré) tant qu'il n'est pas
# explicitement ajouté ici.

func describe_effect(effect: CardEffect) -> String:
	match effect.effect_id:
		"Freeze":
			return "Empêche un serviteur d'attaquer."
		"InfectEnemy":
			return "Inflige 1 dégât chaque tour."
		"InfectAdjacent":
			return "Inflige l'Infection à un serviteur ennemi adjacent."
		"Transform":
			return "Transforme un serviteur en une autre créature."
		"Silence":
			return "Retire les mots-clés et effets."
		"StealMinion":
			return "Prend le contrôle d'un serviteur ennemi."
		_:
			return ""

func _target_label(target: String) -> String:
	match target:
		"Self":              return "à ce serviteur"
		"EnemyMinion":       return "à un serviteur ennemi"
		"AllyMinion":        return "à un serviteur allié"
		"AnyMinion":         return "à un serviteur"
		"AllEnemies":        return "à tous les serviteurs ennemis"
		"AllAllies":         return "à tous les serviteurs alliés"
		"AllMinions":        return "à tous les serviteurs"
		"AllEnemiesFront":   return "à tous les serviteurs ennemis en première ligne"
		"AllEnemiesBack":    return "à tous les serviteurs ennemis en deuxième ligne"
		"AllAlliesFront":    return "à tous les serviteurs alliés en première ligne"
		"AllAlliesBack":     return "à tous les serviteurs alliés en deuxième ligne"
		"RandomEnemy":       return "à un serviteur ennemi aléatoire"
		"RandomAlly":        return "à un serviteur allié aléatoire"
		"EnemyHero":         return "au héros ennemi"
		"OwnerHero":         return "à votre héros"
		_:                   return "à la cible"

func _count_label(n: int, singular: String, plural: String) -> String:
	return "%d %s" % [n, singular if n <= 1 else plural]

func _count_prefix(n: int, name: String) -> String:
	return "%d × %s" % [n, name] if n > 1 else name

# ─── Fabrique de panels ───────────────────────────────────────────────────────

func make_tooltip_panel(title: String, desc: String,
		header_color: Color = Color(0.22, 0.16, 0.07, 1.0)) -> PanelContainer:
	var bg := StyleBoxFlat.new()
	bg.bg_color                   = Color(0.13, 0.10, 0.06, 0.96)
	bg.border_width_left          = 2
	bg.border_width_right         = 2
	bg.border_width_top           = 2
	bg.border_width_bottom        = 2
	bg.border_color               = Color(0.55, 0.38, 0.10, 1.0)
	bg.corner_radius_top_left     = 6
	bg.corner_radius_top_right    = 6
	bg.corner_radius_bottom_left  = 6
	bg.corner_radius_bottom_right = 6

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.custom_minimum_size = Vector2(220, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title_bg := StyleBoxFlat.new()
	title_bg.bg_color            = header_color
	title_bg.border_width_bottom = 1
	title_bg.border_color        = Color(0.55, 0.38, 0.10, 0.8)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.35, 1.0))
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_stylebox_override("normal", title_bg)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.70, 1.0))
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.add_theme_constant_override("margin_left", 6)
	desc_label.add_theme_constant_override("margin_right", 6)
	desc_label.add_theme_constant_override("margin_bottom", 6)
	vbox.add_child(desc_label)

	return panel

func make_race_tooltip(race_name: String) -> PanelContainer:
	var bg := StyleBoxFlat.new()
	bg.bg_color                   = Color(0.18, 0.18, 0.18, 0.92)
	bg.border_width_left          = 1
	bg.border_width_right         = 1
	bg.border_width_top           = 1
	bg.border_width_bottom        = 1
	bg.border_color               = Color(0.45, 0.45, 0.45, 1.0)
	bg.corner_radius_top_left     = 4
	bg.corner_radius_top_right    = 4
	bg.corner_radius_bottom_left  = 4
	bg.corner_radius_bottom_right = 4

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = race_name
	label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_constant_override("margin_left", 10)
	label.add_theme_constant_override("margin_right", 10)
	label.add_theme_constant_override("margin_top", 4)
	label.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(label)

	return panel

# ─── Construction de la liste de panels pour une carte ───────────────────────

func build_panels_for_card(card_data: CardData, parent: Node) -> Array[Control]:
	var panels: Array[Control] = []

	# 1. Mots-clés Mort-Vivant / partagés (enum Keyword.Type)
	for keyword in card_data.get_keyword_values():
		if not KEYWORD_DESCRIPTIONS.has(keyword):
			continue
		var info: Dictionary = KEYWORD_DESCRIPTIONS[keyword]
		var panel := make_tooltip_panel(info["title"], info["desc"], COLOR_KEYWORD)
		panel.position = Vector2(-9999, -9999)
		parent.add_child(panel)
		panels.append(panel)

	# 1b. Mots-clés Humain (enum KeywordHuman.Type)
	for keyword in card_data.get_human_keyword_values():
		if not KEYWORD_HUMAN_DESCRIPTIONS.has(keyword):
			continue
		var info: Dictionary = KEYWORD_HUMAN_DESCRIPTIONS[keyword]
		var panel := make_tooltip_panel(info["title"], info["desc"], COLOR_KEYWORD_HUMAN)
		panel.position = Vector2(-9999, -9999)
		parent.add_child(panel)
		panels.append(panel)

	# 2. Déclencheurs
	for trigger in card_data.trigger_types:
		if not TRIGGER_DESCRIPTIONS.has(trigger.type):
			continue
		# Garde-fou : Présence (OnAura) est réservé aux Rituels/Enchantements.
		# Si un Serviteur a ce trigger par erreur de données, on l'ignore côté tooltip
		# plutôt que d'afficher un panel trompeur (ex: confusion avec le keyword FORMATION).
		if trigger.type == "OnAura" and card_data.card_type == "Minion":
			continue
		var info: Dictionary = TRIGGER_DESCRIPTIONS[trigger.type]
		var panel := make_tooltip_panel(info["title"], info["desc"], COLOR_TRIGGER)
		panel.position = Vector2(-9999, -9999)
		parent.add_child(panel)
		panels.append(panel)

	# 3. Effets (Gel, Infection, Transformation, Silence, Vol de serviteur uniquement)
	for effect in card_data.effects:
		var desc := describe_effect(effect)
		if desc.is_empty():
			continue
		var title := _effect_title(effect.effect_id)
		var panel := make_tooltip_panel(title, desc, COLOR_EFFECT)
		panel.position = Vector2(-9999, -9999)
		parent.add_child(panel)
		panels.append(panel)

	return panels

func _effect_title(effect_id: String) -> String:
	match effect_id:
		"Freeze":           return "Gel"
		"InfectEnemy":      return "Infection"
		"InfectAdjacent":   return "Infection"
		"Transform":        return "Transformation"
		"Silence":          return "Silence"
		"StealMinion":      return "Vol de serviteur"
		_:                  return effect_id
