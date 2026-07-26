# Cuerpo, rastro, mapa e iluminación Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir la segunda sala de Contención en el hallazgo determinista del cuerpo, guiar hasta ella con sangre, sincronizar puertas y mapas con `RunMap`, y ampliar la cobertura de luz sin aumentar su energía.

**Architecture:** `RunMap` conserva la descripción determinista y `MapGenerator` fija los dos primeros hitos. `ProceduralRoom` materializa puertas, cuerpo y rastro consultando ese descriptor; `GameState` solo persiste la recompensa reclamada durante la partida. Los dos mapas calculan su layout desde salas visitadas.

**Tech Stack:** Godot 4.7.1, GDScript tipado, escenas `.tscn`, assets PNG transparentes, pruebas headless sin addons.

## Global Constraints

- Alcance exclusivo: `NIVEL -3 · CONTENCIÓN`.
- La primera sala es `entry/tutorial`; la segunda es `body/body_reward`.
- Pool inicial exacto: `acid_stinger`, `serrated_jaw`, `hydraulic_legs`, `bio_netcaster`.
- La misma `(run_seed, generation_attempt)` produce el mismo mapa y recompensa.
- Seed de regresión obligatoria: `1785033756`.
- El mapa de `TAB` y el minimapa muestran únicamente salas visitadas.
- `PointLight2D.energy` permanece en `1.6`; `texture_scale` pasa a `1.35`.
- El cuerpo y la sangre no tienen colisión ni mecánicas adicionales.

---

### Task 1: Hito determinista del cuerpo

**Files:**
- Modify: `prueba_2/core/run_map.gd:19-36`
- Modify: `prueba_2/core/map_generator.gd:6-29,40-180,232-268`
- Modify: `prueba_2/tests/run_map_tests.gd:14-137`

**Interfaces:**
- Produces: cada descriptor incluye `reward_part_id: String`.
- Produces: `MapGenerator.FIRST_PART_POOL: Array[String]`.
- Produces: `main_path[1]` con `role == &"body"` y `content_type == &"body_reward"`.

- [ ] **Step 1: Escribir las aserciones fallidas del segundo hito**

Añadir en `run_map_tests.gd`, después de validar la entrada:

```gdscript
const FIRST_PART_POOL: Array[String] = [
	"acid_stinger",
	"serrated_jaw",
	"hydraulic_legs",
	"bio_netcaster",
]

var body_data: Dictionary = first.room(first.main_path[1])
_check(body_data["role"] == &"body", "el cuerpo es el segundo hito")
_check(body_data["content_type"] == &"body_reward", "el cuerpo tiene recompensa")
_check(FIRST_PART_POOL.has(body_data["reward_part_id"]), "la primera parte pertenece al pool")
_check(
	body_data["reward_part_id"] == second.room(second.main_path[1])["reward_part_id"],
	"la misma seed conserva la primera parte"
)
```

Dentro del ciclo de 1.000 seeds:

```gdscript
var generated_body: Dictionary = generated.room(generated.main_path[1])
_check(generated_body["role"] == &"body", "seed %d fija el cuerpo segundo" % seed_value)
_check(
	FIRST_PART_POOL.has(String(generated_body["reward_part_id"])),
	"seed %d elige recompensa válida" % seed_value
)
```

- [ ] **Step 2: Ejecutar y confirmar el fallo**

Run:

```powershell
godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
```

Expected: FAIL porque `main_path[1]` todavía es `normal` y no existe `reward_part_id`.

- [ ] **Step 3: Extender el descriptor y poblar el cuerpo**

En `RunMap.add_room()` añadir:

```gdscript
"reward_part_id": "",
```

En `map_generator.gd` añadir:

```gdscript
const FIRST_PART_POOL: Array[String] = [
	"acid_stinger",
	"serrated_jaw",
	"hydraulic_legs",
	"bio_netcaster",
]
```

Asignar el rol al crear el camino:

```gdscript
if index == 0:
	role = &"entry"
elif index == 1:
	role = &"body"
elif index == target_length - 2:
	role = &"preboss"
```

En `_populate_content()`:

```gdscript
var body_data: Dictionary = run_map.room(run_map.main_path[1])
body_data["content_type"] = &"body_reward"
body_data["reward_part_id"] = FIRST_PART_POOL[
	rng.randi_range(0, FIRST_PART_POOL.size() - 1)
]

for path_index in range(2, run_map.main_path.size() - 2):
```

