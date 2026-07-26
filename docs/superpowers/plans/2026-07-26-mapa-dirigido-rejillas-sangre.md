# Mapa dirigido, rejillas de huida y sangre vectorial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir Contención en un grafo procedural ramificado y unidireccional donde toda sala alcanza al jefe, las rejillas huyen siempre hacia delante y la segunda sala usa sangre vectorial sin el cadáver humano provisional.

**Architecture:** `RunMap` modelará salidas e entradas por separado y expondrá recorrido dirigido. `MapGenerator` construirá una ruta crítica, un diamante de bifurcación y destinos de rejilla que reconectan a capas posteriores. `ProceduralRoom` materializará entradas selladas, salidas transitables, llegadas de rejilla sin retorno y recompensas persistentes.

**Tech Stack:** Godot 4.7.1, GDScript, escenas `.tscn`, PNG con alfa, pruebas headless propias.

**Execution note (2026-07-26):** por instrucción explícita del usuario, la
implementación se aplicará directamente y las suites automatizadas descritas
abajo quedan como guía reproducible para una ejecución posterior. La entrega
inmediata será una versión jugable abierta en Godot para validación manual.

## Global Constraints

- Proyecto activo: `prueba_2/`.
- El jugador conserva `move_and_collide()`.
- Sala 1 tiene una salida; sala 2 tiene una entrada sellada y una salida.
- Toda sala distinta del jefe alcanza al jefe mediante aristas dirigidas.
- El jefe es el único nodo sin salidas.
- Debe existir al menos una bifurcación que vuelva a converger.
- Contenido normal: 50 % fácil, 30 % difícil, 20 % vacío.
- Toda sala fácil, difícil y preboss origina exactamente una rejilla.
- Destino de rejilla: 40 % vacío, 20 % combate obligatorio, 40 % loot.
- Una conexión cruzada nunca permite regresar.
- El combate obligatorio de rejilla no genera otra rejilla.
- No cambiar coste de rejilla, combate de EXP07 ni pisos posteriores.
- Mantener y no incluir cambios ajenos ya presentes en el worktree.

---

### Task 1: Contrato dirigido de `RunMap`

**Files:**
- Modify: `prueba_2/core/run_map.gd`
- Modify: `prueba_2/tests/run_map_tests.gd`

**Interfaces:**
- Produces: `connect_forward(from_id: String, to_id: String, direction: StringName) -> void`
- Produces: `forward_neighbors(room_id: String) -> Array[String]`
- Produces: `can_reach(from_id: String, target_id: String) -> bool`
- Produces: campos de sala `entrances: Dictionary` y `layer: int`
- Preserves: `doors` representa únicamente salidas transitables

- [ ] **Step 1: Escribir pruebas fallidas del modelo dirigido**

Añadir un fixture `START → BODY → BOSS`:

```gdscript
map.connect_forward("START", "BODY", &"E")
map.connect_forward("BODY", "BOSS", &"S")
_check(map.room("START")["doors"]["E"] == "BODY", "registra salida")
_check(not map.room("BODY")["doors"].has("O"), "no crea retorno")
_check(map.room("BODY")["entrances"]["O"] == "START", "registra entrada")
_check(map.forward_neighbors("START") == ["BODY"], "expone vecinos futuros")
_check(map.can_reach("START", "BOSS"), "inicio alcanza al jefe")
_check(not map.can_reach("BODY", "START"), "no existe camino de regreso")
```

- [ ] **Step 2: Ejecutar la prueba y observar RED**

Run:

```powershell
& (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source --headless --path prueba_2 --script res://tests/run_map_tests.gd
```

Expected: FAIL porque faltan `connect_forward`, `entrances` y recorrido.

- [ ] **Step 3: Implementar el contrato mínimo**

En `add_room()` añadir:

```gdscript
"entrances": {},
"layer": 0,
"grate_arrival_direction": "",
```

Implementar:

```gdscript
func connect_forward(
	from_id: String,
	to_id: String,
	direction: StringName
) -> void:
	var exit_direction := String(direction)
	var entry_direction: String = OPPOSITE[exit_direction]
	rooms[from_id]["doors"][exit_direction] = to_id
	rooms[from_id]["one_way"][exit_direction] = true
	rooms[to_id]["entrances"][entry_direction] = from_id


func forward_neighbors(room_id: String) -> Array[String]:
	var result: Array[String] = []
	for target: String in room(room_id).get("doors", {}).values():
		if not result.has(target):
			result.append(target)
	var grate_target := String(room(room_id).get("grate_target", ""))
	if not grate_target.is_empty() and not result.has(grate_target):
		result.append(grate_target)
	result.sort()
	return result


func can_reach(from_id: String, target_id: String) -> bool:
	var pending: Array[String] = [from_id]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current := pending.pop_back()
		if current == target_id:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		pending.append_array(forward_neighbors(current))
	return false
```

