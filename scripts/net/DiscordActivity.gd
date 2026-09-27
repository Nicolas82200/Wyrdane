# DiscordActivity.gd
class_name DiscordActivity
extends RefCounted

# Logique PURE du Rich Presence Discord : correspondance état de jeu -> texte
# affiché, et encodage du protocole IPC. Volontairement séparé de
# `DiscordPresence` (l'autoload qui parle réellement au client Discord) pour
# être testable sans thread, sans pipe et sans autoload — voir
# `tests/unit/test_discord_activity.gd`.
#
# Le protocole RPC local de Discord est une suite de trames :
#   [opcode: u32 little-endian][longueur du corps: u32 little-endian][corps JSON]
# (mêmes trames dans les deux sens, voir `decode_header`).

const OP_HANDSHAKE := 0
const OP_FRAME := 1
const OP_CLOSE := 2
const OP_PING := 3
const OP_PONG := 4

const HEADER_SIZE := 8

# États de jeu reconnus. Passés tels quels à `DiscordPresence.set_state()`.
const STATE_MENU := "menu"
const STATE_DECKBUILDER := "deckbuilder"
const STATE_QUEUE := "queue"
const STATE_BATTLE := "battle"
const STATE_ARENA := "arena"

# Clé du visuel côté Discord : c'est le NOM de l'asset téléversé dans l'onglet
# Rich Presence > Art Assets de l'application Discord, pas un chemin local. Un
# nom inconnu est silencieusement ignoré par Discord (le champ disparaît de la
# réponse SET_ACTIVITY, sans erreur) — la présence reste donc fonctionnelle
# tant que l'asset n'a pas été téléversé.
const LARGE_IMAGE := "logo"

# Texte affiché au survol du visuel. Nom du jeu en dur (pas de traduction : un
# nom propre est identique dans les deux langues).
const LARGE_TEXT := "Wyrdane"

# Retourne la clé de traduction décrivant l'état courant (résolue par
# l'appelant via `SettingsManager.t()` — garder la résolution dehors permet de
# tester cette correspondance sans initialiser le TranslationServer).
#
# `ctx` peut porter : `ranked` (bool), `vs_ai` (bool), `tutorial` (bool).
# Volontairement générique : aucun pseudo d'adversaire n'est exposé dans la
# présence Discord, qui est visible par tous les amis du joueur.
static func details_key(state: String, ctx: Dictionary = {}) -> String:
	match state:
		STATE_MENU:
			return "DISCORD_PRESENCE_MENU"
		STATE_DECKBUILDER:
			return "DISCORD_PRESENCE_DECKBUILDER"
		STATE_QUEUE:
			return "DISCORD_PRESENCE_QUEUE_RANKED" if bool(ctx.get("ranked", false)) else "DISCORD_PRESENCE_QUEUE"
		STATE_BATTLE:
			if bool(ctx.get("tutorial", false)):
				return "DISCORD_PRESENCE_TUTORIAL"
			if bool(ctx.get("vs_ai", false)):
				return "DISCORD_PRESENCE_BATTLE_AI"
			return "DISCORD_PRESENCE_BATTLE_RANKED" if bool(ctx.get("ranked", false)) else "DISCORD_PRESENCE_BATTLE"
		STATE_ARENA:
			return "DISCORD_PRESENCE_ARENA"
		_:
			# État inconnu (ajout d'une scène sans mise à jour d'ici) : plutôt
			# qu'une clé absente affichée telle quelle dans la présence, on
			# retombe sur un libellé neutre.
			return "DISCORD_PRESENCE_PLAYING"

# Construit l'objet `activity` du protocole Discord. `started_unix` est l'heure
# de début de l'état courant : Discord en déduit lui-même le chrono affiché
# ("12:34 elapsed"), incrémenté côté client — inutile donc de renvoyer une
# activité juste pour faire avancer le compteur.
static func build_activity(details: String, started_unix: int) -> Dictionary:
	var activity := {
		"type": 0,  # 0 = "Playing"
		"details": details,
		"assets": {"large_image": LARGE_IMAGE, "large_text": LARGE_TEXT},
	}
	if started_unix > 0:
		activity["timestamps"] = {"start": started_unix}
	return activity

# Trame complète prête à écrire dans le pipe.
static func encode_frame(opcode: int, payload: Dictionary) -> PackedByteArray:
	var body := JSON.stringify(payload).to_utf8_buffer()
	var frame := PackedByteArray()
	frame.resize(HEADER_SIZE)
	frame.encode_u32(0, opcode)
	frame.encode_u32(4, body.size())
	frame.append_array(body)
	return frame

# Corps du handshake d'ouverture (opcode 0). `client_id` est l'identifiant de
# l'application Discord, pas celui du bot au sens Discord.js.
static func handshake_payload(client_id: String) -> Dictionary:
	return {"v": 1, "client_id": client_id}

# Corps d'une mise à jour de présence (opcode 1). `nonce` sert uniquement à
# apparier la réponse : Discord le renvoie tel quel, on ne s'en sert pas.
static func set_activity_payload(activity: Dictionary, pid: int, nonce: String) -> Dictionary:
	return {
		"cmd": "SET_ACTIVITY",
		"nonce": nonce,
		"args": {"pid": pid, "activity": activity},
	}

# Décode l'en-tête d'une trame reçue. Retourne un dictionnaire vide si le
# tampon est trop court (lecture partielle sur le pipe).
static func decode_header(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < HEADER_SIZE:
		return {}
	return {"opcode": bytes.decode_u32(0), "length": bytes.decode_u32(4)}
