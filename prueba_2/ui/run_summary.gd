extends Control

const PartsDB := preload("res://core/parts_db.gd")

@onready var zone_label: Label = $Panel/Content/Zone
@onready var rooms_label: Label = $Panel/Content/Rooms
@onready var consumed_label: Label = $Panel/Content/Consumed
@onready var sacrificed_label: Label = $Panel/Content/Sacrificed
@onready var seed_label: Label = $Panel/Content/Seed
@onready var new_run_button: Button = $Panel/Content/Actions/NewRun
@onready var title_button: Button = $Panel/Content/Actions/ToTitle


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	RunManager.run_ended.connect(_show_summary)
	new_run_button.pressed.connect(_new_run)
	title_button.pressed.connect(_to_title)


func _show_summary(data: Dictionary) -> void:
	zone_label.text = "ZONA · %s" % data["zone"]
	rooms_label.text = "SALAS VISITADAS · %d" % int(data["rooms_visited"])
	consumed_label.text = "PARTES COMIDAS · %s" % _part_names(data["consumed"])
	sacrificed_label.text = "PARTES SACRIFICADAS · %s" % _part_names(data["sacrificed"])
	seed_label.text = "SEED · %d" % int(data["seed"])
	visible = true
	get_tree().paused = true
	new_run_button.grab_focus()


func _part_names(ids: Array) -> String:
	if ids.is_empty():
		return "NINGUNA"
	var names: Array[String] = []
	for id_value: Variant in ids:
		names.append(PartsDB.display_name(String(id_value)))
	return ", ".join(names)


func _new_run() -> void:
	get_tree().paused = false
	RunManager.start_new_run()
	get_tree().reload_current_scene()


func _to_title() -> void:
	get_tree().paused = false
	RunManager.active = false
	GameState.reset_run()
	Inventory.reset_run()
	get_tree().change_scene_to_file("res://ui/title.tscn")
