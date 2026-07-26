extends Control

const HOLD_TIME := 0.8
const CROSSFADE_TIME := 0.6
const MENU_FADE_TIME := 0.35

@onready var background_contained: TextureRect = $BackgroundContained
@onready var background_escaped: TextureRect = $BackgroundEscaped
@onready var flash: ColorRect = $Flash
@onready var menu: VBoxContainer = $Menu
@onready var play_button: Button = $Menu/PlayButton
@onready var quit_button: Button = $Menu/QuitButton

var _intro_done := false
var _intro_tween: Tween
var _contained_start_position := Vector2.ZERO


func _ready() -> void:
	GameState.reset_run()
	play_button.pressed.connect(_start_game)
	quit_button.pressed.connect(_quit_game)
	_contained_start_position = background_contained.position
	_start_intro()


func intro_finished() -> bool:
	return _intro_done


func skip_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_finish_intro()


func _start_intro() -> void:
	_intro_tween = create_tween()
	_intro_tween.tween_interval(HOLD_TIME)
	_intro_tween.tween_property(background_contained, "position", _contained_start_position + Vector2(8.0, 0.0), 0.05)
	_intro_tween.tween_property(background_contained, "position", _contained_start_position + Vector2(-8.0, 0.0), 0.05)
	_intro_tween.tween_property(background_contained, "position", _contained_start_position + Vector2(5.0, 0.0), 0.05)
	_intro_tween.tween_property(background_contained, "position", _contained_start_position, 0.05)
	_intro_tween.tween_property(flash, "modulate:a", 0.75, 0.08)
	_intro_tween.tween_property(flash, "modulate:a", 0.0, 0.12)
	_intro_tween.set_parallel(true)
	_intro_tween.tween_property(background_contained, "modulate:a", 0.0, CROSSFADE_TIME)
	_intro_tween.tween_property(background_escaped, "modulate:a", 1.0, CROSSFADE_TIME)
	_intro_tween.set_parallel(false)
	_intro_tween.tween_callback(_finish_intro)


func _finish_intro() -> void:
	if _intro_done:
		return
	_intro_done = true
	background_contained.position = _contained_start_position
	background_contained.modulate.a = 0.0
	background_escaped.modulate.a = 1.0
	flash.modulate.a = 0.0
	menu.show()
	var menu_tween := create_tween()
	menu_tween.tween_property(menu, "modulate:a", 1.0, MENU_FADE_TIME)
	play_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# F11 lo maneja GameState; no debe omitir ni iniciar la partida.
	if event.is_action_pressed("fullscreen"):
		return
	if _intro_done:
		return
	var key_pressed: bool = event is InputEventKey and event.pressed and not event.echo
	var click: bool = event is InputEventMouseButton and event.pressed
	if key_pressed or click:
		get_viewport().set_input_as_handled()
		skip_intro()


func _start_game() -> void:
	if _intro_done:
		get_tree().change_scene_to_file("res://game/main.tscn")


func _quit_game() -> void:
	if _intro_done:
		get_tree().quit()