- [ ] **Step 4: Ejecutar GREEN**

Run: comando del Step 2.  
Expected: fixture dirigido pasa; las aserciones antiguas de retorno se
actualizan al nuevo contrato.

- [ ] **Step 5: Commit**

```powershell
git add -- prueba_2/core/run_map.gd prueba_2/tests/run_map_tests.gd
git commit -m "feat: model directed room connections"
```

---

### Task 2: Generador ramificado que siempre converge

**Files:**
- Modify: `prueba_2/core/map_generator.gd`
- Modify: `prueba_2/tests/run_map_tests.gd`

**Interfaces:**
- Consumes: `RunMap.connect_forward()`, `forward_neighbors()`, `can_reach()`
- Produces: `_all_rooms_reach_boss(run_map: RefCounted) -> bool`
- Produces: `_has_cycle(run_map: RefCounted) -> bool`
- Produces: topología con ruta crítica, diamante y capas crecientes

- [ ] **Step 1: Reemplazar expectativas antiguas por pruebas fallidas**

La prueba de 1.000 semillas debe exigir:

```gdscript
_check(MapGenerator.NORMAL_CONTENT == [
	[&"easy", 50],
	[&"hard", 30],
	[&"empty", 20],
], "pesos normales son 50/30/20")
_check(generated.room(generated.entry_room_id)["doors"].size() == 1, "inicio una salida")
var body := generated.room(generated.main_path[1])
_check(body["entrances"].size() == 1, "cuerpo una entrada")
_check(body["doors"].size() == 1, "cuerpo una salida")
_check(_branch_count(generated) >= 1, "existe bifurcación")
_check(not generator.call("_has_cycle", generated), "grafo acíclico")
for room_id: String in generated.room_ids():
	_check(
		room_id == generated.boss_room_id
		or generated.can_reach(room_id, generated.boss_room_id),
		"%s alcanza al jefe" % room_id
	)
```

Añadir `_branch_count()` contando salas con `doors.size() >= 2`.

- [ ] **Step 2: Ejecutar RED**

Run:

```powershell
& (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source --headless --path prueba_2 --script res://tests/run_map_tests.gd
```

Expected: FAIL por conexiones recíprocas, pesos 40/30/20/10 y ausencia de
garantía de bifurcación.

- [ ] **Step 3: Construir la ruta crítica dirigida**

Mantener una ruta de 6–8 nodos. Sustituir cada `connect_rooms()` de
Contención por `connect_forward()` y asignar:

```gdscript
run_map.room(room_id)["layer"] = index
```

Eliminar `closure` de `NORMAL_CONTENT`:

```gdscript
const NORMAL_CONTENT: Array = [
	[&"easy", 50],
	[&"hard", 30],
	[&"empty", 20],
]
```

- [ ] **Step 4: Insertar un diamante después de la segunda sala**

Crear un split después de `body` y reservar un cuadrado libre:

```text
SPLIT → BRANCH_A → REJOIN
   └──→ BRANCH_B ──┘
```

Las cuatro conexiones usan `connect_forward()`. `main_path` conserva
`BRANCH_A` como ruta crítica; `BRANCH_B` es la rama alternativa. Rotar las dos
direcciones perpendiculares mediante el RNG para variar N/E/S/O.

- [ ] **Step 5: Validar DAG, capas y sumidero único**

Implementar DFS con colores para `_has_cycle()`. `validate()` debe comprobar:

```gdscript
if _has_cycle(run_map):
	errors.append("el mapa dirigido contiene un ciclo")
for room_id: String in run_map.room_ids():
	var exits := run_map.forward_neighbors(room_id)
	if room_id == run_map.boss_room_id:
		if not exits.is_empty():
			errors.append("el jefe no puede tener salidas")
	elif not run_map.can_reach(room_id, run_map.boss_room_id):
		errors.append("%s no alcanza al jefe" % room_id)
```

Comprobar además que toda arista apunte a una capa mayor.

- [ ] **Step 6: Ejecutar GREEN y distribución**

