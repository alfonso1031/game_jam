# Movimiento de arrastre del slime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mantener la carga que define distancia y convertir el lanzamiento del slime en un arrastre ventral lento, uniforme y deformable.

**Architecture:** La máquina de estados, colisión, audio y daño permanecen en `slime.gd`. El tramo `LAUNCHING` usa distancia restante como autoridad y una velocidad central de `480 px/s`; una función visual pura deforma los polígonos sin mover el `CharacterBody2D` ni alterar su `CollisionShape2D`.

**Tech Stack:** Godot 4.7.1, GDScript tipado, `CharacterBody2D`, `Polygon2D`, pruebas headless a 60 Hz.

## Global Constraints

- Mantener `MIN_CHARGE_TIME = 0.12`.
- Distancia mínima válida: `112 px`; distancia completa: `520 px`.
- Velocidad de arrastre inicial: aproximadamente `480 px/s`.
- La carga mayor aumenta duración, no un pico de velocidad.
- Conservar barra, fizzle, colisión, deflexión rasante, embestida, knockback, DASH y audio.
- Conservar una única colisión circular de radio `45`.
- No crear segmentos físicos ni articulaciones.

---

### Task 1: Pruebas objetivas de distancia y velocidad

**Files:**
- Create: `prueba_2/tests/slime_movement_tests.gd`

**Interfaces:**
- Consumes: `_begin_charge()`, `_update_charge()`, `_release_charge()`, `_advance_launch()`.
- Produces: suite headless que mide desplazamiento a pasos de `1.0 / 60.0`.

- [ ] **Step 1: Crear el runner de movimiento**

Crear `slime_movement_tests.gd` como `SceneTree`, cargar
`res://actors/player/slime.tscn` y reutilizar el patrón de
`run_slime_audio_tests.gd::_spawn_player()`.

Prueba mínima:

```gdscript
var player := await _spawn_player(scene)
player.position = Vector2.ZERO
player._begin_charge(Vector2.RIGHT)
player._update_charge(player.MIN_CHARGE_TIME)
player._release_charge()
var samples := _advance_until_recovery(player)
_assert_close(player.position.x, 112.0, 1.0, "carga mínima recorre 112 px")
_assert_uniform(samples, 480.0 / 60.0, 1.0, "carga mínima se arrastra uniforme")
```

Prueba completa:

```gdscript
player = await _spawn_player(scene)
player._begin_charge(Vector2.RIGHT)
player._update_charge(player.MAX_CHARGE_TIME)
player._release_charge()
samples = _advance_until_recovery(player)
_assert_close(player.position.x, 520.0, 1.0, "carga completa recorre 520 px")
_assert_true(samples.size() >= 64 and samples.size() <= 66, "carga completa dura cerca de 1.08 s")
```

El helper guarda la distancia de cada frame:

```gdscript
func _advance_until_recovery(player: Node) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	while player._state == player.State.LAUNCHING and samples.size() < 180:
		var before: Vector2 = player.position
		player._advance_launch(1.0 / 60.0)
		samples.append(before.distance_to(player.position))
	return samples
```

`_assert_uniform()` compara todas las muestras salvo la última: el último frame
se recorta deliberadamente a `_remaining` para respetar la distancia exacta.

- [ ] **Step 2: Ejecutar y confirmar el fallo del perfil actual**

```powershell
godot --headless --path prueba_2 --script res://tests/slime_movement_tests.gd
```

Expected: FAIL porque el perfil actual tiene pico/frenada y la carga mínima no
produce exactamente `112 px`.

- [ ] **Step 3: Commit de la prueba roja**

```powershell
git add prueba_2/tests/slime_movement_tests.gd
git commit -m "test: define el arrastre uniforme del slime"
```

---

### Task 2: Desplazamiento uniforme gobernado por distancia

**Files:**
- Modify: `prueba_2/actors/player/slime.gd:12-29,265-323`
- Modify: `prueba_2/tests/slime_movement_tests.gd`

**Interfaces:**
- Produces: `CRAWL_SPEED := 480.0`.
- Produces: `_distance_power() -> float`, normalizada entre carga mínima y plena.

- [ ] **Step 1: Separar potencia visual de potencia de recorrido**

