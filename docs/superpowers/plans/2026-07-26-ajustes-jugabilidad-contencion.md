# Containment Gameplay Adjustments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Empotrar las rejillas en paredes libres, bloquear físicamente puertas selladas y ajustar iluminación, vida, curación y texto de consumo del primer piso.

**Architecture:** `RunMap` conserva la dirección mural de cada extremo y `MapGenerator` solo crea destinos adyacentes en paredes libres. `procedural_room.gd` ensambla la rejilla usando el mismo sistema de posiciones de las puertas, mientras `door.gd` controla una barrera física independiente de la transición. Balance e interfaz continúan bajo las autoridades existentes: `GameState`, `Inventory` y `body_panel.gd`.

**Tech Stack:** Godot 4.7.1, GDScript, escenas `.tscn`, pruebas headless propias y capturas 1920 × 1080.

## Global Constraints

- El alcance se limita al piso de Contención.
- La rejilla cabe dentro de `120 × 120` y conserva la relación de aspecto del PNG.
- Fuente y retorno ocupan paredes opuestas y nunca comparten pared con una puerta normal.
- Máximo una rejilla por sala y destinos únicos.
- Destinos: `40 %` vacío, `40 %` loot y `20 %` combate.
- La energía de las lámparas permanece en `1.6`; `texture_scale` pasa a `1.85`.
- Vida máxima `15 HP`, vida inicial `7 HP` y consumo de parte `+2 HP`.
- `Tab` muestra `F · COMER` sin informar la cantidad de curación.
- El coste de rejilla y su retorno gratuito durante la partida actual no cambian.

---

### Task 1: Dirección mural y topología adyacente de rejillas

**Files:**
- Modify: `prueba_2/core/run_map.gd`
- Modify: `prueba_2/core/map_generator.gd`
- Modify: `prueba_2/tests/run_map_tests.gd`
- Modify: `prueba_2/tests/grate_flow_tests.gd`
- Modify: `prueba_2/tests/grate_cost_ui_tests.gd`
- Modify: `prueba_2/tests/ui_visual_capture.gd`

**Interfaces:**
- Produces: campo de sala `grate_direction: String`.
- Produces: `RunMap.set_grate(source_id: String, target_id: String, direction: StringName) -> void`.
- Produces: `_available_grate_directions(source_data: Dictionary, occupied: Dictionary) -> Array[String]`.
- Consumes: `RunMap.OPPOSITE`, `MapGenerator.DELTAS` y el diccionario `occupied`.

- [ ] **Step 1: Escribir pruebas fallidas del contrato direccional**

Actualizar el mapa unitario:

```gdscript
map.set_grate("R1", "RG", &"S")
_check(map.room("R1")["grate_direction"] == "S", "fuente guarda pared de rejilla")
_check(map.room("RG")["grate_direction"] == "N", "retorno usa pared opuesta")
```

Dentro del recorrido de seeds, para cada `grate_target` comprobar:

```gdscript
var direction: String = data["grate_direction"]
var target_data: Dictionary = generated.room(grate_target)
_check(not data["doors"].has(direction), "rejilla no comparte pared con puerta")
_check(
	target_data["grid"] - data["grid"] == MapGenerator.DELTAS[direction],
	"destino de rejilla queda adyacente"
)
_check(
	target_data["grate_direction"] == RunMap.OPPOSITE[direction],
	"retorno mira a la fuente"
)
```

Comprobar además los pesos declarados:

```gdscript
_check(MapGenerator.GRATE_CONTENT == [
	[&"empty", 40],
	[&"combat", 20],
	[&"loot", 40],
], "pesos de destino son 40/20/40")
```

Añadir una muestra aislada de `10 000` elecciones para que el tamaño de la
muestra no dependa de cuántas rejillas producen las primeras mil seeds:

