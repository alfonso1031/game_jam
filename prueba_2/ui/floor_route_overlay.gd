extends Control

const DISPLAY_DURATION := 3.0
const FLOOR_ORDER: Array[StringName] = [
	&"surface",
	&"maintenance",
	&"biolabs",
	&"contencion",
]

@onready var status: Label = $Panel/Status

var _display_generation := 0
var _owns_pause := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	RunManager.floor_completed.connect(_on_floor_completed)


func floor_order() -> Array[StringName]:
	return FLOOR_ORDER.duplicate()


func generated_room_count() -> int:
	return 0


func dismiss() -> void:
	if not visible:
		return
	_display_generation += 1
	visible = false
	if _owns_pause:
		get_tree().paused = false
	_owns_pause = false


func _on_floor_completed(floor_id: StringName, healed_hp: int) -> void:
	if floor_id != &"contencion":
		return
	if get_tree().paused and not visible:
		return
	_display_generation += 1
	var generation := _display_generation
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	status.text = "CONTENCIÓN SUPERADA · +%d HP" % healed_hp
	visible = true
	_auto_dismiss(generation)


func _auto_dismiss(generation: int) -> void:
	await get_tree().create_timer(DISPLAY_DURATION, true, false, true).timeout
	if generation == _display_generation:
		dismiss()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("dash")
		or event.is_action_pressed("map")
	):
		dismiss()
		get_viewport().set_input_as_handled()
