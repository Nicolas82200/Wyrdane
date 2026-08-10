# TooltipData.gd
# Autoload : Project > Project Settings > Autoload > ajouter sous le nom "TooltipData"
extends Node

# ─── Données descriptives ─────────────────────────────────────────────────────

# Chaque entrée mappe l'enum vers les clés de traduction (nom + description)
# définies dans translations/game.csv. Le texte affiché est résolu au moment de
# construire le tooltip (voir _tr) pour suivre la langue courante.
const KEYWORD_DESCRIPTIONS := {
	Keyword.Type.TAUNT:         { "title": "KW_TAUNT_NAME",         "desc": "KW_TAUNT_DESC" },
	Keyword.Type.AEGIS:         { "title": "KW_AEGIS_NAME",         "desc": "KW_AEGIS_DESC" },
	Keyword.Type.CHARGE:        { "title": "KW_CHARGE_NAME",        "desc": "KW_CHARGE_DESC" },
	Keyword.Type.LIFESTEAL:     { "title": "KW_LIFESTEAL_NAME",     "desc": "KW_LIFESTEAL_DESC" },
	Keyword.Type.FURY:          { "title": "KW_FURY_NAME",          "desc": "KW_FURY_DESC" },
	Keyword.Type.DEADLY_POISON: { "title": "KW_DEADLY_POISON_NAME", "desc": "KW_DEADLY_POISON_DESC" },
	Keyword.Type.RAVAGE:        { "title": "KW_RAVAGE_NAME",        "desc": "KW_RAVAGE_DESC" },
	Keyword.Type.BLACK_WINGS:   { "title": "KW_BLACK_WINGS_NAME",   "desc": "KW_BLACK_WINGS_DESC" },
}

const KEYWORD_HUMAN_DESCRIPTIONS := {
	KeywordHuman.Type.DISCIPLINE:     { "title": "KW_DISCIPLINE_NAME",     "desc": "KW_DISCIPLINE_DESC" },
	KeywordHuman.Type.FORMATION:      { "title": "KW_FORMATION_NAME",      "desc": "KW_FORMATION_DESC" },
	KeywordHuman.Type.CONTRE_ATTAQUE: { "title": "KW_CONTRE_ATTAQUE_NAME", "desc": "KW_CONTRE_ATTAQUE_DESC" },
	KeywordHuman.Type.COMMANDEMENT:   { "title": "KW_COMMANDEMENT_NAME",   "desc": "KW_COMMANDEMENT_DESC" },
	KeywordHuman.Type.FORTIFICATION:  { "title": "KW_FORTIFICATION_NAME",  "desc": "KW_FORTIFICATION_DESC" },
}

const KEYWORD_UNDEAD_DESCRIPTIONS := {
	KeywordUndead.Type.PESTIFERE:   { "title": "KW_PESTIFERE_NAME",   "desc": "KW_PESTIFERE_DESC" },
	KeywordUndead.Type.NECROPHAGE:  { "title": "KW_NECROPHAGE_NAME",  "desc": "KW_NECROPHAGE_DESC" },
	KeywordUndead.Type.HORDE:       { "title": "KW_HORDE_NAME",       "desc": "KW_HORDE_DESC" },
	KeywordUndead.Type.REVENANT:    { "title": "KW_REVENANT_NAME",    "desc": "KW_REVENANT_DESC" },
	KeywordUndead.Type.CHAIR_MORTE: { "title": "KW_CHAIR_MORTE_NAME", "desc": "KW_CHAIR_MORTE_DESC" },
}

const KEYWORD_DEMON_DESCRIPTIONS := {
	KeywordDemon.Type.PACTE:           { "title": "KW_PACTE_NAME",           "desc": "KW_PACTE_DESC" },
	KeywordDemon.Type.CORRUPTION:      { "title": "KW_CORRUPTION_NAME",      "desc": "KW_CORRUPTION_DESC" },
	KeywordDemon.Type.TERREUR:         { "title": "KW_TERREUR_NAME",         "desc": "KW_TERREUR_DESC" },
	KeywordDemon.Type.RANG_INFERNAL:   { "title": "KW_RANG_INFERNAL_NAME",   "desc": "KW_RANG_INFERNAL_DESC" },
	KeywordDemon.Type.CHAIR_DE_SOUFRE: { "title": "KW_CHAIR_DE_SOUFRE_NAME", "desc": "KW_CHAIR_DE_SOUFRE_DESC" },
	KeywordDemon.Type.SANG_NOIR:       { "title": "KW_SANG_NOIR_NAME",       "desc": "KW_SANG_NOIR_DESC" },
}

