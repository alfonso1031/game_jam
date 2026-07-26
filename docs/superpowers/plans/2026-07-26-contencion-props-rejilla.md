# Containment Props and Grate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrar la utilería ilustrada en las salas procedurales de Contención y convertir `Rejilla.png` en la conexión secreta jugable con coste único y retorno gratuito.

**Architecture:** Un catálogo determinista decide props y celdas; `procedural_room.gd` solo ensambla escenas. La rejilla consulta estado de run en `GameState`, cobra mediante `RunManager`, muestra una UI dedicada y viaja mediante `Transition`.

**Tech Stack:** Godot 4.7.1, GDScript tipado, `Sprite2D`, `StaticBody2D`, `Area2D`, escenas `.tscn`, PNG transparente y pruebas headless.

## Global Constraints

- Solo se modifica el piso Contención.
- La rejilla aparece únicamente cuando existe `grate_target`; máximo una por sala y destinos únicos.
- Entrar cobra una parte equipada o 1 HP; regresar desde el destino es gratuito.
- El desbloqueo vive solo durante la partida actual.
- Los carriles de puerta, fila 3 y columna 6 de la rejilla lógica 13 × 7, quedan libres de props sólidos.
- Ningún recurso puede depender del caché local `.godot/`.

---

### Task 1: Recursos ambientales y escenas reutilizables

**Files:**
- Create: `prueba_2/assets/environment/containment/cabinet.png`
- Create: `prueba_2/assets/environment/containment/grate.png`
- Create: `prueba_2/assets/environment/containment/pipe.png`
- Create: `prueba_2/assets/environment/containment/glass_tube.png`
- Create: `prueba_2/assets/environment/containment/broken_glass_tube.png`
- Create: `prueba_2/world/props/containment/cabinet.tscn`
- Create: `prueba_2/world/props/containment/pipe.tscn`
- Create: `prueba_2/world/props/containment/glass_tube.tscn`
- Create: `prueba_2/world/props/containment/broken_glass_tube.tscn`
- Create: `prueba_2/tests/containment_prop_tests.gd`
- Create: `prueba_2/tests/containment_prop_tests.tscn`

**Interfaces:**
- Consumes: `Armario.png`, `Rejilla.png`, `Tubo.png`, `Tubo_Vidrio.png`, `Tubo_Vidrio_Roto.png`.
- Produces: cuatro escenas sólidas o narrativas con método `footprint() -> Rect2`.

- [ ] **Step 1: Escribir la prueba de recursos y colisiones**

La suite debe cargar las cinco texturas y las cuatro escenas. Para cada escena
comprueba un nodo `Sprite`, el método `footprint()`, una huella positiva y que
las colisiones solo estén en la base. Para el tubo roto exige la metadata
`story_prop = true`.

- [ ] **Step 2: Ejecutar y confirmar que falla por recursos ausentes**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/containment_prop_tests.tscn
```

- [ ] **Step 3: Extraer y copiar los PNG**

```powershell
$assetTemp = Join-Path $env:TEMP 'gamejam-containment-assets'
New-Item -ItemType Directory -Force -Path $assetTemp | Out-Null
Expand-Archive -LiteralPath 'C:\Users\jcbla\Downloads\Assets-20260726T044356Z-1-001.zip' -DestinationPath $assetTemp -Force
New-Item -ItemType Directory -Force -Path 'prueba_2\assets\environment\containment' | Out-Null
$copies = @{
	'Armario.png' = 'cabinet.png'
	'Rejilla.png' = 'grate.png'
	'Tubo.png' = 'pipe.png'
	'Tubo_Vidrio.png' = 'glass_tube.png'
	'Tubo_Vidrio_Roto.png' = 'broken_glass_tube.png'
}
foreach ($source in $copies.Keys) {
	Copy-Item -LiteralPath (Join-Path $assetTemp "Assets\$source") -Destination (Join-Path 'prueba_2\assets\environment\containment' $copies[$source])
}
```

- [ ] **Step 4: Crear escenas con colisión de base**

Cada escena usa `StaticBody2D`, un `Sprite2D` y un `CollisionShape2D` rectangular
en el tercio inferior. Añadir un script compartido
`prueba_2/world/props/containment/containment_prop.gd`:

```gdscript
extends StaticBody2D

@export var footprint_size := Vector2(180.0, 120.0)

func footprint() -> Rect2:
	return Rect2(position - footprint_size * 0.5, footprint_size)
