# Contención Procedural and Run Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el recorrido fijo del nivel -3 por una instancia procedural determinista y convertir la muerte en final de partida, con vida 5/15 HP, slots reutilizables y rejillas con coste.

**Architecture:** `RunMap` y `MapGenerator` serán módulos puros de `core/`; no conocerán autoloads ni escenas. `RunManager` será la autoridad del ciclo, seed, mapa y resumen; `GameState` seguirá siendo autoridad de HP/sala visitada e `Inventory` de partes. `RoomDB` pasará a catalogar plantillas y `RoomAssembler` materializará cada descriptor para que `Transition` continúe siendo el único servicio que cambia salas.

**Tech Stack:** Godot 4.7.1, GDScript tipado, `RandomNumberGenerator`, escenas `.tscn`, pruebas headless sin addons.

## Global Constraints

- Implementar únicamente `NIVEL -3 · CONTENCIÓN`; los pisos -2, -1 y 0 quedan como contratos futuros.
- Godot trata warnings como errores: declarar tipos explícitos al leer `Dictionary` o `Variant`.
- Indentar GDScript con tabs y mantener cada `.tscn` junto a su `.gd`.
- `core/` no puede importar autoloads, actores, UI ni escenas.
- La misma pareja `(run_seed, generation_attempt)` debe producir el mismo mapa.
- El generador permite hasta `128` intentos y nunca relaja reglas silenciosamente.
- Camino principal de `6–8` salas; máximo `12` salas incluyendo destinos de rejilla.
- Salas normales: fácil `40%`, difícil `30%`, vacía `20%`, cierre `10%`.
- Rejilla por combate elegible `60%`, máximo una por sala, mínimo una si existe combate, destinos únicos.
- Destinos de rejilla: vacía `40%`, combate `20%`, loot `40%`.
- Vida máxima `15 HP`, inicio `5 HP`, comer `+1 HP`, completar Contención `+2 HP`.
- Morir termina la partida actual; no existe respawn ni persistencia en disco.
- Cada función nueva nace en ciclo RED → GREEN → REFACTOR.

---

### Task 1: Modelo puro `RunMap`

**Files:**
- Create: `prueba_2/core/run_map.gd`
- Create: `prueba_2/tests/run_map_tests.gd`

**Interfaces:**
- Consumes: solo tipos integrados de Godot.
- Produces: `RunMap.new(seed_value, attempt_value)`, `add_room()`, `connect_rooms()`, `set_grate()`, `room()`, `room_ids()`, `canonical_snapshot()`.

- [ ] **Step 1: Write the failing model test**

Crear `prueba_2/tests/run_map_tests.gd`:

```gdscript
extends SceneTree

const RunMap := preload("res://core/run_map.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var map := RunMap.new(42, 0)
	map.add_room("R0", Vector2i.ZERO, &"entry", &"tutorial")
	map.add_room("R1", Vector2i.RIGHT, &"normal", &"easy")
	map.connect_rooms("R0", "R1", &"E")
	map.set_grate("R1", "RG")
	map.add_room("RG", Vector2i(1, 1), &"grate_destination", &"loot")

	_check(map.seed == 42, "conserva la seed")
	_check(map.room_ids() == ["R0", "R1", "RG"], "ordena ids de forma estable")
	_check(map.room("R0")["doors"]["E"] == "R1", "conecta la ida")
	_check(map.room("R1")["doors"]["O"] == "R0", "conecta la vuelta")
	_check(map.room("R1")["grate_target"] == "RG", "registra la rejilla")
	_check(map.canonical_snapshot()["rooms"].size() == 3, "expone snapshot serializable")
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PASS: run map model")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
```

Expected: parser failure because `res://core/run_map.gd` does not exist.

- [ ] **Step 3: Implement the minimum model**

Crear `prueba_2/core/run_map.gd`:

```gdscript
extends RefCounted

const OPPOSITE: Dictionary = {"N": "S", "S": "N", "E": "O", "O": "E"}

var seed: int
var attempt: int
var floor_id: StringName = &"contencion"
var entry_room_id: String = ""
var boss_room_id: String = ""
var main_path: Array[String] = []
var rooms: Dictionary = {}

func _init(seed_value: int, attempt_value: int) -> void:
	seed = seed_value
	attempt = attempt_value

func add_room(
	room_id: String,
	grid: Vector2i,
	role: StringName,
	content_type: StringName
) -> void:
	rooms[room_id] = {
		"id": room_id,
		"grid": grid,
		"template_id": "",
		"role": role,
		"content_type": content_type,
		"doors": {},
		"one_way": {},
		"grate_target": "",
	}

func connect_rooms(
	from_id: String,
	to_id: String,
	direction: StringName,
	one_way: bool = false
) -> void:
	var dir: String = String(direction)
	var back: String = OPPOSITE[dir]
	var from_doors: Dictionary = rooms[from_id]["doors"]
	var from_one_way: Dictionary = rooms[from_id]["one_way"]
	from_doors[dir] = to_id
	from_one_way[dir] = one_way
	if not one_way:
		var to_doors: Dictionary = rooms[to_id]["doors"]
		var to_one_way: Dictionary = rooms[to_id]["one_way"]
		to_doors[back] = from_id
		to_one_way[back] = false

func set_grate(source_id: String, target_id: String) -> void:
	rooms[source_id]["grate_target"] = target_id

func room(room_id: String) -> Dictionary:
	return rooms.get(room_id, {})

func room_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(rooms.keys())
	ids.sort()
	return ids

func canonical_snapshot() -> Dictionary:
	var ordered_rooms: Array[Dictionary] = []
	for room_id in room_ids():
		ordered_rooms.append(room(room_id).duplicate(true))
	return {
		"seed": seed,
		"attempt": attempt,
		"floor_id": String(floor_id),
		"entry_room_id": entry_room_id,
		"boss_room_id": boss_room_id,
		"main_path": main_path.duplicate(),
		"rooms": ordered_rooms,
	}
```

- [ ] **Step 4: Run the test and verify GREEN**

Run the Task 1 command. Expected: `PASS: run map model`, exit `0`.

- [ ] **Step 5: Commit the model**

```powershell
git add prueba_2/core/run_map.gd prueba_2/tests/run_map_tests.gd
git commit -m "feat: modela el mapa procedural de una partida"
```

---

### Task 2: Topología determinista y validador

**Files:**
- Create: `prueba_2/core/map_generator.gd`
- Modify: `prueba_2/tests/run_map_tests.gd`

**Interfaces:**
- Consumes: `RunMap`.
- Produces: `generate(run_seed: int) -> RefCounted`, `generate_attempt(run_seed: int, attempt: int) -> RefCounted`, `validate(run_map: RefCounted) -> PackedStringArray`.

- [ ] **Step 1: Add failing determinism and topology tests**

Añadir a `_run()`:

```gdscript
const MapGenerator := preload("res://core/map_generator.gd")

var generator := MapGenerator.new()
var first: RefCounted = generator.generate(90125)
var second: RefCounted = generator.generate(90125)
var different: RefCounted = generator.generate(90126)

_check(first != null, "genera una seed válida")
_check(
	first.canonical_snapshot() == second.canonical_snapshot(),
	"la misma seed produce el mismo mapa"
)
_check(
	first.canonical_snapshot() != different.canonical_snapshot(),
	"otra seed cambia la topología o contenido"
)
_check(first.main_path.size() >= 6 and first.main_path.size() <= 8, "camino de 6 a 8")
_check(first.rooms.size() <= 12, "respeta máximo de 12")
_check(first.room(first.main_path[0])["role"] == &"entry", "entrada primero")
_check(first.room(first.main_path[-2])["role"] == &"preboss", "preboss penúltimo")
_check(first.room(first.main_path[-1])["role"] == &"boss_choice", "boss al final")
_check(generator.validate(first).is_empty(), "la propuesta aceptada es válida")
```

- [ ] **Step 2: Run and verify RED**

Expected: preload failure for `map_generator.gd`.

- [ ] **Step 3: Implement deterministic generation**

Implementar:

```gdscript
extends RefCounted

const RunMap := preload("res://core/run_map.gd")
const MAX_ATTEMPTS := 128
const MIN_MAIN_PATH := 6
const MAX_MAIN_PATH := 8
const MAX_ROOMS := 12
const DIRECTIONS: Array[String] = ["N", "E", "S", "O"]
const DELTAS: Dictionary = {
	"N": Vector2i.UP,
	"E": Vector2i.RIGHT,
	"S": Vector2i.DOWN,
	"O": Vector2i.LEFT,
}

func generate(run_seed: int) -> RefCounted:
	for attempt in range(MAX_ATTEMPTS):
		var candidate: RefCounted = generate_attempt(run_seed, attempt)
		if validate(candidate).is_empty():
			return candidate
	return null

func generate_attempt(run_seed: int, attempt: int) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = _mixed_seed(run_seed, attempt)
	var run_map := RunMap.new(run_seed, attempt)
	var target_length: int = rng.randi_range(MIN_MAIN_PATH, MAX_MAIN_PATH)
	var occupied: Dictionary = {}
	var current := Vector2i.ZERO

	for index in range(target_length):
		var room_id := "C_%02d" % index
		var role: StringName = &"normal"
		if index == 0:
			role = &"entry"
		elif index == target_length - 2:
			role = &"preboss"
		elif index == target_length - 1:
			role = &"boss_choice"
		run_map.add_room(room_id, current, role, &"unassigned")
		run_map.main_path.append(room_id)
		occupied[current] = room_id
		if index == target_length - 1:
			break
		var choices: Array[String] = _free_directions(current, occupied, rng)
		if choices.is_empty():
			return run_map
		var direction: String = choices[rng.randi_range(0, choices.size() - 1)]
		current += DELTAS[direction]

	run_map.entry_room_id = run_map.main_path[0]
	run_map.boss_room_id = run_map.main_path[-1]
	for index in range(run_map.main_path.size() - 1):
		var from_id: String = run_map.main_path[index]
		var to_id: String = run_map.main_path[index + 1]
		var from_grid: Vector2i = run_map.room(from_id)["grid"]
		var to_grid: Vector2i = run_map.room(to_id)["grid"]
		run_map.connect_rooms(from_id, to_id, _direction_for(to_grid - from_grid))
	return run_map

func _mixed_seed(run_seed: int, attempt: int) -> int:
	return int((run_seed * 1103515245 + attempt * 12345) & 0x7fffffff)
```

