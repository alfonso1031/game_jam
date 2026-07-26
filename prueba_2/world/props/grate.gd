extends Area2D

var source_room_id: String = ""
var target_room_id: String = ""
var requires_cost := true

var _armed := false
var _player_near := false

@onready var prompt: Label = $Prompt


func configure(source_id: String, target_id: String, cost_required: bool) -> void:
	source_room_id = source_id
	target_room_id = target_id
	requires_cost = cost_required


func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_armed = true
	for body: Node2D in get_overlapping_bodies():
		if body.is_in_group("player"):
			_player_near = true
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not _armed or not _player_near or not event.is_action_pressed("interact"):
		return
	if not requires_cost or GameState.is_grate_unlocked(source_room_id):
		Transition.go_via_grate(target_room_id)
		get_viewport().set_input_as_handled()
		return
	var ui: Node = get_tree().get_first_node_in_group("grate_cost_ui")
	if ui != null:
		ui.open(source_room_id, target_room_id)
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = true
	_update_prompt()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	_update_prompt()


func _update_prompt() -> void:
	prompt.visible = _armed and _player_near