```gdscript
var weight_rng := RandomNumberGenerator.new()
weight_rng.seed = 260726
var weighted_counts := {"empty": 0, "combat": 0, "loot": 0}
for index in range(10000):
	var choice: StringName = generator.call(
		"_weighted_choice",
		weight_rng,
		MapGenerator.GRATE_CONTENT
	)
	weighted_counts[String(choice)] += 1
```

La muestra existente de mapas conserva sus verificaciones de proporción. La
muestra aislada usa tolerancia `0.02` mediante un parámetro opcional:

```gdscript
func _near_ratio(value: int, counts: Dictionary, expected: float, tolerance := 0.05) -> bool:
	# cálculo existente
	return absf(float(value) / float(total) - expected) <= tolerance
```

- [ ] **Step 2: Ejecutar la prueba y confirmar el fallo**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --script res://tests/run_map_tests.gd
```

Expected: FAIL porque `set_grate()` no recibe dirección y las salas no exponen
`grate_direction`.

- [ ] **Step 3: Añadir dirección al modelo**

En `RunMap.add_room()`:

```gdscript
"grate_target": "",
"grate_source": "",
"grate_direction": "",
```

Sustituir `set_grate()`:

```gdscript
func set_grate(
	source_id: String,
	target_id: String,
	direction: StringName
) -> void:
	var source_direction := String(direction)
	rooms[source_id]["grate_target"] = target_id
	rooms[source_id]["grate_direction"] = source_direction
	rooms[target_id]["grate_source"] = source_id
	rooms[target_id]["grate_direction"] = OPPOSITE[source_direction]
```

- [ ] **Step 4: Limitar el generador a paredes y celdas libres**

Añadir:

```gdscript
func _available_grate_directions(
	source_data: Dictionary,
	occupied: Dictionary
) -> Array[String]:
	var result: Array[String] = []
	var source_grid: Vector2i = source_data["grid"]
	var doors: Dictionary = source_data["doors"]
	for direction: String in DIRECTIONS:
		if doors.has(direction):
			continue
		if occupied.has(source_grid + Vector2i(DELTAS[direction])):
			continue
		result.append(direction)
	return result
```

Filtrar `eligible` con esta función. En `_add_grates()`, escoger una dirección
del resultado barajado, crear el destino exactamente en
`source_grid + DELTAS[direction]` y llamar:

```gdscript
run_map.set_grate(source_id, grate_id, StringName(direction))
```

Eliminar `_free_grate_grid()` y su búsqueda lejana. Una fuente obligatoria sin
dirección disponible devuelve `false`; una opcional que perdió su celda por una
rejilla anterior se omite. `validate()` debe rechazar direcciones vacías,
paredes compartidas y destinos no adyacentes.

Actualizar todos los consumidores ejecutables de `set_grate()`:

```gdscript
# grate_flow_tests.gd y grate_cost_ui_tests.gd
map.set_grate("SOURCE", "TARGET", &"E")
```

En el fixture `grate` de `ui_visual_capture.gd`, colocar `GRATE` en
`Vector2i.RIGHT`, no crear la puerta normal `E` en `CENTER` para ese modo y
llamar `map.set_grate("CENTER", "GRATE", &"E")`. Los otros modos de captura
conservan sus cuatro puertas normales.

- [ ] **Step 5: Ejecutar pruebas de mapa**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --script res://tests/run_map_tests.gd
```

Expected: `PASS: run map model`.

- [ ] **Step 6: Commit**

```powershell
git add prueba_2/core/run_map.gd prueba_2/core/map_generator.gd prueba_2/tests/run_map_tests.gd prueba_2/tests/grate_flow_tests.gd prueba_2/tests/grate_cost_ui_tests.gd prueba_2/tests/ui_visual_capture.gd
git commit -m "feat: orienta rejillas en paredes libres"
```

---

### Task 2: Ensamblado mural y escala de puerta