En `validate()` comprobar rol, contenido, pool, conexión directa y ausencia de rejilla:

```gdscript
var body_id: String = run_map.main_path[1]
var body_data: Dictionary = run_map.room(body_id)
if body_data["role"] != &"body" or body_data["content_type"] != &"body_reward":
	errors.append("el cuerpo no ocupa el segundo hito")
if not FIRST_PART_POOL.has(String(body_data["reward_part_id"])):
	errors.append("el cuerpo tiene recompensa inválida")
if not run_map.room(run_map.main_path[0])["doors"].values().has(body_id):
	errors.append("el tutorial no conecta directamente con el cuerpo")
if not String(body_data["grate_target"]).is_empty():
	errors.append("el cuerpo no puede originar una rejilla")
if body_data["doors"].size() != 2:
	errors.append("el cuerpo solo conecta los hitos anterior y siguiente")
```

- En `_add_reconnections()`, omitir una pareja cuando el rol de cualquiera de
  sus extremos sea `&"body"`.
- En `_adjacent_candidates()`, omitir candidatos con rol `&"body"` para que una
  rama de cierre tampoco reconecte con esa sala.

- [ ] **Step 4: Ejecutar la prueba del generador**

Run:

```powershell
godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
```

Expected: `PASS: run map model`.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/core/run_map.gd prueba_2/core/map_generator.gd prueba_2/tests/run_map_tests.gd
git commit -m "feat: fija el cuerpo como segundo hito"
```

---

### Task 2: Contrato de puertas y descubrimiento

**Files:**
- Modify: `prueba_2/tests/run_map_tests.gd`
- Modify: `prueba_2/ui/map_overlay.gd:59-130,157-176,223-250`
- Modify: `prueba_2/tests/map_overlay_tests.gd:27-55`
- Modify: `prueba_2/ui/hud.gd:59-119`
- Modify: `prueba_2/tests/hud_tests.gd:11-35`

**Interfaces:**
- Consumes: `RunMap.rooms[room_id]["doors"]`.
- Produces: `MapOverlay.build_layout(run_map, panel_rect, room_ids) -> Dictionary`.
- Produces: `MapOverlay.visible_room_ids() -> Array[String]` con visitadas únicamente.
- Produces: `HUD.visible_room_ids() -> Array[String]` con el mismo contrato.

- [ ] **Step 1: Añadir regresión de ensamblado para `1785033756`**

En `run_map_tests.gd` precargar:

```gdscript
const RoomAssembler := preload("res://world/rooms/room_assembler.gd")
```

Antes de `_finish()`:

```gdscript
var regression_map: RefCounted = generator.generate(1785033756)
_check(regression_map != null, "la seed de regresión genera")
for room_id: String in regression_map.room_ids():
	var data: Dictionary = regression_map.room(room_id)
	var room: Node2D = RoomAssembler.build(data)
	for direction: String in ["N", "E", "S", "O"]:
		var expected: bool = data["doors"].has(direction)
		_check(
			room.has_node("Door%s" % direction) == expected,
			"%s materializa Door%s" % [room_id, direction]
		)
		_check(
			room.has_node("Spawn%s" % direction) == expected,
			"%s materializa Spawn%s" % [room_id, direction]
		)
	room.free()
```

En `map_overlay_tests.gd`, cambiar la expectativa de vecinas:

```gdscript
var all_ids: Array[String] = cross.room_ids()
var layout: Dictionary = overlay.build_layout(cross, panel, all_ids)

_check(visible_ids == ["CENTER"], "solo muestra la sala visitada")
var visible_layout: Dictionary = overlay.build_layout(cross, panel, visible_ids)
_check(visible_layout["rooms"].size() == 1, "el layout no reserva salas ocultas")
GameState.visited["N"] = true
visible_ids = overlay.visible_room_ids()
_check(visible_ids == ["CENTER", "N"], "entrar descubre la segunda sala")
```

En `hud_tests.gd` construir un `RunMap` con una sala lejana oculta y comprobar:

```gdscript
const RunMap := preload("res://core/run_map.gd")

