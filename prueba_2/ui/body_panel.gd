extends Control

const Palette := preload("res://core/palette.gd")
const PartsDB := preload("res://core/parts_db.gd")

const SLIME_CENTER := Vector2(480.0, 505.0)
const SLIME_RADIUS := 92.0
const SLOT_SIZE := Vector2(210.0, 86.0)
const SLOT_CENTERS := [
	Vector2(180.0, 235.0),
	Vector2(510.0, 215.0),
	Vector2(755.0, 385.0),
	Vector2(750.0, 695.0),
	Vector2(470.0, 805.0),
	Vector2(170.0, 680.0),
]
const CURVE_SAMPLES := 13
const SELECTED_SCALE := 1.06
const DIRECTION_DOT_MIN := 0.15
const ALIGNMENT_EPSILON := 0.001

@onready var slots: Control = $Slots
@onready var ability_card: Button = $Ability
@onready var tooltip: PanelContainer = $PartTooltip
@onready var consume_hint: Label = $ConsumeHint

var _active_tooltip_slot := -1
var selected_slot := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Inventory.slots_changed.connect(_refresh_slots)
	GameState.ability_gained.connect(_on_ability_gained)
	GameState.health_changed.connect(_on_health_changed)
	for index in range(Inventory.SLOT_COUNT):
		var card := _slot_button(index)
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_entered.connect(_show_slot_tooltip.bind(index))
		card.mouse_exited.connect(_hide_slot_tooltip.bind(index))
	ability_card.focus_mode = Control.FOCUS_NONE
	_refresh_slots()
	_refresh_ability()


func slime_rect() -> Rect2:
	return Rect2(
		SLIME_CENTER - Vector2.ONE * SLIME_RADIUS,
		Vector2.ONE * SLIME_RADIUS * 2.0
	)


func slot_rect(index: int) -> Rect2:
	if index < 0 or index >= Inventory.SLOT_COUNT:
		return Rect2()
	var card := _slot_button(index)
	return Rect2(card.position, card.size)


func connection_curve(index: int) -> PackedVector2Array:
	if index < 0 or index >= Inventory.SLOT_COUNT:
		return PackedVector2Array()
	if Inventory.part_at(index).is_empty():
		return PackedVector2Array()
	return _sample_curve(slot_rect(index).get_center(), index)


func ability_connection_curve() -> PackedVector2Array:
	if not GameState.has_ability("dash") or not ability_card.visible:
		return PackedVector2Array()
	return _sample_curve(
		Rect2(ability_card.position, ability_card.size).get_center(),
		Inventory.SLOT_COUNT
	)


func selected_connection_curve() -> PackedVector2Array:
	if selected_slot < 0:
		return PackedVector2Array()
	return connection_curve(selected_slot)


func select_first_equipped() -> void:
	selected_slot = -1
	for index in range(Inventory.SLOT_COUNT):
		if not Inventory.is_empty(index):
			selected_slot = index
			break
	_apply_selection_visuals()


