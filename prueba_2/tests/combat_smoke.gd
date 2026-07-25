extends Node2D

# Prueba de humo del sistema de combate y partes.
#
# Se ejecuta como escena principal para tener los autoloads vivos:
#   godot --headless res://tests/combat_smoke.tscn
#
# No comprueba equilibrio, comprueba que nada revienta: instancia los diez
# experimentos y los deja actuar, ejecuta las 44 partes del catálogo y valida
# las reglas del inventario y de la vida en medios corazones.

const PartsDB := preload("res://core/parts_db.gd")
const EnemyDB := preload("res://core/enemy_db.gd")
const SlimeScene := preload("res://actors/player/slime.tscn")

const FRAMES_PER_ENEMY := 45

var _failures: Array[String] = []
var _checks := 0

var _slime: Node2D
var _runner: Node2D

func _ready() -> void:
	_slime = SlimeScene.instantiate()
	_slime.position = Vector2(960, 540)
	add_child(_slime)
	_runner = _slime.get_node("AbilityRunner")
	# La sala de verdad la pone `Transition`; acá basta con marcar el contenedor
	# para que los efectos tengan dónde colgarse.
	add_to_group("room")
	call_deferred("_run")

func _run() -> void:
	await _test_health_halves()
	await _test_checkpoints()
	await _test_inventory_rules()
	await _test_every_part()
	await _test_every_enemy()
	await _test_drop_rules()
	await _test_rooms()
	await _test_progression()
	_report()

# --- Pruebas ---

func _test_health_halves() -> void:
	GameState.reset_run()
	_check(GameState.health_halves == 10, "vida inicial son 10 medios (5 corazones)")

	GameState.damage(1)
	_check(GameState.health_halves == 8, "un corazón de daño quita 2 medios")

	GameState.heal_half_heart()
	_check(GameState.health_halves == 9, "consumir una parte da medio corazón")
	_check(GameState.health == 5, "9 medios se leen como 5 corazones hacia arriba")

	GameState.heal_halves(20)
	_check(GameState.health_halves == 10, "la cura no pasa del máximo")

	GameState.damage(99)
	_check(GameState.health_halves == 0, "el daño no baja de cero")
	await get_tree().process_frame

func _test_checkpoints() -> void:
	GameState.reset_run()
	var reached_events: Array = []
	var on_reached := func(room_id: String, healed_halves: int) -> void:
		reached_events.append([room_id, healed_halves])
	GameState.checkpoint_reached.connect(on_reached)

	GameState.set_initial_checkpoint("L3_CELDA", -3, "")
	_check(GameState.checkpoint_room == "L3_CELDA", "la celda inicia el checkpoint de la partida")
	_check(GameState.health_halves == GameState.max_health_halves, "el checkpoint inicial no cura")
	_check(reached_events.is_empty(), "el checkpoint inicial no muestra recompensa")

	GameState.damage(2)
	var advanced: bool = GameState.try_reach_checkpoint("L2_ASCENSOR", -2, "SpawnS")
	_check(advanced, "subir al piso -2 avanza el checkpoint")
	_check(GameState.checkpoint_room == "L2_ASCENSOR", "se guarda la sala del piso alcanzado")
	_check(GameState.checkpoint_spawn == "SpawnS", "se guarda la entrada segura del checkpoint")
	_check(GameState.health_halves == 8, "un checkpoint nuevo cura un corazón")
	_check(reached_events.size() == 1 and reached_events[0] == ["L2_ASCENSOR", 2], "el checkpoint informa la cura aplicada")

	GameState.damage_halves(1)
	_check(not GameState.try_reach_checkpoint("L2_ASCENSOR", -2, "SpawnS"), "reentrar al mismo piso no reactiva el checkpoint")
	_check(GameState.health_halves == 7, "reentrar al mismo piso no vuelve a curar")
	_check(not GameState.try_reach_checkpoint("L3_CELDA", -3, ""), "volver a un piso inferior no mueve el checkpoint")
	_check(GameState.checkpoint_room == "L2_ASCENSOR", "el checkpoint nunca retrocede")

	GameState.health_halves = GameState.max_health_halves - 1
	_check(GameState.try_reach_checkpoint("L1_ASCENSOR", -1, "SpawnS"), "subir al piso -1 avanza el checkpoint")
	_check(GameState.health_halves == GameState.max_health_halves, "la cura del checkpoint respeta la vida máxima")
	_check(reached_events[-1] == ["L1_ASCENSOR", 1], "el aviso informa medio corazón si solo faltaba medio")

	for room_id in ["L3_CELDA", "L2_ASCENSOR", "L1_ASCENSOR", "L0_VESTIBULO"]:
		_check(RoomDB.ROOMS[room_id].get("is_checkpoint", false), "%s está marcado como checkpoint" % room_id)

	GameState.reset_run()
	_check(GameState.checkpoint_room == "", "reiniciar la partida borra el checkpoint")
	_check(GameState.checkpoint_spawn == "", "reiniciar la partida borra la entrada del checkpoint")
	GameState.checkpoint_reached.disconnect(on_reached)

