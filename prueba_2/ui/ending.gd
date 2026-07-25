extends Control

const END_ROOM := "L2_ESCLUSA"
const DELAY := 0.9

@onready var stats: Label = $Stats

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameState.room_changed.connect(_on_room_changed)

func _on_room_changed(room_id: String) -> void:
	if room_id != END_ROOM or visible:
		return
	await get_tree().create_timer(DELAY).timeout
	if is_inside_tree():
		_show()

func _show() -> void:
	stats.text = "SALAS VISITADAS: %d / %d\nHABILIDADES: %d" % [
		GameState.visited.size(), RoomDB.ROOMS.size(), GameState.abilities.size()
	]
	visible = true
	get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_action_pressed("fullscreen"):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		GameState.reset_run()
		get_tree().change_scene_to_file("res://ui/title.tscn")
