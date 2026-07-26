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

@onready var slots: Control = $Slots
@onready var ability_card: Button = $Ability
@onready var tooltip: PanelContainer = $PartTooltip

var _active_tooltip_slot := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Inventory.slots_changed.connect(_refresh_slots)
	GameState.ability_gained.connect(_on_ability_gained)
	for index in range(Inventory.SLOT_COUNT):
		var card := _slot_button(index)
		card.mouse_entered.connect(_show_slot_tooltip.bind(index))
		card.mouse_exited.connect(_hide_slot_tooltip.bind(index))
		card.focus_entered.connect(_show_slot_tooltip.bind(index))
		card.focus_exited.connect(_hide_slot_tooltip.bind(index))
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
		_draw_connection(connection_curve(index))
	_draw_connection(ability_connection_curve())
	draw_circle(SLIME_CENTER, SLIME_RADIUS + 8.0, Color(Palette.VOID, 0.8))
	draw_circle(SLIME_CENTER, SLIME_RADIUS, Palette.SLIME_BODY)
	draw_arc(SLIME_CENTER, SLIME_RADIUS, 0.0, TAU, 48, Palette.SLIME_CORE, 4.0)
	draw_circle(SLIME_CENTER - Vector2(25.0, 12.0), 7.0, Palette.VOID)
	draw_circle(SLIME_CENTER + Vector2(25.0, 12.0), 7.0, Palette.VOID)


func _draw_connection(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	draw_polyline(points, Color(Palette.VOID, 0.95), 13.0, true)
	draw_polyline(points, Palette.SLIME_CORE, 6.0, true)


func _refresh_slots() -> void:
	for index in range(Inventory.SLOT_COUNT):
		var card := _slot_button(index)
		card.position = SLOT_CENTERS[index] - SLOT_SIZE * 0.5
		card.size = SLOT_SIZE
		var part_id := Inventory.part_at(index)
		card.visible = not part_id.is_empty()
		card.text = "SLOT %d\n%s" % [index + 1, PartsDB.display_name(part_id)]
	if (
		_active_tooltip_slot >= 0
		and Inventory.part_at(_active_tooltip_slot).is_empty()
	):
		tooltip.hide_part()
		_active_tooltip_slot = -1
	queue_redraw()


func _refresh_ability() -> void:
	ability_card.visible = GameState.has_ability("dash")
	queue_redraw()


func _on_ability_gained(_id: String) -> void:
	_refresh_ability()


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


func _hide_slot_tooltip(index: int) -> void:
	if _active_tooltip_slot != index:
		return
	_active_tooltip_slot = -1
	tooltip.hide_part()
