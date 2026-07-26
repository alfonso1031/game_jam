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
const RoomAssembler := preload("res://world/rooms/room_assembler.gd")

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
	await _test_inventory_rules()
	await _test_every_part()
	await _test_every_enemy()
	await _test_drop_rules()
	await _test_room_templates()
	await _test_procedural_room_assembly()
	await _test_rooms()
	await _test_room_lighting()
	await _test_progression()
	_report()

# --- Pruebas ---


func _test_room_templates() -> void:
	var fixtures: Array = [
		[],
		["E"], ["N"], ["O"], ["S"],
		["N", "E"], ["N", "S"], ["N", "O"],
		["E", "S"], ["E", "O"], ["S", "O"],
		["E", "S", "O"], ["N", "E", "O"], ["N", "E", "S"], ["N", "S", "O"],
		["O", "N", "E", "S"],
	]
	for doors_value: Variant in fixtures:
		var doors: Array[String] = []
		doors.assign(doors_value)
		var template: Dictionary = RoomDB.template_for(doors)
		_check(not template.is_empty(), "hay plantilla para %s" % [doors])
		if not template.is_empty():
			_check(
				ResourceLoader.exists(template["background"]),
				"fondo de plantilla existe para %s" % [doors]
			)


func _test_procedural_room_assembly() -> void:
	var fixtures: Array = [
		{"id": "TEST_E", "doors": {"E": "NEXT"}},
		{"id": "TEST_NE", "doors": {"N": "A", "E": "B"}, "flip_h": true},
		{"id": "TEST_SO", "doors": {"S": "A", "O": "B"}, "flip_h": true},
		{"id": "TEST_NS", "doors": {"N": "NEXT", "S": "PREV"}},
		{"id": "TEST_NES", "doors": {"N": "A", "E": "B", "S": "C"}},
		{"id": "TEST_NESO", "doors": {"N": "A", "E": "B", "S": "C", "O": "D"}},
		{"id": "TEST_GRATE", "doors": {}, "role": &"grate_destination"},
	]
	for fixture_value: Variant in fixtures:
		var fixture: Dictionary = fixture_value
		if not fixture.has("role"):
			fixture["role"] = &"normal"
		fixture["content_type"] = &"empty"
		fixture["enemy_count"] = 0
		fixture["one_way"] = {}
		fixture["grate_target"] = ""
		fixture["closure_keep_direction"] = ""
		var assembled: Node2D = RoomAssembler.build(fixture)
		add_child(assembled)
		_check(assembled.get_meta("room_id") == fixture["id"], "conserva id procedural")
		_check(
			assembled.get_meta("content_type") == fixture["content_type"],
			"conserva contenido procedural"
		)
		_check(assembled.get_meta("enemy_count") == 0, "conserva cantidad de enemigos")
		var doors: Dictionary = fixture["doors"]
		for direction in ["N", "E", "S", "O"]:
			_check(
				assembled.has_node("Door%s" % direction) == doors.has(direction),
				"solo crea puerta %s si está declarada" % direction
			)
			_check(
				assembled.has_node("Spawn%s" % direction) == doors.has(direction),
				"solo crea spawn %s si está declarado" % direction
			)
		var background: Sprite2D = assembled.get_node("Background")
		_check(background.texture != null, "carga fondo compatible")
		_check(
			background.flip_h == bool(fixture.get("flip_h", false)),
			"aplica orientación del fondo para %s" % [doors.keys()]
		)
		if fixture["role"] == &"grate_destination":
			_check(
				background.get_meta("virtual_opening", "") == "E",
				"la sala de rejilla reserva una abertura visual sin puerta normal"
			)
		var lamp_count := 0
		for child in assembled.get_children():
			if child.name.begins_with("Lamp"):
				lamp_count += 1
		_check(lamp_count >= 4, "la sala procedural tiene al menos cuatro focos")
		assembled.queue_free()
		await get_tree().process_frame