Añadir las funciones deterministas:

```gdscript
func _free_directions(
	grid: Vector2i,
	occupied: Dictionary,
	rng: RandomNumberGenerator
) -> Array[String]:
	var choices: Array[String] = []
	for direction in DIRECTIONS:
		if not occupied.has(grid + DELTAS[direction]):
			choices.append(direction)
	for index in range(choices.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var current: String = choices[index]
		choices[index] = choices[swap_index]
		choices[swap_index] = current
	return choices

func _direction_for(delta: Vector2i) -> StringName:
	for direction in DIRECTIONS:
		if DELTAS[direction] == delta:
			return StringName(direction)
	return &""

func validate(run_map: RefCounted) -> PackedStringArray:
	var errors := PackedStringArray()
	if run_map.main_path.size() < MIN_MAIN_PATH or run_map.main_path.size() > MAX_MAIN_PATH:
		errors.append("main_path debe tener 6–8 salas")
	if run_map.rooms.size() > MAX_ROOMS:
		errors.append("el mapa supera 12 salas")
	if run_map.main_path.is_empty():
		errors.append("falta main_path")
		return errors
	if run_map.room(run_map.main_path[0])["role"] != &"entry":
		errors.append("la entrada no es el primer hito")
	if run_map.room(run_map.main_path[-2])["role"] != &"preboss":
		errors.append("el preboss no es el penúltimo hito")
	if run_map.room(run_map.main_path[-1])["role"] != &"boss_choice":
		errors.append("el boss no es el último hito")

	var occupied: Dictionary = {}
	for room_id in run_map.room_ids():
		var data: Dictionary = run_map.room(room_id)
		var grid: Vector2i = data["grid"]
		if occupied.has(grid):
			errors.append("coordenada repetida: %s" % grid)
		occupied[grid] = room_id
		var doors: Dictionary = data["doors"]
		var one_way: Dictionary = data["one_way"]
		for direction in doors:
			var target_id: String = doors[direction]
			if not run_map.rooms.has(target_id):
				errors.append("%s apunta a %s inexistente" % [room_id, target_id])
				continue
			var target: Dictionary = run_map.room(target_id)
			if target["grid"] - grid != DELTAS[direction]:
				errors.append("%s.%s no coincide con su coordenada" % [room_id, direction])
			if not bool(one_way.get(direction, false)):
				var opposite: String = RunMap.OPPOSITE[direction]
				if target["doors"].get(opposite, "") != room_id:
					errors.append("%s.%s no tiene retorno" % [room_id, direction])
	return errors
```

Antes de devolver la propuesta, `_add_reconnections()` recorre pares de salas
ya creadas cuya distancia Manhattan sea 1 y que todavía no estén conectadas.
Con un roll de `35%` añade la puerta recíproca usando el mismo RNG. Esto permite
nodos de tres y cuatro direcciones sin añadir coordenadas ni alterar el camino
principal.

- [ ] **Step 4: Verify GREEN**

Run the Task 1 command. Expected: model and generator checks pass.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/core/map_generator.gd prueba_2/tests/run_map_tests.gd
git commit -m "feat: genera y valida la ruta de Contención"
```

---

### Task 3: Contenido, cierres, reconexiones y rejillas

**Files:**
- Modify: `prueba_2/core/map_generator.gd`
- Modify: `prueba_2/tests/run_map_tests.gd`

**Interfaces:**
- Consumes: topología válida de Task 2.
- Produces: `content_type`, `enemy_count`, `closure_keep_direction`, `grate_target` y destinos exclusivos.

- [ ] **Step 1: Add failing distribution and invariant tests**

Añadir una prueba sobre `1_000` seeds que acumule:

```gdscript
var normal_counts := {"easy": 0, "hard": 0, "empty": 0, "closure": 0}
var grate_destinations := {"empty": 0, "combat": 0, "loot": 0}
var eligible_combats := 0
var grates := 0

