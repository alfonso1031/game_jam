extends Node

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameState.reset_run()
	Inventory.reset_run()

	var pickup_scene: PackedScene = load("res://world/props/part_pickup.tscn")
	var loose_pickup: Area2D = pickup_scene.instantiate()
	_check(loose_pickup.has_signal("collected"), "el pickup avisa cuando se recoge")
	loose_pickup.free()

	var has_state_contract := (
		GameState.has_method("claim_room_reward")
		and GameState.has_method("is_room_reward_claimed")
	)
	_check(has_state_contract, "GameState expone recompensas de sala")

	var body_path := "res://world/props/body_source.tscn"
	var has_body_scene := ResourceLoader.exists(body_path)
	_check(has_body_scene, "existe la escena del cuerpo")
	if has_state_contract and has_body_scene:
		await _test_body_reward(body_path)

	_finish()


func _test_body_reward(body_path: String) -> void:
	var scene: PackedScene = load(body_path)
	var body: Node2D = scene.instantiate()
	body.configure("C_01", "serrated_jaw")
	add_child(body)
	await get_tree().process_frame

	var pickup := body.get_node_or_null("PartPickup")
	_check(
		pickup != null and pickup.part_id == "serrated_jaw",
		"el cuerpo aloja la recompensa"
	)
	if pickup != null:
		pickup.emit_signal("collected", "serrated_jaw")
		_check(GameState.is_room_reward_claimed("C_01"), "recoger marca la sala")

	body.queue_free()
	await get_tree().process_frame

	var revisited: Node2D = scene.instantiate()
	revisited.configure("C_01", "serrated_jaw")
	add_child(revisited)
	await get_tree().process_frame
	_check(revisited.get_node_or_null("PartPickup") == null, "volver no duplica la parte")
	revisited.queue_free()
	await get_tree().process_frame

	GameState.reset_run()
	_check(
		not GameState.is_room_reward_claimed("C_01"),
		"otra partida libera la recompensa"
	)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	print("%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("PASS: room story content")
		get_tree().quit(0)
		return
	get_tree().quit(1)
