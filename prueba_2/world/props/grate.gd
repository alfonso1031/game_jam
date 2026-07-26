extends Area2D

const MAX_VISUAL_SIZE := Vector2(120.0, 120.0)
const PROMPT_POSITIONS := {
	"N": Vector2(0, 86),
	"S": Vector2(0, -116),
	"O": Vector2(150, -15),
	"E": Vector2(-150, -15),
}
# La textura permanece montada en la pared. Solo el sensor se acerca al cuarto:
# así el muro sigue siendo sólido, pero el jugador puede usar la rejilla desde
# el mismo punto interior donde reaparece al regresar.
const SENSOR_POSITIONS := {
	"N": Vector2(0, 105),
	"S": Vector2(0, -105),
	"O": Vector2(105, 0),
	"E": Vector2(-105, 0),
}

var source_room_id: String = ""
var target_room_id: String = ""
var requires_cost := true
var wall_direction := ""

var _armed := false
var _player_near := false

@onready var prompt: Label = $Prompt
@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func configure(
	source_id: String,
	target_id: String,
	cost_required: bool,
	direction: String
) -> void:
	source_room_id = source_id
	target_room_id = target_id
	requires_cost = cost_required
	wall_direction = direction


func _ready() -> void:
	_fit_visual()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_armed = true
	for body: Node2D in get_overlapping_bodies():
		if body.is_in_group("player"):
			_player_near = true
	_update_prompt()


func _fit_visual() -> void:
	var texture_size := sprite.texture.get_size()
	var factor := minf(
		MAX_VISUAL_SIZE.x / texture_size.x,
		MAX_VISUAL_SIZE.y / texture_size.y
	)
	sprite.scale = Vector2.ONE * factor
	prompt.position = PROMPT_POSITIONS.get(wall_direction, Vector2.ZERO)
	collision_shape.position = SENSOR_POSITIONS.get(wall_direction, Vector2.ZERO)


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
