extends Node

const MapGenerator := preload("res://core/map_generator.gd")

signal run_started(seed: int)
signal map_generated(run_map: RefCounted)
signal floor_completed(floor_id: StringName, healed_hp: int)
signal run_ended(summary: Dictionary)

var current_seed: int = 0
var current_map: RefCounted
var completed_floors: Dictionary = {}
var parts_consumed: Array[String] = []
var parts_sacrificed: Array[String] = []
var active := false


func _ready() -> void:
	if not Inventory.part_consumed.is_connected(_on_part_consumed):
		Inventory.part_consumed.connect(_on_part_consumed)


func start_new_run(seed_value: int = -1) -> void:
	GameState.reset_run()
	Inventory.reset_run()
	current_seed = (
		seed_value
		if seed_value >= 0
		else int(Time.get_unix_time_from_system())
	)
	current_map = MapGenerator.new().generate(current_seed)
	assert(current_map != null, "No se pudo generar Contención")
	completed_floors.clear()
	parts_consumed.clear()
	parts_sacrificed.clear()
	active = true
	run_started.emit(current_seed)
	map_generated.emit(current_map)


func complete_floor(floor_id: StringName) -> bool:
	if not active or completed_floors.has(floor_id):
		return false
	completed_floors[floor_id] = true
	var before: int = GameState.health_halves
	GameState.heal_halves(2)
	floor_completed.emit(floor_id, GameState.health_halves - before)
	return true


func pay_grate_cost(slot_index: int, confirm_lethal: bool = false) -> StringName:
	if not Inventory.is_empty(slot_index):
		var sacrificed_id: String = Inventory.sacrifice_slot(slot_index)
		if sacrificed_id != "":
			parts_sacrificed.append(sacrificed_id)
			return &"part"
	if GameState.health_halves <= 0:
		return &"invalid"
	if GameState.health_halves == 1 and not confirm_lethal:
		return &"confirmation_required"
	GameState.damage_halves(1)
	if GameState.health_halves <= 0:
		return &"death"
	return &"hp"


func _on_part_consumed(part_id: String) -> void:
	if active:
		parts_consumed.append(part_id)