var map := RunMap.new(77, 0)
map.add_room("CENTER", Vector2i.ZERO, &"entry", &"tutorial")
map.add_room("HIDDEN", Vector2i(8, 8), &"normal", &"empty")
RunManager.current_map = map
GameState.current_room = "CENTER"
GameState.visited["CENTER"] = true
_check(hud.has_method("visible_room_ids"), "el minimapa expone salas visitadas")
_check(hud.visible_room_ids() == ["CENTER"], "el minimapa oculta topología futura")
```

- [ ] **Step 2: Ejecutar las tres pruebas y observar el fallo de descubrimiento**

```powershell
godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
godot --headless --path prueba_2 res://tests/map_overlay_tests.tscn
godot --headless --path prueba_2 res://tests/hud_tests.tscn
```

Expected: puertas PASS; mapa y minimapa FAIL porque todavía incluyen vecinas o calculan límites con todas las salas.

- [ ] **Step 3: Filtrar el overlay por visitadas**

Cambiar la firma:

```gdscript
func build_layout(
	run_map: RefCounted,
	panel_rect: Rect2,
	room_ids: Array[String]
) -> Dictionary:
	var all_rooms: Dictionary = run_map.get("rooms")
	var room_data: Dictionary = {}
	for room_id: String in room_ids:
		if all_rooms.has(room_id):
			room_data[room_id] = all_rooms[room_id]
```

Simplificar `visible_room_ids()`:

```gdscript
func visible_room_ids() -> Array[String]:
	var result: Array[String] = []
	if RunManager.current_map == null:
		return result
	for room_id: String in GameState.visited:
		if GameState.visited[room_id] and RunManager.current_map.rooms.has(room_id):
			result.append(room_id)
	result.sort()
	return result
```

En `_draw()` obtener primero `visible_ids` y pasarlos a `build_layout()`. En `_draw_room()`, dibujar una muesca solo si el destino también está visible:

```gdscript
for direction: String in data["doors"]:
	var target_id: String = data["doors"][direction]
	if visible_ids.has(target_id):
		_draw_door_notch(rect, direction, border)
```

Añadir `visible_ids` como parámetro de `_draw_room()`.

- [ ] **Step 4: Aplicar el mismo subconjunto al minimapa**

En `hud.gd`:

```gdscript
func visible_room_ids() -> Array[String]:
	var result: Array[String] = []
	for room_id: String in GameState.visited:
		if GameState.visited[room_id] and _active_rooms().has(room_id):
			result.append(room_id)
	result.sort()
	return result
```

En `_draw_minimap()`, calcular límites y dibujar iterando `visible_room_ids()` en lugar de `rooms`. Si el arreglo está vacío, retornar sin dividir entre cero.

- [ ] **Step 5: Ejecutar pruebas y commit**

```powershell
godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
godot --headless --path prueba_2 res://tests/map_overlay_tests.tscn
godot --headless --path prueba_2 res://tests/hud_tests.tscn
git add prueba_2/tests/run_map_tests.gd prueba_2/ui/map_overlay.gd prueba_2/tests/map_overlay_tests.gd prueba_2/ui/hud.gd prueba_2/tests/hud_tests.gd
git commit -m "fix: oculta la topologia no visitada"
```

Expected: las tres suites terminan en PASS.

---

### Task 3: Recompensa del cuerpo de una sola toma

**Files:**
- Modify: `prueba_2/autoload/game_state.gd:23-75,139-152`
- Modify: `prueba_2/world/props/part_pickup.gd`
- Create: `prueba_2/world/props/body_source.gd`
- Create: `prueba_2/world/props/body_source.tscn`
- Create: `prueba_2/tests/room_story_tests.gd`
- Create: `prueba_2/tests/room_story_tests.tscn`

**Interfaces:**
- Produces: `GameState.claim_room_reward(room_id: String) -> void`.
- Produces: `GameState.is_room_reward_claimed(room_id: String) -> bool`.
- Produces: `PartPickup.collected(part_id: String)`.
- Produces: `BodySource.configure(room_id: String, reward_part_id: String) -> void`.

- [ ] **Step 1: Crear la prueba fallida del estado y el prop**

`room_story_tests.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/room_story_tests.gd" id="1"]

[node name="RoomStoryTests" type="Node"]
script = ExtResource("1")
```

En `room_story_tests.gd`, instanciar `body_source.tscn`, configurarlo y verificar:

```gdscript
GameState.reset_run()
var scene: PackedScene = load("res://world/props/body_source.tscn")
var body: Node2D = scene.instantiate()
body.configure("C_01", "serrated_jaw")
add_child(body)
await get_tree().process_frame
var pickup := body.get_node_or_null("PartPickup")
_check(pickup != null and pickup.part_id == "serrated_jaw", "el cuerpo aloja la recompensa")
pickup.collected.emit("serrated_jaw")
_check(GameState.is_room_reward_claimed("C_01"), "recoger marca la sala")
body.queue_free()
await get_tree().process_frame