for seed_value in range(1000):
	var generated: RefCounted = generator.generate(seed_value)
	_check(generated != null, "seed %d genera" % seed_value)
	_check(generator.validate(generated).is_empty(), "seed %d valida" % seed_value)
	var seen_grate_targets: Dictionary = {}
	for room_id in generated.room_ids():
		var data: Dictionary = generated.room(room_id)
		var role: StringName = data["role"]
		var content: String = String(data["content_type"])
		if role == &"normal":
			normal_counts[content] += 1
		if content == "easy" or content == "hard":
			eligible_combats += 1
		var grate_target: String = data["grate_target"]
		if grate_target != "":
			grates += 1
			_check(not seen_grate_targets.has(grate_target), "destino único")
			seen_grate_targets[grate_target] = true
			var target_content: String = generated.room(grate_target)["content_type"]
			grate_destinations[target_content] += 1
	_check(generated.rooms.size() <= 12, "seed %d mantiene máximo" % seed_value)

_check(_near_ratio(normal_counts["easy"], normal_counts, 0.40), "fácil cerca de 40%")
_check(_near_ratio(normal_counts["hard"], normal_counts, 0.30), "difícil cerca de 30%")
_check(_near_ratio(normal_counts["empty"], normal_counts, 0.20), "vacía cerca de 20%")
_check(_near_ratio(normal_counts["closure"], normal_counts, 0.10), "cierre cerca de 10%")
_check(absf(float(grates) / float(eligible_combats) - 0.60) <= 0.05, "rejilla cerca de 60%")
_check(_near_ratio(grate_destinations["empty"], grate_destinations, 0.40), "destino vacío 40%")
_check(_near_ratio(grate_destinations["combat"], grate_destinations, 0.20), "destino combate 20%")
_check(_near_ratio(grate_destinations["loot"], grate_destinations, 0.40), "destino loot 40%")
```

`_near_ratio()` suma el diccionario y acepta ±`0.05`.

- [ ] **Step 2: Run and verify RED**

Expected: content remains `unassigned`; distribution assertions fail.

- [ ] **Step 3: Implement weighted choices and grate promotion**

Añadir:

```gdscript
const NORMAL_CONTENT: Array = [
	[&"easy", 40],
	[&"hard", 30],
	[&"empty", 20],
	[&"closure", 10],
]
const GRATE_CONTENT: Array = [
	[&"empty", 40],
	[&"combat", 20],
	[&"loot", 40],
]

func _weighted_choice(rng: RandomNumberGenerator, table: Array) -> StringName:
	var roll: int = rng.randi_range(1, 100)
	var cursor := 0
	for item in table:
		cursor += int(item[1])
		if roll <= cursor:
			return item[0]
	return table[-1][0]
```

Después de crear el camino:

1. entrada recibe `tutorial`, preboss `preboss` y final `boss_choice`;
2. cada rol normal usa `NORMAL_CONTENT`;
3. `easy` fija `enemy_count = 1`, `hard` un entero `2–3`;
4. si sale `closure`, la sala debe ser interna al camino y conservar la puerta
   que apunta al siguiente ID de `main_path`;
5. si todavía tiene solo dos puertas, se añade una sala `B_%02d` en una
   coordenada cardinal libre y se conecta como tercera salida;
6. la rama `B_%02d` recibe combate y debe reconectar con una sala adyacente o
   terminar en una rejilla; si no caben la rama y su destino dentro de 12, esa
   propuesta se rechaza para que avance `generation_attempt`;
7. `closure_keep_direction` guarda la dirección hacia el siguiente hito y el
   evento cerrará las otras dos puertas;
8. cada combate normal hace roll `< 0.60`;
9. si ninguno gana, se promueve el combate cuyo ID resulte primero tras
   barajar con el mismo RNG;
10. se limita el número de destinos por `12 - rooms.size()`;
11. cada destino usa `GRATE_CONTENT`, ID `G_%02d` y coordenada libre;
12. se añade al origen con `set_grate()`;
13. el validador comprueba fuente de combate, máximo uno y destinos únicos;
14. cada cierre debe tener exactamente tres puertas y su puerta conservada debe
    mantener alcanzable `boss_room_id`.

- [ ] **Step 4: Run the 1,000-seed test**

Expected: `PASS: run map model`, exit `0`, sin errores de validación.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/core/map_generator.gd prueba_2/tests/run_map_tests.gd
git commit -m "feat: distribuye combates eventos y rejillas"
```

---

### Task 4: Catálogo de plantillas de `RoomDB`

