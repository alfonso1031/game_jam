# Limpieza de UI y tutorial ambiental Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retirar texto explicativo redundante de la interfaz y enseñar el movimiento cargado mediante un mural permanente en la primera sala.

**Architecture:** Las escenas de UI conservan solo información operativa. `TutorialMural` es un prop visual del mundo, instanciado por `ProceduralRoom` al reconocer `entry/tutorial`; no usa `CanvasLayer`, no pausa y no conoce inputs.

**Tech Stack:** Godot 4.7.1, GDScript tipado, escenas `.tscn`, PNG transparente, pruebas headless y captura a 1920×1080.

## Global Constraints

- Portada: conservar nombre, slime y `PULSA CUALQUIER TECLA`.
- Eliminar de portada el subtítulo y el bloque actual de controles.
- HUD: conservar barra/valor de vida y barra de carga; eliminar `BIOMASA`, nivel y sala.
- Mapa: conservar diagrama, cuerpo y tooltips; eliminar título, leyenda y ayuda `TAB`.
- Conservar texto necesario en inventario, pausa, pickups, recompensas y resumen.
- El mural enseña solo mantener dirección, cargar y soltar.
- No enseñar `TAB`, inventario, pausa, pantalla completa ni DASH.
- Los futuros botones de portada están fuera de alcance.

---

### Task 1: Contrato de texto operativo

**Files:**
- Create: `prueba_2/tests/ui_cleanup_tests.gd`
- Create: `prueba_2/tests/ui_cleanup_tests.tscn`
- Modify: `prueba_2/ui/title.tscn:33-56`
- Modify: `prueba_2/ui/hud.tscn:30-92`
- Modify: `prueba_2/ui/hud.gd:11-57`
- Modify: `prueba_2/ui/map_overlay.tscn:8-47`

**Interfaces:**
- Produces: escenas sin nodos `Subtitle`, `Controls`, `Caption`, `LevelLabel`, `RoomLabel`, `Title`, `Legend` ni `Hint`.
- Conserva: `Title/TitleLabel`, `Title/Prompt`, `HUD/Health`, `MapOverlay/BodyPanel`.

- [ ] **Step 1: Crear pruebas de presencia y ausencia**

`ui_cleanup_tests.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/ui_cleanup_tests.gd" id="1"]

[node name="UICleanupTests" type="Node"]
script = ExtResource("1")
```

En `ui_cleanup_tests.gd`:

```gdscript
var title: Control = load("res://ui/title.tscn").instantiate()
add_child(title)
_check(title.has_node("TitleLabel"), "la portada conserva el nombre")
_check(title.has_node("Prompt"), "la portada conserva la acción de inicio")
_check(not title.has_node("Subtitle"), "la portada elimina el subtítulo")
_check(not title.has_node("Controls"), "la portada elimina controles")

var hud: Control = load("res://ui/hud.tscn").instantiate()
add_child(hud)
_check(hud.has_node("Health/Track"), "el HUD conserva la barra")
_check(hud.has_node("Health/Value"), "el HUD conserva el valor")
_check(not hud.has_node("Health/Caption"), "el HUD elimina BIOMASA")
_check(not hud.has_node("LevelLabel"), "el HUD elimina nivel")
_check(not hud.has_node("RoomLabel"), "el HUD elimina sala")

var map: Control = load("res://ui/map_overlay.tscn").instantiate()
add_child(map)
_check(map.has_node("BodyPanel"), "el mapa conserva el cuerpo")
_check(not map.has_node("Title"), "el mapa elimina título")
_check(not map.has_node("Legend"), "el mapa elimina leyenda")
_check(not map.has_node("Hint"), "el mapa elimina ayuda")
```

- [ ] **Step 2: Ejecutar y confirmar el fallo**

```powershell
godot --headless --path prueba_2 res://tests/ui_cleanup_tests.tscn
```

Expected: FAIL porque los ocho nodos redundantes aún existen.

- [ ] **Step 3: Retirar nodos y referencias**

Eliminar los nodos indicados de los tres `.tscn`. En `hud.gd`, quitar los
`@onready` de nivel/sala y `_refresh_labels()`. Mantener la conexión
`room_changed` únicamente para `queue_redraw()` del minimapa:

