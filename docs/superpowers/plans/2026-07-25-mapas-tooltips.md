# Maps, Health Bar, and Part Tooltips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Presentar el mapa local procedural, la ruta vertical entre pisos, una barra de 15 HP y un panel corporal cuyas partes se conectan orgánicamente al slime y muestran tooltips junto al cursor.

**Architecture:** Los controles de UI solo leen snapshots de `RunManager`, `GameState`, `Inventory` y `PartsDB`, y se actualizan por señales. `MapOverlay` dibuja únicamente el piso actual desde `RunMap`; `FloorRouteOverlay` muestra un nodo por piso; `BodyPanel` y `PartTooltip` comparten metadatos del catálogo sin duplicar textos.

**Tech Stack:** Godot 4.7.1, GDScript tipado, `Control._draw()`, `Curve2D`, escenas `.tscn`, resolución objetivo 1920×1080.

## Global Constraints

- UI objetivo `1920 × 1080`, verificada también a `1280 × 720`.
- TAB muestra solo el mapa local de Contención y admite salas N/E/S/O en cruz.
- La ruta global coloca Contención abajo y Superficie arriba, sin habitaciones.
- La ruta permanece `3.0 s` y se puede continuar antes.
- El tooltip lee `PartsDB`, sigue cursor/foco y nunca sale del viewport.
- Se conservan los nombres `Piel Escamada` y `Cola de Látigo`.
- Cada slot equipado tiene una conexión orgánica al borde del slime.
- Comer, perder o sacrificar elimina tarjeta, tooltip y conexión.
- Ningún overlay sondea inventario o sala desde `_process()`.
- Todos los overlays usan `PROCESS_MODE_ALWAYS` y evitan superponerse.

---

### Task 1: Descripciones únicas en `PartsDB`

**Files:**
- Modify: `prueba_2/core/parts_db.gd`
- Create: `prueba_2/tests/ui_data_tests.gd`

**Interfaces:**
- Produces: `description(id: String) -> String`.

- [ ] **Step 1: Write failing text assertions**

```gdscript
_check(PartsDB.description("serrated_jaw") == "Mordisco a corta distancia.", "mandíbula")
_check(PartsDB.description("mycelium_hand") == "Dispara una línea de raíz que inmoviliza al primer enemigo tocado.", "micelio")
_check(PartsDB.description("crusher_claw") == "Ataque cónico frontal.", "tenaza")
_check(PartsDB.description("scaled_skin") == "Endurecimiento instantáneo que bloquea el siguiente impacto recibido.", "piel")
_check(PartsDB.description("whip_tail") == "Barrido giratorio de 360 grados que repele a los enemigos alrededor.", "cola")
```

- [ ] **Step 2: Verify RED**

Expected: missing `description()`.

- [ ] **Step 3: Add exact descriptions and accessor**

Actualizar los cinco `desc` y añadir:

```gdscript
static func description(id: String) -> String:
	return str(PARTS.get(id, {}).get("desc", ""))
```

- [ ] **Step 4: Verify GREEN and commit**

```powershell
godot --headless --path prueba_2 --script res://tests/ui_data_tests.gd
git add prueba_2/core/parts_db.gd prueba_2/tests/ui_data_tests.gd
git commit -m "feat: centraliza descripciones breves de partes"
```

---

### Task 2: Barra de vida 15 HP

**Files:**
- Modify: `prueba_2/ui/hud.gd`
- Modify: `prueba_2/ui/hud.tscn`
- Create: `prueba_2/tests/hud_tests.gd`
- Create: `prueba_2/tests/hud_tests.tscn`

**Interfaces:**
- Consumes: `GameState.health_changed`, `health_halves`, `max_health_halves`.
- Produces: barra con ratio `hp/max_hp` y texto `5 / 15 HP`.

- [ ] **Step 1: Add failing HUD assertions**

Instanciar HUD, fijar `5/15`, emitir `health_changed` y comprobar:

```gdscript
_check(hud.get_node("Health/Value").text == "5 / 15 HP", "texto HP")
_check(is_equal_approx(hud.health_ratio(), 1.0 / 3.0), "ratio correcto")
```

- [ ] **Step 2: Verify RED**

Expected: node `Health/Value` or `health_ratio()` missing.

- [ ] **Step 3: Implement bar**

Reemplazar gotas por un panel con fondo, relleno recortado y texto. Añadir:

```gdscript
func health_ratio() -> float:
	if GameState.max_health_halves <= 0:
		return 0.0
	return clampf(
		float(GameState.health_halves) / float(GameState.max_health_halves),
		0.0,
		1.0
	)
```

`_on_health_changed()` actualiza texto y `queue_redraw()`.

- [ ] **Step 4: Verify and commit**

```powershell
godot --headless --path prueba_2 res://tests/hud_tests.tscn
git add prueba_2/ui/hud.gd prueba_2/ui/hud.tscn prueba_2/tests/hud_tests.gd prueba_2/tests/hud_tests.tscn
git commit -m "feat: muestra la vida como barra de 15 HP"
```