const KEYWORD_ABOMINATION_DESCRIPTIONS := {
	KeywordAbomination.Type.MUTATION:        { "title": "KW_MUTATION_NAME",        "desc": "KW_MUTATION_DESC" },
	KeywordAbomination.Type.FUSION:          { "title": "KW_FUSION_NAME",          "desc": "KW_FUSION_DESC" },
	KeywordAbomination.Type.VIRULENT:        { "title": "KW_VIRULENT_NAME",        "desc": "KW_VIRULENT_DESC" },
	KeywordAbomination.Type.CHAIR_ADAPTATIVE:{ "title": "KW_CHAIR_ADAPTATIVE_NAME","desc": "KW_CHAIR_ADAPTATIVE_DESC" },
	KeywordAbomination.Type.ASSIMILATION:    { "title": "KW_ASSIMILATION_NAME",    "desc": "KW_ASSIMILATION_DESC" },
	KeywordAbomination.Type.INSTABLE:        { "title": "KW_INSTABLE_NAME",        "desc": "KW_INSTABLE_DESC" },
}

# ─── Icônes de mots-clés ───────────────────────────────────────────────────────
# Source unique, réutilisée par BoardMinion (icônes sous le serviteur) et par les
# tooltips (icône dans l'en-tête du panel) pour ne jamais désynchroniser les deux.
const KEYWORD_ICONS := {
	Keyword.Type.TAUNT:         preload("res://assets/icons/keyword/dragon-shield.svg"),
	Keyword.Type.CHARGE:        preload("res://assets/icons/keyword/axe-swing.svg"),
	Keyword.Type.AEGIS:         preload("res://assets/icons/keyword/shield-reflect.svg"),
	Keyword.Type.LIFESTEAL:     preload("res://assets/icons/keyword/pretty-fangs.svg"),
	Keyword.Type.FURY:          preload("res://assets/icons/keyword/sword-clash.svg"),
	Keyword.Type.DEADLY_POISON: preload("res://assets/icons/keyword/foamy-disc.svg"),
	Keyword.Type.RAVAGE:        preload("res://assets/icons/keyword/gooey-impact.svg"),
	Keyword.Type.BLACK_WINGS:   preload("res://assets/icons/keyword/hood.svg"),
}

const KEYWORD_HUMAN_ICONS := {
	KeywordHuman.Type.DISCIPLINE:     preload("res://assets/icons/keyword/suspicious.svg"),
	KeywordHuman.Type.FORMATION:      preload("res://assets/icons/keyword/rally-the-troops.svg"),
	KeywordHuman.Type.CONTRE_ATTAQUE: preload("res://assets/icons/keyword/riposte.svg"),
	KeywordHuman.Type.COMMANDEMENT:   preload("res://assets/icons/keyword/knight-banner.svg"),
	KeywordHuman.Type.FORTIFICATION:  preload("res://assets/icons/keyword/crenulated-shield.svg"),
}

const KEYWORD_UNDEAD_ICONS := {
	KeywordUndead.Type.PESTIFERE:   preload("res://assets/icons/keyword/bird-mask.svg"),
	KeywordUndead.Type.NECROPHAGE:  preload("res://assets/icons/keyword/carrion.svg"),
	KeywordUndead.Type.HORDE:       preload("res://assets/icons/keyword/dark-squad.svg"),
	KeywordUndead.Type.REVENANT:    preload("res://assets/icons/keyword/raise-zombie.svg"),
	KeywordUndead.Type.CHAIR_MORTE: preload("res://assets/icons/keyword/lost-limb.svg"),
}

const KEYWORD_DEMON_ICONS := {
	KeywordDemon.Type.PACTE:           preload("res://assets/icons/keyword/death-juice.svg"),
	KeywordDemon.Type.CORRUPTION:      preload("res://assets/icons/keyword/evil-comet.svg"),
	KeywordDemon.Type.TERREUR:         preload("res://assets/icons/keyword/terror.svg"),
	KeywordDemon.Type.RANG_INFERNAL:   preload("res://assets/icons/keyword/daemon-skull.svg"),
	KeywordDemon.Type.CHAIR_DE_SOUFRE: preload("res://assets/icons/keyword/fire-silhouette.svg"),
	KeywordDemon.Type.SANG_NOIR:       preload("res://assets/icons/keyword/blood.svg"),
}

