extends Node
class_name DropSystem

const BOARD_MINION_SIZE := Vector2(100, 150)
const DROP_HIGHLIGHT_COLOR := Color(1.0, 0.45, 0.05, 0.28)
const DROP_HIGHLIGHT_BORDER_COLOR := Color(1.0, 0.58, 0.12, 0.9)

var battle

var _drop_highlights: Dictionary = {}
var _drop_placeholder: Control = null
var _drop_placeholder_row: String = ""
var _drop_placeholder_index: int = -1
var _last_placeholder_index: int = -1
var _last_placeholder_row: String = ""

func init(_battle) -> void:
	battle = _battle

# ─── Highlight ────────────────────────────────────────────────────────────────

func update_player_drop_highlight(card_data: CardData, mouse: Vector2, display_show: bool) -> bool:
	_ensure_drop_highlights()
	var allowed_rows: Array[String] = battle.get_allowed_rows_for_card(card_data)
	for row in [battle.ROW_FRONT, battle.ROW_BACK]:
		var panel: Panel = _drop_highlights.get(row) as Panel
		var row_container: Control = _get_player_row_container(row)
		if panel == null or row_container == null:
			continue
		var can_show: bool = display_show and row in allowed_rows and battle.can_summon_to_row(true, row)
		panel.visible = can_show
		if can_show:
			_fit_drop_highlight_to(row_container, panel)
	var drop_row: String = get_player_drop_row_at(mouse, card_data)
	if display_show and not drop_row.is_empty() and battle.can_summon_to_row(true, drop_row):
		var insert_index: int = _get_stable_player_drop_index_at(mouse, drop_row)
		_update_drop_placeholder(drop_row, insert_index)
		return true
	_clear_drop_placeholder()
	return false

func clear_player_drop_highlight() -> void:
	for panel in _drop_highlights.values():
		var control: Control = panel as Control
		if control != null:
			control.visible = false
	_clear_drop_placeholder()

func _ensure_drop_highlights() -> void:
	if not _drop_highlights.is_empty():
		return
	var board: Control = battle.get_node_or_null("Board") as Control
	if board == null:
		return
	for row in [battle.ROW_FRONT, battle.ROW_BACK]:
		var panel: Panel = Panel.new()
		panel.name = "Player%sDropHighlight" % row
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.visible = false
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = DROP_HIGHLIGHT_COLOR
		style.border_color = DROP_HIGHLIGHT_BORDER_COLOR
		style.border_width_left   = 3
		style.border_width_right  = 3
		style.border_width_top    = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left     = 8
		style.corner_radius_top_right    = 8
		style.corner_radius_bottom_left  = 8
		style.corner_radius_bottom_right = 8
		panel.add_theme_stylebox_override("panel", style)
		board.add_child(panel)
		_drop_highlights[row] = panel

func _fit_drop_highlight_to(row_container: Control, panel: Control) -> void:
	var board: Control = battle.get_node_or_null("Board") as Control
	if board == null:
		return
	var rect: Rect2 = row_container.get_global_rect()
	panel.position = rect.position - board.global_position
	panel.size = rect.size
	board.move_child(panel, 0)

# ─── Drop row / index ─────────────────────────────────────────────────────────

func get_player_drop_row_at(mouse: Vector2, card_data: CardData = null) -> String:
	var allowed_rows: Array[String] = battle.get_allowed_rows_for_card(card_data)
	if battle.player_front_container is Control and battle.player_front_container.get_global_rect().has_point(mouse):
		return battle.ROW_FRONT if battle.ROW_FRONT in allowed_rows else ""
	if battle.player_back_container is Control and battle.player_back_container.get_global_rect().has_point(mouse):
		return battle.ROW_BACK if battle.ROW_BACK in allowed_rows else ""
	return ""

func get_player_drop_index_at(mouse: Vector2, row: String) -> int:
	return _get_stable_player_drop_index_at(mouse, row)

func _get_raw_player_drop_index_at(mouse: Vector2, row: String) -> int:
	var container: Control = _get_player_row_container(row)
	if container == null:
		return -1
	var index: int = 0
	for child in container.get_children():
		if child is BoardMinion:
			var rect: Rect2 = child.get_global_rect()
			if mouse.x < rect.position.x + rect.size.x * 0.5:
				return index
			index += 1
	return index

func _get_stable_player_drop_index_at(mouse: Vector2, row: String) -> int:
	if _drop_placeholder != null and _drop_placeholder.visible and _drop_placeholder_row == row:
		var placeholder_rect: Rect2 = _drop_placeholder.get_global_rect().grow(35.0)
		if placeholder_rect.has_point(mouse):
			return _drop_placeholder_index
	return _get_raw_player_drop_index_at(mouse, row)

# ─── Placeholder ──────────────────────────────────────────────────────────────

func _update_drop_placeholder(row: String, insert_index: int) -> void:
	var container: Control = _get_player_row_container(row)
	if container == null:
		return
	if _drop_placeholder == null:
		_drop_placeholder = _create_drop_placeholder()
	if _drop_placeholder.get_parent() != container:
		if _drop_placeholder.get_parent() != null:
			_drop_placeholder.get_parent().remove_child(_drop_placeholder)
		container.add_child(_drop_placeholder)
	_drop_placeholder.visible = true
	_drop_placeholder.custom_minimum_size = BOARD_MINION_SIZE
	_drop_placeholder_row = row
	_drop_placeholder_index = insert_index
	if _last_placeholder_index != insert_index or _last_placeholder_row != row:
		var child_index: int = _get_row_child_index_for_insert(container, insert_index)
		container.move_child(_drop_placeholder, child_index)
		_last_placeholder_index = insert_index
		_last_placeholder_row = row

func _create_drop_placeholder() -> Panel:
	var placeholder: Panel = Panel.new()
	placeholder.name = "DropPlaceholder"
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.custom_minimum_size = BOARD_MINION_SIZE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.45, 0.05, 0.16)
	style.border_color = DROP_HIGHLIGHT_BORDER_COLOR
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	placeholder.add_theme_stylebox_override("panel", style)
	return placeholder

func _get_row_child_index_for_insert(container: Control, insert_index: int) -> int:
	var seen_minions: int = 0
	var fallback_index: int = container.get_child_count()
	for i in range(container.get_child_count()):
		var child: Node = container.get_child(i)
		if child == _drop_placeholder:
			continue
		if child is BoardMinion:
			if seen_minions == insert_index:
				return i
			seen_minions += 1
		fallback_index = i + 1
	return fallback_index

func _clear_drop_placeholder() -> void:
	if _drop_placeholder == null:
		return
	_drop_placeholder.visible = false
	_drop_placeholder_row = ""
	_drop_placeholder_index = -1
	_last_placeholder_index = -1
	_last_placeholder_row = ""
	if _drop_placeholder.get_parent() != null:
		_drop_placeholder.get_parent().remove_child(_drop_placeholder)

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _get_player_row_container(row: String) -> Control:
	if row == battle.ROW_BACK:
		return battle.player_back_container
	return battle.player_front_container