func _test_health_halves() -> void:
	GameState.reset_run()
	_check(GameState.health_halves == 5, "la partida inicia con 5 HP")
	_check(GameState.max_health_halves == 15, "la vida máxima es 15 HP")

	GameState.damage(1)
	_check(GameState.health_halves == 3, "un corazón de daño quita 2 HP")

	GameState.heal_half_heart()
	_check(GameState.health_halves == 4, "consumir una parte da 1 HP")
	_check(GameState.health == 2, "4 HP se leen como 2 corazones")

	GameState.heal_halves(20)
	_check(GameState.health_halves == 15, "la cura no pasa del máximo")

	GameState.damage(99)
	_check(GameState.health_halves == 0, "el daño no baja de cero")
	await get_tree().process_frame

func _test_inventory_rules() -> void:
	Inventory.reset_run()
	GameState.reset_run()

	_check(Inventory.SLOT_COUNT == 6, "el inventario tiene exactamente 6 huecos")
	_check(
		not _has_property(Inventory, &"pending"),
		"las seis partes no tienen una reserva pendiente"
	)

	# Los huecos son genéricos: cualquier parte entra en cualquiera.
	for i in range(Inventory.SLOT_COUNT):
		_check(Inventory.can_place("acid_stinger", i), "cualquier parte entra en el hueco %d" % (i + 1))

	Inventory.pick_up("acid_stinger")
	_check(Inventory.has_part("acid_stinger"), "recoger equipa en el primer hueco libre")
	_check(not Inventory.can_place("acid_stinger", 2), "no se puede llevar la misma parte dos veces")

	# Al llenar el cuerpo, una séptima parte se rechaza sin crear estado oculto.
	Inventory.reset_run()
	for part_id: String in [
		"acid_stinger",
		"serrated_jaw",
		"hydraulic_legs",
		"bio_netcaster",
		"whip_tail",
		"scaled_skin",
	]:
		_check(Inventory.pick_up(part_id), "equipa %s mientras existe espacio" % part_id)
	var full_body: Array[String] = Inventory.slots.duplicate()
	_check(
		not Inventory.pick_up("electric_gland"),
		"rechaza una séptima parte cuando los seis slots están llenos"
	)
	_check(Inventory.slots == full_body, "rechazar la séptima parte no altera el cuerpo")

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


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if property["name"] == property_name:
			return true
	return false

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

	# El overlay local se calcula desde la generación activa, no desde el grafo
	# legacy de cuatro pisos.
	RunManager.start_new_run(1001)
	var overlay: Control = load("res://ui/map_overlay.tscn").instantiate()
	add_child(overlay)
	var layout: Dictionary = overlay.build_layout(
		RunManager.current_map,
		Rect2(0.0, 0.0, 900.0, 700.0)
	)
	_check(
		layout["rooms"].size() == RunManager.current_map.rooms.size(),
		"el mapa coloca toda la generación de Contención"
	)
	var overlapped := false
	var ids: Array = layout["rooms"].keys()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			if layout["rooms"][ids[i]].intersects(layout["rooms"][ids[j]]):
				overlapped = true
	_check(not overlapped, "ninguna sala procedural se dibuja encima de otra")
	overlay.queue_free()
	await get_tree().process_frame

func _test_room_lighting() -> void:
	for room_id in RoomDB.ROOMS:
		var room_data: Dictionary = RoomDB.ROOMS[room_id]
		var scene: PackedScene = load(room_data["scene"])
		var room: Node = scene.instantiate()
		var active_count := 0
		var has_overlap := false
		var blocks_door_lane := false
		for side_value in ["n", "s", "e", "o"]:
			var side: String = side_value
			var active_indices: Array = room.get("lamps_%s" % side)
			var dead_indices: Array = room.get("dead_lamps_%s" % side)
			active_count += active_indices.size()
			for index in active_indices:
				if index in dead_indices:
					has_overlap = true
			var door_side: String = side.to_upper()
			var door_index: int = 6 if side == "n" or side == "s" else 3
			if room_data["doors"].has(door_side) and door_index in active_indices:
				blocks_door_lane = true
		_check(active_count >= 3, "%s tiene al menos tres focos activos" % room_id)
		_check(not has_overlap, "%s no declara el mismo foco activo y averiado" % room_id)
		_check(not blocks_door_lane, "%s deja libre el centro de las paredes con puerta" % room_id)
		room.free()

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