const KEYWORD_ABOMINATION_ICONS := {
	KeywordAbomination.Type.MUTATION:         preload("res://assets/icons/keyword/dna1.svg"),
	KeywordAbomination.Type.FUSION:           preload("res://assets/icons/keyword/swallow.svg"),
	KeywordAbomination.Type.VIRULENT:         preload("res://assets/icons/keyword/poison-gas.svg"),
	KeywordAbomination.Type.CHAIR_ADAPTATIVE: preload("res://assets/icons/keyword/mucous-pillar.svg"),
	KeywordAbomination.Type.ASSIMILATION:     preload("res://assets/icons/keyword/lightning-electron.svg"),
	KeywordAbomination.Type.INSTABLE:         preload("res://assets/icons/keyword/unstable-orb.svg"),
}

# Les clés de ce dict (String) doivent correspondre EXACTEMENT au champ
# trigger.type de CardData ; les valeurs pointent vers game.csv.
const TRIGGER_DESCRIPTIONS := {
	"ONPLAY":       { "title": "TRIG_ONPLAY_NAME",      "desc": "TRIG_ONPLAY_DESC" },
	"DEATHRATTLE":  { "title": "TRIG_DEATHRATTLE_NAME", "desc": "TRIG_DEATHRATTLE_DESC" },
	"CHARGE":       { "title": "TRIG_CHARGE_NAME",      "desc": "TRIG_CHARGE_DESC" },
	"OnDamaged":    { "title": "TRIG_ONDAMAGED_NAME",   "desc": "TRIG_ONDAMAGED_DESC" },
	"OnAwaken":     { "title": "TRIG_ONAWAKEN_NAME",    "desc": "TRIG_ONAWAKEN_DESC" },
	"OnDecline":    { "title": "TRIG_ONDECLINE_NAME",   "desc": "TRIG_ONDECLINE_DESC" },
	"OnGrief":      { "title": "TRIG_ONGRIEF_NAME",     "desc": "TRIG_ONGRIEF_DESC" },
	"OnSpell":      { "title": "TRIG_ONSPELL_NAME",     "desc": "TRIG_ONSPELL_DESC" },
	"OnSacrifice":  { "title": "TRIG_ONSACRIFICE_NAME", "desc": "TRIG_ONSACRIFICE_DESC" },
	"OnExecution":  { "title": "TRIG_ONEXECUTION_NAME", "desc": "TRIG_ONEXECUTION_DESC" },
	"OnCarnage":    { "title": "TRIG_ONCARNAGE_NAME",   "desc": "TRIG_ONCARNAGE_DESC" },
	"OnAttack":     { "title": "TRIG_ONATTACK_NAME",    "desc": "TRIG_ONATTACK_DESC" },
	"OnDeathRage":  { "title": "TRIG_ONDEATHRAGE_NAME", "desc": "TRIG_ONDEATHRAGE_DESC" },
	"OnAura":       { "title": "TRIG_ONAURA_NAME",      "desc": "TRIG_ONAURA_DESC" },
	"OnSummon":     { "title": "TRIG_ONSUMMON_NAME",    "desc": "TRIG_ONSUMMON_DESC" },
	"OnResonance":  { "title": "TRIG_ONRESONANCE_NAME", "desc": "TRIG_ONRESONANCE_DESC" },
	"OnSelfDamage": { "title": "TRIG_ONSELFDAMAGE_NAME", "desc": "TRIG_ONSELFDAMAGE_DESC" },
	"OnMutation":   { "title": "TRIG_ONMUTATION_NAME",   "desc": "TRIG_ONMUTATION_DESC" },
	"OnDevoration": { "title": "TRIG_ONDEVORATION_NAME", "desc": "TRIG_ONDEVORATION_DESC" },
}

const RACE_DESCRIPTIONS := {
	Race.Type.UNDEAD: "RACE_UNDEAD",
	Race.Type.HUMAN:  "RACE_HUMAN",
	Race.Type.ELF:    "RACE_ELF",
	Race.Type.DWARF:  "RACE_DWARF",
	Race.Type.DEMON:  "RACE_DEMON",
	Race.Type.ABOMINATION: "RACE_ABOMINATION",
}

