extends Node2D

# La Pierna Escamada se activa con su tecla, pero su escudo era invisible: no
# había forma de saber si estaba puesto ni de ver que se gastaba. Acá se
# comprueba que la costra aparece al activarla, aguanta el golpe y se retira.

const SlimeScene := preload("res://actors/player/slime.tscn")

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	add_to_group("room")
	call_deferred("_run")


func _run() -> void:
	GameState.reset_run()
	Inventory.reset_run()

	var slime: CharacterBody2D = SlimeScene.instantiate()
	add_child(slime)
	await get_tree().physics_frame

	var shell: Line2D = slime.get_node("ScaleShell")
	_check(not shell.visible, "sin activar no hay costra")
	_check(not slime.has_scale_shell(), "sin activar no hay escudo")

	_check(Inventory.pick_up("scaled_skin"), "la Pierna Escamada entra en el cuerpo")
	var runner: Node2D = slime.get_node("AbilityRunner")
	_check(runner.try_activate(0), "la Pierna Escamada se activa desde su hueco")
	await get_tree().physics_frame

	_check(slime.has_scale_shell(), "activarla deja el escudo puesto")
	_check(shell.visible, "activarla muestra la costra")

	var health_before: int = GameState.health
	slime.take_damage(3, Vector2(400, 0))
	await get_tree().physics_frame

	_check(GameState.health == health_before, "la costra se come el impacto entero")
	_check(not slime.has_scale_shell(), "el golpe gasta el escudo")
	_check(shell.visible, "al romperse la costra todavía se ve el destello")

	# El destello dura `SHELL_FLASH_TIME`; pasado eso no queda nada en pantalla.
	var flash: float = slime.get_script().get_script_constant_map()["SHELL_FLASH_TIME"]
	await get_tree().create_timer(flash + 0.15).timeout
	_check(not shell.visible, "consumido el destello la costra desaparece")

	# Un segundo golpe ya cuesta vida: el escudo no se regala dos veces.
	slime.set("_invuln", 0.0)
	slime.take_damage(2, Vector2(400, 0))
	await get_tree().physics_frame
	_check(GameState.health < health_before, "sin costra el golpe sí duele")

	slime.queue_free()
	await get_tree().process_frame
	Inventory.reset_run()
	GameState.reset_run()
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
		print("PASS: scale shell")
		get_tree().quit(0)
		return
	get_tree().quit(1)