**Files:**
- Modify: `prueba_2/autoload/room_db.gd`
- Modify: `prueba_2/tests/combat_smoke.gd`

**Interfaces:**
- Consumes: conjunto de puertas de cada descriptor.
- Produces: `template_for(directions: Array[String]) -> Dictionary` y catálogo `TEMPLATES`.

- [ ] **Step 1: Add failing catalog tests**

Añadir a `combat_smoke.gd`:

```gdscript
func _test_room_templates() -> void:
	for doors in [
		["E"], ["N"], ["O"], ["S"],
		["N", "S"], ["E", "O"], ["O", "N"], ["S", "E"],
		["E", "S", "O"], ["N", "E", "O"], ["N", "E", "S"], ["N", "S", "O"],
		["O", "N", "E", "S"],
	]:
		var template: Dictionary = RoomDB.template_for(doors)
		_check(not template.is_empty(), "hay plantilla para %s" % [doors])
		_check(ResourceLoader.exists(template["background"]), "fondo de plantilla existe")
```

Llamarla desde `_run()`.

- [ ] **Step 2: Verify RED**

Expected: `Invalid call. Nonexistent function 'template_for'`.

- [ ] **Step 3: Add templates without removing legacy rooms**

Añadir el catálogo exacto:

```gdscript
const TEMPLATES := {
	"E": {"background": "res://assets/environment/rooms/room_1door_E.png"},
	"N": {"background": "res://assets/environment/rooms/room_1door_N.png"},
	"O": {"background": "res://assets/environment/rooms/room_1door_O.png"},
	"S": {"background": "res://assets/environment/rooms/room_1door_S.png"},
	"NS": {"background": "res://assets/environment/rooms/room_2door_NS.png"},
	"EO": {"background": "res://assets/environment/rooms/room_2door_OE.png"},
	"NO": {"background": "res://assets/environment/rooms/room_2door_ON.png"},
	"ES": {"background": "res://assets/environment/rooms/room_2door_SE.png"},
	"ESO": {"background": "res://assets/environment/rooms/room_3door_ESO.png"},
	"NEO": {"background": "res://assets/environment/rooms/room_3door_NEO.png"},
	"NES": {"background": "res://assets/environment/rooms/room_3door_NES.png"},
	"NSO": {"background": "res://assets/environment/rooms/room_3door_NSO.png"},
	"NESO": {"background": "res://assets/environment/rooms/room_4door_ONES.png"},
}
```

Y el selector:

```gdscript
func template_for(directions: Array[String]) -> Dictionary:
	var key_parts := directions.duplicate()
	key_parts.sort_custom(func(a: String, b: String) -> bool:
		return "NESO".find(a) < "NESO".find(b)
	)
	return TEMPLATES.get("".join(key_parts), {})
```

Mantener temporalmente `ROOMS` para que el MVP fijo siga pasando mientras se
integra el generador.

- [ ] **Step 4: Verify GREEN and legacy regression**

Run `combat_smoke.tscn`. Expected: all existing checks plus template checks,
zero failures.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/autoload/room_db.gd prueba_2/tests/combat_smoke.gd
git commit -m "feat: cataloga plantillas por conexiones de sala"
```

---

### Task 5: `RunManager`, seed y vida 5/15

**Files:**
- Create: `prueba_2/autoload/run_manager.gd`
- Modify: `prueba_2/project.godot`
- Modify: `prueba_2/autoload/game_state.gd`
- Modify: `prueba_2/autoload/inventory.gd`
- Create: `prueba_2/tests/run_lifecycle_tests.gd`
- Create: `prueba_2/tests/run_lifecycle_tests.tscn`
- Modify: `prueba_2/tests/combat_smoke.gd`

**Interfaces:**
- Consumes: `MapGenerator`, `GameState`, `Inventory`.
- Produces: `start_new_run(seed_value: int = -1)`, `complete_floor(floor_id)`, `end_run(reason)`, `current_map`, `current_seed`, `summary()`.

- [ ] **Step 1: Add failing lifecycle scene**

La escena instancia el test y el script comprueba:

```gdscript
RunManager.start_new_run(777)
_check(RunManager.current_seed == 777, "conserva seed explícita")
_check(RunManager.current_map != null, "crea mapa")
_check(GameState.max_health_halves == 15, "máximo son 15 HP")
_check(GameState.health_halves == 5, "inicia con 5 HP")
_check(Inventory.equipped_ids().is_empty(), "inicia sin partes")

GameState.damage_halves(2)
_check(RunManager.complete_floor(&"contencion"), "completa una vez")
_check(GameState.health_halves == 5, "el piso cura 2 HP")
_check(not RunManager.complete_floor(&"contencion"), "no repite recompensa")
```

- [ ] **Step 2: Verify RED**

Expected: `RunManager` autoload does not exist.

- [ ] **Step 3: Implement run ownership**

Registrar:

```ini
RunManager="*res://autoload/run_manager.gd"
```

Implementar señales y estado:

```gdscript
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