```

El tubo roto mantiene el cuerpo en el fondo visual y una base estrecha, de modo
que el slime pueda salir por ambos lados.

- [ ] **Step 5: Importar y ejecutar la suite**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --import
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/containment_prop_tests.tscn
```

- [ ] **Step 6: Commit**

```powershell
git add prueba_2/assets/environment/containment prueba_2/world/props/containment prueba_2/tests/containment_prop_tests.gd prueba_2/tests/containment_prop_tests.tscn
git commit -m "feat: añade utileria ilustrada de contencion"
```

### Task 2: Colocación procedural determinista

**Files:**
- Create: `prueba_2/core/containment_prop_catalog.gd`
- Modify: `prueba_2/world/rooms/procedural_room.gd`
- Modify: `prueba_2/tests/room_story_tests.gd`
- Modify: `prueba_2/tests/room_assembly_tests.gd`

**Interfaces:**
- Consumes: `ContainmentPropCatalog.placements_for(room_data: Dictionary)`.
- Produces: `placements_for(...) -> Array[Dictionary]` con claves `scene`, `id` y `position`.

- [ ] **Step 1: Escribir pruebas de la receta**

Exigir que:

```gdscript
var first := ContainmentPropCatalog.placements_for(fixture)
var second := ContainmentPropCatalog.placements_for(fixture)
_check(first == second, "la misma sala conserva props")
for item: Dictionary in first:
	var cell := item["cell"] as Vector2i
	_check(cell.x != 6 and cell.y != 3, "deja carriles de puerta")
```

En `room_story_tests.gd`, exigir `BrokenGlassTube` en la sala `entry` y ausencia
en `body` y `normal`. En `room_assembly_tests.gd`, recorrer varias salas y
comprobar que las huellas de props no contienen `DoorN/E/S/O`, `SpawnN/E/S/O`
ni `BODY_POSITION`.

- [ ] **Step 2: Ejecutar y confirmar los fallos**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_story_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_assembly_tests.tscn
```

- [ ] **Step 3: Implementar el catálogo**

`containment_prop_catalog.gd` precarga las cuatro escenas y usa estas celdas:

```gdscript
const SAFE_CELLS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(4, 1), Vector2i(8, 1), Vector2i(11, 1),
	Vector2i(1, 5), Vector2i(4, 5), Vector2i(8, 5), Vector2i(11, 5),
]
```

La selección usa un hash estable de `room_data["id"]`; no usa `randf()`. La
entrada devuelve solo el tubo roto centrado en `Vector2(960, 500)`. Las salas
`body`, `preboss` y `boss_choice` no reciben utilería aleatoria. Una sala normal
recibe entre uno y tres elementos sin repetir celda.

- [ ] **Step 4: Instanciar desde `procedural_room.gd`**

Añadir `_build_environment_props()` después de paredes y antes de contenido
narrativo. Cada instancia recibe nombre `Prop_<id>_<index>`, posición del
catálogo y metadata `prop_id`.

- [ ] **Step 5: Ejecutar las pruebas procedurales**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/containment_prop_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_story_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_assembly_tests.tscn
```

- [ ] **Step 6: Commit**

```powershell
git add prueba_2/core/containment_prop_catalog.gd prueba_2/world/rooms/procedural_room.gd prueba_2/tests/room_story_tests.gd prueba_2/tests/room_assembly_tests.gd
git commit -m "feat: distribuye props por seed en contencion"
```

### Task 3: Estado bidireccional de la rejilla

**Files:**
- Modify: `prueba_2/core/run_map.gd`
- Modify: `prueba_2/core/map_generator.gd`
- Modify: `prueba_2/autoload/game_state.gd`
- Modify: `prueba_2/tests/run_map_tests.gd`
- Modify: `prueba_2/tests/run_lifecycle_tests.gd`

**Interfaces:**
- Produces: campo de sala `grate_source`; `GameState.unlock_grate(source_id: String)`, `GameState.is_grate_unlocked(source_id: String) -> bool`.

- [ ] **Step 1: Añadir pruebas del origen y del desbloqueo**

En `run_map_tests.gd` exigir:

```gdscript
map.set_grate("R1", "RG")
_check(map.room("R1")["grate_target"] == "RG", "registra destino")
_check(map.room("RG")["grate_source"] == "R1", "registra retorno")
```

En `run_lifecycle_tests.gd` desbloquear `R1`, comprobar el resultado y ejecutar
`start_new_run(777)` para verificar que el desbloqueo desaparece.