```gdscript
func _on_room_changed(_room_id: String) -> void:
	queue_redraw()
```

No modificar `inventory_ui.gd`, `pause_menu.tscn`, `part_pickup.gd`,
`floor_route_overlay.tscn` ni `run_summary.tscn`.

- [ ] **Step 4: Ejecutar UI y regresiones**

```powershell
godot --headless --path prueba_2 res://tests/ui_cleanup_tests.tscn
godot --headless --path prueba_2 res://tests/hud_tests.tscn
godot --headless --path prueba_2 res://tests/map_overlay_tests.tscn
godot --headless --path prueba_2 res://tests/body_panel_tests.tscn
```

Expected: todas PASS.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/tests/ui_cleanup_tests.gd prueba_2/tests/ui_cleanup_tests.tscn prueba_2/ui/title.tscn prueba_2/ui/hud.tscn prueba_2/ui/hud.gd prueba_2/ui/map_overlay.tscn
git commit -m "refactor: retira texto redundante de la interfaz"
```

---

### Task 2: Asset y escena del mural

**Files:**
- Create: `prueba_2/assets/environment/tutorial/charged_movement_mural.png`
- Create: `prueba_2/world/props/tutorial_mural.tscn`
- Create: `prueba_2/world/props/tutorial_mural.gd`
- Modify: `prueba_2/tests/room_story_tests.gd`

**Interfaces:**
- Produces: `TutorialMural` visual, sin input ni pausa.
- Produces: `footprint() -> Rect2` para validar espacio libre.

- [ ] **Step 1: Añadir prueba fallida del recurso y escena**

En `room_story_tests.gd`:

```gdscript
_check(
	load("res://assets/environment/tutorial/charged_movement_mural.png") is Texture2D,
	"el mural importa como textura"
)
var mural: Node2D = load("res://world/props/tutorial_mural.tscn").instantiate()
add_child(mural)
_check(mural.has_method("footprint"), "el mural expone su huella")
_check(not (mural is CanvasLayer), "el tutorial pertenece al mundo")
_check(mural.process_mode != Node.PROCESS_MODE_ALWAYS, "el mural no opera durante pausa")
```

- [ ] **Step 2: Generar el mural sin texto explicativo**

Usar la skill `imagegen` con:

```text
Decal de tutorial para el suelo de un laboratorio biológico visto exactamente
desde arriba. Secuencia horizontal sin palabras: grupo de teclas WASD y flechas
presionadas, slime verde estirando solo su frente con una barra que se llena,
símbolo claro de soltar la tecla, y el slime avanzando por arrastre. Pintura
industrial gastada, paleta cian verdosa y crema, alto contraste sobre suelo
oscuro, sin TAB, inventario, pausa, pantalla completa ni dash, sin frases,
elemento aislado para juego 2D.
```

Generar con chroma key, retirar el fondo con el helper de `imagegen`, guardar
`charged_movement_mural.png` y verificarlo con `view_image`.

- [ ] **Step 3: Crear escena pasiva**

`tutorial_mural.gd`:

```gdscript
extends Node2D

const SIZE := Vector2(760.0, 190.0)

func footprint() -> Rect2:
	return Rect2(position - SIZE * 0.5, SIZE)
```

`tutorial_mural.tscn` contiene raíz `Node2D`, el script y un `Sprite2D` con la
textura. Ajustar `scale` para que la huella sea `760×190 px`, `z_index = -3` y
`modulate.a` entre `0.72` y `0.85` para parecer pintura del suelo.

- [ ] **Step 4: Importar, ejecutar y commit**

```powershell
godot --headless --path prueba_2 --import
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
git add prueba_2/assets/environment/tutorial prueba_2/world/props/tutorial_mural.gd prueba_2/world/props/tutorial_mural.tscn prueba_2/tests/room_story_tests.gd
git commit -m "art: añade el mural de movimiento cargado"
```

---

### Task 3: Mural obligatorio solo en la primera sala

**Files:**
- Modify: `prueba_2/world/rooms/procedural_room.gd`
- Modify: `prueba_2/tests/room_story_tests.gd`

**Interfaces:**
- Consumes: descriptor con `role == &"entry"` y `content_type == &"tutorial"`.
- Produces: exactamente un hijo `TutorialMural` en la primera sala.

- [ ] **Step 1: Añadir pruebas de ubicación**

Para las cuatro orientaciones cardinales ya creadas en `room_story_tests.gd`:

```gdscript
var mural := entry.get_node_or_null("TutorialMural") as Node2D
_check(mural != null, "%s siempre incluye mural" % direction)
_check(body.get_node_or_null("TutorialMural") == null, "%s no repite mural" % direction)
if mural != null:
	var rect: Rect2 = mural.footprint()
	_check(not rect.has_point(Vector2(960, 540)), "%s deja libre el spawn" % direction)
	for door_position: Vector2 in [
		Vector2(960, 60),
		Vector2(1800, 540),
		Vector2(960, 1020),
		Vector2(120, 540),
	]:
		_check(not rect.grow(80.0).has_point(door_position), "%s deja libres puertas" % direction)