**Files:**
- Modify: `prueba_2/world/rooms/procedural_room.gd`
- Modify: `prueba_2/world/props/grate.gd`
- Modify: `prueba_2/world/props/grate.tscn`
- Modify: `prueba_2/tests/grate_flow_tests.gd`
- Modify: `prueba_2/tests/room_assembly_tests.gd`

**Interfaces:**
- Consumes: `room_data["grate_direction"]`.
- Produces: `Grate.configure(source_id, target_id, cost_required, wall_direction)`.
- Produces: `Grate.wall_direction: String`.
- Produces: rejilla y `GrateSpawn` en `DOOR_POSITIONS[direction]` y `SPAWN_POSITIONS[direction]`.

- [ ] **Step 1: Escribir pruebas fallidas del ensamblado**

Construir un mapa con fuente en pared este y retorno oeste:

```gdscript
map.add_room("SOURCE", Vector2i.ZERO, &"normal", &"easy")
map.add_room("TARGET", Vector2i.RIGHT, &"grate_destination", &"loot")
map.set_grate("SOURCE", "TARGET", &"E")
```

Esperar:

```gdscript
_test_grate_assembly(source_room, "SOURCE", "TARGET", true, "E",
	Vector2(1800, 540), Vector2(1640, 540))
_test_grate_assembly(target_room, "TARGET", "SOURCE", false, "O",
	Vector2(120, 540), Vector2(240, 540))
```

En `_test_grate_assembly()` comprobar `wall_direction`, que el sprite cabe en
`120 × 120` y que la dirección no existe en `room_data["doors"]`.

- [ ] **Step 2: Ejecutar RED**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/grate_flow_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_assembly_tests.tscn
```

Expected: FAIL por posiciones interiores y ausencia de `wall_direction`.

- [ ] **Step 3: Ensamblar usando posiciones de puerta**

Eliminar las cuatro constantes `GRATE_*_POSITION`. En `_build_grate()`:

```gdscript
var direction: String = String(_room_data.get("grate_direction", ""))
assert(DOOR_POSITIONS.has(direction), "Rejilla sin pared válida en %s" % room_id)
assert(not _room_data["doors"].has(direction), "Rejilla comparte pared en %s" % room_id)

var grate: Area2D = GrateScene.instantiate()
grate.name = "Grate"
grate.position = DOOR_POSITIONS[direction]
grate.configure(room_id, target_id, requires_cost, direction)
add_child(grate)

var spawn := Marker2D.new()
spawn.name = "GrateSpawn"
spawn.position = SPAWN_POSITIONS[direction]
add_child(spawn)
```

- [ ] **Step 4: Ajustar sprite, colisión y prompt**

En `grate.gd`:

```gdscript
const MAX_VISUAL_SIZE := Vector2(120.0, 120.0)
const PROMPT_POSITIONS := {
	"N": Vector2(0, 86),
	"S": Vector2(0, -116),
	"O": Vector2(150, -15),
	"E": Vector2(-150, -15),
}

var wall_direction := ""
@onready var sprite: Sprite2D = $Sprite

func configure(source_id: String, target_id: String, cost_required: bool, direction: String) -> void:
	source_room_id = source_id
	target_room_id = target_id
	requires_cost = cost_required
	wall_direction = direction

func _fit_visual() -> void:
	var size := sprite.texture.get_size()
	var factor := minf(MAX_VISUAL_SIZE.x / size.x, MAX_VISUAL_SIZE.y / size.y)
	sprite.scale = Vector2.ONE * factor
	prompt.position = PROMPT_POSITIONS[wall_direction]
```

Llamar `_fit_visual()` al inicio de `_ready()`. Mantener el área interactiva
dentro del hueco mediante un `RectangleShape2D` de `100 × 100`.

- [ ] **Step 5: Ejecutar GREEN y regresión de coste**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/grate_flow_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_assembly_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/grate_cost_ui_tests.tscn
```

Expected: todas PASS.

- [ ] **Step 6: Commit**

