extends Control

const PartsDB := preload("res://core/parts_db.gd")

const SELECTED_BORDER := Color(0.925, 0.69, 0.31, 1.0)
const DEFAULT_BORDER := Color(0.25, 0.53, 0.53, 0.8)

@onready var options_container: HBoxContainer = $Options
@onready var warning: Label = $Warning

var options: Array[Dictionary] = []
var selected_option := 0
var _source_id := ""
var _target_id := ""
var _confirming_lethal := false
var _owns_pause := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("grate_cost_ui")


func open(source_id: String, target_id: String) -> void:
	_source_id = source_id
	_target_id = target_id
	_confirming_lethal = false
	warning.text = ""
	_build_options()
	selected_option = 0
	_refresh_selection()
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	visible = true


func cancel() -> void:
	if not visible:
		return
	_close()


func confirm_selection() -> void:
	if not visible or options.is_empty():
		return
	var slot_index: int = int(options[selected_option]["slot_index"])
	var result := RunManager.pay_grate_cost(slot_index, _confirming_lethal)
	match result:
		&"confirmation_required":
			_confirming_lethal = true
			warning.text = "ESTA DECISIÓN TERMINA LA PARTIDA · CONFIRMA OTRA VEZ"
		&"part", &"hp":
			GameState.unlock_grate(_source_id)
			_close()
			Transition.go_via_grate(_target_id)
		&"death":
			_close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		cancel()
	elif event.is_action_pressed("move_left"):
		_move_selection(-1)
	elif event.is_action_pressed("move_right"):
		_move_selection(1)
	elif event.is_action_pressed("interact"):
		confirm_selection()
	else:
		return
	get_viewport().set_input_as_handled()


func _build_options() -> void:
	options.clear()
	for child in options_container.get_children():
		child.queue_free()
	for slot_index in range(Inventory.SLOT_COUNT):
		var part_id := Inventory.part_at(slot_index)
		if part_id.is_empty():
			continue
		options.append({
			"slot_index": slot_index,
			"label": PartsDB.display_name(part_id),
		})
	options.append({"slot_index": -1, "label": "½ CORAZÓN"})
	for option in options:
		options_container.add_child(_make_card(String(option["label"])))


func _make_card(label_text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(230.0, 150.0)
	card.pivot_offset = card.custom_minimum_size * 0.5
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 24)
	card.add_child(label)
	return card


func _move_selection(direction: int) -> void:
	if options.is_empty():
		return
	selected_option = posmod(selected_option + direction, options.size())
	_confirming_lethal = false
	warning.text = ""
	_refresh_selection()


func _refresh_selection() -> void:
	for index in range(options_container.get_child_count()):
		var card := options_container.get_child(index) as Control
		var selected := index == selected_option
		card.scale = Vector2(1.08, 1.08) if selected else Vector2.ONE
		card.add_theme_stylebox_override("panel", _card_style(SELECTED_BORDER if selected else DEFAULT_BORDER))


func _card_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.09, 0.1, 0.98)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	return style


func _close() -> void:
	visible = false
	_confirming_lethal = false
	warning.text = ""
	if _owns_pause:
		get_tree().paused = false
	_owns_pause = false
