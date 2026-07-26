extends Node

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameState.reset_run()
	var hud_scene: PackedScene = load("res://ui/hud.tscn")
	var hud: Control = hud_scene.instantiate()
	add_child(hud)
	await get_tree().process_frame

	var value_label := hud.get_node_or_null("Health/Value") as Label
	_check(value_label != null, "el HUD tiene un valor textual de vida")
	_check(hud.has_method("health_ratio"), "el HUD expone la proporción de vida")
	if value_label != null:
		_check(value_label.text == "5 / 15 HP", "inicia mostrando 5 de 15 HP")
	if hud.has_method("health_ratio"):
		_check(is_equal_approx(hud.health_ratio(), 5.0 / 15.0), "la barra inicia a un tercio")

	GameState.damage_halves(2)
	await get_tree().process_frame
	if value_label != null:
		_check(value_label.text == "3 / 15 HP", "la señal de daño actualiza el texto")
	if hud.has_method("health_ratio"):
		_check(is_equal_approx(hud.health_ratio(), 3.0 / 15.0), "la señal de daño actualiza el relleno")

	hud.queue_free()
	await get_tree().process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	print("%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("PASS: HUD health bar")
		get_tree().quit(0)
		return
	get_tree().quit(1)
