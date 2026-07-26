# Movilidad por piernas, anticipación del boss e input de TAB Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Activar movimiento continuo al equipar cualquier parte de pierna, ampliar la anticipación de la Quimera sin textos de estado y garantizar navegación de `TAB` con WASD y flechas.

**Architecture:** `PartsDB` conserva el tipo corporal de cada parte e `Inventory` ofrece un conteo derivado sin guardar estado duplicado. `Slime` selecciona entre su máquina cargada y un desplazamiento continuo, manteniendo DASH, estados y knockback como prioridades. El boss conserva su máquina de estados y el overlay conserva `BodyPanel` como autoridad de la selección.

**Tech Stack:** Godot 4.7.1, GDScript, escenas `.tscn`, pruebas headless integradas.

## Global Constraints

- Los seis slots del inventario siguen siendo genéricos.
- Una parte es pierna únicamente cuando `PartsDB.slot_of(id) == PartsDB.SLOT_PIERNA`.
- Una o más piernas activan movimiento continuo a `280 px/s`; cero piernas conservan el impulso cargado.
- El movimiento del slime usa `move_and_collide()`, nunca `move_and_slide()`.
- DASH, DASH de partes, knockback y `root` conservan prioridad.
- La Quimera mantiene `12 HP`, daño, velocidad, recompensas y ciclo `SEEK_CORNER → CORNER_AIM → POUNCE → RECOVER`.
- La anticipación por fase es exactamente `[1.35, 1.08, 0.84]` segundos.
- `StateLabel` y todos los textos de acción del boss desaparecen; la barra, línea y objetivo permanecen.
- `TAB` acepta WASD y flechas sin añadir texto explicativo a la UI.
- No incluir cambios ajenos ya presentes en el worktree al preparar commits.

---

### Task 1: Consulta de partes equipadas por tipo

**Files:**
- Create: `prueba_2/tests/leg_mobility_tests.gd`
- Create: `prueba_2/tests/leg_mobility_tests.tscn`
- Modify: `prueba_2/autoload/inventory.gd:45-65`

**Interfaces:**
- Consumes: `PartsDB.slot_of(part_id: String) -> String` y `Inventory.slots: Array[String]`.
- Produces: `Inventory.equipped_count_for_slot(slot_type: String) -> int`.

- [ ] **Step 1: Crear la escena de prueba**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/leg_mobility_tests.gd" id="1"]