var revisited: Node2D = scene.instantiate()
revisited.configure("C_01", "serrated_jaw")
add_child(revisited)
await get_tree().process_frame
_check(revisited.get_node_or_null("PartPickup") == null, "volver no duplica la parte")
GameState.reset_run()
_check(not GameState.is_room_reward_claimed("C_01"), "otra partida libera la recompensa")
```

- [ ] **Step 2: Ejecutar y confirmar que faltan las interfaces**

```powershell
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
```

Expected: FAIL al cargar `body_source.tscn` o llamar los métodos nuevos.

- [ ] **Step 3: Implementar estado y señal de recogida**

En `game_state.gd`:

```gdscript
var claimed_room_rewards: Dictionary = {}

func claim_room_reward(room_id: String) -> void:
	if not room_id.is_empty():
		claimed_room_rewards[room_id] = true

func is_room_reward_claimed(room_id: String) -> bool:
	return claimed_room_rewards.get(room_id, false)
```

Limpiar `claimed_room_rewards` en `reset_run()`.

En `part_pickup.gd` añadir:

```gdscript
signal collected(part_id: String)

func _collect() -> void:
	Inventory.pick_up(part_id)
	collected.emit(part_id)
	queue_free()
```

Reemplazar las dos secuencias `Inventory.pick_up(part_id); queue_free()` por `_collect()`.

- [ ] **Step 4: Implementar `BodySource`**

`body_source.gd`:

```gdscript
extends Node2D

const PartPickupScene := preload("res://world/props/part_pickup.tscn")

var _room_id := ""
var _reward_part_id := ""

func configure(room_id: String, reward_part_id: String) -> void:
	_room_id = room_id
	_reward_part_id = reward_part_id

func _ready() -> void:
	if _room_id.is_empty() or _reward_part_id.is_empty():
		return
	if GameState.is_room_reward_claimed(_room_id):
		return
	var pickup: Area2D = PartPickupScene.instantiate()
	pickup.name = "PartPickup"
	pickup.part_id = _reward_part_id
	pickup.position = Vector2(110.0, 0.0)
	pickup.collected.connect(_on_collected)
	add_child(pickup)

func _on_collected(_part_id: String) -> void:
	GameState.claim_room_reward(_room_id)
```

Crear `body_source.tscn` con raíz `Node2D`, script y un `Sprite2D` llamado `Body`; la textura se conectará en Task 4.

- [ ] **Step 5: Ejecutar prueba y commit**

```powershell
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
git add prueba_2/autoload/game_state.gd prueba_2/world/props/part_pickup.gd prueba_2/world/props/body_source.gd prueba_2/world/props/body_source.tscn prueba_2/tests/room_story_tests.gd prueba_2/tests/room_story_tests.tscn
git commit -m "feat: entrega una sola parte desde el cuerpo"
```

Expected: `0 fallos` y salida PASS.

---

### Task 4: Assets y rastro de sangre

**Files:**
- Create: `prueba_2/assets/environment/body/inert_body.png`
- Create: `prueba_2/assets/environment/blood/blood_drops.png`
- Create: `prueba_2/assets/environment/blood/blood_drag.png`
- Create: `prueba_2/assets/environment/blood/blood_pool.png`
- Create: `prueba_2/world/props/blood_trail.gd`
- Create: `prueba_2/world/props/blood_trail.tscn`
- Modify: `prueba_2/world/props/body_source.tscn`
- Modify: `prueba_2/tests/room_story_tests.gd`

**Interfaces:**
- Produces: cuatro PNG con transparencia real y sin texto.
- Produces: `BloodTrail.configure(start: Vector2, finish: Vector2, include_pool: bool) -> void`.

- [ ] **Step 1: Añadir prueba de carga de recursos**

En `room_story_tests.gd`:

```gdscript
for path: String in [
	"res://assets/environment/body/inert_body.png",
	"res://assets/environment/blood/blood_drops.png",
	"res://assets/environment/blood/blood_drag.png",
	"res://assets/environment/blood/blood_pool.png",
]:
	_check(load(path) is Texture2D, "%s importa como textura" % path)
```

- [ ] **Step 2: Generar los assets originales**

Usar la skill `imagegen` con dos generaciones:

```text
1) Cuerpo humano inerte visto exactamente desde arriba, laboratorio de
contención biológica, uniforme clínico rasgado, silueta legible a 1920x1080,
paleta fría gris verdosa, sangre oscura limitada alrededor, sin texto, sin
perspectiva lateral, elemento aislado para videojuego 2D.

