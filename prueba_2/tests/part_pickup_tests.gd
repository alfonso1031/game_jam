extends Node

const PART_IDS: Array[String] = [
	"acid_stinger",
	"serrated_jaw",
	"hydraulic_legs",
	"bio_netcaster",
	"whip_tail",
	"scaled_skin",
]

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameState.reset_run()
	Inventory.reset_run()
	for part_id: String in PART_IDS:
		Inventory.pick_up(part_id)

	var blocked_pickup: Area2D = _make_pickup("electric_gland")
	var blocked_collections: Array[String] = []
	blocked_pickup.collected.connect(
		func(part_id: String) -> void:
			blocked_collections.append(part_id)
	)
	blocked_pickup.call("_collect")
	_check(blocked_collections.is_empty(), "sin espacio no emite collected")
	_check(
		not blocked_pickup.is_queued_for_deletion(),
		"sin espacio el pickup permanece en el mundo"
	)
	_check(not Inventory.has_part("electric_gland"), "sin espacio no equipa la parte")

	Inventory.clear_slot(0)
	var available_pickup: Area2D = _make_pickup("electric_gland")
	var available_collections: Array[String] = []
	available_pickup.collected.connect(
		func(part_id: String) -> void:
			available_collections.append(part_id)
	)
	available_pickup.call("_collect")
	_check(
		available_collections == ["electric_gland"],
		"al liberar espacio emite collected una vez"
	)
	_check(available_pickup.is_queued_for_deletion(), "con espacio retira el pickup")
	_check(Inventory.has_part("electric_gland"), "con espacio equipa la parte")

	await _check_drop_animation()

	blocked_pickup.queue_free()
	await get_tree().process_frame
	Inventory.reset_run()
	_finish()


# La parte soltada por un experimento salta, aterriza y solo entonces se puede
# recoger: sin esa demora el jugador la absorbe en el frame de la muerte.
func _check_drop_animation() -> void:
	Inventory.reset_run()
	var pickup: Area2D = _make_pickup("electric_gland")
	pickup.call("start_drop")
	_check(not bool(pickup.get("_armed")), "recién soltada la parte nace desarmada")

	var constants: Dictionary = pickup.get_script().get_script_constant_map()
	var total: float = (
		float(constants["DROP_RISE_TIME"])
		+ float(constants["DROP_FALL_TIME"])
		+ float(constants["DROP_SQUASH_TIME"])
		+ float(constants["DROP_RECOVER_TIME"])
		+ float(constants["DROP_ARM_DELAY"])
	)
	_check(total >= 0.5, "la caída dura lo bastante para verse")

	await get_tree().create_timer(total * 0.4).timeout
	_check(not bool(pickup.get("_armed")), "a mitad de la caída sigue desarmada")

	await get_tree().create_timer(total * 0.8 + 0.2).timeout
	_check(bool(pickup.get("_armed")), "al aterrizar la parte queda recogible")
	var glow: Polygon2D = pickup.get_node("Glow")
	_check(glow.position.is_zero_approx(), "el brillo vuelve al suelo")

	pickup.queue_free()
	await get_tree().process_frame


func _make_pickup(part_id: String) -> Area2D:
	var scene: PackedScene = load("res://world/props/part_pickup.tscn")
	var pickup: Area2D = scene.instantiate()
	pickup.set("part_id", part_id)
	add_child(pickup)
	return pickup


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	print("%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("PASS: part pickup capacity")
		get_tree().quit(0)
		return
	get_tree().quit(1)