[node name="LegMobilityTests" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Escribir la prueba fallida del conteo**

```gdscript
extends Node

const PartsDB := preload("res://core/parts_db.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Inventory.reset_run()
	_check(
		Inventory.has_method("equipped_count_for_slot"),
		"Inventory expone el conteo por tipo corporal"
	)
	if Inventory.has_method("equipped_count_for_slot"):
		_check(
			Inventory.call("equipped_count_for_slot", PartsDB.SLOT_PIERNA) == 0,
			"sin piernas el conteo es cero"
		)
		Inventory.slots[0] = "hydraulic_legs"
		_check(
			Inventory.call("equipped_count_for_slot", PartsDB.SLOT_PIERNA) == 1,
			"una parte de pierna cuenta una vez"
		)
		Inventory.slots[1] = "whip_tail"
		_check(
			Inventory.call("equipped_count_for_slot", PartsDB.SLOT_PIERNA) == 2,
			"dos partes de pierna quedan disponibles para reglas futuras"
		)
		Inventory.slots[2] = "serrated_jaw"
		_check(
			Inventory.call("equipped_count_for_slot", PartsDB.SLOT_PIERNA) == 2,
			"una parte de cabeza no altera el conteo de piernas"
		)
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("PASS: leg mobility" if failures.is_empty() else "FAIL: leg mobility")
	get_tree().quit(0 if failures.is_empty() else 1)
```

- [ ] **Step 3: Ejecutar la prueba y observar el fallo correcto**

Run:

```powershell
& (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source --headless --path prueba_2 res://tests/leg_mobility_tests.tscn
```

Expected: `FAIL: leg mobility` porque `Inventory` todavía no expone `equipped_count_for_slot`.

- [ ] **Step 4: Implementar el conteo puro**

Añadir junto a `equipped_ids()`:

```gdscript
func equipped_count_for_slot(slot_type: String) -> int:
	var count := 0
	for part_id in slots:
		if part_id != "" and PartsDB.slot_of(part_id) == slot_type:
			count += 1
	return count
```

- [ ] **Step 5: Ejecutar la prueba y confirmar verde**

Run:

```powershell
& (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source --headless --path prueba_2 res://tests/leg_mobility_tests.tscn
```

Expected: `PASS: leg mobility`, exit code `0`.

- [ ] **Step 6: Commit aislado**

```powershell
git add -- prueba_2/autoload/inventory.gd prueba_2/tests/leg_mobility_tests.gd prueba_2/tests/leg_mobility_tests.tscn
git commit -m "feat: count equipped parts by body type"
```

---

### Task 2: Movimiento continuo del slime con piernas

**Files:**
- Modify: `prueba_2/actors/player/slime.gd:9-160`
- Modify: `prueba_2/actors/player/slime.gd:690-750`
- Modify: `prueba_2/tests/leg_mobility_tests.gd`

**Interfaces:**
- Consumes: `Inventory.equipped_count_for_slot(PartsDB.SLOT_PIERNA) -> int`, `Inventory.slots_changed`, acciones `move_left/right/up/down`.
- Produces: `Slime.leg_count() -> int`, `Slime.uses_continuous_movement() -> bool`, `_advance_continuous(delta: float) -> void`.

- [ ] **Step 1: Ampliar la prueba con el contrato del slime**

Precargar `SlimeScene`, convertir `_run()` en `async` y, después del conteo, limpiar el inventario y añadir:

```gdscript
const SlimeScene := preload("res://actors/player/slime.tscn")
const FRAME_TIME := 1.0 / 60.0


func _run() -> void:
	# Mantener primero las comprobaciones de Task 1.
	Inventory.reset_run()
	var player: CharacterBody2D = SlimeScene.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)

	_check(player.has_method("leg_count"), "el slime expone cuántas piernas tiene")
	_check(
		player.has_method("uses_continuous_movement"),
		"el slime expone el modo de movimiento actual"
	)
	if player.has_method("uses_continuous_movement"):
		_check(
			not player.call("uses_continuous_movement"),
			"sin piernas conserva el movimiento cargado"
		)

	Inventory.slots[0] = "hydraulic_legs"
	Inventory.slots_changed.emit()
	_check(player.call("leg_count") == 1, "una pierna llega al controlador")
	_check(player.call("uses_continuous_movement"), "una pierna activa movimiento continuo")

	var before := player.position
	Input.action_press("move_right")
	player.call("_advance_continuous", FRAME_TIME)
	Input.action_release("move_right")
	_check(
		is_equal_approx(player.position.x - before.x, 280.0 * FRAME_TIME),
		"el movimiento continuo avanza a 280 px/s"
	)
	_check(player.aim_direction() == Vector2.RIGHT, "caminar actualiza el apuntado")

	player.apply_status(PartsDB.STATUS_ROOT, 1.0)
	before = player.position
	Input.action_press("move_right")
	player.call("_advance_continuous", FRAME_TIME)
	Input.action_release("move_right")
	_check(player.position == before, "root bloquea el movimiento continuo")
	player.set("_status", {})

	Inventory.clear_slot(0)
	_check(not player.call("uses_continuous_movement"), "perder la última pierna restaura la carga")
	player.queue_free()
	await get_tree().process_frame
	_finish()
```

Eliminar la llamada anterior a `_finish()` para que solo se ejecute al final.

- [ ] **Step 2: Ejecutar la prueba y observar el fallo correcto**

Run:

```powershell
& (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source --headless --path prueba_2 res://tests/leg_mobility_tests.tscn
```

Expected: FAIL porque `Slime` todavía no ofrece `leg_count`, `uses_continuous_movement` ni `_advance_continuous`.

- [ ] **Step 3: Añadir estado y API de movilidad**

Junto a las constantes de movimiento:

```gdscript
const CONTINUOUS_MOVE_SPEED := 280.0
```

Junto a las variables del controlador:

```gdscript
var _leg_count := 0
var _continuous_moving := false
```

En `_ready()`:

```gdscript
Inventory.slots_changed.connect(_refresh_leg_mobility)
_refresh_leg_mobility()
```

Añadir:

```gdscript
func leg_count() -> int:
	return _leg_count


func uses_continuous_movement() -> bool:
	return _leg_count > 0


func _refresh_leg_mobility() -> void:
	var previous := _leg_count
	_leg_count = Inventory.equipped_count_for_slot(PartsDB.SLOT_PIERNA)
	if previous == 0 and _leg_count > 0 and _state == State.CHARGING:
		slime_audio.stop_charge()
		_state = State.IDLE
		_charge_time = 0.0
		_speed_ratio = 0.0
		velocity = Vector2.ZERO
	if previous > 0 and _leg_count == 0:
		_continuous_moving = false
		_state = State.IDLE
		velocity = Vector2.ZERO
```

- [ ] **Step 4: Integrar el movimiento sin romper prioridades**

En `_physics_process()`, conservar primero `PART_DASH`, `DASHING` y `_try_dash()`. En el
ramal normal usar:

```gdscript
	elif not _try_dash():
		if uses_continuous_movement():
			if _state == State.RECOVERING:
				_advance_recovery(delta)
			else:
				_state = State.IDLE
				_advance_continuous(delta)
		else:
			_continuous_moving = false
			match _state:
				State.IDLE:
					var input_dir := _input_direction()
					if input_dir != Vector2.ZERO:
						_begin_charge(input_dir)
				State.CHARGING:
					if _has_direction_held():
						_update_charge(delta)
					else:
						_release_charge()
				State.LAUNCHING:
					_advance_launch(delta)
				State.RECOVERING:
					_advance_recovery(delta)
```

Añadir:

```gdscript
func _advance_continuous(delta: float) -> void:
	if has_status(PartsDB.STATUS_ROOT) or not _knockback.is_zero_approx():
		_continuous_moving = false
		velocity = Vector2.ZERO
		return
	var direction := _input_direction()
	_continuous_moving = direction != Vector2.ZERO
	if not _continuous_moving:
		velocity = Vector2.ZERO
		return
	direction = direction.normalized()
	_facing = direction
	velocity = direction * CONTINUOUS_MOVE_SPEED
	move_and_collide(velocity * delta)
```

- [ ] **Step 5: Mantener el arrastre visual continuo**

En `_update_visual(delta)`, reemplazar el avance exclusivo de `launching` por:

```gdscript
	var crawling := launching or _continuous_moving
	if crawling:
		_crawl_phase += delta * 9.0

	if _state == State.CHARGING or crawling:
		body.polygon = _deform_points(_body_base, charge, _crawl_phase, crawling)
		core.polygon = _deform_points(_core_base, charge * 0.65, _crawl_phase, crawling)
```

Antes del `match _state`, si `_continuous_moving`:

```gdscript
	if _continuous_moving:
		body.rotation = lerp_angle(
			body.rotation,
			_facing.angle(),
			1.0 - exp(-14.0 * delta)
		)
```

En el caso `State.IDLE`, aplicar la respiración solo cuando `not _continuous_moving`.

- [ ] **Step 6: Ejecutar pruebas de movimiento**

Run:

```powershell
$godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
& $godot --headless --path prueba_2 res://tests/leg_mobility_tests.tscn
& $godot --headless --path prueba_2 --script res://tests/slime_movement_tests.gd
```

Expected: ambas imprimen `PASS` y terminan con exit code `0`.

- [ ] **Step 7: Commit aislado**

```powershell
git add -- prueba_2/actors/player/slime.gd prueba_2/tests/leg_mobility_tests.gd
git commit -m "feat: unlock continuous movement with leg parts"
```

---

### Task 3: Anticipación legible del boss sin texto de acción

**Files:**
- Modify: `prueba_2/actors/boss/boss_core.gd:15-25`
- Modify: `prueba_2/actors/boss/boss_core.gd:45-240`
- Modify: `prueba_2/actors/boss/boss_core.tscn:69-78`
- Modify: `prueba_2/tests/containment_boss_tests.gd:25-65`

**Interfaces:**
- Consumes: fases calculadas por `BossCore._phase()`.
- Produces: `AIM_TIME == [1.35, 1.08, 0.84]`; escena sin `StateLabel`, con `HealthBar`.

- [ ] **Step 1: Añadir pruebas fallidas de anticipación y UI**

Después de instanciar el boss:

```gdscript
	var constants: Dictionary = boss.get_script().get_script_constant_map()
	_check(
		constants.get("AIM_TIME", []) == [1.35, 1.08, 0.84],
		"la Quimera ofrece más anticipación en las tres fases"
	)
	_check(
		boss.get_node_or_null("StateLabel") == null,
		"la Quimera no anuncia su acción con texto"
	)
	_check(boss.get_node_or_null("HealthBar") != null, "la barra de vida permanece")

	for sample in [
		{"health": 12, "time": 1.35},
		{"health": 8, "time": 1.08},
		{"health": 4, "time": 0.84},
	]:
		boss.set("health", sample["health"])
		boss.call("_enter_corner_aim")
		_check(
			is_equal_approx(float(boss.get("_timer")), sample["time"]),
			"la fase de %d HP usa %.2f s de anticipación" % [sample["health"], sample["time"]]
		)
```

- [ ] **Step 2: Ejecutar la prueba y observar los fallos correctos**

Run:

```powershell
& (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source --headless --path prueba_2 res://tests/containment_boss_tests.tscn
```

Expected: FAIL por tiempos antiguos y por presencia de `StateLabel`.

- [ ] **Step 3: Cambiar tiempos y eliminar el contrato textual**

En `boss_core.gd`:

```gdscript
const AIM_TIME := [1.35, 1.08, 0.84]
```

Eliminar:

```gdscript
@onready var state_label: Label = $StateLabel
```

Eliminar las cuatro llamadas `_set_label(...)` de `_choose_next_corner`,
`_enter_corner_aim`, `_enter_pounce` y `_enter_recover`, y eliminar el método:

```gdscript
func _set_label(text: String, color: Color) -> void:
	state_label.text = text
	state_label.add_theme_color_override("font_color", color)
```

En `boss_core.tscn`, borrar solamente el nodo `[node name="StateLabel" ...]` y
sus propiedades. No tocar `HealthBar`.

- [ ] **Step 4: Ejecutar la prueba del boss**

Run:

```powershell
& (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source --headless --path prueba_2 res://tests/containment_boss_tests.tscn
```

Expected: `PASS: containment boss`, exit code `0`.

- [ ] **Step 5: Commit aislado**

```powershell
git add -- prueba_2/actors/boss/boss_core.gd prueba_2/actors/boss/boss_core.tscn prueba_2/tests/containment_boss_tests.gd
git commit -m "feat: extend boss telegraph without action labels"
```

---

### Task 4: Navegación de TAB con teclas físicas

**Files:**
- Modify: `prueba_2/tests/map_overlay_tests.gd:65-85`
- Modify only if the raw-key regression fails: `prueba_2/ui/map_overlay.gd:23-47`

**Interfaces:**
- Consumes: acciones `move_left/right/up/down`, acciones UI `ui_left/right/up/down`, `BodyPanel.move_selection(direction: Vector2)`.
- Produces: una pulsación física WASD o flecha mueve la selección exactamente una vez.

- [ ] **Step 1: Añadir eventos físicos a la prueba**

Añadir el helper:

```gdscript
func _key_event(physical_keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.pressed = true
	return event
```

Sustituir la navegación simulada por acciones con comprobaciones físicas:

```gdscript
	overlay.call("_unhandled_input", _key_event(KEY_D))
	_check(body_panel.get("selected_slot") == 2, "TAB navega a la derecha con D")
	overlay.call("_unhandled_input", _key_event(KEY_LEFT))
	_check(body_panel.get("selected_slot") == 0, "TAB navega a la izquierda con flecha")
	overlay.call("_unhandled_input", _key_event(KEY_D))
	_check(body_panel.get("selected_slot") == 2, "cada pulsación mueve una sola vez")
```

- [ ] **Step 2: Ejecutar la caracterización**

Run:

```powershell
& (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source --headless --path prueba_2 res://tests/map_overlay_tests.tscn
```

Expected: si la configuración actual ya entrega ambos teclados, PASS y no se modifica
`map_overlay.gd`. Si falla solo una familia, continuar al Step 3.

- [ ] **Step 3: Añadir fallback explícito solo si Step 2 falla**

En `_unhandled_input`, aceptar ambas acciones por dirección:

```gdscript
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		body_panel.call("move_selection", Vector2.LEFT)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		body_panel.call("move_selection", Vector2.RIGHT)
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		body_panel.call("move_selection", Vector2.UP)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		body_panel.call("move_selection", Vector2.DOWN)
```

- [ ] **Step 4: Ejecutar mapa y panel corporal**

Run:

```powershell
$godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
& $godot --headless --path prueba_2 res://tests/map_overlay_tests.tscn
& $godot --headless --path prueba_2 res://tests/body_panel_tests.tscn
```

Expected: ambas suites imprimen `PASS` y terminan con exit code `0`.

- [ ] **Step 5: Commit aislado**

Si `map_overlay.gd` no necesitó cambios:

```powershell
git add -- prueba_2/tests/map_overlay_tests.gd
git commit -m "test: cover tab navigation with wasd and arrows"
```

Si necesitó el fallback:

```powershell
git add -- prueba_2/ui/map_overlay.gd prueba_2/tests/map_overlay_tests.gd
git commit -m "fix: support wasd and arrows in body map"
```

---

### Task 5: Documentación y verificación integrada

**Files:**
- Modify: `AGENTS.md:120-145`
- Modify: `docs/ARQUITECTURA.md:280-450`
- Modify: `docs/ARQUITECTURA.md:600-630`

**Interfaces:**
- Consumes: contratos ya verdes de Tasks 1–4.
- Produces: documentación coherente con movilidad continua, anticipación y ausencia de texto del boss.

- [ ] **Step 1: Actualizar las reglas operativas**

En `AGENTS.md`, reemplazar la afirmación de que el movimiento continuo es solo futuro
por el contrato:

```markdown
- Sin partes de `pierna`, soltar antes de `MIN_CHARGE_TIME` no lanza y aplica
  `FIZZLE_RECOVERY_TIME`.
- Con una o más partes cuyo `PartsDB.slot_of()` sea `SLOT_PIERNA`, el slime usa
  movimiento continuo a 280 px/s. El conteo queda disponible para futuras reglas
  de una o dos piernas.
```

En la regla del boss documentar `AIM_TIME = [1.35, 1.08, 0.84]` y que no existe
`StateLabel`; la línea y el círculo son el aviso.

- [ ] **Step 2: Actualizar arquitectura**

En la sección de movimiento de `docs/ARQUITECTURA.md`, añadir la tabla:

```markdown
| Piernas equipadas | Movimiento |
|---:|---|
| 0 | impulso cargado |
| 1 o más | continuo, 280 px/s |
```

Documentar que `Inventory.equipped_count_for_slot()` deriva el conteo desde
`PartsDB.slot_of()`. En la sección del boss registrar los tres tiempos y la
eliminación del texto de estado.

- [ ] **Step 3: Ejecutar todas las suites afectadas**

Run:

```powershell
$godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
$scenes = @(
  'res://tests/leg_mobility_tests.tscn',
  'res://tests/containment_boss_tests.tscn',
  'res://tests/map_overlay_tests.tscn',
  'res://tests/body_panel_tests.tscn',
  'res://tests/combat_smoke.tscn'
)
foreach ($scene in $scenes) {
  & $godot --headless --path prueba_2 $scene
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
& $godot --headless --path prueba_2 --script res://tests/slime_movement_tests.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

Expected: seis suites con `PASS`, ningún `Debugger Break` y exit code final `0`.

- [ ] **Step 4: Arrancar el juego y revisar la salida**

Con Godot MCP:

```text
run_project(projectPath=(Resolve-Path prueba_2).Path)
get_debug_output()
```

Expected: `errors: []`. Mantener el juego abierto para prueba humana.

- [ ] **Step 5: Comprobación manual dirigida**

En una partida:

1. confirmar que sin pierna se carga y aparece la barra;
2. recoger cualquier parte de tipo pierna y confirmar movimiento inmediato con WASD y flechas;
3. abrir `TAB`, navegar con D y flecha izquierda y comer la pierna con `F`;
4. confirmar que vuelve el movimiento cargado;
5. llegar al boss y observar anticipaciones más largas, línea/círculo visibles y ningún texto de acción.

Reportar la sensación de velocidad y lectura del boss como verificación humana, no como
resultado automatizado.

- [ ] **Step 6: Commit de documentación**

```powershell
git add -- AGENTS.md docs/ARQUITECTURA.md
git commit -m "docs: explain leg mobility and boss telegraph"
```