```powershell
git add prueba_2/world/rooms/procedural_room.gd prueba_2/world/props/grate.gd prueba_2/world/props/grate.tscn prueba_2/tests/grate_flow_tests.gd prueba_2/tests/room_assembly_tests.gd
git commit -m "feat: empotra rejillas en las paredes"
```

---

### Task 3: Barrera física para puertas selladas

**Files:**
- Modify: `prueba_2/world/props/door.gd`
- Modify: `prueba_2/world/props/door.tscn`
- Modify: `prueba_2/tests/room_assembly_tests.gd`

**Interfaces:**
- Consumes: `Door.set_sealed(value: bool)`.
- Produces: `Door/SealBody/CollisionShape2D`, deshabilitado al abrir y habilitado al sellar.

- [ ] **Step 1: Escribir una prueba física fallida**

Instanciar `door.tscn` y un `CharacterBody2D` con colisión. Después de
`door.set_sealed(true)` y un `physics_frame`, mover el cuerpo contra el hueco:

```gdscript
var blocked := player.move_and_collide(Vector2(180.0, 0.0))
_check(blocked != null, "puerta sellada bloquea físicamente")
door.set_sealed(false)
await get_tree().physics_frame
player.position = Vector2(-140, 0)
var open_collision := player.move_and_collide(Vector2(180.0, 0.0))
_check(open_collision == null, "puerta abierta permite cruzar")
```

La prueba debe montar la puerta sin otros muros para que la única posible
colisión sea el sello.

- [ ] **Step 2: Ejecutar RED**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_assembly_tests.tscn
```

Expected: la puerta sellada no produce colisión física.

- [ ] **Step 3: Añadir el cuerpo de sello**

En `door.tscn` añadir:

```text
[sub_resource type="RectangleShape2D" id="SealShape"]
size = Vector2(100, 120)

