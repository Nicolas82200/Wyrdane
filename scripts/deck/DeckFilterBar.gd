extends RefCounted
class_name DeckFilterBar

# Construction des barres de filtres/tri du deck builder (radios race/type/
# rareté/coût, bouton bascule "cacher les cartes non débloquées", dropdown
# mot-clé, tri) — extrait de DeckBuilder.gd. Les callables passées à
# `_add_filter_group`/`_make_keyword_dropdown` referencent directement l'état
# de `builder` (`builder._filter_race`, `builder._refresh_card_grid()`...).

## Crée la barre de filtres directement en code sous la SearchEdit.
## Appelée depuis DeckBuilder._retranslate() (reconstruit aussi au changement
## de langue : la sélection active est préservée car chaque groupe s'initialise
## depuis les variables `builder._filter_*`).
static func build_filter_bar(builder) -> void:
	# remove_child() avant queue_free() : la suppression du parent est immédiate
	# (queue_free() seul ne libère qu'en fin de frame, donc les anciens boutons
	# compteraient encore dans la taille calculée de cette HFlowContainer le
	# temps d'ajouter les nouveaux juste après, la faisant paraître trop haute
	# le temps d'une frame — et avec elle, la grille de cartes en dessous qui se
	# retrouve décalée/rognée en haut).
	for child in builder.filter_bar.get_children():
		builder.filter_bar.remove_child(child)
		child.queue_free()

	var all_label := SettingsManager.t("deck.filter_all")

	# Race (seules les races dotées de cartes sont proposées comme filtre)
	var race_values: Array = [-1]
	var race_labels: Array[String] = [all_label]
	var race_keys := Race.Type.keys()
	for race_value in Race.get_implemented_races():
		race_values.append(race_value)
		race_labels.append(SettingsManager.t("RACE_" + race_keys[race_value]))
	_add_labeled_filter_group(builder.filter_bar, SettingsManager.t("deck.filter_race"), race_values,
		func(v: int) -> void: builder._filter_race = v; builder._refresh_card_grid(),
		func() -> int: return builder._filter_race,
		race_labels)

	# Type de carte
	_add_labeled_filter_group(builder.filter_bar, SettingsManager.t("deck.filter_type"),
		["", "Minion", "Instant", "Ritual", "Enchantment", "Resource"],
		func(v: String) -> void: builder._filter_type = v; builder._refresh_card_grid(),
		func() -> String: return builder._filter_type,
		[all_label, SettingsManager.t("cardtype.minion"), SettingsManager.t("cardtype.instant"),
			SettingsManager.t("cardtype.ritual"), SettingsManager.t("cardtype.enchantment"),
			SettingsManager.t("cardtype.resource")])

	# Rareté
	_add_labeled_filter_group(builder.filter_bar, SettingsManager.t("deck.filter_rarity"),
		["", "Common", "Rare", "Epic", "Legendary"],
		func(v: String) -> void: builder._filter_rarity = v; builder._refresh_card_grid(),
		func() -> String: return builder._filter_rarity,
		[all_label, "Common", "Rare", "Epic", "Legendary"])

	# Coût
	_add_labeled_filter_group(builder.filter_bar, SettingsManager.t("deck.filter_cost"),
		[-1, 0, 1, 2, 3, 4, 5, 6, 7],
		func(v: int) -> void: builder._filter_cost = v; builder._refresh_card_grid(),
		func() -> int: return builder._filter_cost,
		[all_label, "0", "1", "2", "3", "4", "5", "6", "7+"])

	# Cacher/montrer les cartes non débloquées (bouton à bascule seul, pas un groupe radio)
	var lock_btn := Button.new()
	lock_btn.text            = SettingsManager.t("deck.filter_hide_locked")
	lock_btn.toggle_mode     = true
	lock_btn.button_pressed  = builder._filter_hide_locked
	lock_btn.custom_minimum_size = Vector2(0, 26)
	lock_btn.add_theme_font_size_override("font_size", 12)
	_style_filter_button(lock_btn, builder._filter_hide_locked)
	lock_btn.toggled.connect(func(pressed: bool) -> void:
		builder._filter_hide_locked = pressed
		_style_filter_button(lock_btn, pressed)
		builder._refresh_card_grid())
	builder.filter_bar.add_child(lock_btn)

## Barre secondaire : filtre par mot-clé (dropdown, trop de valeurs pour des
## boutons radio) et tri de la grille de cartes.
static func build_sort_bar(builder) -> void:
	# Voir build_filter_bar ci-dessus : remove_child() immédiat avant
	# queue_free(), pour ne pas fausser la taille calculée de cette
	# HFlowContainer pendant la reconstruction.
	for child in builder.sort_bar.get_children():
		builder.sort_bar.remove_child(child)
		child.queue_free()

	var all_label := SettingsManager.t("deck.filter_all")

	var kw_wrap := HBoxContainer.new()
	kw_wrap.add_theme_constant_override("separation", 6)
	kw_wrap.add_child(_make_filter_label(SettingsManager.t("deck.filter_keyword")))
	var kw_values: Array[String] = [""]
	var kw_labels: Array[String] = [all_label]
	for entry in _all_keyword_entries():
		kw_values.append(entry["id"])
		kw_labels.append(entry["label"])
	kw_wrap.add_child(_make_keyword_dropdown(builder, kw_values, kw_labels))
	builder.sort_bar.add_child(kw_wrap)

	var sort_spacer := Control.new()
	sort_spacer.custom_minimum_size = Vector2(20, 0)
	builder.sort_bar.add_child(sort_spacer)

	_add_labeled_filter_group(builder.sort_bar, SettingsManager.t("deck.sort_label"),
		["", "cost", "name", "rarity"],
		func(v: String) -> void: builder._sort_mode = v; builder._refresh_card_grid(),
		func() -> String: return builder._sort_mode,
		[SettingsManager.t("deck.sort_default"), SettingsManager.t("deck.sort_cost"),
			SettingsManager.t("deck.sort_name"), SettingsManager.t("deck.sort_rarity")])