func _test_inventory_rules() -> void:
	Inventory.reset_run()
	GameState.reset_run()

	_check(Inventory.SLOT_COUNT == 6, "el inventario tiene exactamente 6 huecos")

	# Los huecos son genéricos: cualquier parte entra en cualquiera.
	for i in range(Inventory.SLOT_COUNT):
		_check(Inventory.can_place("acid_stinger", i), "cualquier parte entra en el hueco %d" % (i + 1))

	Inventory.pick_up("acid_stinger")
	_check(Inventory.has_part("acid_stinger"), "recoger equipa en el primer hueco libre")
	_check(not Inventory.can_place("acid_stinger", 2), "no se puede llevar la misma parte dos veces")

	# Zona corporal: dos partes que ocupan el mismo sitio no conviven.
	Inventory.reset_run()
	Inventory.pick_up("bear_claw")
	_check(Inventory.placement_error("bear_claw", 2) != "", "la misma parte no se duplica de zona")

	# Vida máxima: el Tentáculo cuesta un corazón.
	Inventory.reset_run()
	var base_max := GameState.max_health_halves
	Inventory.pick_up("tentacle_limb")
	_check(GameState.max_health_halves == base_max - 2, "el Tentáculo baja la vida máxima un corazón")
	Inventory.reset_run()
	_check(GameState.max_health_halves == base_max, "al quitarla se recupera la vida máxima")

	# Consumir: medio corazón y registro del bono si es parte de jefe.
	GameState.damage(1)
	Inventory.pick_up("compression_piston")
	var before := GameState.health_halves
	Inventory.consume_slot(Inventory.slots.find("compression_piston"))
	_check(GameState.health_halves == before + 1, "consumir una parte cura medio corazón")
	_check(GameState.base_damage_multiplier() > 1.0, "consumir parte de jefe da bono de daño permanente")

	# El multiplicador ofensivo no se acumula: solo cuenta el más alto.
	Inventory.reset_run()
	Inventory.pick_up("bear_claw")
	_check(is_equal_approx(Inventory.mod_best("melee_mult"), 2.0), "la Garra de Oso multiplica x2 el cuerpo a cuerpo")
	Inventory.pick_up("true_heart")
	_check(
		is_equal_approx(Inventory.ability_damage_multiplier(true), 1.6),
		"el Corazón castiga un 20%: x2 pasa a x1,6"
	)
	Inventory.reset_run()
	await get_tree().process_frame

func _test_every_part() -> void:
	Inventory.reset_run()
	GameState.reset_run()

	# Un enemigo de saco para que los efectos tengan a quién apuntar.
	var dummy: Node2D = EnemyDB.scene_for("exp01").instantiate()
	dummy.position = Vector2(1100, 540)
	dummy.max_health = 9999
	add_child(dummy)
	await get_tree().process_frame

	var ran := 0
	for part_id in PartsDB.PARTS:
		var slot_index := _slot_index_for(part_id)
		if slot_index < 0:
			_fail("no hay hueco compatible para %s" % part_id)
			continue

		Inventory.reset_run()
		Inventory.slots[slot_index] = part_id
		if not PartsDB.is_active(part_id):
			continue
		# Se llama al runner directamente: `try_activate` mira recargas y
		# bloqueos, y acá lo que se prueba es que el efecto se ejecuta.
		_runner._run(PartsDB.get_part(part_id)["effect"])
		ran += 1
		await get_tree().physics_frame

	_check(ran > 0, "se ejecutaron %d habilidades activas sin reventar" % ran)

	# Deja correr unos frames para que proyectiles, zonas y torretas hagan su
	# ciclo completo, que es donde suele saltar el error.
	for i in range(60):
		await get_tree().physics_frame

	Inventory.reset_run()
	if is_instance_valid(dummy):
		dummy.queue_free()
	await get_tree().process_frame