[node name="SealBody" type="StaticBody2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="SealBody"]
disabled = true
shape = SubResource("SealShape")
```

En `door.gd`:

```gdscript
@onready var seal_collision: CollisionShape2D = $SealBody/CollisionShape2D

func _apply_seal_visual() -> void:
	if plate != null:
		plate.visible = _sealed
	if seal_collision != null:
		seal_collision.set_deferred("disabled", not _sealed)
```

Conservar la guarda `_sealed` de `_on_body_entered()` como defensa lógica.

- [ ] **Step 4: Ejecutar GREEN y pruebas de transición**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_assembly_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_story_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/combat_smoke.tscn
```

Expected: todas PASS.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/world/props/door.gd prueba_2/world/props/door.tscn prueba_2/tests/room_assembly_tests.gd
git commit -m "fix: bloquea físicamente puertas selladas"
```

---

### Task 4: Vida inicial, curación y texto de `Tab`

**Files:**
- Modify: `prueba_2/autoload/game_state.gd`
- Modify: `prueba_2/autoload/inventory.gd`
- Modify: `prueba_2/ui/body_panel.gd`
- Modify: `prueba_2/ui/body_panel.tscn`
- Modify: `prueba_2/ui/hud.tscn`
- Modify: `prueba_2/tests/run_lifecycle_tests.gd`
- Modify: `prueba_2/tests/body_panel_tests.gd`
- Modify: `AGENTS.md`

**Interfaces:**
- Produces: `GameState.STARTING_HEALTH_HALVES = 7`.
- Produces: `Inventory._digest(part_id)` cura mediante `GameState.heal_halves(2)`.
- Produces: `BodyPanel/ConsumeHint.text = "F · COMER"` cuando el consumo es válido.

- [ ] **Step 1: Escribir pruebas fallidas de balance**

En ciclo de partida:

```gdscript
_check(GameState.health_halves == 7, "inicia con 7 HP")
GameState.health_halves = 10
Inventory.pick_up("serrated_jaw")
_check(Inventory.consume_slot(0), "consume una parte")
_check(GameState.health_halves == 12, "comer cura 2 HP")
```

En panel corporal, iniciar tres puntos por debajo del máximo:

```gdscript
GameState.health_halves = GameState.max_health_halves - 3
var health_before := GameState.health_halves
_check(panel.call("consume_selected"), "consume la parte seleccionada")
_check(GameState.health_halves == health_before + 2, "consumir cura 2 HP")
_check(panel.get_node("ConsumeHint").text == "F · COMER", "oculta cantidad curada")
_check(
	not panel.get_node("ConsumeHint").text.contains("CORAZÓN"),
	"Tab no anuncia corazones"
)
```

Añadir un caso desde `14/15` que termine en `15/15`.

- [ ] **Step 2: Ejecutar RED**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/run_lifecycle_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/body_panel_tests.tscn
```

Expected: FAIL con inicio `5`, curación `1` y texto `(+½ CORAZÓN)`.

- [ ] **Step 3: Aplicar los valores aprobados**

```gdscript
# game_state.gd
const STARTING_HEALTH_HALVES := 7

# inventory.gd
func _digest(part_id: String) -> void:
	GameState.heal_halves(2)
	# conservar registro de boss y señal

# body_panel.gd
consume_hint.text = "F · COMER"
```

Cambiar también el texto inicial de `ConsumeHint` en `body_panel.tscn` a
`F · COMER`, el valor inicial del HUD a `7 / 15 HP` y actualizar el comentario
de consumo en `inventory.gd`. En `AGENTS.md`, la regla 14 debe declarar inicio
`7 HP` y consumo `+2 HP`.

- [ ] **Step 4: Ejecutar GREEN y buscar textos obsoletos**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/run_lifecycle_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/body_panel_tests.tscn
rg -n "COMER \(\+|cura medio corazón|inicia con 5 HP" prueba_2
```

Expected: ambas suites PASS y `rg` sin coincidencias de contrato obsoleto.

- [ ] **Step 5: Commit**

```powershell
git add AGENTS.md prueba_2/autoload/game_state.gd prueba_2/autoload/inventory.gd prueba_2/ui/body_panel.gd prueba_2/ui/body_panel.tscn prueba_2/ui/hud.tscn prueba_2/tests/run_lifecycle_tests.gd prueba_2/tests/body_panel_tests.gd
git commit -m "feat: ajusta vida y consumo de partes"
```

---

### Task 5: Iluminación, captura, documentación y regresión

**Files:**
- Modify: `prueba_2/world/props/lamp.tscn`
- Modify: `prueba_2/ui/grate_cost_overlay.tscn`
- Modify: `prueba_2/tests/ui_visual_capture.gd`
- Modify: `prueba_2/tests/room_assembly_tests.gd`
- Modify: `prueba_2/docs/ART_SPEC.md`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Produces: `PointLight2D.texture_scale = 1.85`.
- Produces: fixture visual `grate` con pared este libre y retorno oeste.
- Produces: captura `user://grate-wall-flow.png` a 1920 × 1080.

- [ ] **Step 1: Añadir una comprobación fallida de iluminación**

En `room_assembly_tests.gd`, para una lámpara ensamblada:

```gdscript
var light := room.get_node("LampN2/Light") as PointLight2D
_check(is_equal_approx(light.energy, 1.6), "mantiene intensidad de foco")
_check(is_equal_approx(light.texture_scale, 1.85), "amplía radio de foco")
```

- [ ] **Step 2: Ejecutar RED y ajustar la luz**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_assembly_tests.tscn
```

Expected: FAIL porque `texture_scale` todavía es `1.35`.

Cambiar únicamente:

```text
[node name="Light" type="PointLight2D" parent="."]
energy = 1.6
texture_scale = 1.85
```

- [ ] **Step 3: Adaptar el fixture visual**

Para modo `grate`, no conectar una puerta este. Crear `GRATE` en
`Vector2i.RIGHT` y usar:

```gdscript
map.set_grate("CENTER", "GRATE", &"E")
```

Mantener dos partes, selector abierto, primera tarjeta resaltada y la aserción
de que `GameState.current_room == "CENTER"`. Subir el `Hint` del selector para
que quede completamente dentro del panel y no toque su borde inferior.

- [ ] **Step 4: Actualizar documentación operativa**

Documentar en los tres `.md`:

- `grate_direction`, destino adyacente y pared libre;
- escala visual máxima `120 × 120`;
- barrera física de puertas selladas;
- energía `1.6` y radio `1.85`;
- inicio `7/15 HP`, consumo `+2 HP` y texto neutro `F · COMER`;
- pesos de destino `40/40/20`;
- receta de captura y pruebas.

Actualizar además las reglas 15 y 17 de `AGENTS.md` con radio `1.85`,
colocación mural, dirección explícita y pesos `40/40/20`.

Conservar y completar los cambios no confirmados que ya existen en estos
archivos por la Tarea 6 interrumpida; no descartarlos.

- [ ] **Step 5: Generar e inspeccionar captura**

```powershell
$godot = 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe'
$capture = Start-Process -FilePath $godot -ArgumentList @(
	'--path','prueba_2','--windowed','--resolution','1920x1080',
	'res://tests/ui_visual_capture.tscn','--','grate',
	'user://grate-wall-flow.png','1920x1080'
) -WorkingDirectory (Get-Location).Path -PassThru -Wait
if ($capture.ExitCode -ne 0) { exit $capture.ExitCode }
```

Inspeccionar
`C:\Users\jcbla\AppData\Roaming\Godot\app_userdata\Slime Escape\grate-wall-flow.png`
y confirmar:

- rejilla empotrada en la pared este, no dentro de la sala;
- tamaño comparable al hueco de puerta;
- selector sin solapes y selección visible;
- centro de la sala con mejor cobertura luminosa;
- resolución exacta 1920 × 1080.

- [ ] **Step 6: Ejecutar regresión completa**

```powershell
$godot = 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe'
& $godot --headless --path prueba_2 --import
& $godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
& $godot --headless --path prueba_2 res://tests/run_lifecycle_tests.tscn
& $godot --headless --path prueba_2 res://tests/body_panel_tests.tscn
& $godot --headless --path prueba_2 res://tests/room_story_tests.tscn
& $godot --headless --path prueba_2 res://tests/room_assembly_tests.tscn
& $godot --headless --path prueba_2 res://tests/grate_flow_tests.tscn
& $godot --headless --path prueba_2 res://tests/grate_cost_ui_tests.tscn
& $godot --headless --path prueba_2 res://tests/combat_smoke.tscn
& $godot --headless --path prueba_2 --quit-after 3
git ls-files --error-unmatch prueba_2/assets/environment/containment/grate.png
git diff --check
git status --short
```

Expected: import y arranque sin errores; todas las suites PASS; asset
rastreado; ninguna modificación `.uid` generada queda sin trackear.

- [ ] **Step 7: Commit**

```powershell
git add AGENTS.md prueba_2/world/props/lamp.tscn prueba_2/ui/grate_cost_overlay.tscn prueba_2/tests/ui_visual_capture.gd prueba_2/tests/room_assembly_tests.gd prueba_2/docs/ART_SPEC.md docs/ARQUITECTURA.md docs/agents/REFERENCIA.md
git commit -m "docs: registra ajustes jugables de contencion"
```

- [ ] **Step 8: Revisión final del plan**

Comparar `git diff 805fd34..HEAD` con
`docs/superpowers/specs/2026-07-26-ajustes-jugabilidad-contencion-design.md`.
No cerrar con hallazgos P0, P1 o P2 abiertos. Registrar observaciones P3 como
deuda explícita, sin ocultarlas.
