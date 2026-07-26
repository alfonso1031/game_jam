extends Node

# Contrato visual del slime: la selección de animación no modifica su lógica.

const SlimeScene := preload("res://actors/player/slime.tscn")

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	var slime: Node2D = SlimeScene.instantiate()
	add_child(slime)
	var sprite := slime.get_node_or_null("Sprite") as AnimatedSprite2D
	_check(sprite != null, "el slime usa AnimatedSprite2D")
	if sprite == null:
		_finish()
		return

	var frames: SpriteFrames = sprite.sprite_frames
	_check(frames != null, "Sprite tiene SpriteFrames")
	if frames == null:
		_finish()
		return
	_check(frames.get_frame_count(&"idle") == 5, "Idle conserva 5 frames")
	_check(frames.get_frame_count(&"walk") == 2, "Walk conserva 2 frames")
	_check(frames.get_frame_count(&"jump") == 6, "Jump conserva 6 frames")
	_check(frames.get_frame_count(&"recover") == 12, "Recover conserva 12 frames")

	var states: Dictionary = slime.get_script().get_script_constant_map()["State"]
	_assert_animation(slime, sprite, states["IDLE"], false, &"idle", "IDLE inmóvil usa idle")
	_assert_animation(slime, sprite, states["IDLE"], true, &"walk", "movimiento continuo usa walk")
	_assert_animation(slime, sprite, states["CHARGING"], false, &"idle", "carga usa idle")
	_assert_animation(slime, sprite, states["LAUNCHING"], false, &"jump", "lanzamiento usa jump")
	_assert_animation(slime, sprite, states["DASHING"], false, &"jump", "dash usa jump")
	_assert_animation(slime, sprite, states["PART_DASH"], false, &"jump", "dash de parte usa jump")
	_assert_animation(slime, sprite, states["RECOVERING"], false, &"recover", "recuperación usa recover")
	_finish()


func _assert_animation(
	slime: Node2D,
	sprite: AnimatedSprite2D,
	state: int,
	continuous_moving: bool,
	expected: StringName,
	label: String
) -> void:
	slime.set("_state", state)
	slime.set("_continuous_moving", continuous_moving)
	slime.call("_update_sprite_animation")
	_check(sprite.animation == expected, label)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok  %s" % label)
		return
	_failures.append(label)
	printerr("  FALLO  %s" % label)


func _finish() -> void:
	print("%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	get_tree().quit(1 if not _failures.is_empty() else 0)
