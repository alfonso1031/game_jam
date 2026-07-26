# Iluminación tenue y modo de prueba Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hacer legible toda la sala bajo una penumbra azulada y añadir en TAB un modo de vida infinita para probar la partida sin perder la respuesta física de los impactos.

**Architecture:** `GameState` conserva la autoridad de vida y del nuevo flag de prueba durante la run. `BodyPanel` presenta el interruptor y `MapOverlay` enruta la tecla `V`; la iluminación se resuelve elevando solo el `CanvasModulate` global para no tocar el comportamiento de las lámparas.

**Tech Stack:** Godot 4.7.1, GDScript tipado, escenas `.tscn`, InputMap y pruebas headless.

## Global Constraints

- El modo infinito persiste entre salas, pero `GameState.reset_run()` lo apaga.
- El daño conserva invulnerabilidad temporal, retroceso y feedback; solo se bloquea la mutación de HP.
- Las lámparas mantienen energía `1.6`, radio `1.85`, parpadeo y estado fundido.
- Flechas y `F` dentro de TAB conservan selección y consumo de partes.
- La regresión global se ejecutará únicamente cuando termine el conjunto completo de cambios solicitado.

---

### Task 1: Autoridad de vida infinita

**Files:**
- Modify: `prueba_2/autoload/game_state.gd`
- Modify: `prueba_2/tests/run_lifecycle_tests.gd`

**Interfaces:**
- Produces: `GameState.infinite_health: bool`
- Produces: `GameState.infinite_health_changed(enabled: bool)`
- Produces: `GameState.set_infinite_health(enabled: bool) -> void`
- Produces: `GameState.toggle_infinite_health() -> bool`

- [ ] **Step 1: Escribir la prueba focalizada que falla**

Añadir a `run_lifecycle_tests.gd`, después de comprobar la vida inicial:

```gdscript
_check(not GameState.infinite_health, "la run inicia sin vida infinita")
GameState.set_infinite_health(true)
var protected_health := GameState.health_halves
GameState.damage_halves(4)
_check(GameState.health_halves == protected_health, "vida infinita bloquea pérdida de HP")
_check(GameState.toggle_infinite_health() == false, "el toggle desactiva el modo")
GameState.damage_halves(1)
_check(GameState.health_halves == protected_health - 1, "al apagarlo vuelve el daño")
GameState.set_infinite_health(true)
GameState.reset_run()
_check(not GameState.infinite_health, "nueva run apaga vida infinita")
```

- [ ] **Step 2: Ejecutar y confirmar el fallo**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/run_lifecycle_tests.tscn
```

Esperado: falla porque `GameState` todavía no expone `infinite_health`.

- [ ] **Step 3: Implementar el estado mínimo**

En `game_state.gd`:

```gdscript
signal infinite_health_changed(enabled: bool)

var infinite_health := false

func set_infinite_health(enabled: bool) -> void:
	if infinite_health == enabled:
		return
	infinite_health = enabled
	infinite_health_changed.emit(infinite_health)

func toggle_infinite_health() -> bool:
	set_infinite_health(not infinite_health)
	return infinite_health
```

En `reset_run()` llamar `set_infinite_health(false)`. En `damage_halves()` conservar
el corte por muerte y añadir inmediatamente después:

```gdscript
if infinite_health:
	return
```

No modificar `slime.take_damage()`: seguirá asignando invulnerabilidad y aplicando
retroceso después de llamar a `GameState.damage()`.

- [ ] **Step 4: Ejecutar la prueba focalizada**

Ejecutar el comando del paso 2. Esperado: `PASS: run lifecycle`.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/autoload/game_state.gd prueba_2/tests/run_lifecycle_tests.gd
git commit -m "feat: añade vida infinita de prueba"
```

### Task 2: Interruptor de TAB y tecla V

**Files:**
- Modify: `prueba_2/project.godot`
- Modify: `prueba_2/ui/body_panel.tscn`
- Modify: `prueba_2/ui/body_panel.gd`
- Modify: `prueba_2/ui/map_overlay.gd`
- Modify: `prueba_2/tests/body_panel_tests.gd`
- Modify: `prueba_2/tests/map_overlay_tests.gd`

**Interfaces:**
- Consumes: `GameState.toggle_infinite_health() -> bool`
- Consumes: `GameState.infinite_health_changed(enabled: bool)`
- Produces: `BodyPanel.toggle_infinite_health() -> bool`
- Produces: acción InputMap `test_mode` enlazada a la tecla física `V`

- [ ] **Step 1: Escribir pruebas de UI que fallen**

En `body_panel_tests.gd`, después de instanciar el panel:

```gdscript
var test_mode: Button = panel.get_node_or_null("TestMode") as Button
_check(test_mode != null, "TAB expone el modo de prueba")
if test_mode != null and panel.has_method("toggle_infinite_health"):
	panel.call("toggle_infinite_health")
	_check(GameState.infinite_health, "el interruptor activa vida infinita")
	_check(test_mode.text.ends_with("SÍ"), "el texto refleja el modo activo")
	panel.call("toggle_infinite_health")
	_check(not GameState.infinite_health, "el interruptor también lo apaga")
```

