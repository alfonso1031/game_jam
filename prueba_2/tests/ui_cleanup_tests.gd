extends Node

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var title: Control = load("res://ui/title.tscn").instantiate()
	add_child(title)
	_check(title.has_node("TitleLabel"), "la portada conserva el nombre")
	_check(title.has_node("Prompt"), "la portada conserva la acción de inicio")
	_check(not title.has_node("Subtitle"), "la portada elimina el subtítulo")
	_check(not title.has_node("Controls"), "la portada elimina controles")
	title.queue_free()

	var hud: Control = load("res://ui/hud.tscn").instantiate()
	add_child(hud)
	_check(hud.has_node("Health/Track"), "el HUD conserva la barra")
	_check(hud.has_node("Health/Value"), "el HUD conserva el valor")
	_check(not hud.has_node("Health/Caption"), "el HUD elimina BIOMASA")
	_check(not hud.has_node("LevelLabel"), "el HUD elimina nivel")
	_check(not hud.has_node("RoomLabel"), "el HUD elimina sala")
	hud.queue_free()

	var map: Control = load("res://ui/map_overlay.tscn").instantiate()
	add_child(map)
	_check(map.has_node("BodyPanel"), "el mapa conserva el cuerpo")
	_check(not map.has_node("Title"), "el mapa elimina título")
	_check(not map.has_node("Legend"), "el mapa elimina leyenda")
	_check(not map.has_node("Hint"), "el mapa elimina ayuda")
	map.queue_free()

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
		print("PASS: UI cleanup")
		get_tree().quit(0)
		return
	get_tree().quit(1)