2) Hoja de tres decals vistos exactamente desde arriba: gotas pequeñas de
sangre oscura, mancha alargada de arrastre y charco final, estilo de laboratorio
biológico, bordes irregulares, sin texto, elementos aislados.
```

Generar sobre chroma key uniforme, ejecutar el helper de `imagegen` para retirar
el fondo, recortar cada decal y guardar las cuatro rutas exactas. Verificar cada
PNG con `view_image`.

- [ ] **Step 3: Importar y comprobar recursos**

```powershell
godot --headless --path prueba_2 --import
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
```

Expected: las cuatro texturas cargan.

- [ ] **Step 4: Implementar el distribuidor visual**

`blood_trail.gd`:

```gdscript
extends Node2D

const DROPS := preload("res://assets/environment/blood/blood_drops.png")
const DRAG := preload("res://assets/environment/blood/blood_drag.png")
const POOL := preload("res://assets/environment/blood/blood_pool.png")

func configure(start: Vector2, finish: Vector2, include_pool: bool) -> void:
	position = Vector2.ZERO
	var direction := start.direction_to(finish)
	for index in range(5):
		var sprite := Sprite2D.new()
		sprite.texture = DRAG if index == 2 else DROPS
		sprite.position = start.lerp(finish, float(index + 1) / 6.0)
		sprite.rotation = direction.angle()
		sprite.z_index = -4
		add_child(sprite)
	if include_pool:
		var pool := Sprite2D.new()
		pool.texture = POOL
		pool.position = finish
		pool.z_index = -4
		add_child(pool)
```

Crear `blood_trail.tscn` con raíz `Node2D` y el script. Conectar `inert_body.png`
al `Sprite2D` de `body_source.tscn`.

- [ ] **Step 5: Ejecutar y commit**

```powershell
godot --headless --path prueba_2 --import
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
git add prueba_2/assets/environment/body prueba_2/assets/environment/blood prueba_2/world/props/body_source.tscn prueba_2/world/props/blood_trail.gd prueba_2/world/props/blood_trail.tscn prueba_2/tests/room_story_tests.gd
git commit -m "art: añade cuerpo y rastro de sangre"
```

---

### Task 5: Materialización del relato en las dos primeras salas

**Files:**
- Modify: `prueba_2/world/rooms/procedural_room.gd:1-47`
- Modify: `prueba_2/tests/room_story_tests.gd`

**Interfaces:**
- Consumes: `RunManager.current_map.main_path` y las puertas del descriptor.
- Consumes: `BodySource.configure()` y `BloodTrail.configure()`.
- Produces: nodos `BloodTrail` en tutorial/cuerpo y `BodySource` solo en cuerpo.

- [ ] **Step 1: Escribir pruebas para las cuatro orientaciones**

Crear mapas de dos salas para `N`, `E`, `S`, `O`, asignarlos a
`RunManager.current_map`, construir ambas salas con `RoomAssembler` y comprobar:

```gdscript
_check(entry.get_node_or_null("BloodTrail") != null, "%s guía desde tutorial" % direction)
_check(entry.get_node_or_null("BodySource") == null, "%s no pone cuerpo en tutorial" % direction)
_check(body.get_node_or_null("BloodTrail") != null, "%s continúa sangre" % direction)
_check(body.get_node_or_null("BodySource") != null, "%s pone cuerpo segundo" % direction)
```

Construir una tercera sala `normal/empty` y comprobar que no contiene ninguno.

- [ ] **Step 2: Ejecutar y confirmar el fallo**

```powershell
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
```

Expected: FAIL porque `ProceduralRoom` aún no instancia contenido narrativo.

- [ ] **Step 3: Integrar escenas desde `RunMap`**

En `procedural_room.gd` precargar escenas y añadir:

```gdscript
const BloodTrailScene := preload("res://world/props/blood_trail.tscn")
const BodySourceScene := preload("res://world/props/body_source.tscn")
const BODY_POSITION := Vector2(1060.0, 540.0)
```

Llamar `_build_story_content()` al final de `configure()`. Resolver la dirección
sin IDs fijos:

```gdscript
func _direction_to(target_id: String) -> String:
	for direction: String in _room_data["doors"]:
		if _room_data["doors"][direction] == target_id:
			return direction
	return ""