# Résout une clé de traduction dans la langue courante.
func _tr(key: String) -> String:
	return TranslationServer.translate(key)

const COLOR_KEYWORD        := Color(0.15, 0.28, 0.48, 1.0)  # Mots-clés partagés
const COLOR_KEYWORD_HUMAN  := Color(0.55, 0.42, 0.10, 1.0)  # Humain
const COLOR_KEYWORD_UNDEAD := Color(0.25, 0.36, 0.16, 1.0)  # Mort-Vivant (vert putride)
const COLOR_KEYWORD_DEMON  := Color(0.42, 0.12, 0.12, 1.0)  # Démon (rouge écarlate)
const COLOR_KEYWORD_ABOMINATION := Color(0.30, 0.40, 0.10, 1.0)  # Abomination (vert bilieux)
const COLOR_TRIGGER       := Color(0.38, 0.22, 0.06, 1.0)
const COLOR_EFFECT        := Color(0.18, 0.32, 0.18, 1.0)

# ─── Génération de la description d'un effet ─────────────────────────────────
# Portée volontairement limitée : Gel, Infection, Transformation, Silence, Vol de serviteur.
# Tout autre effect_id renvoie une chaîne vide (aucun panel généré) tant qu'il n'est pas
# explicitement ajouté ici.

func describe_effect(effect: CardEffect) -> String:
	match effect.effect_id:
		"Freeze":          return _tr("EFF_FREEZE_DESC")
		"InfectEnemy":     return _tr("EFF_INFECT_ENEMY_DESC")
		"InfectAdjacent":  return _tr("EFF_INFECT_ADJ_DESC")
		"Transform":       return _tr("EFF_TRANSFORM_DESC")
		"Silence":         return _tr("EFF_SILENCE_DESC")
		"StealMinion":     return _tr("EFF_STEAL_DESC")
		"Corrupt":         return _tr("EFF_CORRUPT_DESC")
		"StealMinionThenDestroy": return _tr("EFF_STEAL_DESTROY_DESC")
		_:                 return ""

# ─── Fabrique de panels ───────────────────────────────────────────────────────

func make_tooltip_panel(title: String, desc: String,
		header_color: Color = Color(0.22, 0.16, 0.07, 1.0),
		icon: Texture2D = null) -> PanelContainer:
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
	panel.custom_minimum_size = Vector2(195, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title_bg := StyleBoxFlat.new()
	title_bg.bg_color            = header_color
	title_bg.border_width_bottom = 1
	title_bg.border_color        = Color(0.55, 0.38, 0.10, 0.8)
	title_bg.content_margin_top    = 4
	title_bg.content_margin_bottom = 4
	title_bg.content_margin_left   = 6
	title_bg.content_margin_right  = 6

	var title_panel := PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", title_bg)
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_panel)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(title_row)

	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture             = icon
		icon_rect.custom_minimum_size = Vector2(18, 18)
		icon_rect.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		title_row.add_child(icon_rect)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.35, 1.0))
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.70, 1.0))
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# MarginContainer plutôt que des theme overrides "margin_*" posés
	# directement sur le Label : Label n'a pas de constante de thème de ce nom,
	# ces overrides n'avaient donc aucun effet (texte collé à la bordure).
	var desc_margin := MarginContainer.new()
	desc_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_margin.add_theme_constant_override("margin_left", 8)
	desc_margin.add_theme_constant_override("margin_right", 8)
	desc_margin.add_theme_constant_override("margin_top", 2)
	desc_margin.add_theme_constant_override("margin_bottom", 8)
	desc_margin.add_child(desc_label)
	vbox.add_child(desc_margin)

	return panel

# race_key : une clé de traduction de race (RACE_*), résolue dans la langue courante.
func make_race_tooltip(race_key: String) -> PanelContainer:
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
	label.text = _tr(race_key)
	label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# MarginContainer plutôt qu'un override "margin_*" sur le Label lui-même
	# (constante de thème inexistante sur Label, donc sans effet).
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(label)
	panel.add_child(margin)

	return panel

# ─── Construction de la liste de panels pour une carte ───────────────────────

