extends RefCounted
class_name ProfilePanel

# Vue Profil du menu principal (stats, badge de rang) + récompense de
# connexion quotidienne — extrait de MainMenu.gd. Fonctions statiques
# prenant `menu` (le MainMenu propriétaire) en paramètre, même pattern que
# NewsPanel/QuestsPanel.

static func open(menu) -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	if SteamService.ensure_init():
		var persona := SteamService.local_persona_name()
		if persona != "":
			menu.profile_name_label.text = persona
		var tex := SteamService.local_avatar_texture()
		if tex:
			menu.profile_avatar.texture = tex
	menu.profile_match_stats_label.text = SettingsManager.t("MENU_MATCH_STATS") % [SettingsManager.match_wins, SettingsManager.match_losses]
	_show_placeholders(menu)
	_fetch(menu)
	ReferralPanel.open(menu)

# BackendClient.login_with_steam() est lancé de façon asynchrone au démarrage
# du menu (voir MainMenu._start_backend_sync) : si le joueur ouvre cette vue
# avant la fin de la connexion, is_authenticated() est encore faux. Attendre
# login_succeeded sans jamais relancer la requête laisserait les libellés
# bloqués sur "Chargement..." indéfiniment.
static func _fetch(menu) -> void:
	if BackendClient.is_authenticated():
		BackendClient.get_profile(_on_response.bind(menu))
		return
	if not BackendClient.login_succeeded.is_connected(_on_login_succeeded.bind(menu)):
		BackendClient.login_succeeded.connect(_on_login_succeeded.bind(menu), CONNECT_ONE_SHOT)
	if not BackendClient.login_failed.is_connected(_on_login_failed.bind(menu)):
		BackendClient.login_failed.connect(_on_login_failed.bind(menu), CONNECT_ONE_SHOT)

static func _on_login_succeeded(_user: Dictionary, menu) -> void:
	if menu._current_info_view != menu.InfoView.PROFILE:
		return
	BackendClient.get_profile(_on_response.bind(menu))

static func _on_login_failed(_reason: String, menu) -> void:
	if menu._current_info_view != menu.InfoView.PROFILE:
		return
	_show_unavailable(menu)

static func _on_response(success: bool, data: Dictionary, menu) -> void:
	if menu._current_info_view != menu.InfoView.PROFILE:
		return
	if success:
		_populate_stats(menu, data)
	else:
		_show_unavailable(menu)

static func _show_placeholders(menu) -> void:
	var dash := SettingsManager.t("PROFILE_LOADING")
	menu.profile_member_since_label.text = dash
	menu.profile_collection_label.text = dash
	menu.profile_solo_stats_label.text = dash
	menu.profile_ranked_stats_label.text = dash
	menu.profile_rank_badge_label.text = dash

static func _show_unavailable(menu) -> void:
	var dash := SettingsManager.t("PROFILE_UNAVAILABLE")
	menu.profile_member_since_label.text = dash
	menu.profile_collection_label.text = dash
	menu.profile_solo_stats_label.text = dash
	menu.profile_ranked_stats_label.text = dash
	menu.profile_rank_badge_label.text = dash

static func _populate_stats(menu, data: Dictionary) -> void:
	var created_at: String = str(data.get("created_at", ""))
	var date_str := created_at.substr(0, 10) if created_at.length() >= 10 else SettingsManager.t("PROFILE_UNAVAILABLE")
	menu.profile_member_since_label.text = SettingsManager.t("PROFILE_MEMBER_SINCE") % date_str

	var collection_count := int(data.get("collection_count", 0))
	menu.profile_collection_label.text = SettingsManager.t("PROFILE_COLLECTION_COUNT") % collection_count

	var solo: Dictionary = data.get("solo", {})
	menu.profile_solo_stats_label.text = SettingsManager.t("PROFILE_SOLO_STATS") % [int(solo.get("wins", 0)), int(solo.get("losses", 0))]

	var ranked: Dictionary = data.get("ranked", {})
	menu.profile_ranked_stats_label.text = SettingsManager.t("PROFILE_RANKED_STATS") % [
		int(ranked.get("wins", 0)), int(ranked.get("losses", 0)),
		int(ranked.get("mmr", 0)), int(ranked.get("rank", 0)),
	]
	apply_rank_badge(menu.profile_rank_badge_label, int(ranked.get("mmr", 0)), true)