func _build_story_content() -> void:
	if RunManager.current_map == null:
		return
	var role: StringName = _room_data.get("role", &"normal")
	if role == &"entry":
		var body_id: String = RunManager.current_map.main_path[1]
		var direction := _direction_to(body_id)
		_add_blood(ROOM_CENTER, DOOR_POSITIONS[direction], false)
	elif role == &"body":
		var entry_id: String = RunManager.current_map.main_path[0]
		var direction := _direction_to(entry_id)
		_add_blood(DOOR_POSITIONS[direction], BODY_POSITION, true)
		var source: Node2D = BodySourceScene.instantiate()
		source.name = "BodySource"
		source.position = BODY_POSITION
		source.configure(String(_room_data["id"]), String(_room_data["reward_part_id"]))
		add_child(source)

func _add_blood(start: Vector2, finish: Vector2, include_pool: bool) -> void:
	var trail: Node2D = BloodTrailScene.instantiate()
	trail.name = "BloodTrail"
	trail.configure(start, finish, include_pool)
	add_child(trail)
```

Validar `direction != ""` antes de indexar `DOOR_POSITIONS` y usar
`push_error()` si el descriptor incumple el contrato.

- [ ] **Step 4: Ejecutar pruebas**

```powershell
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
```

Expected: ambas suites PASS.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/world/rooms/procedural_room.gd prueba_2/tests/room_story_tests.gd
git commit -m "feat: guia al cuerpo desde la sala tutorial"
```

---

### Task 6: Radio de iluminación

**Files:**
- Modify: `prueba_2/world/props/lamp.tscn:19-23`
- Modify: `prueba_2/tests/room_story_tests.gd`

**Interfaces:**
- Produces: lámpara con `energy == 1.6` y `texture_scale == 1.35`.

- [ ] **Step 1: Añadir prueba de contrato**

```gdscript
var lamp: Node2D = load("res://world/props/lamp.tscn").instantiate()
add_child(lamp)
var light := lamp.get_node("Light") as PointLight2D
_check(is_equal_approx(light.energy, 1.6), "la energía se conserva")
_check(is_equal_approx(light.texture_scale, 1.35), "el radio aumenta 35 por ciento")
```

- [ ] **Step 2: Ejecutar y observar el fallo**

```powershell
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
```

Expected: FAIL con `texture_scale == 1.0`.

- [ ] **Step 3: Cambiar únicamente el radio**

En `lamp.tscn`:

```ini
energy = 1.6
texture_scale = 1.35
```

- [ ] **Step 4: Ejecutar y commit**

```powershell
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
git add prueba_2/world/props/lamp.tscn prueba_2/tests/room_story_tests.gd
git commit -m "feat: amplia el radio de las lamparas"
```

---

### Task 7: Documentación y verificación ambiental

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`

**Interfaces:**
- Produces: documentación del segundo hito, recompensa, descubrimiento y comando de importación.

- [ ] **Step 1: Documentar contratos concretos**

Registrar:

```markdown
- `main_path[0]` es tutorial y `main_path[1]` es cuerpo/recompensa.
- `reward_part_id` pertenece al pool EXP-01/EXP-02 y es determinista por seed.
- `GameState.claimed_room_rewards` vive solo durante la partida.
- Overlay y minimapa calculan límites únicamente con salas visitadas.
- Tras recibir PNG nuevos: `godot --headless --path prueba_2 --import`.
```

- [ ] **Step 2: Ejecutar verificación automatizada completa del bloque**

```powershell
godot --headless --path prueba_2 --import
godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
godot --headless --path prueba_2 res://tests/run_lifecycle_tests.tscn
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
godot --headless --path prueba_2 res://tests/map_overlay_tests.tscn
godot --headless --path prueba_2 res://tests/hud_tests.tscn
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
godot --headless --path prueba_2 --quit-after 3
```

Expected: todas las suites terminan con código 0 y no aparece
`Assertion failed: No existe fondo`.

- [ ] **Step 3: Verificar visualmente a 1920×1080**

Arrancar con la seed `1785033756`, capturar tutorial, segunda sala, mapa antes y
después de entrar, y confirmar:

```text
- sangre apunta a la puerta real;
- cuerpo y pickup no se solapan;
- no hay habitaciones ocultas en mapa/minimapa;
- las cuatro lámparas conservan intensidad y cubren más superficie.
```

- [ ] **Step 4: Commit**

```powershell
git add AGENTS.md docs/ARQUITECTURA.md docs/agents/REFERENCIA.md
git commit -m "docs: explica el hallazgo del cuerpo procedural"
```
