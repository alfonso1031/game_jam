extends Node

const RunMap := preload("res://core/run_map.gd")

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay_scene: PackedScene = load("res://ui/map_overlay.tscn")
	var overlay: Control = overlay_scene.instantiate()
	add_child(overlay)
	await get_tree().process_frame

	_check(overlay.has_method("build_layout"), "expone el layout procedural")
	_check(overlay.has_method("visible_room_ids"), "expone las salas conocidas")
	if not overlay.has_method("build_layout") or not overlay.has_method("visible_room_ids"):
		overlay.queue_free()
		await get_tree().process_frame
		_finish()
		return

	var cross := _cross_map()
	var panel := Rect2(0.0, 0.0, 900.0, 700.0)
	var layout: Dictionary = overlay.build_layout(cross, panel)
	var rects: Dictionary = layout["rooms"]
	_check(rects.size() == 5, "incluye las cinco salas de la cruz")
	_check(_rects_do_not_overlap(rects), "las celdas no se solapan")
	_check(_all_inside(rects, panel), "toda la cruz cabe en el panel")
	_check(
		rects["N"].get_center().y < rects["CENTER"].get_center().y,
		"el norte queda visualmente arriba"
	)
	_check(
		rects["E"].get_center().x > rects["CENTER"].get_center().x,
		"el este queda visualmente a la derecha"
	)

	cross.add_room("HIDDEN", Vector2i(4, 4), &"normal", &"loot")
	RunManager.current_map = cross
	GameState.current_room = "CENTER"
	GameState.visited.clear()
	GameState.visited["CENTER"] = true
	var visible_ids: Array[String] = overlay.visible_room_ids()
	_check(visible_ids.has("CENTER"), "muestra la sala actual")
	_check(visible_ids.has("N") and visible_ids.has("E"), "muestra vecinas cardinales")
	_check(not visible_ids.has("HIDDEN"), "oculta una sala no descubierta")

	overlay.queue_free()
	await get_tree().process_frame
	_finish()


func _cross_map() -> RefCounted:
	var map := RunMap.new(444, 0)
	map.add_room("CENTER", Vector2i.ZERO, &"entry", &"empty")
	map.add_room("N", Vector2i.UP, &"normal", &"easy")
	map.add_room("E", Vector2i.RIGHT, &"normal", &"loot")
	map.add_room("S", Vector2i.DOWN, &"normal", &"hard")
	map.add_room("O", Vector2i.LEFT, &"normal", &"empty")
	map.connect_rooms("CENTER", "N", &"N")
	map.connect_rooms("CENTER", "E", &"E")
	map.connect_rooms("CENTER", "S", &"S")
	map.connect_rooms("CENTER", "O", &"O")
	map.entry_room_id = "CENTER"
	return map


func _rects_do_not_overlap(rects: Dictionary) -> bool:
	var ids: Array = rects.keys()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			if (rects[ids[i]] as Rect2).intersects(rects[ids[j]] as Rect2):
				return false
	return true


func _all_inside(rects: Dictionary, panel: Rect2) -> bool:
	for rect: Rect2 in rects.values():
		if not panel.encloses(rect):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	print("%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("PASS: procedural local map")
		get_tree().quit(0)
		return
	get_tree().quit(1)
