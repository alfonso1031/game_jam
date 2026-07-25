# Floor Checkpoints and Room Lighting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir checkpoints en memoria al entrar en cada piso, curación parcial y aviso de tres segundos, y asegurar un mínimo de tres focos activos en cada sala.

**Architecture:** `GameState` será la autoridad del checkpoint y guardará sala, nivel y `Spawn`; `Transition` detectará las salas marcadas en `RoomDB` y `main.gd` reaparecerá en el checkpoint vigente. Un componente UI aislado escuchará la señal de checkpoint. La iluminación seguirá siendo data-driven mediante los arrays exportados de cada sala.

**Tech Stack:** Godot 4.7.1, GDScript con tipado estático, escenas `.tscn`, suite headless `combat_smoke.tscn`.

## Global Constraints

- El checkpoint existe solo durante la partida actual; no hay guardado en disco.
- `GameState.reset_run()` elimina el checkpoint.
- Solo un checkpoint de nivel superior cura; repetirlo o retroceder no cura.
- La recompensa es un corazón, equivalente a `2` medios corazones, limitada por la vida máxima.
- Morir mantiene inventario, habilidades, bosses y salas limpias; recupera toda la vida.
- El aviso completo dura `3.0 s` y se desvanece durante los últimos `0.35 s`.
- El respawn usa el `Spawn` guardado; nunca el centro ocupado por enemigos.
- Cada una de las trece salas declara al menos tres focos activos.
- No cambiar energía, radio, color ni parpadeo de los focos.
- No modificar `prueba/`.
- Preservar los cambios locales preexistentes en `prueba_2/project.godot` y los `.png.import`.
- Actualizar la documentación en el mismo commit que el comportamiento correspondiente.

---

### Task 1: Estado y contrato de checkpoint

**Files:**
- Modify: `prueba_2/tests/combat_smoke.gd`
- Modify: `prueba_2/autoload/game_state.gd`
- Modify: `prueba_2/autoload/room_db.gd`

**Interfaces:**
- Consumes: `GameState.heal_halves(halves: int) -> void`
- Produces: `checkpoint_reached(room_id: String, healed_halves: int)`
- Produces: `set_initial_checkpoint(room_id: String, level: int, spawn_name: String = "") -> void`
- Produces: `try_reach_checkpoint(room_id: String, level: int, spawn_name: String) -> bool`
- Produces: `checkpoint_room`, `checkpoint_level`, `checkpoint_spawn`

- [ ] **Step 1: Escribir la prueba fallida del estado**

Añadir `await _test_checkpoints()` en `_run()` y este caso a
`prueba_2/tests/combat_smoke.gd`:

```gdscript
func _test_checkpoints() -> void:
	GameState.reset_run()
	var events: Array[Dictionary] = []
	var listener: Callable = func(room_id: String, healed_halves: int) -> void:
		events.append({"room": room_id, "healed": healed_halves})
	GameState.checkpoint_reached.connect(listener)

	GameState.damage(2)
	GameState.set_initial_checkpoint("L3_CELDA", -3)
	_check(GameState.checkpoint_room == "L3_CELDA", "checkpoint inicial en la celda")
	_check(GameState.health_halves == 6, "checkpoint inicial no cura")
	_check(events.is_empty(), "checkpoint inicial no muestra aviso")

	var advanced: bool = GameState.try_reach_checkpoint("L2_ASCENSOR", -2, "SpawnS")
	_check(advanced, "checkpoint avanza al piso -2")
	_check(GameState.checkpoint_spawn == "SpawnS", "checkpoint conserva el punto de entrada")
	_check(GameState.health_halves == 8, "checkpoint cura un corazón")
	_check(events.size() == 1 and events[0]["healed"] == 2, "checkpoint emite la curación real")

	var health_after_first: int = GameState.health_halves
	_check(
		not GameState.try_reach_checkpoint("L2_ASCENSOR", -2, "SpawnS"),
		"repetir checkpoint no avanza"
	)
	_check(GameState.health_halves == health_after_first, "repetir checkpoint no cura")
	_check(
		not GameState.try_reach_checkpoint("L3_CELDA", -3, ""),
		"checkpoint nunca retrocede"
	)

	GameState.health_halves = GameState.max_health_halves - 1
	GameState.try_reach_checkpoint("L1_ASCENSOR", -1, "SpawnS")
	_check(GameState.health_halves == GameState.max_health_halves, "curación se limita al máximo")
	_check(events[-1]["healed"] == 1, "se informa medio corazón cuando solo falta medio")

	GameState.checkpoint_reached.disconnect(listener)
	GameState.reset_run()
	_check(GameState.checkpoint_room == "", "reset limpia la sala de checkpoint")
	_check(GameState.checkpoint_spawn == "", "reset limpia el Spawn de checkpoint")
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run:

```powershell
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
```

Expected: fallo porque todavía no existen la señal, las propiedades ni los métodos de checkpoint.

- [ ] **Step 3: Implementar el estado mínimo**

En `game_state.gd`, añadir:

```gdscript
signal checkpoint_reached(room_id: String, healed_halves: int)