# Palier dérivé du MMR (voir RankTier) — appliqué au badge du menu principal
# (persistant, avec_progress = false) et à celui de la vue Profil (avec la
# progression vers le palier suivant, plus lisible dans un contexte dédié).
static func apply_rank_badge(label: Label, mmr: int, with_progress: bool) -> void:
	var tier := RankTier.from_mmr(mmr)
	AchievementManager.check_rank_tier(tier)
	label.add_theme_color_override("font_color", RankTier.color(tier))
	var text := SettingsManager.t("RANK_BADGE_FORMAT") % [RankTier.symbol(tier), SettingsManager.t(RankTier.tier_key(tier)), mmr]
	if with_progress:
		var remaining := RankTier.mmr_to_next_tier(mmr)
		if remaining >= 0:
			var next_tier_name := SettingsManager.t(RankTier.tier_key(tier + 1))
			text += "\n" + SettingsManager.t("RANK_BADGE_PROGRESS") % [remaining, next_tier_name]
		else:
			text += "\n" + SettingsManager.t("RANK_BADGE_MAX_TIER")
	label.text = text

static func fetch_rank_badge(menu) -> void:
	if not BackendClient.is_authenticated():
		return
	BackendClient.get_profile(func(success: bool, data: Dictionary):
		if success:
			apply_rank_badge(menu.rank_badge_label, int(data.get("ranked", {}).get("mmr", 0)), false)
	)

# --- Récompense de connexion quotidienne ---------------------------------
# Popup automatique au chargement du menu (une fois la sync backend faite),
# uniquement si pas déjà réclamée aujourd'hui — voir BackendClient.get_login_reward_status.
# Le montant n'est connu qu'une fois réclamé (POST /claim) : /status ne renvoie
# que le palier, pas la récompense associée — évite de dupliquer la table de
# récompenses par palier (REWARD_BY_DAY) côté client, où elle pourrait dériver
# de celle du backend sans que personne ne s'en aperçoive.
static func fetch_login_reward_status(menu) -> void:
	if not BackendClient.is_authenticated():
		return
	BackendClient.get_login_reward_status(func(success: bool, data: Dictionary):
		if not success or bool(data.get("claimed_today", true)):
			return
		_show_login_reward_popup(menu, int(data.get("streak_day", 1)))
	)

static func _show_login_reward_popup(menu, streak_day: int) -> void:
	menu.login_reward_title_label.text = SettingsManager.t("LOGIN_REWARD_TITLE")
	menu.login_reward_streak_label.text = SettingsManager.t("LOGIN_REWARD_STREAK") % streak_day
	menu.login_reward_amount_label.text = ""
	menu.login_reward_claim_button.text = SettingsManager.t("LOGIN_REWARD_CLAIM")
	menu.login_reward_claim_button.disabled = false
	menu.login_reward_popup.visible = true
	menu._fade_in_overlay(menu.login_reward_popup)

static func on_claim_login_reward_pressed(menu) -> void:
	menu.login_reward_claim_button.disabled = true
	BackendClient.claim_login_reward(func(success: bool, data: Dictionary):
		if not success:
			menu.login_reward_claim_button.disabled = false
			return
		AudioManager.play(AudioManager.CONFIRM)
		CurrencyManager.sync_from_backend()
		menu.login_reward_amount_label.text = SettingsManager.t("LOGIN_REWARD_AMOUNT") % int(data.get("reward_currency", 0))
		menu.login_reward_claim_button.text = SettingsManager.t("LOGIN_REWARD_CLAIMED")
		await menu.get_tree().create_timer(1.4).timeout
		menu.login_reward_popup.visible = false
	)