func build_panels_for_card(card_data: CardData, parent: Node) -> Array[Control]:
	var panels: Array[Control] = []

	# 1. Mots-clés Mort-Vivant / partagés (enum Keyword.Type)
	for keyword in card_data.get_keyword_values():
		if not KEYWORD_DESCRIPTIONS.has(keyword):
			continue
		var info: Dictionary = KEYWORD_DESCRIPTIONS[keyword]
		var panel := make_tooltip_panel(_tr(info["title"]), _tr(info["desc"]), COLOR_KEYWORD, KEYWORD_ICONS.get(keyword))
		panel.position = Vector2(-9999, -9999)
		parent.add_child(panel)
		panels.append(panel)

	# 1b. Mots-clés Humain (enum KeywordHuman.Type)
	for keyword in card_data.get_human_keyword_values():
		if not KEYWORD_HUMAN_DESCRIPTIONS.has(keyword):
			continue
		var info: Dictionary = KEYWORD_HUMAN_DESCRIPTIONS[keyword]
		var panel := make_tooltip_panel(_tr(info["title"]), _tr(info["desc"]), COLOR_KEYWORD_HUMAN, KEYWORD_HUMAN_ICONS.get(keyword))
		panel.position = Vector2(-9999, -9999)
		parent.add_child(panel)
		panels.append(panel)

	# 1c. Mots-clés Mort-Vivant (enum KeywordUndead.Type)
	for keyword in card_data.get_undead_keyword_values():
		if not KEYWORD_UNDEAD_DESCRIPTIONS.has(keyword):
			continue
		var info: Dictionary = KEYWORD_UNDEAD_DESCRIPTIONS[keyword]
		var panel := make_tooltip_panel(_tr(info["title"]), _tr(info["desc"]), COLOR_KEYWORD_UNDEAD, KEYWORD_UNDEAD_ICONS.get(keyword))
		panel.position = Vector2(-9999, -9999)
		parent.add_child(panel)
		panels.append(panel)

	# 1d. Mots-clés Démon (enum KeywordDemon.Type)
	for keyword in card_data.get_demon_keyword_values():
		if not KEYWORD_DEMON_DESCRIPTIONS.has(keyword):
			continue
		var info: Dictionary = KEYWORD_DEMON_DESCRIPTIONS[keyword]
		var panel := make_tooltip_panel(_tr(info["title"]), _tr(info["desc"]), COLOR_KEYWORD_DEMON, KEYWORD_DEMON_ICONS.get(keyword))
		panel.position = Vector2(-9999, -9999)
		parent.add_child(panel)
		panels.append(panel)

	# 1e. Mots-clés Abomination (enum KeywordAbomination.Type)
	for keyword in card_data.get_abomination_keyword_values():
		if not KEYWORD_ABOMINATION_DESCRIPTIONS.has(keyword):
			continue
		var info: Dictionary = KEYWORD_ABOMINATION_DESCRIPTIONS[keyword]
		var panel := make_tooltip_panel(_tr(info["title"]), _tr(info["desc"]), COLOR_KEYWORD_ABOMINATION, KEYWORD_ABOMINATION_ICONS.get(keyword))
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
		var panel := make_tooltip_panel(_tr(info["title"]), _tr(info["desc"]), COLOR_TRIGGER)
		panel.position = Vector2(-9999, -9999)
		parent.add_child(panel)
		panels.append(panel)

	# 2b. Charges (Rituels à durée limitée uniquement — pas les rituels permanents)
	if card_data.card_type == "Ritual" and card_data.ritual_duration > 0:
		var charges_panel := make_tooltip_panel(
			_tr("RITUAL_CHARGES_NAME"), _tr("RITUAL_CHARGES_DESC"), COLOR_TRIGGER)
		charges_panel.position = Vector2(-9999, -9999)
		parent.add_child(charges_panel)
		panels.append(charges_panel)

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
		"Freeze":           return _tr("EFF_FREEZE_NAME")
		"InfectEnemy":      return _tr("EFF_INFECT_NAME")
		"InfectAdjacent":   return _tr("EFF_INFECT_NAME")
		"Transform":        return _tr("EFF_TRANSFORM_NAME")
		"Silence":          return _tr("EFF_SILENCE_NAME")
		"StealMinion":      return _tr("EFF_STEAL_NAME")
		"Corrupt":          return _tr("EFF_CORRUPT_NAME")
		"StealMinionThenDestroy": return _tr("EFF_STEAL_NAME")
		_:                  return effect_id