const CHECKPOINT_HEAL_HALVES := 2
const NO_CHECKPOINT_LEVEL := -999

var checkpoint_room: String = ""
var checkpoint_level: int = NO_CHECKPOINT_LEVEL
var checkpoint_spawn: String = ""

func set_initial_checkpoint(room_id: String, level: int, spawn_name: String = "") -> void:
	checkpoint_room = room_id
	checkpoint_level = level
	checkpoint_spawn = spawn_name

func try_reach_checkpoint(room_id: String, level: int, spawn_name: String) -> bool:
	if level <= checkpoint_level:
		return false
	checkpoint_room = room_id
	checkpoint_level = level
	checkpoint_spawn = spawn_name
	var healed_halves: int = min(
		CHECKPOINT_HEAL_HALVES,
		max_health_halves - health_halves
	)
	if healed_halves > 0:
		heal_halves(healed_halves)
	checkpoint_reached.emit(room_id, healed_halves)
	return true
```

Añadir al final de `reset_run()`:

```gdscript
checkpoint_room = ""
checkpoint_level = NO_CHECKPOINT_LEVEL
checkpoint_spawn = ""
```

En `RoomDB.ROOMS`, añadir `"is_checkpoint": true` a `L3_CELDA`,
`L2_ASCENSOR`, `L1_ASCENSOR` y `L0_VESTIBULO`.

- [ ] **Step 4: Ejecutar la suite y comprobar que pasa**

Run:

```powershell
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
```

Expected: todas las comprobaciones existentes y las nuevas terminan con `0 fallos`.

- [ ] **Step 5: Commit del contrato**

```powershell
git add prueba_2/autoload/game_state.gd prueba_2/autoload/room_db.gd prueba_2/tests/combat_smoke.gd
git commit -m "feat: guarda el checkpoint más avanzado"
```

---

### Task 2: Flujo de transición, respawn y aviso visual

**Files:**
- Modify: `prueba_2/tests/combat_smoke.gd`
- Modify: `prueba_2/autoload/transition.gd`
- Modify: `prueba_2/game/main.gd`
- Modify: `prueba_2/game/main.tscn`
- Create: `prueba_2/ui/checkpoint_notice.gd`
- Create: `prueba_2/ui/checkpoint_notice.tscn`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: `GameState.try_reach_checkpoint(room_id, level, spawn_name)`
- Consumes: `GameState.checkpoint_room` and `GameState.checkpoint_spawn`
- Produces: `Transition.respawn(room_id: String, spawn_name: String = "") -> void`
- Produces: `CheckpointNotice._on_checkpoint_reached(room_id, healed_halves) -> void`

- [ ] **Step 1: Escribir las pruebas fallidas de integración y UI**

Añadir a `combat_smoke.gd` una prueba que cargue el aviso, emita la señal y
compruebe el texto:

```gdscript
func _test_checkpoint_notice() -> void:
	var scene := load("res://ui/checkpoint_notice.tscn") as PackedScene
	_check(scene != null, "la escena del aviso de checkpoint carga")
	if scene == null:
		return
	var notice: Control = scene.instantiate()
	add_child(notice)
	await get_tree().process_frame
	GameState.checkpoint_reached.emit("L2_ASCENSOR", 2)
	await get_tree().process_frame
	_check(notice.visible, "el aviso aparece al alcanzar checkpoint")
	var title := notice.get_node("Panel/VBox/Title") as Label
	var heal := notice.get_node("Panel/VBox/Heal") as Label
	_check(title.text == "CHECKPOINT ALCANZADO", "el aviso muestra el título")
	_check(heal.text == "+1 CORAZÓN", "el aviso muestra la cura")
	notice.queue_free()
	await get_tree().process_frame