Run: comando del Step 2.  
Expected: `PASS: run map model`, 1.000 semillas válidas y aproximación
50/30/20.

- [ ] **Step 7: Commit**

```powershell
git add -- prueba_2/core/map_generator.gd prueba_2/tests/run_map_tests.gd
git commit -m "feat: generate converging one-way room branches"
```

---

### Task 3: Puertas de entrada selladas y transición sin retorno

**Files:**
- Modify: `prueba_2/world/rooms/procedural_room.gd`
- Modify: `prueba_2/world/props/door.gd`
- Modify: `prueba_2/ui/map_overlay.gd`
- Modify: `prueba_2/tests/room_assembly_tests.gd`
- Modify: `prueba_2/tests/room_story_tests.gd`

**Interfaces:**
- Consumes: `room_data["doors"]` como salidas
- Consumes: `room_data["entrances"]` como entradas cerradas
- Produces: `Door.configure(direction: String, traversable: bool) -> void`
- Produces: `_opening_directions() -> Array[String]`

- [ ] **Step 1: Escribir pruebas fallidas de ensamblaje**

Construir `ENTRY → BODY → NEXT` y exigir:

```gdscript
var body := RoomAssembler.build(map.room("BODY"))
_check(body.has_node("DoorO"), "dibuja entrada")
_check(body.has_node("DoorE"), "dibuja salida")
_check(body.get_node("DoorO").get("traversable") == false, "entrada cerrada")
_check(body.get_node("DoorE").get("traversable") == true, "salida activa")
_check(body.has_node("SpawnO"), "entrada conserva spawn")
```

La prueba de historia debe usar `connect_forward()` y confirmar que la sangre
encuentra el hito tanto desde una salida como desde `entrances`.

- [ ] **Step 2: Ejecutar RED**

Run:

```powershell
$godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
& $godot --headless --path prueba_2 res://tests/room_assembly_tests.tscn
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path prueba_2 res://tests/room_story_tests.tscn
```

Expected: FAIL porque `ProceduralRoom` solo materializa `doors`.

- [ ] **Step 3: Materializar la unión de entradas y salidas**

Añadir:

```gdscript
func _opening_directions() -> Array[String]:
	var result: Array[String] = []
	for source: Dictionary in [
		_room_data.get("doors", {}),
		_room_data.get("entrances", {}),
	]:
		for direction: String in source:
			if not result.has(direction):
				result.append(direction)
	return result
```

Usar esta lista para fondo, muros, nodos `Door<dir>` y `Spawn<dir>`.
Configurar cada puerta con:

```gdscript
door.configure(direction, _room_data["doors"].has(direction))
```

- [ ] **Step 4: Sellar permanentemente entradas**

En `door.gd`:

```gdscript
var traversable := true

func configure(value: String, can_traverse: bool) -> void:
	direction = value
	traversable = can_traverse

func _ready() -> void:
	_sealed = not traversable
	# conservar armado, orientación y visual actuales
```

`_on_body_entered()` retorna inmediatamente si `not traversable`.

- [ ] **Step 5: Adaptar el rastro narrativo**

Cambiar `_direction_to()` para buscar primero en `doors` y luego en
`entrances`, de forma que el cuerpo pueda localizar la sala de inicio sin
crear retorno.

- [ ] **Step 6: Dibujar entradas y salidas en el mapa local**

En `map_overlay.gd`, dibujar conectores para la unión de `doors` y
`entrances`, pero crear líneas de conexión únicamente desde `doors`. Así una
entrada consumida conserva su abertura visual sin sugerir que permite volver.

- [ ] **Step 7: Ejecutar GREEN**

Run: comandos del Step 2.  
Expected: ambas suites pasan y ninguna entrada viaja.

- [ ] **Step 8: Commit**

```powershell
git add -- prueba_2/world/rooms/procedural_room.gd prueba_2/world/props/door.gd prueba_2/ui/map_overlay.gd prueba_2/tests/room_assembly_tests.gd prueba_2/tests/room_story_tests.gd
git commit -m "feat: seal consumed room entrances"
```

---

### Task 4: Rejillas irreversibles y loot hacia delante

**Files:**
- Modify: `prueba_2/core/map_generator.gd`
- Modify: `prueba_2/core/run_map.gd`
- Modify: `prueba_2/world/rooms/procedural_room.gd`
- Modify: `prueba_2/world/props/grate.gd`
- Modify: `prueba_2/tests/grate_flow_tests.gd`
- Modify: `prueba_2/tests/grate_cost_ui_tests.gd`
- Modify: `prueba_2/tests/run_map_tests.gd`