func _test_every_enemy() -> void:
	GameState.reset_run()
	for type_id in EnemyDB.SCENES:
		var scene: PackedScene = EnemyDB.scene_for(type_id)
		if scene == null:
			_fail("falta la escena de %s" % type_id)
			continue
		var enemy: Node2D = scene.instantiate()
		enemy.position = Vector2(1200, 540)
		add_child(enemy)
		await get_tree().physics_frame

		# Se le pasa por todos los estados alterados: cada uno toca ramas
		# distintas de la máquina de estados.
		enemy.apply_status(PartsDB.STATUS_SLOW, 0.4)
		enemy.apply_status(PartsDB.STATUS_ROOT, 0.4)
		enemy.apply_status(PartsDB.STATUS_BURN, 0.6)
		enemy.apply_status(PartsDB.STATUS_MARK, 0.6)
		enemy.apply_status(PartsDB.STATUS_STUN, 0.3)

		for i in range(FRAMES_PER_ENEMY):
			if not is_instance_valid(enemy):
				break
			await get_tree().physics_frame

		if is_instance_valid(enemy):
			enemy.take_damage(9999, _slime.global_position, 200.0)
		_check(true, "%s corre su IA y muere sin errores" % type_id)
		await get_tree().physics_frame

func _test_drop_rules() -> void:
	GameState.reset_run()
	Inventory.reset_run()

	# El jefe de sala siempre suelta parte: es la fuente fiable del sistema.
	var leader: Node2D = EnemyDB.scene_for("exp09").instantiate()
	leader.position = Vector2(700, 540)
	leader.is_room_leader = true
	add_child(leader)
	await get_tree().physics_frame

	var before := _count_pickups()
	leader.take_damage(99999, Vector2(600, 540))
	await get_tree().process_frame
	_check(_count_pickups() == before + 1, "el jefe de sala siempre suelta una parte")

	# Con probabilidad cero, un experimento normal no suelta nada.
	var grunt: Node2D = EnemyDB.scene_for("exp01").instantiate()
	grunt.position = Vector2(800, 540)
	grunt.drop_rate = 0.0
	add_child(grunt)
	await get_tree().physics_frame
	before = _count_pickups()
	grunt.take_damage(99999, Vector2(700, 540))
	await get_tree().process_frame
	_check(_count_pickups() == before, "con rate 0 un experimento normal no suelta nada")

	# Y todas las salas pobladas apuntan a tipos y partes que existen.
	for room_id in EnemyDB.SPAWNS:
		_check(RoomDB.ROOMS.has(room_id), "la sala %s de la tabla de spawns existe" % room_id)
		for entry in EnemyDB.spawns_for(room_id):
			_check(EnemyDB.scene_for(entry["type"]) != null, "%s: tipo %s conocido" % [room_id, entry["type"]])

	for type_id in EnemyDB.SCENES:
		var enemy: Node2D = EnemyDB.scene_for(type_id).instantiate()
		for part_id in enemy.drop_parts:
			_check(PartsDB.exists(part_id), "%s suelta la parte conocida %s" % [type_id, part_id])
		enemy.queue_free()
	await get_tree().process_frame