Añadir:

```gdscript
const CRAWL_SPEED := 480.0

func _distance_power() -> float:
	var duration := _max_charge_time() - MIN_CHARGE_TIME
	if duration <= 0.0:
		return 1.0
	return clampf((_charge_time - MIN_CHARGE_TIME) / duration, 0.0, 1.0)
```

Mantener `_charge_power()` para barra/audio. En `_release_charge()`:

```gdscript
_launch_power = _distance_power()
_remaining = lerpf(MIN_DISTANCE, MAX_DISTANCE, _launch_power)
_launch_distance = _remaining
```

- [ ] **Step 2: Sustituir solo el perfil del impulso base**

Reemplazar `_advance_launch()` hasta antes de colisión por:

```gdscript
func _advance_launch(delta: float) -> void:
	var speed := CRAWL_SPEED * _speed_multiplier()
	_speed_ratio = clampf(speed / CRAWL_SPEED, 0.0, 1.5)
	velocity = _charge_dir * speed
	var step: float = minf(speed * delta, _remaining)
	var collision := move_and_collide(_charge_dir * step)
	_remaining -= step
```

Conservar intacto el bloque de impacto, `_deflect()` y recuperación. No eliminar
`_eased_speed()`: el DASH todavía lo consume.

- [ ] **Step 3: Ejecutar movimiento, audio y combate**

```powershell
godot --headless --path prueba_2 --script res://tests/slime_movement_tests.gd
godot --headless --path prueba_2 --script res://tests/run_slime_audio_tests.gd
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
```

Expected: las tres suites PASS.

- [ ] **Step 4: Commit**

```powershell
git add prueba_2/actors/player/slime.gd prueba_2/tests/slime_movement_tests.gd
git commit -m "feat: convierte el impulso en arrastre uniforme"
```

---

### Task 3: Deformación peristáltica de un solo cuerpo

**Files:**
- Modify: `prueba_2/actors/player/slime.tscn:29-35`
- Modify: `prueba_2/actors/player/slime.gd:87-108,664-700`
- Modify: `prueba_2/tests/slime_movement_tests.gd`

**Interfaces:**
- Produces: `_deform_points(base, charge, crawl_phase, launching) -> PackedVector2Array`.
- Produces: `body` y `core` vuelven a sus polígonos base en reposo.

- [ ] **Step 1: Añadir pruebas de deformación sin traslación**

```gdscript
var player := await _spawn_player(scene)
var body := player.get_node("Body") as Polygon2D
var collision := player.get_node("CollisionShape2D") as CollisionShape2D
var base_points: PackedVector2Array = body.polygon.duplicate()
var initial_position: Vector2 = player.position

player._begin_charge(Vector2.RIGHT)
player._update_charge(1.0)
player._update_visual(1.0 / 60.0)
_assert_true(_max_x(body.polygon) > _max_x(base_points) + 10.0, "el frente se estira")
_assert_close(player.position.distance_to(initial_position), 0.0, 0.01, "cargar no traslada")
_assert_close((collision.shape as CircleShape2D).radius, 45.0, 0.01, "colisión no cambia")

player._begin_recovery(0.0)
player._state = player.State.IDLE
for _frame in range(90):
	player._update_visual(1.0 / 60.0)
_assert_points_close(body.polygon, base_points, 0.75, "el cuerpo vuelve a reposo")
```

- [ ] **Step 2: Ejecutar y confirmar que el escalado global no cumple**

```powershell
godot --headless --path prueba_2 --script res://tests/slime_movement_tests.gd
```

Expected: FAIL porque el polígono no cambia; hoy se modifica `body.scale`.

- [ ] **Step 3: Guardar geometría base y deformar regiones**

En `_ready()`:

```gdscript
_body_base = body.polygon.duplicate()
_core_base = core.polygon.duplicate()
```

Definir:

```gdscript
var _body_base := PackedVector2Array()
var _core_base := PackedVector2Array()
var _crawl_phase := 0.0

func _deform_points(
	base: PackedVector2Array,
	charge: float,
	phase: float,
	launching: bool
) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in base:
		var normalized_x := clampf(point.x / 45.0, -1.0, 1.0)
		var front := maxf(normalized_x, 0.0)
		var tail := maxf(-normalized_x, 0.0)
		var x := point.x + front * front * charge * 30.0
		x += tail * charge * 8.0
		var belly := 1.0 + charge * 0.10 * (1.0 - absf(normalized_x))
		var wave := sin(phase - normalized_x * PI) * 4.0 if launching else 0.0
		result.append(Vector2(x + wave, point.y * belly))
	return result
```

Actualizar el polígono externo en `slime.tscn` a 16 puntos con regiones
longitudinales claras:

```ini
polygon = PackedVector2Array(48, 0, 44, 16, 36, 30, 22, 40, 0, 46, -20, 42, -36, 32, -46, 18, -50, 0, -46, -18, -36, -32, -20, -42, 0, -46, 22, -40, 36, -30, 44, -16)
```

Actualizar el núcleo a 16 puntos equivalentes:

```ini
polygon = PackedVector2Array(26, 0, 24, 9, 20, 17, 12, 22, 0, 25, -11, 23, -20, 17, -25, 10, -27, 0, -25, -10, -20, -17, -11, -23, 0, -25, 12, -22, 20, -17, 24, -9)
```

En `_update_visual()`:

```gdscript
var charge := pow(_charge_power(), 0.75) if _state == State.CHARGING else 0.0
var launching := _state == State.LAUNCHING
if launching:
	_crawl_phase += delta * 9.0
body.polygon = _deform_points(_body_base, charge, _crawl_phase, launching)
core.polygon = _deform_points(_core_base, charge * 0.65, _crawl_phase, launching)
body.position = Vector2.ZERO
body.scale = Vector2.ONE
body.rotation = lerp_angle(body.rotation, _facing.angle(), 1.0 - exp(-14.0 * delta))
```

En reposo interpolar cada punto hacia el base para evitar un salto. DASH y
`PART_DASH` pueden conservar un estiramiento longitudinal uniforme, pero no
deben reutilizar la onda ventral del impulso base.

- [ ] **Step 4: Ejecutar regresiones**

```powershell
godot --headless --path prueba_2 --script res://tests/slime_movement_tests.gd
godot --headless --path prueba_2 --script res://tests/run_slime_audio_tests.gd
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
```

Expected: todas PASS; no hay deriva de posición ni cambio de colisión.

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/actors/player/slime.gd prueba_2/actors/player/slime.tscn prueba_2/tests/slime_movement_tests.gd
git commit -m "feat: deforma el slime como un gusano"
```

---

### Task 4: Documentación y prueba visual del arrastre

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`

**Interfaces:**
- Produces: contrato documentado de velocidad, distancias y separación del DASH.

- [ ] **Step 1: Actualizar documentación**

Documentar exactamente:

```markdown
- Mantener dirección carga; soltar inicia arrastre.
- Carga válida: 112–520 px.
- Velocidad base del tramo: 480 px/s; la potencia cambia duración/distancia.
- La deformación del Polygon2D no gobierna colisión.
- DASH conserva su curva y constantes propias.
```

- [ ] **Step 2: Ejecutar suite completa relacionada**

```powershell
godot --headless --path prueba_2 --script res://tests/slime_movement_tests.gd
godot --headless --path prueba_2 --script res://tests/run_slime_audio_tests.gd
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
godot --headless --path prototypes/slime_charge_movement --script res://tests/run_tests.gd
godot --headless --path prueba_2 --quit-after 3
```

Expected: código 0 en todos los comandos.

- [ ] **Step 3: Prueba manual a 1920×1080**

Grabar o capturar:

```text
1. carga mínima, media y completa;
2. estiramiento frontal sin desplazar el centro;
3. onda de contracción durante el arrastre;
4. choque frontal, roce con jamba, fizzle y DASH;
5. regreso a silueta de reposo.
```

Confirmar que el movimiento se percibe como arrastre sobre el vientre, no salto,
rodadura ni acordeón vertical.

- [ ] **Step 4: Commit**

```powershell
git add AGENTS.md docs/ARQUITECTURA.md docs/agents/REFERENCIA.md
git commit -m "docs: define el movimiento de arrastre"
```
