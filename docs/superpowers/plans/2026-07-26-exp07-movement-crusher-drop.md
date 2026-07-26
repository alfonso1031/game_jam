# EXP07 Movement and Crusher Claw Drop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hacer que el Crustáceo Escudo use sus animaciones de avance y pellizco en todos sus estados y sea la fuente exclusiva de Tenaza Trituradora.

**Architecture:** `exp07_crustacean.gd` conserva la autoridad de estados y daño, mientras `enemy_base.gd` selecciona y orienta la animación solicitada por `_visual_state()`. La escena configura un pool de drop de un solo elemento, `crusher_claw`; las pruebas focalizadas validan recursos, estados, orientación y recompensa.

**Tech Stack:** Godot 4.7.1, GDScript tipado, `AnimatedSprite2D`, `SpriteFrames`, PNG transparente y pruebas headless.

## Global Constraints

- El arte pertenece al enemigo EXP07, no al slime.
- `PINCH_WINDUP` conserva `0,8 s` y `RECOVER` conserva `0,6 s`.
- `_pinch()` sigue siendo el único lugar que aplica daño y retroceso.
- El sprite se orienta mediante `facing`, sin rotar el arte lateral.
- `drop_parts` contiene únicamente `crusher_claw`.
- El porcentaje normal de drop no cambia; los líderes conservan drop garantizado.
- Todos los PNG usados deben quedar rastreados en Git y cargar sin depender de `.godot/`.

---

### Task 1: Contrato visual y drop exclusivo

**Files:**
- Modify: `prueba_2/tests/exp07_attack_tests.gd`
- Modify: `prueba_2/actors/enemies/exp07_crustacean.tscn`

**Interfaces:**
- Consumes: `Exp07Scene`, `Exp07Frames`, `EnemyBase._update_sprite()` y `facing: Vector2`.
- Produces: `drop_parts == ["crusher_claw"]` y un contrato automatizado para las animaciones `advance`, `pinch_windup` y `recover`.

- [ ] **Step 1: Escribir la prueba focalizada que falla**

Añadir a `_check_animation_contract()`:

```gdscript
_check(Exp07Frames.get_frame_count(&"advance") == 4, "advance usa el ciclo completo")
_check(Exp07Frames.get_animation_loop(&"advance"), "advance se reproduce en bucle")
```

El recurso usa las tres poses disponibles y repite la pose intermedia al cerrar
el ciclo, por eso la animación contiene cuatro entradas: `00 → 01 → 02 → 01`.

Añadir a `_check_state_contract()`:

```gdscript
_check(states.has("ADVANCE"), "EXP07 declara ADVANCE")
if states.has("ADVANCE"):
	enemy.set("_state", states["ADVANCE"])
	_check(enemy._visual_state() == &"advance", "ADVANCE usa el ciclo de movimiento")

_check(
	enemy.get("drop_parts") == Array[String](["crusher_claw"]),
	"EXP07 solo puede soltar Tenaza Trituradora"
)

var sprite: AnimatedSprite2D = enemy.get_node("Sprite")
enemy.set("facing", Vector2.LEFT)
enemy._update_sprite()
_check(sprite.flip_h, "el arte mira a la izquierda con el enemigo")
enemy.set("facing", Vector2.RIGHT)
enemy._update_sprite()
_check(not sprite.flip_h, "el arte mira a la derecha con el enemigo")
```

- [ ] **Step 2: Ejecutar la prueba y confirmar el fallo correcto**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/exp07_attack_tests.tscn
```

Expected: `FAIL: EXP07 claw attack` porque la escena todavía incluye
`bone_plate` junto a `crusher_claw`.

- [ ] **Step 3: Aplicar el cambio mínimo de producción**

En `exp07_crustacean.tscn`, reemplazar:

```ini
drop_parts = Array[String](["bone_plate", "crusher_claw"])
```

por:

```ini
drop_parts = Array[String](["crusher_claw"])
```

No modificar `drop_rate`, `is_room_leader`, `_pinch()` ni las duraciones de la
máquina de estados.

- [ ] **Step 4: Ejecutar la prueba y confirmar que pasa**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/exp07_attack_tests.tscn
```

Expected: `PASS: EXP07 claw attack`.

- [ ] **Step 5: Confirmar el cambio**

```powershell
git add prueba_2/tests/exp07_attack_tests.gd prueba_2/actors/enemies/exp07_crustacean.tscn
git commit -m "feat: vincula exp07 con tenaza trituradora"
```

### Task 2: Recursos, animaciones y versión jugable

**Files:**
- Verify: `prueba_2/assets/enemies/exp07_crustacean/exp07_crustacean_00.png`
- Verify: `prueba_2/assets/enemies/exp07_crustacean/exp07_crustacean_01.png`
- Verify: `prueba_2/assets/enemies/exp07_crustacean/exp07_crustacean_02.png`
- Verify: `prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_00.png`
- Verify: `prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_01.png`
- Verify: `prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_02.png`
- Verify: `prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_03.png`
- Verify: `prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_04.png`
- Verify: `prueba_2/actors/enemies/exp07_crustacean_frames.tres`
- Verify: `prueba_2/actors/enemies/exp07_crustacean.gd`
- Verify: `prueba_2/tests/exp07_asset_tests.tscn`
- Verify: `prueba_2/tests/check_enemy_animations.tscn`
- Verify: `prueba_2/tests/combat_smoke.tscn`

**Interfaces:**
- Consumes: los ocho PNG de runtime y la escena configurada en Task 1.
- Produces: recursos importados, animaciones válidas y una instancia jugable actualizada.

- [ ] **Step 1: Importar todos los recursos**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --import
```

Expected: código de salida `0` y sin errores de recursos.

- [ ] **Step 2: Ejecutar las pruebas focalizadas del enemigo**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/exp07_asset_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/exp07_attack_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/check_enemy_animations.tscn
```

Expected:

```text
PASS: EXP07 attack assets
PASS: EXP07 claw attack
ANIM_CHECK_OK
```

- [ ] **Step 3: Ejecutar el smoke test de combate**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/combat_smoke.tscn
```

Expected: todas las comprobaciones pasan y EXP07 se instancia, actúa, muere y
genera un ID de parte conocido.

- [ ] **Step 4: Verificar que los assets de runtime estén rastreados**

```powershell
git ls-files --error-unmatch prueba_2/assets/enemies/exp07_crustacean/exp07_crustacean_00.png prueba_2/assets/enemies/exp07_crustacean/exp07_crustacean_01.png prueba_2/assets/enemies/exp07_crustacean/exp07_crustacean_02.png prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_00.png prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_01.png prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_02.png prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_03.png prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_04.png
```

Expected: los ocho archivos aparecen sin error.

- [ ] **Step 5: Abrir la versión jugable actualizada**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --path prueba_2
```

Verificación humana pendiente: comprobar que el avance se percibe continuo, el
pellizco tiene aviso legible, la orientación coincide con el jugador y al morir
un EXP07 que genere drop aparece Tenaza Trituradora.