```

- [ ] **Step 2: Ejecutar y confirmar el fallo**

```powershell
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
```

Expected: FAIL porque la sala no contiene `TutorialMural`.

- [ ] **Step 3: Instanciar por rol/contenido**

En `procedural_room.gd`:

```gdscript
const TutorialMuralScene := preload("res://world/props/tutorial_mural.tscn")
const TUTORIAL_MURAL_POSITION := Vector2(960.0, 790.0)

func _build_tutorial_mural() -> void:
	if (
		_room_data.get("role", &"normal") != &"entry"
		or _room_data.get("content_type", &"empty") != &"tutorial"
	):
		return
	var mural: Node2D = TutorialMuralScene.instantiate()
	mural.name = "TutorialMural"
	mural.position = TUTORIAL_MURAL_POSITION
	add_child(mural)
```

Llamar `_build_tutorial_mural()` desde `configure()` después del fondo y antes de
actores. Si la salida sur intersecta la posición base, desplazar el mural a
`Vector2(960, 290)`; elegir entre ambas usando `doors.has("S")`.

- [ ] **Step 4: Ejecutar pruebas**

```powershell
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
```

Expected: ambas PASS en N/E/S/O.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/world/rooms/procedural_room.gd prueba_2/tests/room_story_tests.gd
git commit -m "feat: enseña el movimiento en la primera sala"
```

---

### Task 4: Documentación y evidencia visual de UI

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`
- Modify: `prueba_2/tests/ui_visual_capture.gd:13-44`

**Interfaces:**
- Produces: modos de captura `title`, `hud`, `map` y `tutorial`.

- [ ] **Step 1: Extender el capturador visual**

Añadir modo `title` que instancia `title.tscn` y modo `tutorial` que genera la
seed `1785033756`, construye la entrada con `RoomAssembler` y centra la cámara.
Mantener salida PNG al tamaño físico solicitado.

- [ ] **Step 2: Generar capturas a 1920×1080**

```powershell
godot --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- title user://title-clean.png 1920x1080
godot --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- hud user://hud-clean.png 1920x1080
godot --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- map user://map-clean.png 1920x1080
godot --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- tutorial user://tutorial-mural.png 1920x1080
```

Inspeccionar las cuatro imágenes con `view_image`. Confirmar que no quedan textos
eliminados, no hay solapes y el mural se lee como parte del suelo.

- [ ] **Step 3: Ejecutar suite de UI y arranque**

```powershell
godot --headless --path prueba_2 res://tests/ui_cleanup_tests.tscn
godot --headless --path prueba_2 res://tests/hud_tests.tscn
godot --headless --path prueba_2 res://tests/map_overlay_tests.tscn
godot --headless --path prueba_2 res://tests/body_panel_tests.tscn
godot --headless --path prueba_2 res://tests/part_tooltip_tests.tscn
godot --headless --path prueba_2 res://tests/room_story_tests.tscn
godot --headless --path prueba_2 --quit-after 3
```

Expected: código 0 en todos los comandos.

- [ ] **Step 4: Documentar y commit**

Registrar que los controles secundarios esperan el futuro menú con botones y
que la primera sala solo enseña el movimiento cargado.

```powershell
git add AGENTS.md docs/ARQUITECTURA.md docs/agents/REFERENCIA.md prueba_2/tests/ui_visual_capture.gd
git commit -m "docs: explica la interfaz sin texto redundante"
```
