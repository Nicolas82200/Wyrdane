extends GutTest

# Horodatage des messages de chat : conversion UTC -> heure locale et format
# d'affichage (voir ChatPanel._local_datetime/_format_time). Chargé
# directement plutôt que via la classe globale pour ne dépendre d'aucun
# autoload (voir « Tests automatisés » dans CLAUDE.md).

var ChatPanelScript = load("res://scripts/mainMenu/ChatPanel.gd")


func _local_bias_seconds() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func test_parses_iso_utc_with_milliseconds() -> void:
	var stamp: Dictionary = ChatPanelScript._local_datetime("2026-09-26T14:32:11.000Z")
	assert_false(stamp.is_empty(), "une date ISO UTC doit être lisible")
	# On revient à l'UTC en retirant le décalage local appliqué par la méthode :
	# le résultat doit retomber exactement sur l'instant d'origine.
	var back: int = int(Time.get_unix_time_from_datetime_dict(stamp)) - _local_bias_seconds()
	assert_eq(back, int(Time.get_unix_time_from_datetime_string("2026-09-26T14:32:11")))


func test_parses_mysql_space_separated_datetime() -> void:
	var stamp: Dictionary = ChatPanelScript._local_datetime("2026-09-26 14:32:11")
	assert_false(stamp.is_empty(), "le format DATETIME MySQL brut doit aussi être lisible")
	var back: int = int(Time.get_unix_time_from_datetime_dict(stamp)) - _local_bias_seconds()
	assert_eq(back, int(Time.get_unix_time_from_datetime_string("2026-09-26T14:32:11")))


func test_empty_or_invalid_datetime_returns_empty_dict() -> void:
	assert_true(ChatPanelScript._local_datetime("").is_empty())
	assert_true(ChatPanelScript._local_datetime("   ").is_empty())
	assert_true(ChatPanelScript._local_datetime("pas une date").is_empty())


func test_format_time_pads_hours_and_minutes() -> void:
	assert_eq(ChatPanelScript._format_time({"hour": 9, "minute": 5}), "09:05")
	assert_eq(ChatPanelScript._format_time({"hour": 23, "minute": 59}), "23:59")


func test_format_time_is_empty_without_timestamp() -> void:
	assert_eq(ChatPanelScript._format_time({}), "")