## Rassemble tous les mots-clés (générique + 3 races) sous forme d'ids "pool:value".
static func _all_keyword_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key in Keyword.Type.keys():
		var v: int = Keyword.Type[key]
		entries.append({"id": "K:%d" % v, "label": Keyword.get_keyword_name(v)})
	for key in KeywordHuman.Type.keys():
		var v: int = KeywordHuman.Type[key]
		entries.append({"id": "H:%d" % v, "label": KeywordHuman.get_keyword_name(v)})
	for key in KeywordUndead.Type.keys():
		var v: int = KeywordUndead.Type[key]
		entries.append({"id": "U:%d" % v, "label": KeywordUndead.get_keyword_name(v)})
	for key in KeywordDemon.Type.keys():
		var v: int = KeywordDemon.Type[key]
		entries.append({"id": "D:%d" % v, "label": KeywordDemon.get_keyword_name(v)})
	for key in KeywordAbomination.Type.keys():
		var v: int = KeywordAbomination.Type[key]
		entries.append({"id": "A:%d" % v, "label": KeywordAbomination.get_keyword_name(v)})
	return entries

static func _make_keyword_dropdown(builder, values: Array[String], labels: Array[String]) -> OptionButton:
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(170, 26)
	opt.add_theme_font_size_override("font_size", 12)
	for i in range(labels.size()):
		opt.add_item(labels[i])
	var current_idx := values.find(builder._filter_keyword)
	opt.selected = max(current_idx, 0)
	opt.item_selected.connect(func(idx: int) -> void:
		builder._filter_keyword = values[idx]
		builder._refresh_card_grid())
	return opt

static func _make_filter_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4, 1))
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

## Comme _add_filter_group, mais enveloppe le libellé et son groupe de boutons
## dans un seul HBoxContainer — évite qu'une HFlowContainer ne renvoie le
## libellé seul à la ligne en séparant "Coût :" de ses boutons quand la
## largeur manque.
static func _add_labeled_filter_group(parent: Control, label_text: String, values: Array,
		on_select: Callable, get_current: Callable, labels: Array) -> void:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(_make_filter_label(label_text))
	_add_filter_group(wrap, values, on_select, get_current, labels)
	parent.add_child(wrap)

## Crée un groupe de boutons radio pour un filtre donné.
## values      : tableau de valeurs (String ou int)
## on_select   : callable(value) appelé au clic
## get_current : callable() → valeur active
## labels      : libellés affichés (même taille que values)
static func _add_filter_group(parent: Control, values: Array, on_select: Callable,
		get_current: Callable, labels: Array) -> void:
	var group_box := HBoxContainer.new()
	group_box.add_theme_constant_override("separation", 2)
	parent.add_child(group_box)

	var buttons: Array[Button] = []
	for i in range(values.size()):
		var val   = values[i]
		var label = labels[i] if i < labels.size() else str(val)
		var btn   := Button.new()
		btn.text               = label
		btn.toggle_mode        = true
		btn.button_pressed     = (val == get_current.call())
		btn.custom_minimum_size = Vector2(0, 26)
		btn.add_theme_font_size_override("font_size", 12)
		_style_filter_button(btn, btn.button_pressed)
		buttons.append(btn)
		group_box.add_child(btn)

		btn.pressed.connect(func() -> void:
			# Déselectionne les autres du groupe
			for b in buttons:
				b.button_pressed = false
				_style_filter_button(b, false)
			btn.button_pressed = true
			_style_filter_button(btn, true)
			on_select.call(val)
		)

static func _style_filter_button(btn: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color                   = Color(0.35, 0.26, 0.06, 0.9) if active else Color(0.12, 0.10, 0.08, 0.85)
	sb.border_color               = Color(0.78, 0.58, 0.10, 1) if active else Color(0.30, 0.24, 0.10, 0.6)
	sb.border_width_left          = 1
	sb.border_width_right         = 1
	sb.border_width_top           = 1
	sb.border_width_bottom        = 1
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left        = 7
	sb.content_margin_right       = 7
	sb.content_margin_top         = 3
	sb.content_margin_bottom      = 3
	btn.add_theme_stylebox_override("normal",   sb)
	btn.add_theme_stylebox_override("pressed",  sb)
	btn.add_theme_stylebox_override("hover",    sb)
	var font_color := Color(0.98, 0.85, 0.40, 1) if active else Color(0.72, 0.64, 0.48, 1)
	btn.add_theme_color_override("font_color",         font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_hover_color",   Color(1, 0.92, 0.60, 1))