- [ ] **Step 2: Ejecutar y confirmar los fallos**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --script res://tests/run_map_tests.gd
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/run_lifecycle_tests.tscn
```

- [ ] **Step 3: Implementar el contrato**

`RunMap.add_room()` inicializa `"grate_source": ""`; `set_grate()` escribe
destino y origen. `MapGenerator.validate()` comprueba que el origen del destino
coincida y que cada destino solo tenga uno.

En `GameState`:

```gdscript
var unlocked_grates: Dictionary = {}

func unlock_grate(source_id: String) -> void:
	if not source_id.is_empty():
		unlocked_grates[source_id] = true

func is_grate_unlocked(source_id: String) -> bool:
	return unlocked_grates.get(source_id, false)
```

`reset_run()` vacía `unlocked_grates`.

- [ ] **Step 4: Ejecutar las pruebas**

Ejecutar los dos comandos del paso 2 y esperar `PASS`.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/core/run_map.gd prueba_2/core/map_generator.gd prueba_2/autoload/game_state.gd prueba_2/tests/run_map_tests.gd prueba_2/tests/run_lifecycle_tests.gd
git commit -m "feat: modela retorno gratuito de rejillas"
```

### Task 4: Prop de rejilla y transición

**Files:**
- Create: `prueba_2/world/props/grate.gd`
- Create: `prueba_2/world/props/grate.tscn`
- Modify: `prueba_2/world/rooms/procedural_room.gd`
- Modify: `prueba_2/autoload/transition.gd`
- Create: `prueba_2/tests/grate_flow_tests.gd`
- Create: `prueba_2/tests/grate_flow_tests.tscn`

**Interfaces:**
- Produces: `Grate.configure(source_id: String, target_id: String, requires_cost: bool)` y `Transition.go_via_grate(target_id: String)`.
- Consumes: grupo `grate_cost_ui` con método `open(source_id, target_id)`.

- [ ] **Step 1: Escribir pruebas de ensamblaje y viaje**

Construir un `RunMap` con `SOURCE` y `TARGET`, llamar `set_grate()` y exigir:

- un nodo `Grate` en cada sala;
- el origen requiere coste y el retorno no;
- `TARGET` apunta de vuelta a `SOURCE`;
- ambos cuartos tienen `GrateSpawn`;
- `go_via_grate("TARGET")` actualiza `GameState.current_room` y coloca al jugador
  en `GrateSpawn`.

- [ ] **Step 2: Ejecutar y confirmar el fallo**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/grate_flow_tests.tscn
```

- [ ] **Step 3: Crear la escena funcional**

`grate.tscn` usa `Area2D`, la textura `grate.png`, una colisión elíptica y un
`Label` oculto con `E · USAR REJILLA`. `grate.gd` arma la interacción después de
dos frames de física para no reactivarse al aparecer.

Al pulsar `interact`:

```gdscript
if not requires_cost or GameState.is_grate_unlocked(source_room_id):
	Transition.go_via_grate(target_room_id)
else:
	var ui := get_tree().get_first_node_in_group("grate_cost_ui")
	if ui != null:
		ui.open(source_room_id, target_room_id)
```

- [ ] **Step 4: Ensamblar origen, destino y spawn**

En `procedural_room.gd`, `_build_grate()`:

- origen: posición `Vector2(1650, 540)`, coste verdadero;
- destino: posición `Vector2(960, 540)`, coste falso;
- `GrateSpawn`: 180 px hacia el interior respecto a la rejilla.

Llamar `_build_grate()` una sola vez en `configure()`.

- [ ] **Step 5: Añadir la transición dedicada**

`Transition.go_via_grate()` reutiliza el mismo fundido de `go_to()`, ensambla el
destino, busca `GrateSpawn`, actualiza sala y libera `_busy`. No interpreta
direcciones de puerta.

- [ ] **Step 6: Ejecutar la suite**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/grate_flow_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_assembly_tests.tscn
```

- [ ] **Step 7: Commit**

```powershell
git add prueba_2/world/props/grate.gd prueba_2/world/props/grate.tscn prueba_2/world/rooms/procedural_room.gd prueba_2/autoload/transition.gd prueba_2/tests/grate_flow_tests.gd prueba_2/tests/grate_flow_tests.tscn
git commit -m "feat: materializa conexiones por rejilla"
```

### Task 5: Selector de coste

**Files:**
- Create: `prueba_2/ui/grate_cost_overlay.gd`
- Create: `prueba_2/ui/grate_cost_overlay.tscn`
- Modify: `prueba_2/game/main.tscn`
- Create: `prueba_2/tests/grate_cost_ui_tests.gd`
- Create: `prueba_2/tests/grate_cost_ui_tests.tscn`