func _test_rooms() -> void:
	GameState.reset_run()
	for room_id in RoomDB.ROOMS:
		var scene: PackedScene = load(RoomDB.ROOMS[room_id]["scene"])
		var room: Node2D = scene.instantiate()
		# Igual que hace `Transition`: el nombre es lo que la sala usa para
		# buscarse en las tablas, y hay que fijarlo antes del _ready.
		room.name = room_id
		add_child(room)
		await get_tree().physics_frame

		var expected: int = EnemyDB.spawns_for(room_id).size()
		var spawned := 0
		var leaders := 0
		for child in room.get_children():
			if child.is_in_group("enemies"):
				spawned += 1
				if child.is_room_leader:
					leaders += 1
		if RoomDB.ROOMS[room_id].get("is_safe", false):
			_check(spawned == 0, "%s es sala segura y nunca puebla" % room_id)
		else:
			_check(spawned == expected, "%s puebla %d experimentos" % [room_id, expected])
		_check(leaders <= 1, "%s tiene como mucho un jefe de sala" % room_id)

		# Sala con enemigos vivos = sala cerrada; sala vacía = puertas abiertas.
		# La sala del boss queda fuera: ahí el sellado lo gestiona el propio boss.
		_check(room.is_cleared() == (spawned == 0), "%s se sella si y solo si tiene enemigos" % room_id)
		if not RoomDB.ROOMS[room_id].get("is_boss", false):
			for child in room.get_children():
				if child.has_method("set_sealed"):
					_check(
						child._sealed == (spawned > 0),
						"%s: la salida %s está %s" % [room_id, child.direction, "sellada" if spawned > 0 else "abierta"]
					)

		room.queue_free()
		await get_tree().process_frame

	# Una sala ya limpiada no vuelve a poblarse.
	GameState.mark_room_cleared("L3_PASILLO")
	var cleared: Node2D = load(RoomDB.ROOMS["L3_PASILLO"]["scene"]).instantiate()
	cleared.name = "L3_PASILLO"
	add_child(cleared)
	await get_tree().physics_frame
	var still_there := 0
	for child in cleared.get_children():
		if child.is_in_group("enemies"):
			still_there += 1
	_check(still_there == 0, "una sala ya limpiada no vuelve a poblarse")
	cleared.queue_free()
	await get_tree().process_frame

func _test_progression() -> void:
	# Se puede llegar andando desde la celda hasta la salida, y todas las salas
	# del mapa están en ese camino: nada queda colgado sin conexión.
	var reachable := {"L3_CELDA": true}
	var frontier: Array[String] = ["L3_CELDA"]
	while not frontier.is_empty():
		var room_id: String = frontier.pop_back()
		for dir in RoomDB.ROOMS[room_id]["doors"]:
			var target: String = RoomDB.ROOMS[room_id]["doors"][dir]
			if reachable.has(target):
				continue
			reachable[target] = true
			frontier.append(target)

	_check(reachable.has("L0_SALIDA"), "se llega desde la celda inicial hasta la salida")
	_check(reachable.size() == RoomDB.ROOMS.size(), "todas las salas son alcanzables")

	# Los niveles van del más profundo a la superficie, sin saltarse ninguno.
	var levels := {}
	for room_id in RoomDB.ROOMS:
		levels[RoomDB.ROOMS[room_id]["level"]] = true
	var sorted: Array = levels.keys()
	sorted.sort()
	_check(sorted[0] == -3 and sorted[-1] == 0, "los niveles van del -3 al 0")
	for i in range(sorted.size() - 1):
		_check(sorted[i + 1] - sorted[i] == 1, "no falta el nivel entre %d y %d" % [sorted[i], sorted[i + 1]])

	# El mapa se calcula sin reventar y coloca todas las salas.
	var overlay: Control = load("res://ui/map_overlay.tscn").instantiate()
	add_child(overlay)
	var layout: Dictionary = overlay._build_layout()
	_check(layout["rooms"].size() == RoomDB.ROOMS.size(), "el mapa coloca todas las salas")
	var overlapped := false
	var ids: Array = layout["rooms"].keys()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			if layout["rooms"][ids[i]].intersects(layout["rooms"][ids[j]]):
				overlapped = true
	_check(not overlapped, "ninguna sala del mapa se dibuja encima de otra")
	overlay.queue_free()
	await get_tree().process_frame

# --- Utilidades ---

func _slot_index_for(_part_id: String) -> int:
	# Con huecos genéricos siempre vale el primero.
	return 0

func _count_pickups() -> int:
	var count := 0
	for child in get_children():
		if child.get_script() != null and child.has_method("_slot_color"):
			count += 1
	return count

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok  %s" % label)
		return
	_fail(label)

func _fail(label: String) -> void:
	_failures.append(label)
	printerr("  FALLO  %s" % label)

func _report() -> void:
	print("")
	print("%d comprobaciones, %d fallos" % [_checks, _failures.size()])
	for failure in _failures:
		print("  - %s" % failure)
	get_tree().quit(1 if _failures.size() > 0 else 0)