func start_new_run(seed_value: int = -1) -> void:
	GameState.reset_run()
	Inventory.reset_run()
	current_seed = seed_value if seed_value >= 0 else int(Time.get_unix_time_from_system())
	current_map = MapGenerator.new().generate(current_seed)
	assert(current_map != null, "No se pudo generar Contención")
	completed_floors.clear()
	parts_consumed.clear()
	parts_sacrificed.clear()
	active = true
	run_started.emit(current_seed)
	map_generated.emit(current_map)

func complete_floor(floor_id: StringName) -> bool:
	if completed_floors.has(floor_id):
		return false
	completed_floors[floor_id] = true
	var before: int = GameState.health_halves
	GameState.heal_halves(2)
	floor_completed.emit(floor_id, GameState.health_halves - before)
	return true
```

En `GameState`, fijar `_base_max_halves = 15`, `max_health_halves = 15` y
`health_halves = 5`; `reset_run()` vuelve a 15/5. Las señales y métodos legacy
de checkpoint permanecen declarados pero no se invocan durante Tasks 5–7, para
que el cambio de transición sea atómico en Task 8.

- [ ] **Step 4: Verify lifecycle and update legacy assertions**

Run lifecycle test and `combat_smoke.tscn`. Expected: both exit `0`; old
assertions de 10 medios/checkpoint se sustituyen por 5/15 y hito sin respawn.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/project.godot prueba_2/autoload/run_manager.gd prueba_2/autoload/game_state.gd prueba_2/autoload/inventory.gd prueba_2/tests/run_lifecycle_tests.gd prueba_2/tests/run_lifecycle_tests.tscn prueba_2/tests/combat_smoke.gd
git commit -m "feat: inicia partidas con seed y vida 5 de 15"
```

---

### Task 6: Comer, perder y sacrificar partes

**Files:**
- Modify: `prueba_2/autoload/inventory.gd`
- Modify: `prueba_2/autoload/run_manager.gd`
- Modify: `prueba_2/tests/run_lifecycle_tests.gd`

**Interfaces:**
- Produces: `lose_slot(index)`, `sacrifice_slot(index)`,
  `pay_grate_cost(slot_index, confirm_lethal) -> StringName`.

- [ ] **Step 1: Add failing cost tests**

```gdscript
Inventory.pick_up("serrated_jaw")
GameState.health_halves = 3
_check(Inventory.consume_slot(0), "come parte equipada")
_check(GameState.health_halves == 4, "comer cura 1 HP")
_check(Inventory.is_empty(0), "comer libera slot")

Inventory.pick_up("serrated_jaw")
_check(Inventory.lose_slot(0) == "serrated_jaw", "perder devuelve id")
_check(GameState.health_halves == 4, "perder no cura")

Inventory.pick_up("serrated_jaw")
_check(RunManager.pay_grate_cost(0, false) == &"part", "rejilla sacrifica parte")
_check(Inventory.is_empty(0), "sacrificio libera slot")

GameState.health_halves = 2
_check(RunManager.pay_grate_cost(-1, false) == &"hp", "sin partes cuesta HP")
_check(GameState.health_halves == 1, "cobra exactamente 1 HP")
_check(RunManager.pay_grate_cost(-1, false) == &"confirmation_required", "1 HP pide confirmar")
_check(RunManager.pay_grate_cost(-1, true) == &"death", "confirmar permite morir")
```

- [ ] **Step 2: Verify RED**

Expected: missing methods.

- [ ] **Step 3: Implement removals and grate payment**

`Inventory.lose_slot()` y `sacrifice_slot()` llaman `clear_slot()`; solo
`consume_slot()` llama `_digest()`. `RunManager.pay_grate_cost()` prioriza un
slot equipado válido, registra `parts_sacrificed`, y si no hay parte cobra
`GameState.damage_halves(1)`. Con un HP devuelve confirmación sin mutar salvo que
`confirm_lethal` sea `true`.

- [ ] **Step 4: Verify GREEN**

