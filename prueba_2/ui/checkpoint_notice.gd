extends Control

const DISPLAY_DURATION := 3.0
const FADE_DURATION := 0.35

@onready var _heal_label: Label = $Panel/VBox/Heal

var _display_generation := 0
var _fade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameState.checkpoint_reached.connect(_on_checkpoint_reached)

func _on_checkpoint_reached(_room_id: String, healed_halves: int) -> void:
	_display_generation += 1
	var generation := _display_generation
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	_heal_label.visible = healed_halves > 0
	if healed_halves == 1:
		_heal_label.text = "+½ CORAZÓN"
	elif healed_halves > 1:
		_heal_label.text = "+1 CORAZÓN"

	modulate.a = 1.0
	visible = true
	_hide_after_delay(generation)

func _hide_after_delay(generation: int) -> void:
	await get_tree().create_timer(DISPLAY_DURATION - FADE_DURATION, true).timeout
	if generation != _display_generation or not is_inside_tree():
		return
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	await _fade_tween.finished
	if generation == _display_generation:
		visible = false
