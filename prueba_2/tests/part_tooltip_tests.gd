extends Node

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://ui/part_tooltip.tscn")
	_check(scene != null, "la escena de tooltip existe")
	if scene == null:
		_finish()
		return

	var tooltip: Control = scene.instantiate()
	add_child(tooltip)
	await get_tree().process_frame
	tooltip.show_part("mycelium_hand", Vector2(1900, 1060))
	_check(tooltip.visible, "se muestra")
	_check(tooltip.title_text() == "Mano de Micelio", "nombre desde catálogo")
	_check(
		tooltip.body_text().begins_with("Dispara una línea"),
		"descripción desde catálogo"
	)
	var rect: Rect2 = tooltip.tooltip_rect()
	var viewport_size := get_viewport().get_visible_rect().size
	_check(
		rect.end.x <= viewport_size.x - 8.0 and rect.end.y <= viewport_size.y - 8.0,
		"queda dentro del viewport"
	)
	_check(rect.position.x >= 8.0 and rect.position.y >= 8.0, "respeta el margen superior")
	tooltip.hide_part()
	_check(not tooltip.visible, "se oculta")
	tooltip.queue_free()
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
		print("PASS: part tooltip")
		get_tree().quit(0)
		return
	get_tree().quit(1)