```

Añadir una comprobación de que `main.tscn` contiene `CheckpointNotice` y que
`Transition.respawn` acepta el `Spawn` guardado mediante una prueba de flujo:

```gdscript
func _test_checkpoint_respawn() -> void:
	GameState.reset_run()
	var main_scene := load("res://game/main.tscn") as PackedScene
	var main: Node2D = main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.set_initial_checkpoint("L2_ASCENSOR", -2, "SpawnS")
	main._on_died()
	await get_tree().create_timer(Transition.FADE_DURATION * 2.0 + 0.2).timeout
	_check(GameState.current_room == "L2_ASCENSOR", "muerte reaparece en el checkpoint")
	var room: Node = main.get_node("RoomHost").get_child(0)
	var spawn: Node2D = room.get_node("SpawnS")
	var player: Node2D = main.get_node("Player")
	_check(player.position.is_equal_approx(spawn.position), "respawn usa el Spawn guardado")
	_check(main.get_node_or_null("CheckpointLayer/CheckpointNotice") != null, "main contiene el aviso")
	main.queue_free()
	await get_tree().process_frame
```

Invocar ambas pruebas desde `_run()`.

- [ ] **Step 2: Ejecutar y comprobar el fallo**

Run:

```powershell
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
```

Expected: fallo porque no existe el aviso y el respawn sigue fijo en `L3_CELDA`.

- [ ] **Step 3: Integrar checkpoints en Transition**

En `go_to()`, calcular el mismo nombre que ya usa el swap:

```gdscript
var spawn_name := "Spawn%s" % OPPOSITE[from_dir]
```

Pasarlo a `_swap_room(target_id, spawn_name)`. Tras terminar el fade-in, llamar
a un helper que separa carga inicial, avance normal y respawn:

```gdscript
func _record_checkpoint(room_id: String, spawn_name: String, initial: bool) -> void:
	var room_data: Dictionary = RoomDB.ROOMS[room_id]
	if not room_data.get("is_checkpoint", false):
		return
	var level: int = int(room_data["level"])
	if initial:
		GameState.set_initial_checkpoint(room_id, level, spawn_name)
	else:
		GameState.try_reach_checkpoint(room_id, level, spawn_name)
```

`load_initial()` llama:

```gdscript
_record_checkpoint(room_id, "", true)
```

`go_to()` llama después de `await fade_in.finished`:

```gdscript
_record_checkpoint(target_id, spawn_name, false)
```

Cambiar la firma de `respawn()` y su llamada a `_swap_room()`:

```gdscript
func respawn(room_id: String, spawn_name: String = "") -> void:
	if _busy:
		return
	_busy = true
	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await fade_out.finished
	_swap_room(room_id, spawn_name)
	GameState.current_room = room_id
	GameState.visited[room_id] = true
	GameState.room_changed.emit(room_id)
	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
	await fade_in.finished
	_busy = false
```

No llamar a `try_reach_checkpoint()` desde `respawn()`.

- [ ] **Step 4: Usar el checkpoint al morir**

En `main.gd`:

```gdscript
func _on_died() -> void:
	GameState.reset_health()
	var room_id := GameState.checkpoint_room
	if room_id == "":
		room_id = START_ROOM
	Transition.respawn(room_id, GameState.checkpoint_spawn)
```

- [ ] **Step 5: Crear el aviso**

Crear `checkpoint_notice.gd`:

```gdscript
extends Control

const DISPLAY_DURATION := 3.0
const FADE_DURATION := 0.35

@onready var heal_label: Label = $Panel/VBox/Heal

var _display_id := 0

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.checkpoint_reached.connect(_on_checkpoint_reached)

