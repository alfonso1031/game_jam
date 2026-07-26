extends Node

const Exp07Scene := preload("res://actors/enemies/exp07_crustacean.tscn")
const Exp07Frames := preload("res://actors/enemies/exp07_crustacean_frames.tres")

var failures: Array[String] = []


func _ready() -> void:
	_check_animation_contract()
	await _check_state_contract()
	_finish()


func _check_animation_contract() -> void:
	_check(Exp07Frames.get_frame_count(&"advance") == 4, "advance usa el ciclo completo")
	_check(Exp07Frames.get_animation_loop(&"advance"), "advance se reproduce en bucle")
	_check(Exp07Frames.get_frame_count(&"pinch_windup") == 5, "windup usa cinco fotogramas")
	_check(Exp07Frames.get_frame_count(&"recover") == 5, "recover usa cinco fotogramas")
	_check(
		is_equal_approx(Exp07Frames.get_animation_speed(&"pinch_windup"), 6.25),
		"windup dura 0,8 s"
	)
	_check(
		is_equal_approx(Exp07Frames.get_animation_speed(&"recover"), 8.333333),
		"recover dura 0,6 s"
	)
	_check(not Exp07Frames.get_animation_loop(&"pinch_windup"), "windup no repite")
	_check(not Exp07Frames.get_animation_loop(&"recover"), "recover no repite")
	if (
		Exp07Frames.get_frame_count(&"pinch_windup") == 5
		and Exp07Frames.get_frame_count(&"recover") == 5
	):
		_check(
			Exp07Frames.get_frame_texture(&"pinch_windup", 4)
				== Exp07Frames.get_frame_texture(&"recover", 0),
			"recover inicia en el extremo del ataque"
		)
		_check(
			Exp07Frames.get_frame_texture(&"pinch_windup", 0)
				== Exp07Frames.get_frame_texture(&"recover", 4),
			"recover termina en la postura inicial"
		)


func _check_state_contract() -> void:
	var enemy: Node = Exp07Scene.instantiate()
	add_child(enemy)
	await get_tree().process_frame
	var constants: Dictionary = enemy.get_script().get_script_constant_map()
	var states: Dictionary = constants.get("State", {})
	_check(states.has("ADVANCE"), "EXP07 declara ADVANCE")
	_check(states.has("PINCH_WINDUP"), "EXP07 declara PINCH_WINDUP")
	_check(states.has("RECOVER"), "EXP07 declara RECOVER")
	if states.has("ADVANCE"):
		enemy.set("_state", states["ADVANCE"])
		_check(enemy._visual_state() == &"advance", "ADVANCE usa el ciclo de movimiento")
	if states.has("PINCH_WINDUP"):
		enemy.set("_state", states["PINCH_WINDUP"])
		_check(enemy._visual_state() == &"pinch_windup", "PINCH_WINDUP usa su animación")
	if states.has("RECOVER"):
		enemy.set("_state", states["RECOVER"])
		_check(enemy._visual_state() == &"recover", "RECOVER usa su animación")
	var expected_drops: Array[String] = ["crusher_claw"]
	_check(enemy.get("drop_parts") == expected_drops, "EXP07 solo puede soltar Tenaza Trituradora")

	var sprite: AnimatedSprite2D = enemy.get_node("Sprite")
	enemy.set("facing", Vector2.LEFT)
	enemy._update_sprite()
	_check(not sprite.flip_h, "el arte mira a la izquierda con el enemigo")
	enemy.set("facing", Vector2.RIGHT)
	enemy._update_sprite()
	_check(sprite.flip_h, "el arte mira a la derecha con el enemigo")

	var player := Node2D.new()
	add_child(player)
	player.global_position = enemy.global_position + Vector2(100.0, 0.0)
	enemy.set("_player", player)
	enemy.set("_pinch_cd", 1.0)
	enemy.velocity = Vector2.ZERO
	enemy._advance(0.1)
	_check(
		enemy.velocity.is_zero_approx(),
		"EXP07 no persigue al jugador dentro del alcance durante el cooldown"
	)
	player.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("PASS: EXP07 claw attack" if failures.is_empty() else "FAIL: EXP07 claw attack")
	get_tree().quit(0 if failures.is_empty() else 1)