En `map_overlay_tests.gd`, con TAB abierto:

```gdscript
overlay.call("_unhandled_input", _action_event(&"test_mode"))
_check(GameState.infinite_health, "TAB entrega V al modo de prueba")
_check(not Inventory.is_empty(0), "V no consume la parte seleccionada")
```

- [ ] **Step 2: Ejecutar ambas pruebas y confirmar el fallo**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/body_panel_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/map_overlay_tests.tscn
```

Esperado: fallan por ausencia de `TestMode` y de la acción `test_mode`.

- [ ] **Step 3: Añadir la acción y el control visual**

En `project.godot` registrar `test_mode` con `physical_keycode=86`.

En `body_panel.tscn` añadir un `Button` llamado `TestMode`, centrado entre
`y=900` y `y=962`, con `CardNormal`, `CardHover` y `CardSelected`. Texto inicial:

```text
MODO PRUEBA · VIDA INFINITA: NO
```

En `body_panel.gd`:

```gdscript
@onready var test_mode: Button = $TestMode

func toggle_infinite_health() -> bool:
	return GameState.toggle_infinite_health()

func _refresh_test_mode(enabled: bool) -> void:
	test_mode.text = "MODO PRUEBA · VIDA INFINITA: %s" % (
		"SÍ" if enabled else "NO"
	)
	if enabled:
		test_mode.add_theme_stylebox_override("normal", test_mode.get_theme_stylebox("pressed"))
	else:
		test_mode.remove_theme_stylebox_override("normal")
```

En `_ready()`, conectar `test_mode.pressed` a `toggle_infinite_health`,
`GameState.infinite_health_changed` a `_refresh_test_mode` y llamar la
actualización inicial.

- [ ] **Step 4: Enrutar V solo con TAB abierto**

En `map_overlay.gd::_unhandled_input`, dentro de la rama `visible`:

```gdscript
elif event.is_action_pressed("test_mode"):
	body_panel.call("toggle_infinite_health")
```

El evento se marca atendido mediante el flujo existente.

- [ ] **Step 5: Ejecutar las pruebas focalizadas**

Ejecutar los dos comandos del paso 2. Esperado:
`PASS: organic body panel` y `PASS: procedural local map`.

- [ ] **Step 6: Commit**

```powershell
git add prueba_2/project.godot prueba_2/ui/body_panel.tscn prueba_2/ui/body_panel.gd prueba_2/ui/map_overlay.gd prueba_2/tests/body_panel_tests.gd prueba_2/tests/map_overlay_tests.gd
git commit -m "feat: expone vida infinita en tab"
```

### Task 3: Penumbra legible, captura y documentación

**Files:**
- Modify: `prueba_2/game/main.tscn`
- Modify: `prueba_2/tests/ui_visual_capture.gd`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`

**Interfaces:**
- Produces: `main.tscn::Darkness.color = Color(0.28, 0.31, 0.34, 1)`
- Produces: modo de captura `lighting`

- [ ] **Step 1: Aplicar el nivel ambiental**

Cambiar únicamente:

```ini
[node name="Darkness" type="CanvasModulate" parent="."]
color = Color(0.28, 0.31, 0.34, 1)
```

No modificar `lamp.tscn` ni `lamp.gd`.

- [ ] **Step 2: Añadir fixture visual**

En `ui_visual_capture.gd` precargar `res://game/main.tscn`. Para el modo
`lighting`, ocultar `$Background`, iniciar la seed `1785033756`, instanciar
`MainScene` y dejar que cargue su sala inicial.

- [ ] **Step 3: Capturar a 1920 × 1080**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- lighting user://lighting-test-mode.png 1920x1080
```

Revisar que paredes, suelo, puertas y props se distingan en todo el cuarto y que
los focos sigan creando manchas cálidas. Si el fondo aún se pierde, subir los
canales juntos en incrementos máximos de `0.03`; si parece diurno, bajarlos igual.

- [ ] **Step 4: Documentar**

En `ARQUITECTURA.md` y `REFERENCIA.md` registrar:

- ambiente `Color(0.28, 0.31, 0.34, 1)`;
- lámparas intactas a energía `1.6` y radio `1.85`;
- toggle `V`/clic en TAB;
- persistencia por run y reinicio a `false`;
- daño sin pérdida de HP, pero con respuesta física intacta.

- [ ] **Step 5: Importar y abrir versión jugable**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --import
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --path prueba_2
```

No ejecutar todavía la regresión global.

- [ ] **Step 6: Commit**

```powershell
git add prueba_2/game/main.tscn prueba_2/tests/ui_visual_capture.gd docs/ARQUITECTURA.md docs/agents/REFERENCIA.md
git commit -m "feat: aclara contencion para pruebas"
```