**Interfaces:**
- Consumes: `set_grate(source_id, target_id, direction)`
- Produces: destino sin `Grate`, con `GrateSpawn` y salida dirigida
- Produces: `reward_part_id` para destino loot

- [ ] **Step 1: Escribir pruebas fallidas de reglas de rejilla**

Por cada seed:

```gdscript
var escapable := role == &"preboss" or content == "easy" or content == "hard"
_check(
	escapable == not String(data["grate_target"]).is_empty(),
	"solo todo combate escapable origina rejilla"
)
if role == &"grate_destination":
	_check(String(data["grate_target"]).is_empty(), "destino no encadena rejilla")
	_check(data["doors"].size() >= 1, "destino continúa hacia delante")
	_check(generated.can_reach(room_id, generated.boss_room_id), "destino llega al jefe")
	if content == "combat":
		_check(data["enemy_count"] > 0, "combate obligatorio tiene enemigos")
	if content == "loot":
		_check(FIRST_PART_POOL.has(String(data["reward_part_id"])), "loot tiene parte")
```

En `grate_flow_tests.gd`, el destino debe tener `GrateSpawn` pero no `Grate`.

- [ ] **Step 2: Ejecutar RED**

Run:

```powershell
$godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
& $godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path prueba_2 res://tests/grate_flow_tests.tscn
```

Expected: FAIL por retorno gratuito actual, 60 % de fuentes y destinos sin
salida de puerta.

- [ ] **Step 3: Reservar una rejilla para todo combate escapable**

Eliminar `GRATE_CHANCE`. Para cada fuente fácil, difícil o preboss:

1. elegir una pared libre;
2. crear un destino `G_*`;
3. asignar 40/20/40;
4. colocar el destino en una celda libre adyacente a una sala de capa
   posterior;
5. conectarlo a esa sala mediante `connect_forward()`;
6. llamar `set_grate()` desde la fuente.

El preboss elige como rejoin obligatorio al jefe. Si una colocación no cabe,
se descarta el intento completo; nunca se elimina una rejilla requerida.

- [ ] **Step 4: Hacer irreversible `set_grate()`**

Conservar metadatos de fuente para auditoría y spawn, pero no crear salida de
retorno:

```gdscript
func set_grate(source_id: String, target_id: String, direction: StringName) -> void:
	var source_direction := String(direction)
	rooms[source_id]["grate_target"] = target_id
	rooms[source_id]["grate_direction"] = source_direction
	rooms[target_id]["grate_source"] = source_id
	rooms[target_id]["grate_arrival_direction"] = OPPOSITE[source_direction]
```

- [ ] **Step 5: Ensamblar llegada sin rejilla**

`_build_grate()` instancia `Grate` solo cuando `grate_target` no está vacío.
Si la sala solo tiene `grate_source`, crea:

```gdscript
var spawn := Marker2D.new()
spawn.name = "GrateSpawn"
spawn.position = SPAWN_POSITIONS[arrival_direction]
add_child(spawn)
```

No se crea sensor, sprite, prompt ni transición de regreso.

- [ ] **Step 6: Instanciar loot persistente**

Cuando `role == &"grate_destination"` y `content_type == &"loot"`, instanciar
`BodySourceScene` como `LootSource`, configurado con `id` y `reward_part_id`.
Colocarlo en `ROOM_CENTER`.

- [ ] **Step 7: Ejecutar GREEN**

Run:

```powershell
$godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
& $godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path prueba_2 res://tests/grate_flow_tests.tscn
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path prueba_2 res://tests/grate_cost_ui_tests.tscn
```

Expected: tres suites pasan; pagar viaja hacia delante y no aparece retorno.

- [ ] **Step 8: Commit**

```powershell
git add -- prueba_2/core/map_generator.gd prueba_2/core/run_map.gd prueba_2/world/rooms/procedural_room.gd prueba_2/world/props/grate.gd prueba_2/tests/grate_flow_tests.gd prueba_2/tests/grate_cost_ui_tests.gd prueba_2/tests/run_map_tests.gd
git commit -m "feat: route grate escapes forward"
```

---

### Task 5: Retirar cadáver humano y conservar recompensa