---

### Task 3: Tooltip que sigue cursor y foco

**Files:**
- Create: `prueba_2/ui/part_tooltip.gd`
- Create: `prueba_2/ui/part_tooltip.tscn`
- Create: `prueba_2/tests/part_tooltip_tests.gd`
- Create: `prueba_2/tests/part_tooltip_tests.tscn`

**Interfaces:**
- Produces: `show_part(part_id, anchor_position)`, `hide_part()`, `clamped_position()`.

- [ ] **Step 1: Add failing tooltip tests**

```gdscript
tooltip.show_part("mycelium_hand", Vector2(1900, 1060))
_check(tooltip.visible, "se muestra")
_check(tooltip.title_text() == "Mano de Micelio", "nombre desde catálogo")
_check(tooltip.body_text().begins_with("Dispara una línea"), "descripción desde catálogo")
var rect: Rect2 = tooltip.tooltip_rect()
_check(rect.end.x <= 1920.0 and rect.end.y <= 1080.0, "queda dentro de 1080p")
tooltip.hide_part()
_check(not tooltip.visible, "se oculta")
```

- [ ] **Step 2: Verify RED**

Expected: scene missing.

- [ ] **Step 3: Implement tooltip**

El componente usa `mouse_filter = MOUSE_FILTER_IGNORE`, consulta `PartsDB` y
posiciona con:

```gdscript
func _clamp_to_viewport(desired: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(
		clampf(desired.x, 8.0, viewport_size.x - size.x - 8.0),
		clampf(desired.y, 8.0, viewport_size.y - size.y - 8.0)
	)
```

- [ ] **Step 4: Verify and commit**

```powershell
godot --headless --path prueba_2 res://tests/part_tooltip_tests.tscn
git add prueba_2/ui/part_tooltip.gd prueba_2/ui/part_tooltip.tscn prueba_2/tests/part_tooltip_tests.gd prueba_2/tests/part_tooltip_tests.tscn
git commit -m "feat: muestra tooltips de partes junto al cursor"
```

---

### Task 4: Panel corporal con conexiones orgánicas

**Files:**
- Create: `prueba_2/ui/body_panel.gd`
- Create: `prueba_2/ui/body_panel.tscn`
- Modify: `prueba_2/ui/map_overlay.tscn`
- Create: `prueba_2/tests/body_panel_tests.gd`
- Create: `prueba_2/tests/body_panel_tests.tscn`

**Interfaces:**
- Consumes: `Inventory.slots_changed`, `PartsDB`.
- Produces: tarjetas por slot, `connection_curve(index) -> PackedVector2Array`, tooltip compartido.

- [ ] **Step 1: Add failing connection tests**

```gdscript
Inventory.pick_up("serrated_jaw")
await get_tree().process_frame
var points: PackedVector2Array = panel.connection_curve(0)
_check(points.size() >= 8, "curva tiene muestras suaves")
_check(panel.slime_rect().has_point(points[0]), "nace en borde del slime")
_check(panel.slot_rect(0).has_point(points[-1]), "termina en tarjeta")
Inventory.consume_slot(0)
await get_tree().process_frame
_check(panel.connection_curve(0).is_empty(), "slot libre elimina conexión")
```

- [ ] **Step 2: Verify RED**

Expected: body panel missing.

- [ ] **Step 3: Implement curves and events**

Distribuir seis tarjetas alrededor del slime. Para cada slot ocupado crear
`Curve2D` con inicio/fin en bordes, dos controles desplazados según índice y
muestrear 12 puntos. `_draw()` pinta primero trazo oscuro grueso y después trazo
interior de `Palette.SLIME_CORE`. Las tarjetas emiten hover/focus hacia
`PartTooltip`.

- [ ] **Step 4: Verify and commit**

```powershell
godot --headless --path prueba_2 res://tests/body_panel_tests.tscn
git add prueba_2/ui/body_panel.gd prueba_2/ui/body_panel.tscn prueba_2/ui/map_overlay.tscn prueba_2/tests/body_panel_tests.gd prueba_2/tests/body_panel_tests.tscn
git commit -m "feat: conecta las partes equipadas al cuerpo del slime"
```

---

### Task 5: Mapa local desde `RunMap`

**Files:**
- Modify: `prueba_2/ui/map_overlay.gd`
- Modify: `prueba_2/ui/map_overlay.tscn`
- Create: `prueba_2/tests/map_overlay_tests.gd`
- Create: `prueba_2/tests/map_overlay_tests.tscn`

**Interfaces:**
- Consumes: `RunManager.map_generated`, `GameState.room_changed`, snapshot de `RunMap`.
- Produces: `build_layout(run_map, panel_rect)`, celdas cardinales y rejillas descubiertas.

- [ ] **Step 1: Add failing cross fixture**

Construir centro `(0,0)` y vecinos N/E/S/O. Comprobar:

```gdscript
var layout: Dictionary = overlay.build_layout(cross_map, Rect2(0, 0, 900, 700))
_check(layout["rooms"].size() == 5, "incluye cinco salas")
_check(_rects_do_not_overlap(layout["rooms"]), "no solapa celdas")
_check(_all_inside(layout["rooms"], Rect2(0, 0, 900, 700)), "cabe en panel")
_check(overlay.visible_room_ids().has("CENTER"), "muestra actual")
_check(not overlay.visible_room_ids().has("HIDDEN"), "oculta no descubierta")
```

- [ ] **Step 2: Verify RED**

Expected: current `_build_layout()` reads fixed `RoomDB.ROOMS`.

- [ ] **Step 3: Switch to floor-local snapshot**

Eliminar niveles apilados. Calcular min/max de `grid`, escala y origen centrado.
Mostrar actual, visitadas y vecinas de visitadas; boss/loot permanecen sin
icono hasta visita. Dibujar conexiones N/E/S/O y rejilla solo si
`GameState.discovered_grates` contiene el origen.

Conectar señales en `_ready()`:

```gdscript
RunManager.map_generated.connect(_on_map_generated)
GameState.room_changed.connect(_on_room_changed)
```

- [ ] **Step 4: Verify at two resolutions and commit**

```powershell
godot --headless --path prueba_2 res://tests/map_overlay_tests.tscn
git add prueba_2/ui/map_overlay.gd prueba_2/ui/map_overlay.tscn prueba_2/tests/map_overlay_tests.gd prueba_2/tests/map_overlay_tests.tscn
git commit -m "feat: dibuja el mapa local procedural de Contención"
```

---

### Task 6: Ruta vertical entre pisos

**Files:**
- Create: `prueba_2/ui/floor_route_overlay.gd`
- Create: `prueba_2/ui/floor_route_overlay.tscn`
- Modify: `prueba_2/game/main.tscn`
- Create: `prueba_2/tests/floor_route_tests.gd`
- Create: `prueba_2/tests/floor_route_tests.tscn`

**Interfaces:**
- Consumes: `RunManager.floor_completed`.
- Produces: overlay de `3.0 s`, orden `-3 → 0`, continuar anticipado.

- [ ] **Step 1: Add failing ordering/timing tests**

```gdscript
RunManager.floor_completed.emit(&"contencion", 2)
await get_tree().process_frame
_check(route.visible, "aparece")
_check(route.floor_order() == [&"surface", &"maintenance", &"biolabs", &"contencion"], "ascenso visual")
_check(route.generated_room_count() == 0, "no dibuja habitaciones")
_check(is_equal_approx(route.DISPLAY_DURATION, 3.0), "dura tres segundos")
```

- [ ] **Step 2: Verify RED**

Expected: scene missing.

- [ ] **Step 3: Implement route overlay**

Usar cuatro nodos, línea vertical, Contención abajo y Superficie arriba.
`PROCESS_MODE_ALWAYS`, pausa exclusiva, temporizador de `3.0`; `ui_accept`,
`dash` o `map` cierran antes. No concede HP: solo reacciona a la señal ya
resuelta por `RunManager`.

- [ ] **Step 4: Verify and commit**

```powershell
godot --headless --path prueba_2 res://tests/floor_route_tests.tscn
git add prueba_2/ui/floor_route_overlay.gd prueba_2/ui/floor_route_overlay.tscn prueba_2/game/main.tscn prueba_2/tests/floor_route_tests.gd prueba_2/tests/floor_route_tests.tscn
git commit -m "feat: muestra la ruta vertical de ascenso"
```

---

### Task 7: Integración visual, documentación y regresión

**Files:**
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: UI completa de Tasks 1–6.
- Produces: contrato visual y operativo actualizado.

- [ ] **Step 1: Run automated UI and project suites**

```powershell
godot --headless --path prueba_2 res://tests/hud_tests.tscn
godot --headless --path prueba_2 res://tests/part_tooltip_tests.tscn
godot --headless --path prueba_2 res://tests/body_panel_tests.tscn
godot --headless --path prueba_2 res://tests/map_overlay_tests.tscn
godot --headless --path prueba_2 res://tests/floor_route_tests.tscn
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
godot --headless --path prueba_2 --quit-after 3
git diff --check
```

- [ ] **Step 2: Capture 1920×1080 and 1280×720 evidence**

Abrir una seed con sala en cruz y todos los slots ocupados. Capturar:

1. mapa local;
2. tooltip en esquina inferior derecha;
3. cuerpo con seis conexiones;
4. ruta de ascenso.

Repetir a `1280×720` y confirmar que no hay clipping.

- [ ] **Step 3: Update documentation**

Documentar layout, señales, fuente de tooltips, clamping, duración de ruta y
comandos de pruebas visuales.

- [ ] **Step 4: Commit**

```powershell
git add AGENTS.md docs/ARQUITECTURA.md docs/agents/REFERENCIA.md
git commit -m "docs: explica mapas tooltips y barra de vida"
```