**Interfaces:**
- Produces: `open(source_id: String, target_id: String) -> void`, `cancel()`, `confirm_selection()`.
- Consumes: `RunManager.pay_grate_cost(slot_index, confirm_lethal)` y `Transition.go_via_grate(target_id)`.

- [ ] **Step 1: Escribir pruebas de navegación y coste**

La prueba equipa dos partes, abre el overlay y exige:

- opciones solo para slots ocupados más una opción `½ CORAZÓN`;
- izquierda/derecha cambia `selected_option`;
- la tarjeta seleccionada usa escala `1.08` y borde cálido;
- cancelar no muta vida ni partes;
- elegir parte sacrifica el slot y desbloquea el origen;
- elegir vida con 1 HP muestra confirmación letal sin cobrar;
- confirmar de nuevo permite la muerte y no intenta viajar.

- [ ] **Step 2: Ejecutar y confirmar el fallo**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/grate_cost_ui_tests.tscn
```

- [ ] **Step 3: Implementar el overlay**

La escena pertenece al grupo `grate_cost_ui`, usa
`PROCESS_MODE_ALWAYS`, pausa al abrir y muestra un `HBoxContainer` de opciones.
Cada tarjeta de parte obtiene nombre desde `PartsDB.display_name()`. La opción
de vida siempre está al final.

`confirm_selection()`:

```gdscript
var result := RunManager.pay_grate_cost(slot_index, _confirming_lethal)
match result:
	&"confirmation_required":
		_confirming_lethal = true
		warning.text = "ESTA DECISIÓN TERMINA LA PARTIDA · CONFIRMA OTRA VEZ"
	&"part", &"hp":
		GameState.unlock_grate(_source_id)
		_close()
		Transition.go_via_grate(_target_id)
	&"death":
		_close()
```

`pause` cancela; `move_left` y `move_right` navegan; `interact` confirma.

- [ ] **Step 4: Instanciar en `main.tscn`**

Añadir `GrateLayer` en capa 18 y una instancia `GrateCostOverlay`. Debe quedar
debajo de pausa y resumen, pero encima del mapa y del fundido normal.

- [ ] **Step 5: Ejecutar pruebas funcionales**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/grate_cost_ui_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/grate_flow_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/run_lifecycle_tests.tscn
```

- [ ] **Step 6: Commit**

```powershell
git add prueba_2/ui/grate_cost_overlay.gd prueba_2/ui/grate_cost_overlay.tscn prueba_2/game/main.tscn prueba_2/tests/grate_cost_ui_tests.gd prueba_2/tests/grate_cost_ui_tests.tscn
git commit -m "feat: permite elegir el coste de la rejilla"
```

### Task 6: Documentación, assets rastreados y regresión

**Files:**
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`
- Modify: `prueba_2/docs/ART_SPEC.md`
- Modify: `prueba_2/tests/ui_visual_capture.gd`

**Interfaces:**
- Produces: modo de captura `grate` y documentación operativa.

- [ ] **Step 1: Documentar responsabilidades**

Registrar catálogo, escenas, `grate_source`, coste único, retorno gratuito,
selector y posiciones reservadas. Añadir las dimensiones originales de cada
PNG al `ART_SPEC`.

- [ ] **Step 2: Añadir fixture visual de rejilla**

El modo `grate` genera una sala fuente con conexión y muestra el overlay con dos
partes equipadas, sin cambiar de sala.

- [ ] **Step 3: Generar captura y revisarla**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- grate user://grate-flow.png 1920x1080
```

Verificar escala del prop, prompt, selección resaltada y ausencia de solapes.

- [ ] **Step 4: Ejecutar regresión**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --import
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --script res://tests/run_map_tests.gd
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/run_lifecycle_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_story_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/room_assembly_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/grate_flow_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/grate_cost_ui_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/combat_smoke.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --quit-after 3
git ls-files --error-unmatch prueba_2/assets/environment/containment/cabinet.png prueba_2/assets/environment/containment/grate.png prueba_2/assets/environment/containment/pipe.png prueba_2/assets/environment/containment/glass_tube.png prueba_2/assets/environment/containment/broken_glass_tube.png
```

- [ ] **Step 5: Commit**

```powershell
git add docs/ARQUITECTURA.md docs/agents/REFERENCIA.md prueba_2/docs/ART_SPEC.md prueba_2/tests/ui_visual_capture.gd
git commit -m "docs: registra props y flujo de rejillas"
```