Run lifecycle test and combat smoke. Expected: zero failures.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/autoload/inventory.gd prueba_2/autoload/run_manager.gd prueba_2/tests/run_lifecycle_tests.gd
git commit -m "feat: libera slots al comer perder o sacrificar"
```

---

### Task 7: Ensamblador de salas procedurales

**Files:**
- Create: `prueba_2/world/rooms/procedural_room.tscn`
- Create: `prueba_2/world/rooms/procedural_room.gd`
- Create: `prueba_2/world/rooms/room_assembler.gd`
- Modify: `prueba_2/tests/combat_smoke.gd`

**Interfaces:**
- Consumes: descriptor de `RunMap` y plantilla de `RoomDB`.
- Produces: `RoomAssembler.build(room_data: Dictionary) -> Node2D`.

- [ ] **Step 1: Add failing assembly tests**

Para fixtures de puertas `E`, `NS`, `NES` y `ONES`:

```gdscript
var assembled: Node2D = RoomAssembler.build(fixture)
add_child(assembled)
_check(assembled.get_meta("room_id") == fixture["id"], "conserva id")
for direction in fixture["doors"]:
	_check(assembled.has_node("Door%s" % direction), "crea puerta %s" % direction)
_check(assembled.get_node("Background").texture != null, "carga fondo compatible")
assembled.queue_free()
```

- [ ] **Step 2: Verify RED**

Expected: assembler file missing.

- [ ] **Step 3: Implement generic scene assembly**

`procedural_room.tscn` conserva las medidas, colisiones, luz y grupos del
controlador de sala actual. `room_assembler.gd`:

```gdscript
extends RefCounted

const RoomScene := preload("res://world/rooms/procedural_room.tscn")

static func build(room_data: Dictionary) -> Node2D:
	var room: Node2D = RoomScene.instantiate()
	room.configure(room_data)
	return room
```

`configure()` selecciona fondo por `RoomDB.template_for(doors.keys())`, crea
solo `DoorN/E/S/O` declaradas, asigna targets, genera lámparas sin bloquear el
carril central y entrega `enemy_count/content_type` al flujo de spawn.

- [ ] **Step 4: Verify GREEN**

Run combat smoke. Expected: fixtures cargan, puertas y fondos coinciden.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/world/rooms/procedural_room.tscn prueba_2/world/rooms/procedural_room.gd prueba_2/world/rooms/room_assembler.gd prueba_2/tests/combat_smoke.gd
git commit -m "feat: ensambla salas desde descriptores procedurales"
```

---

### Task 8: Transición sobre la instancia `RunMap`

**Files:**
- Modify: `prueba_2/autoload/transition.gd`
- Modify: `prueba_2/game/main.gd`
- Modify: `prueba_2/game/main.tscn`
- Modify: `prueba_2/autoload/room_db.gd`
- Modify: `prueba_2/autoload/game_state.gd`
- Delete: `prueba_2/ui/checkpoint_notice.gd`
- Delete: `prueba_2/ui/checkpoint_notice.tscn`
- Modify: `prueba_2/tests/run_lifecycle_tests.gd`

**Interfaces:**
- Consumes: `RunManager.current_map`, `RoomAssembler`.
- Produces: carga inicial y `go_to()` por ID procedural; elimina respawn de muerte.

- [ ] **Step 1: Add failing transition tests**

```gdscript
RunManager.start_new_run(777)
Transition.setup(room_host, player, fade)
Transition.load_initial(RunManager.current_map.entry_room_id)
_check(GameState.current_room == RunManager.current_map.entry_room_id, "carga entrada procedural")
var first_data: Dictionary = RunManager.current_map.room(GameState.current_room)
var first_target: String = first_data["doors"].values()[0]
await Transition.go_to(first_target, first_data["doors"].find_key(first_target))
_check(GameState.current_room == first_target, "cruza a descriptor generado")
```

Añadir una prueba que emita `GameState.died` y confirme que nunca se llama
`Transition.respawn()`.

- [ ] **Step 2: Verify RED**

Expected: `Transition._swap_room()` busca IDs solo en `RoomDB.ROOMS`.

- [ ] **Step 3: Switch room resolution**

`Transition._swap_room()` obtiene el descriptor con
`RunManager.current_map.room(room_id)` y llama `RoomAssembler.build()`. Mantiene
el orden crítico existente: posicionar jugador en `Spawn<opuesto>` antes de
añadir la sala al árbol. `main.gd` llama `RunManager.start_new_run()` y carga
`entry_room_id`.

`Main._on_died()` cambia a:

```gdscript
func _on_died() -> void:
	RunManager.end_run(&"death")
```

Se elimina la llamada a `GameState.reset_health()` y `Transition.respawn()`.
Se eliminan `checkpoint_reached`, sus campos y métodos de `GameState`, además
del nodo/escena `CheckpointNotice`. `RoomDB.ROOMS` queda marcado como legado y
deja de ser consultado por partida.

- [ ] **Step 4: Verify GREEN and no transition regressions**