**Files:**
- Modify: `prueba_2/world/props/body_source.tscn`
- Delete: `prueba_2/assets/environment/body/inert_body.png`
- Delete: `prueba_2/assets/environment/body/inert_body.png.import`
- Modify: `prueba_2/tests/room_story_tests.gd`

**Interfaces:**
- Preserves: `BodySource.configure(room_id, reward_part_id)`
- Preserves: `PartPickup` y persistencia por `GameState`

- [ ] **Step 1: Escribir prueba fallida del placeholder ausente**

```gdscript
var body_scene: PackedScene = load("res://world/props/body_source.tscn")
var body := body_scene.instantiate()
_check(body.get_node_or_null("Body") == null, "no muestra cadáver humano")
_check(
	not ResourceLoader.exists("res://assets/environment/body/inert_body.png"),
	"el asset provisional deja de formar parte del runtime"
)
```

Mantener la comprobación que exige `PartPickup`.

- [ ] **Step 2: Ejecutar RED**

Run:

```powershell
& (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source --headless --path prueba_2 res://tests/room_story_tests.tscn
```

Expected: FAIL porque el sprite y textura todavía existen.

- [ ] **Step 3: Retirar escena y assets**

Eliminar el `ext_resource` de `inert_body.png` y el nodo `Body` de
`body_source.tscn`. Borrar únicamente los dos archivos aprobados. La
recuperación permanece disponible mediante Git.

- [ ] **Step 4: Ejecutar GREEN**

Run: comando del Step 2.  
Expected: la segunda sala no muestra humano y sigue entregando la primera
parte una sola vez.

- [ ] **Step 5: Commit**

```powershell
git add -- prueba_2/world/props/body_source.tscn prueba_2/assets/environment/body/inert_body.png prueba_2/assets/environment/body/inert_body.png.import prueba_2/tests/room_story_tests.gd
git commit -m "fix: remove provisional human corpse"
```

---

### Task 6: Sangre plana de estilo vectorial

**Files:**
- Replace: `prueba_2/assets/environment/blood/blood_drops.png`
- Replace: `prueba_2/assets/environment/blood/blood_drag.png`
- Replace: `prueba_2/assets/environment/blood/blood_pool.png`
- Modify: `prueba_2/world/props/blood_trail.gd`
- Modify: `prueba_2/tests/room_story_tests.gd`

**Interfaces:**
- Preserves: rutas `DROPS`, `DRAG`, `POOL`
- Produces: tres PNG RGBA planos y coherentes

- [ ] **Step 1: Reforzar prueba de recursos antes de reemplazar**

Exigir carga, alfa y dimensiones positivas:

```gdscript
for path: String in BLOOD_ASSETS:
	var texture := load(path) as Texture2D
	var image := texture.get_image()
	_check(image != null and image.get_format() in [
		Image.FORMAT_RGBA8,
		Image.FORMAT_RGBAF,
	], "%s conserva alfa" % path)
	_check(image.get_size().x >= 512 and image.get_size().y >= 256, "%s tiene resolución útil" % path)
```

Esta caracterización puede pasar antes del cambio; la aceptación estética es
visual y no se sustituye por una aserción falsa sobre estilo.

- [ ] **Step 2: Generar familia visual con imagegen**

Usar tres llamadas built-in, con el mismo lenguaje:

```text
Use case: stylized-concept
Asset type: top-down 2D game decal
Primary request: flat vector-style biological blood [drops/drag/pool]
Style/medium: clean geometric 2D shapes, two-tone burgundy, dark outline
Color palette: #3A1623, #7A2948, #B33C5A
Composition: isolated centered decal, generous padding
Constraints: top-down, no text, no watermark, no photorealism, no wet gloss,
no volume, no cast shadow; perfectly flat #00ff00 chroma-key background
```

Copiar los resultados al workspace y ejecutar
`remove_chroma_key.py --auto-key border --soft-matte --despill`. Validar
esquinas transparentes y ausencia de borde verde.

- [ ] **Step 3: Ajustar regiones y escalas**

Actualizar `DROP_REGIONS` a las dimensiones reales del nuevo sprite de gotas.
Mantener cuatro regiones no solapadas y el contrato de cinco sprites más
charco.

- [ ] **Step 4: Ejecutar prueba e importación**

Run:

```powershell
$godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
& $godot --headless --path prueba_2 --import
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path prueba_2 res://tests/room_story_tests.tscn
```

Expected: assets importan y `PASS: room story content`.

- [ ] **Step 5: Inspección visual**

