extends Control

const Palette := preload("res://scripts/core/palette.gd")

@onready var prompt: Label = $Prompt

var _t := 0.0

func _ready() -> void:
	GameState.reset_run()

func _process(delta: float) -> void:
	_t += delta
	prompt.modulate.a = 0.45 + sin(_t * 3.0) * 0.35

func _unhandled_input(event: InputEvent) -> void:
	# F11 lo maneja GameState; no debe arrancar la partida.
	if event.is_action_pressed("fullscreen"):
		return
	var key_pressed: bool = event is InputEventKey and event.pressed and not event.echo
	var click: bool = event is InputEventMouseButton and event.pressed
	if key_pressed or click:
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