Run lifecycle, combat smoke and a three-second main scene smoke. Expected:
procedural entry loads, transition completes, no debugger break.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/autoload/transition.gd prueba_2/game/main.gd prueba_2/game/main.tscn prueba_2/autoload/room_db.gd prueba_2/autoload/game_state.gd prueba_2/ui/checkpoint_notice.gd prueba_2/ui/checkpoint_notice.tscn prueba_2/tests/run_lifecycle_tests.gd
git commit -m "feat: recorre la instancia procedural de Contención"
```

---

### Task 9: Resumen de muerte y cierre de Contención

**Files:**
- Create: `prueba_2/ui/run_summary.gd`
- Create: `prueba_2/ui/run_summary.tscn`
- Modify: `prueba_2/game/main.tscn`
- Modify: `prueba_2/autoload/run_manager.gd`
- Modify: `prueba_2/ui/pause_menu.gd`
- Modify: `prueba_2/tests/run_lifecycle_tests.gd`

**Interfaces:**
- Consumes: `RunManager.run_ended(summary)`.
- Produces: resumen de zona, salas, consumidas, sacrificadas y seed; nueva partida o título.

- [ ] **Step 1: Add failing summary assertions**

```gdscript
RunManager.start_new_run(777)
GameState.visited["C_00"] = true
RunManager.parts_consumed.append("serrated_jaw")
RunManager.parts_sacrificed.append("scaled_skin")
var summary: Dictionary = RunManager.end_run(&"death")
_check(summary["zone"] == "CONTENCIÓN", "resume zona")
_check(summary["rooms_visited"] == 1, "cuenta salas")
_check(summary["consumed"] == ["serrated_jaw"], "lista comidas")
_check(summary["sacrificed"] == ["scaled_skin"], "lista sacrificadas")
_check(summary["seed"] == 777, "muestra seed")
```

- [ ] **Step 2: Verify RED**

Expected: `end_run()` does not return the required summary.

- [ ] **Step 3: Implement summary UI**

`RunManager.end_run()` desactiva la partida, duplica arrays y emite el mismo
diccionario que devuelve. `run_summary.gd` escucha la señal, pausa, muestra los
cinco campos y ofrece:

```gdscript
func _new_run() -> void:
	get_tree().paused = false
	RunManager.start_new_run()
	get_tree().reload_current_scene()

func _to_title() -> void:
	get_tree().paused = false
	GameState.reset_run()
	Inventory.reset_run()
	get_tree().change_scene_to_file("res://ui/title.tscn")
```

Pausa `REINICIAR` también llama `RunManager.start_new_run()` antes de recargar.

- [ ] **Step 4: Verify GREEN**

Run lifecycle test; launch main, emit death in test fixture, verify summary
visible and buttons reset all state.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/ui/run_summary.gd prueba_2/ui/run_summary.tscn prueba_2/game/main.tscn prueba_2/autoload/run_manager.gd prueba_2/ui/pause_menu.gd prueba_2/tests/run_lifecycle_tests.gd
git commit -m "feat: termina la partida con un resumen reproducible"
```

---

### Task 10: Documentación y regresión integral

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/CONVENCIONES.md`
- Modify: `docs/DIRECCION.md`
- Modify: `docs/agents/REFERENCIA.md`

**Interfaces:**
- Consumes: comportamiento verificado de Tasks 1–9.
- Produces: contrato operativo actualizado para el equipo.

- [ ] **Step 1: Update superseded documentation**

Documentar:

- `RunManager`/`RunMap`/`MapGenerator`;
- vida 5/15 HP;
- hito +2 HP sin respawn;
- muerte termina la partida;
- slots liberados;
- rejillas sin `squeeze`;
- seed y comando del test de 1.000 generaciones.

Eliminar reglas que ordenen reaparecer en checkpoints.

- [ ] **Step 2: Run full verification**

```powershell
godot --headless --path prueba_2 --import
godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
godot --headless --path prueba_2 res://tests/run_lifecycle_tests.tscn
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
godot --headless --path prueba_2 --script res://tests/run_slime_audio_tests.gd
godot --headless --path prueba_2 res://tests/check_enemy_animations.tscn
godot --headless --path prueba_2 --quit-after 3
godot --headless --path prototypes/slime_charge_movement --script res://tests/run_tests.gd
git diff --check
```

Expected: todas las suites salen `0`, cero debugger breaks y ningún warning
nuevo.

- [ ] **Step 3: Manual gameplay verification**

Con seed visible:

1. recorrer la ruta principal;
2. comprobar al menos una rejilla;
3. comer, perder y sacrificar partes;
4. confirmar muerte voluntaria con 1 HP;
5. completar Contención y ver +2 HP;
6. morir y comprobar que no hay respawn.

- [ ] **Step 4: Commit documentation**

```powershell
git add AGENTS.md docs/ARQUITECTURA.md docs/CONVENCIONES.md docs/DIRECCION.md docs/agents/REFERENCIA.md
git commit -m "docs: explica la partida procedural de Contención"
```
