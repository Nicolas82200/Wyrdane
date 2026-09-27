extends GutTest

# Couvre DiscordActivity (scripts/net/DiscordActivity.gd) : la correspondance
# état de jeu -> clé de traduction affichée dans la présence Discord, et
# l'encodage/décodage des trames du protocole IPC local (en-tête 8 octets
# little-endian + corps JSON). La couche qui parle réellement au pipe
# (`DiscordPresence`, thread + FileAccess) n'est pas testable sans un client
# Discord lancé — d'où la séparation.

func test_menu_state_maps_to_menu_key() -> void:
	assert_eq(DiscordActivity.details_key(DiscordActivity.STATE_MENU), "DISCORD_PRESENCE_MENU")

func test_deckbuilder_state_maps_to_its_key() -> void:
	assert_eq(DiscordActivity.details_key(DiscordActivity.STATE_DECKBUILDER), "DISCORD_PRESENCE_DECKBUILDER")

func test_queue_distinguishes_ranked() -> void:
	assert_eq(DiscordActivity.details_key(DiscordActivity.STATE_QUEUE), "DISCORD_PRESENCE_QUEUE")
	assert_eq(DiscordActivity.details_key(DiscordActivity.STATE_QUEUE, {"ranked": false}), "DISCORD_PRESENCE_QUEUE")
	assert_eq(DiscordActivity.details_key(DiscordActivity.STATE_QUEUE, {"ranked": true}), "DISCORD_PRESENCE_QUEUE_RANKED")

func test_battle_distinguishes_ranked_ai_and_tutorial() -> void:
	assert_eq(DiscordActivity.details_key(DiscordActivity.STATE_BATTLE), "DISCORD_PRESENCE_BATTLE")
	assert_eq(DiscordActivity.details_key(DiscordActivity.STATE_BATTLE, {"ranked": true}), "DISCORD_PRESENCE_BATTLE_RANKED")
	assert_eq(DiscordActivity.details_key(DiscordActivity.STATE_BATTLE, {"vs_ai": true}), "DISCORD_PRESENCE_BATTLE_AI")

# Le tutoriel se joue contre une IA scriptée ET hors classé : les trois drapeaux
# peuvent être vrais en même temps, le libellé tutoriel doit gagner.
func test_tutorial_wins_over_other_battle_flags() -> void:
	var key := DiscordActivity.details_key(DiscordActivity.STATE_BATTLE, {
		"tutorial": true,
		"vs_ai": true,
		"ranked": true,
	})
	assert_eq(key, "DISCORD_PRESENCE_TUTORIAL")

# Une partie classée est forcément en réseau : si les deux drapeaux arrivent
# ensemble (contexte mal rempli côté appelant), "contre l'IA" reste le plus
# prudent — on n'affiche pas "classée" pour une partie solo.
func test_ai_wins_over_ranked() -> void:
	var key := DiscordActivity.details_key(DiscordActivity.STATE_BATTLE, {"vs_ai": true, "ranked": true})
	assert_eq(key, "DISCORD_PRESENCE_BATTLE_AI")

func test_arena_state_maps_to_its_key() -> void:
	assert_eq(DiscordActivity.details_key(DiscordActivity.STATE_ARENA), "DISCORD_PRESENCE_ARENA")

func test_unknown_state_falls_back_to_neutral_key() -> void:
	assert_eq(DiscordActivity.details_key("écran-inexistant"), "DISCORD_PRESENCE_PLAYING")

func test_build_activity_carries_details_assets_and_start() -> void:
	var activity := DiscordActivity.build_activity("En partie", 1700000000)
	assert_eq(activity["type"], 0)
	assert_eq(activity["details"], "En partie")
	assert_eq(activity["assets"], {
		"large_image": DiscordActivity.LARGE_IMAGE,
		"large_text": DiscordActivity.LARGE_TEXT,
	})
	assert_eq(activity["timestamps"], {"start": 1700000000})

# Sans horodatage de début, le champ doit être ABSENT et non pas à 0 : Discord
# afficherait sinon un chrono parti de 1970.
func test_build_activity_omits_timestamps_without_start() -> void:
	var activity := DiscordActivity.build_activity("Dans le menu principal", 0)
	assert_false(activity.has("timestamps"))

func test_encode_frame_writes_little_endian_header_then_json_body() -> void:
	var frame := DiscordActivity.encode_frame(DiscordActivity.OP_HANDSHAKE, {"v": 1})
	var body := JSON.stringify({"v": 1}).to_utf8_buffer()
	assert_eq(frame.size(), DiscordActivity.HEADER_SIZE + body.size())
	assert_eq(frame.decode_u32(0), DiscordActivity.OP_HANDSHAKE)
	assert_eq(frame.decode_u32(4), body.size())
	assert_eq(frame.slice(DiscordActivity.HEADER_SIZE).get_string_from_utf8(), JSON.stringify({"v": 1}))

func test_encoded_frame_header_round_trips_through_decode_header() -> void:
	var frame := DiscordActivity.encode_frame(DiscordActivity.OP_FRAME, {"cmd": "SET_ACTIVITY"})
	var header := DiscordActivity.decode_header(frame.slice(0, DiscordActivity.HEADER_SIZE))
	assert_eq(header["opcode"], DiscordActivity.OP_FRAME)
	assert_eq(int(header["length"]), frame.size() - DiscordActivity.HEADER_SIZE)

func test_decode_header_rejects_partial_read() -> void:
	var partial := PackedByteArray([0, 0, 0, 0, 1])
	assert_eq(DiscordActivity.decode_header(partial), {})

func test_handshake_payload_declares_protocol_version_and_client() -> void:
	assert_eq(DiscordActivity.handshake_payload("123"), {"v": 1, "client_id": "123"})

func test_set_activity_payload_wraps_activity_with_pid_and_nonce() -> void:
	var activity := DiscordActivity.build_activity("En Arène", 0)
	var payload := DiscordActivity.set_activity_payload(activity, 4242, "7")
	assert_eq(payload["cmd"], "SET_ACTIVITY")
	assert_eq(payload["nonce"], "7")
	assert_eq(payload["args"]["pid"], 4242)
	assert_eq(payload["args"]["activity"], activity)