func move_selection(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	if selected_slot < 0 or Inventory.is_empty(selected_slot):
		select_first_equipped()
		return

	var normalized_direction := direction.normalized()
	var origin: Vector2 = SLOT_CENTERS[selected_slot]
	var best_index := -1
	var best_alignment := -1.0
	var best_distance: float = INF
	for index in range(Inventory.SLOT_COUNT):
		if index == selected_slot or Inventory.is_empty(index):
			continue
		var offset: Vector2 = SLOT_CENTERS[index] - origin
		var distance: float = offset.length()
		if distance <= 0.0:
			continue
		var alignment: float = offset.normalized().dot(normalized_direction)
		if alignment < DIRECTION_DOT_MIN:
			continue
		if (
			alignment > best_alignment + ALIGNMENT_EPSILON
			or (
				is_equal_approx(alignment, best_alignment)
				and distance < best_distance
			)
		):
			best_index = index
			best_alignment = alignment
			best_distance = distance

	if best_index < 0:
		return
	selected_slot = best_index
	_apply_selection_visuals()


func consume_selected() -> bool:
	if selected_slot < 0 or Inventory.is_empty(selected_slot):
		return false
	if GameState.health_halves >= GameState.max_health_halves:
		_refresh_consume_hint()
		return false
	return Inventory.consume_slot(selected_slot)


func _sample_curve(target: Vector2, index: int) -> PackedVector2Array:
	var direction := SLIME_CENTER.direction_to(target)
	var perpendicular := Vector2(-direction.y, direction.x)
	var bend := (32.0 if index % 2 == 0 else -32.0)
	var start := SLIME_CENTER + direction * (SLIME_RADIUS - 2.0)
	var finish := target
	var control_a := start + direction * 95.0 + perpendicular * bend
	var control_b := finish - direction * 75.0 + perpendicular * bend
	var points := PackedVector2Array()
	for step in range(CURVE_SAMPLES):
		var t := float(step) / float(CURVE_SAMPLES - 1)
		var inv := 1.0 - t
		points.append(
			inv * inv * inv * start
			+ 3.0 * inv * inv * t * control_a
			+ 3.0 * inv * t * t * control_b
			+ t * t * t * finish
		)
	return points


func _draw() -> void:
	for index in range(Inventory.SLOT_COUNT):
		if index != selected_slot:
			_draw_connection(connection_curve(index))
	_draw_connection(ability_connection_curve())
	_draw_connection(selected_connection_curve(), true)
	draw_circle(SLIME_CENTER, SLIME_RADIUS + 8.0, Color(Palette.VOID, 0.8))
	draw_circle(SLIME_CENTER, SLIME_RADIUS, Palette.SLIME_BODY)
	draw_arc(SLIME_CENTER, SLIME_RADIUS, 0.0, TAU, 48, Palette.SLIME_CORE, 4.0)
	draw_circle(SLIME_CENTER - Vector2(25.0, 12.0), 7.0, Palette.VOID)
	draw_circle(SLIME_CENTER + Vector2(25.0, 12.0), 7.0, Palette.VOID)


func _draw_connection(points: PackedVector2Array, highlighted: bool = false) -> void:
	if points.size() < 2:
		return
	var shadow_width := 18.0 if highlighted else 13.0
	var line_width := 9.0 if highlighted else 6.0
	var line_color := Palette.WARM_LIGHT if highlighted else Palette.SLIME_CORE
	draw_polyline(points, Color(Palette.VOID, 0.95), shadow_width, true)
	draw_polyline(points, line_color, line_width, true)


func _refresh_slots() -> void:
	var selection_anchor := Vector2.ZERO
	var must_reanchor := false
	if selected_slot >= 0:
		selection_anchor = SLOT_CENTERS[selected_slot]
		must_reanchor = Inventory.is_empty(selected_slot)
	if must_reanchor:
		selected_slot = _nearest_equipped_to(selection_anchor)

	for index in range(Inventory.SLOT_COUNT):
		var card := _slot_button(index)
		card.position = SLOT_CENTERS[index] - SLOT_SIZE * 0.5
		card.size = SLOT_SIZE
		card.pivot_offset = SLOT_SIZE * 0.5
		var part_id := Inventory.part_at(index)
		card.visible = not part_id.is_empty()
		card.text = "SLOT %d\n%s" % [index + 1, PartsDB.display_name(part_id)]
	_apply_selection_visuals()


func _nearest_equipped_to(origin: Vector2) -> int:
	var nearest_index := -1
	var nearest_distance: float = INF
	for index in range(Inventory.SLOT_COUNT):
		if Inventory.is_empty(index):
			continue
		var distance: float = origin.distance_squared_to(SLOT_CENTERS[index])
		if distance < nearest_distance:
			nearest_index = index
			nearest_distance = distance
	return nearest_index


func _apply_selection_visuals() -> void:
	for index in range(Inventory.SLOT_COUNT):
		var card := _slot_button(index)
		var selected := index == selected_slot and not Inventory.is_empty(index)
		card.scale = Vector2.ONE * (SELECTED_SCALE if selected else 1.0)
		card.z_index = 20 if selected else 0
		if selected:
			card.add_theme_stylebox_override("normal", card.get_theme_stylebox("pressed"))
		else:
			card.remove_theme_stylebox_override("normal")

	if selected_slot >= 0 and not Inventory.is_empty(selected_slot):
		_show_selected_tooltip()
	elif (
		_active_tooltip_slot >= 0
		and Inventory.part_at(_active_tooltip_slot).is_empty()
	):
		tooltip.hide_part()
		_active_tooltip_slot = -1
	_refresh_consume_hint()
	queue_redraw()


func _refresh_consume_hint() -> void:
	if selected_slot < 0 or Inventory.is_empty(selected_slot):
		consume_hint.hide()
		return
	consume_hint.show()
	if GameState.health_halves >= GameState.max_health_halves:
		consume_hint.text = "VIDA AL MÁXIMO"
		return
	consume_hint.text = "F · COMER (+½ CORAZÓN)"


func _refresh_ability() -> void:
	ability_card.visible = GameState.has_ability("dash")
	queue_redraw()


func _on_ability_gained(_id: String) -> void:
	_refresh_ability()


func _on_health_changed(_halves: int) -> void:
	_refresh_consume_hint()


func _slot_button(index: int) -> Button:
	return slots.get_node("Slot%d" % (index + 1)) as Button


func _show_slot_tooltip(index: int) -> void:
	var part_id := Inventory.part_at(index)
	if part_id.is_empty():
		return
	_active_tooltip_slot = index
	var card := _slot_button(index)
	var anchor := card.get_global_rect().position + Vector2(card.size.x, card.size.y * 0.5)
	if card.has_focus():
		anchor = card.get_global_rect().get_center()
	else:
		anchor = get_viewport().get_mouse_position()
	tooltip.show_part(part_id, anchor)


func _show_selected_tooltip() -> void:
	if not is_inside_tree() or not tooltip.is_inside_tree():
		_active_tooltip_slot = -1
		tooltip.hide_part()
		return
	if selected_slot < 0 or Inventory.is_empty(selected_slot):
		return
	_active_tooltip_slot = selected_slot
	var card := _slot_button(selected_slot)
	tooltip.show_part(Inventory.part_at(selected_slot), card.get_global_rect().get_center())


func _hide_slot_tooltip(index: int) -> void:
	if _active_tooltip_slot != index:
		return
	if selected_slot >= 0 and not Inventory.is_empty(selected_slot):
		_show_selected_tooltip()
		return
	_active_tooltip_slot = -1
	tooltip.hide_part()
