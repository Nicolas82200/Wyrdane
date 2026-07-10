extends Node

const ALL_CARDS_PATH := "res://resources/cards"

var all_cards: Array[CardData] = []
var is_loaded: bool = false

signal loading_finished

func load_all_cards() -> void:
	if is_loaded:
		return
	all_cards.clear()
	_scan_recursive(ALL_CARDS_PATH)
	all_cards.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost < b.cost)
	is_loaded = true
	loading_finished.emit()

func _scan_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path + "/" + file_name
		if dir.current_is_dir():
			_scan_recursive(full_path)
		elif file_name.ends_with(".tres"):
			var res := load(full_path)
			if res is CardData:
				all_cards.append(res as CardData)
		file_name = dir.get_next()
	dir.list_dir_end()
