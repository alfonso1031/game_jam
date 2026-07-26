extends Node

const ProceduralRoomScene := preload("res://world/rooms/procedural_room.tscn")
const Exp07Script := preload("res://actors/enemies/exp07_crustacean.gd")
const ContainmentMinionScripts: Array[Script] = [
	preload("res://actors/enemies/exp01_centipede.gd"),
	preload("res://actors/enemies/exp02_spider.gd"),
	preload("res://actors/enemies/exp03_saurian.gd"),
]

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_run()
	await _check_normal_room_pool()
	await _check_preboss_leader()
	_finish()


func _check_normal_room_pool() -> void:
	var script_paths: Array[String] = []
	var exp07_count := 0
	for room_id: String in ["A", "B", "C", "D"]:
		var room: Node2D = await _spawn_room(room_id, &"normal", 1)
		var enemies: Array[Node] = _enemies(room)
		_check(enemies.size() == 1, "%s genera un enemigo" % room_id)
		if enemies.size() == 1:
			var script_path: String = _script_path(enemies[0])
			script_paths.append(script_path)
			if enemies[0].get_script() == Exp07Script:
				exp07_count += 1
		room.queue_free()
		await get_tree().process_frame

	var unique_paths: Dictionary = {}
	for script_path: String in script_paths:
		unique_paths[script_path] = true
	_check(unique_paths.size() == 4, "el pool normal contiene cuatro enemigos con el mismo peso")
	_check(exp07_count == 1, "EXP07 ocupa una de cada cuatro posiciones del pool normal")


func _check_preboss_leader() -> void:
	var room: Node2D = await _spawn_room("PREBOSS", &"preboss", 0)
	var enemies: Array[Node] = _enemies(room)
	var exp07_enemies: Array[Node] = []
	for enemy: Node in enemies:
		if enemy.get_script() == Exp07Script:
			exp07_enemies.append(enemy)

	_check(enemies.size() == 3, "el preboss genera tres enemigos por defecto")
	_check(exp07_enemies.size() == 1, "el preboss garantiza exactamente un EXP07")
	if exp07_enemies.size() == 1:
		var leader: Node = exp07_enemies[0]
		_check(bool(leader.get("is_room_leader")), "EXP07 es el líder del preboss")
		var expected_drops: Array[String] = ["crusher_claw"]
		_check(
			leader.get("drop_parts") == expected_drops,
			"el líder EXP07 garantiza Tenaza Trituradora"
		)
	for enemy: Node in enemies:
		if enemy.get_script() != Exp07Script:
			_check(
				ContainmentMinionScripts.has(enemy.get_script()),
				"los acompañantes usan EXP01-03"
			)

	room.queue_free()
	await get_tree().process_frame


func _spawn_room(room_id: String, role: StringName, enemy_count: int) -> Node2D:
	var room: Node2D = ProceduralRoomScene.instantiate()
	room.configure({
		"id": room_id,
		"doors": {},
		"role": role,
		"content_type": &"combat",
		"enemy_count": enemy_count,
		"one_way": {},
		"grate_target": "",
		"grate_source": "",
		"closure_keep_direction": "",
	})
	add_child(room)
	await get_tree().process_frame
	return room


func _enemies(room: Node2D) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in room.get_children():
		if child.is_in_group("enemies"):
			result.append(child)
	return result


func _script_path(enemy: Node) -> String:
	var script: Script = enemy.get_script() as Script
	return script.resource_path if script != null else ""


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	for failure: String in failures:
		push_error(failure)
	print(
		"PASS: containment enemy spawn"
		if failures.is_empty()
		else "FAIL: containment enemy spawn"
	)
	get_tree().quit(0 if failures.is_empty() else 1)