func _on_checkpoint_reached(_room_id: String, healed_halves: int) -> void:
	_display_id += 1
	var current_id: int = _display_id
	heal_label.visible = healed_halves > 0
	heal_label.text = _heal_text(healed_halves)
	modulate.a = 1.0
	visible = true
	await get_tree().create_timer(DISPLAY_DURATION - FADE_DURATION).timeout
	if current_id != _display_id:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	if current_id == _display_id:
		visible = false

func _heal_text(healed_halves: int) -> String:
	if healed_halves == 1:
		return "+½ CORAZÓN"
	if healed_halves == 2:
		return "+1 CORAZÓN"
	return ""
```

Crear `checkpoint_notice.tscn` como `Control` centrado en la zona superior,
`mouse_filter = IGNORE`, con esta estructura funcional mínima:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/checkpoint_notice.gd" id="1"]

[node name="CheckpointNotice" type="Control"]
layout_mode = 3
anchors_right = 1.0
anchors_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1")

[node name="Panel" type="PanelContainer" parent="."]
layout_mode = 0
offset_left = 660.0
offset_top = 80.0
offset_right = 1260.0
offset_bottom = 210.0
mouse_filter = 2

[node name="VBox" type="VBoxContainer" parent="Panel"]
layout_mode = 2
alignment = 1

[node name="Title" type="Label" parent="Panel/VBox"]
layout_mode = 2
theme_override_font_sizes/font_size = 34
text = "CHECKPOINT ALCANZADO"
horizontal_alignment = 1

[node name="Heal" type="Label" parent="Panel/VBox"]
layout_mode = 2
theme_override_font_sizes/font_size = 26
text = "+1 CORAZÓN"
horizontal_alignment = 1
```

Montarlo en `main.tscn` bajo un `CanvasLayer` llamado `CheckpointLayer`, con
capa `15`: sobre HUD y fade (`10`), debajo de pausa (`20`). Añadir el
`ext_resource` y:

```ini
[node name="CheckpointLayer" type="CanvasLayer" parent="."]
layer = 15

[node name="CheckpointNotice" parent="CheckpointLayer" instance=ExtResource("8_checkpoint")]
```

- [ ] **Step 6: Actualizar la documentación de checkpoint**

Documentar en:

- `docs/ARQUITECTURA.md`: flujo, recompensa, respawn con `Spawn` y duración del aviso.
- `docs/agents/REFERENCIA.md`: las cuatro salas marcadas y regla de avance único.
- `AGENTS.md`: no activar checkpoint desde `respawn()` ni permitir retroceso/recompensa repetida.

- [ ] **Step 7: Ejecutar pruebas**

Run:

```powershell
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
godot --headless --path prueba_2 --quit-after 3
```

Expected: suite con `0 fallos` y arranque sin errores ni `Debugger Break`.

- [ ] **Step 8: Commit del flujo completo**

```powershell
git add AGENTS.md docs/ARQUITECTURA.md docs/agents/REFERENCIA.md prueba_2/autoload/transition.gd prueba_2/game/main.gd prueba_2/game/main.tscn prueba_2/ui/checkpoint_notice.gd prueba_2/ui/checkpoint_notice.tscn prueba_2/tests/combat_smoke.gd
git commit -m "feat: reaparece en checkpoints por piso"
```

---

### Task 3: Mínimo de iluminación por sala

**Files:**
- Modify: `prueba_2/tests/combat_smoke.gd`
- Modify: `prueba_2/world/rooms/l3_pasillo.tscn`
- Modify: `prueba_2/world/rooms/l3_nucleo.tscn`
- Modify: `prueba_2/world/rooms/l1_taller.tscn`
- Modify: `prueba_2/world/rooms/l1_deposito.tscn`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`

**Interfaces:**
- Consumes: exported arrays `lamps_n/s/e/o` and `dead_lamps_n/s/e/o`
- Produces: invariant of at least three active lamps per room

- [ ] **Step 1: Escribir la prueba fallida de iluminación**

Añadir a `combat_smoke.gd`:

```gdscript
func _test_room_lighting() -> void:
	for room_id: String in RoomDB.ROOMS:
		var scene := load(RoomDB.ROOMS[room_id]["scene"]) as PackedScene
		var room: Node = scene.instantiate()
		var active := {}
		var dead := {}
		for side: String in ["n", "s", "e", "o"]:
			var active_indices: Array = room.get("lamps_%s" % side)
			var dead_indices: Array = room.get("dead_lamps_%s" % side)
			for index: int in active_indices:
				active["%s:%d" % [side, index]] = true
			for index: int in dead_indices:
				dead["%s:%d" % [side, index]] = true
		_check(active.size() >= 3, "%s tiene al menos tres focos activos" % room_id)
		for key: String in active:
			_check(not dead.has(key), "%s no superpone foco activo y fundido en %s" % [room_id, key])
		room.free()