Capturar entrada y segunda sala a 1920×1080. Confirmar formas planas, alfa,
contraste sobre el suelo y ausencia del humano.

- [ ] **Step 6: Commit**

```powershell
git add -- prueba_2/assets/environment/blood prueba_2/world/props/blood_trail.gd prueba_2/tests/room_story_tests.gd
git commit -m "art: replace blood with flat vector decals"
```

---

### Task 7: Hacer visible la rejilla en la penumbra

**Files:**
- Modify: `prueba_2/world/props/grate.gd`
- Modify: `prueba_2/world/props/grate.tscn`
- Modify: `prueba_2/tests/grate_flow_tests.gd`
- Modify: `prueba_2/tests/ui_visual_capture.gd`

**Interfaces:**
- Preserves: tamaño visual máximo `120×120`
- Produces: `Glow` cian tenue sin texto permanente

- [ ] **Step 1: Escribir prueba fallida de contraste**

```gdscript
var glow := grate.get_node_or_null("Glow") as PointLight2D
_check(glow != null, "rejilla tiene halo")
_check(glow != null and glow.energy > 0.0, "halo permanece visible")
_check(sprite.modulate.get_luminance() > 1.0, "sprite se aclara en penumbra")
```

- [ ] **Step 2: Ejecutar RED**

Run:

```powershell
& (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source --headless --path prueba_2 res://tests/grate_flow_tests.tscn
```

Expected: FAIL porque no existe `Glow`.

- [ ] **Step 3: Añadir halo y borde**

Crear `PointLight2D` con textura radial existente, color
`Palette.SLIME_CORE`, energía tenue y escala limitada. Aclarar el sprite sin
cambiar el tamaño. Dibujar un arco cian sutil desde `grate.gd`; no mostrar
texto hasta entrar al sensor.

- [ ] **Step 4: Ejecutar GREEN y captura**

Run:

```powershell
$godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
& $godot --headless --path prueba_2 res://tests/grate_flow_tests.tscn
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- grate user://grate-forward.png 1920x1080
```

Expected: prueba pasa y la rejilla se distingue claramente de la pared sin
dominar la sala.

- [ ] **Step 5: Commit**

```powershell
git add -- prueba_2/world/props/grate.gd prueba_2/world/props/grate.tscn prueba_2/tests/grate_flow_tests.gd prueba_2/tests/ui_visual_capture.gd
git commit -m "fix: improve grate visibility"
```

---

### Task 8: Documentación y verificación completa

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`

**Interfaces:**
- Documents: DAG, conexiones consumidas, 50/30/20, 40/20/40, loot y assets

- [ ] **Step 1: Actualizar contratos operativos**

Documentar:

- `doors` son salidas y `entrances` son pasos sellados;
- toda sala alcanza al jefe;
- rejillas sin retorno y combate de destino obligatorio;
- segunda sala sin asset humano;
- rutas de sangre permanecen estables.

- [ ] **Step 2: Ejecutar suites afectadas**

Run:

```powershell
$godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
& $godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$scenes = @(
	'res://tests/room_assembly_tests.tscn',
	'res://tests/room_story_tests.tscn',
	'res://tests/grate_flow_tests.tscn',
	'res://tests/grate_cost_ui_tests.tscn',
	'res://tests/map_overlay_tests.tscn',
	'res://tests/combat_smoke.tscn'
)
foreach ($scene in $scenes) {
	& $godot --headless --path prueba_2 $scene
	if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: todas las suites terminan con código 0.

- [ ] **Step 3: Buscar contratos obsoletos**

Run:

```powershell
rg -n "40 %.*fácil|closure.*10|retorno.*rejilla|inert_body|connect_rooms" AGENTS.md docs prueba_2/core prueba_2/world prueba_2/tests
git diff --check
```

Revisar cada coincidencia; no deben quedar reglas activas que contradigan la
especificación.

- [ ] **Step 4: Arrancar juego real**

Con Godot MCP:

```text
run_project(projectPath=<ruta absoluta a prueba_2>)
get_debug_output()
```

Expected: `errors: []`. Mantenerlo abierto para prueba humana.

- [ ] **Step 5: Commit**

Stagear solo los hunks propios si `docs/ARQUITECTURA.md` conserva cambios
previos ajenos:

```powershell
git add -- AGENTS.md docs/agents/REFERENCIA.md
git add -p -- docs/ARQUITECTURA.md
git commit -m "docs: explain forward-only containment map"
```