```

Invocarla desde `_run()`.

- [ ] **Step 2: Ejecutar y comprobar cuatro fallos**

Run:

```powershell
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
```

Expected: `L3_PASILLO`, `L3_NUCLEO`, `L1_TALLER` y `L1_DEPOSITO` fallan el mínimo.

- [ ] **Step 3: Ajustar únicamente los datos de las cuatro salas**

- `L3_PASILLO`: añadir `lamps_s = Array[int]([6])` y quitar
  `dead_lamps_s = Array[int]([6])`.
- `L3_NUCLEO`: añadir `lamps_e = Array[int]([3])`.
- `L1_TALLER`: cambiar `lamps_s` a `Array[int]([2, 6, 10])`.
- `L1_DEPOSITO`: añadir `lamps_n = Array[int]([6])` y quitar
  `dead_lamps_n = Array[int]([6])`.

- [ ] **Step 4: Documentar la regla de iluminación**

Añadir a `docs/ARQUITECTURA.md` y `docs/agents/REFERENCIA.md`:

- mínimo de tres focos activos por sala;
- focos fundidos no cuentan;
- no colocar foco centrado en una pared con puerta;
- ajustar distribución por sala, nunca compensar subiendo `BASE_ENERGY`.

- [ ] **Step 5: Ejecutar la suite y arranque**

Run:

```powershell
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
godot --headless --path prueba_2 --quit-after 3
```

Expected: suite con `0 fallos`; arranque limpio.

- [ ] **Step 6: Commit de iluminación**

```powershell
git add docs/ARQUITECTURA.md docs/agents/REFERENCIA.md prueba_2/tests/combat_smoke.gd prueba_2/world/rooms/l3_pasillo.tscn prueba_2/world/rooms/l3_nucleo.tscn prueba_2/world/rooms/l1_taller.tscn prueba_2/world/rooms/l1_deposito.tscn
git commit -m "feat: equilibra la iluminación de las salas"
```

---

### Task 4: Regresión completa y verificación manual pendiente

**Files:**
- Verify only; no planned source changes.

**Interfaces:**
- Consumes: all deliverables from Tasks 1-3.
- Produces: evidence for handoff.

- [ ] **Step 1: Reimportar assets existentes**

```powershell
godot --headless --path prueba_2 --import
```

Expected: importación termina con código `0`.

- [ ] **Step 2: Ejecutar todas las suites relevantes**

```powershell
python tools/audio/test_generate_slime_audio.py
godot --headless --path prototypes/slime_charge_movement --script res://tests/run_tests.gd
godot --headless --path prueba_2 --script res://tests/run_slime_audio_tests.gd
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
godot --headless --path prueba_2 res://tests/check_enemy_animations.tscn
```

Expected: Python `OK`, prototipo `PASS`, audio activo `PASS`, combate con
`0 fallos` y animaciones con `0 fallos`.

- [ ] **Step 3: Verificar alcance y limpieza**

```powershell
git diff --check
git status --short
```

Expected: ningún error de whitespace; los cambios preexistentes de
`project.godot` y `.png.import` siguen sin estar incluidos en los commits.

- [ ] **Step 4: Registrar la frontera manual**

Reportar como pendiente de prueba humana:

- duración y legibilidad del aviso durante una transición real;
- sensación de alivio de la cura de un corazón;
- respawn junto al ascensor con enemigos vivos;
- distribución visual de luz en las trece salas.
