# Animación del slime y balance de salas — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrar las cuatro animaciones entregadas del slime, publicarlas primero y después publicar el balance procedural 60/30/10 con enemigos 1–3 y 4–7.

**Architecture:** Un procesador Godot convierte hojas fuente de 320 px en fotogramas runtime centrados; `slime.gd` selecciona una animación puramente visual desde su estado existente. El balance queda encapsulado en las constantes y población de `MapGenerator`, con una prueba focalizada independiente de la suite procedural antigua.

**Tech Stack:** Godot 4.7.1, GDScript, recursos `.tscn`/`.tres`, PNG RGBA, Git.

## Global Constraints

- Proyecto activo: `prueba_2/`; no modificar `prueba/`.
- No cambiar hitbox, movimiento, daño, capas, tiempos ni invulnerabilidad del slime.
- `idle=5`, `walk=2`, `jump=6`, `recover=12`.
- Pesos posteriores al primer push: `easy=60`, `hard=30`, `empty=10`.
- Rangos posteriores al primer push: `easy=1..3`, `hard=4..7`.
- Preservar cambios locales no relacionados del checkout principal.

---

### Task 1: Contrato de animación y fuentes

**Files:**
- Create: `art_raw/personaje/slime/slime_idle_sheet.png`
- Create: `art_raw/personaje/slime/slime_walk_sheet.png`
- Create: `art_raw/personaje/slime/slime_jump_sheet.png`
- Create: `art_raw/personaje/slime/slime_recover_sheet.png`
- Create: `prueba_2/tests/slime_animation_tests.gd`
- Create: `prueba_2/tests/slime_animation_tests.tscn`

**Interfaces:**
- Consumes: `res://actors/player/slime.tscn`.
- Produces: prueba ejecutable que exige `Sprite`, cuatro animaciones y el mapeo aprobado.

- [ ] **Step 1: Copiar y normalizar las cuatro fuentes del ZIP**

Extraer las hojas sin recomprimir y renombrar `spritesheet(8).png` como
`slime_recover_sheet.png`.

- [ ] **Step 2: Escribir la prueba fallida**

La prueba debe instanciar `slime.tscn` y comprobar:

```gdscript
var sprite := slime.get_node_or_null("Sprite") as AnimatedSprite2D
_check(sprite != null, "el slime usa AnimatedSprite2D")
_check(frames.get_frame_count(&"idle") == 5, "Idle conserva 5 frames")
_check(frames.get_frame_count(&"walk") == 2, "Walk conserva 2 frames")
_check(frames.get_frame_count(&"jump") == 6, "Jump conserva 6 frames")
_check(frames.get_frame_count(&"recover") == 12, "Recover conserva 12 frames")
```

También debe fijar `_state` y `_continuous_moving`, llamar
`_update_sprite_animation()` y exigir el mapeo de la especificación.

- [ ] **Step 3: Ejecutar RED**

Run:

```powershell
godot --headless --path prueba_2 res://tests/slime_animation_tests.tscn
```

Expected: `FAIL` porque `slime.tscn` todavía no contiene `Sprite`.

- [ ] **Step 4: Commit de la prueba y fuentes**

```powershell
git add art_raw/personaje/slime prueba_2/tests/slime_animation_tests.*
git commit -m "test: exige las animaciones entregadas del slime"
```

### Task 2: Procesador reproducible y recursos runtime

**Files:**
- Create: `prueba_2/tools/art/process_slime_delivered_sheets.gd`
- Create: `prueba_2/assets/player/slime/animations/slime_idle_00.png` y restantes
- Create: `prueba_2/actors/player/slime_frames.tres`

**Interfaces:**
- Consumes: cuatro hojas RGBA con celdas exactas de `320 × 320`.
- Produces: 25 PNG centrados y un `SpriteFrames` con `idle`, `walk`, `jump`, `recover`.

- [ ] **Step 1: Implementar validación y separación**

El script debe validar dimensiones divisibles por `320`, cantidad
`5/2/6/12`, alfa no vacío y un único recorte común. Cada salida debe usar el
mismo lienzo transparente y nombre `slime_<anim>_%02d.png`.

- [ ] **Step 2: Ejecutar el procesador e importar**

```powershell
godot --headless --path prueba_2 --script res://tools/art/process_slime_delivered_sheets.gd
godot --headless --path prueba_2 --import
```

Expected: `SLIME_ANIMATION_OK idle=5 walk=2 jump=6 recover=12`, sin errores.

- [ ] **Step 3: Crear `slime_frames.tres`**

Configurar `idle` y `walk` en loop; `jump` y `recover` sin loop. Todas las
texturas deben provenir de `assets/player/slime/animations/`.

- [ ] **Step 4: Commit**

```powershell
git add art_raw/personaje/slime prueba_2/tools/art/process_slime_delivered_sheets.gd prueba_2/assets/player/slime/animations prueba_2/actors/player/slime_frames.tres
git commit -m "feat: procesa el arte animado del slime"
```

### Task 3: Integración visual sin alterar gameplay

**Files:**
- Modify: `prueba_2/actors/player/slime.tscn`
- Modify: `prueba_2/actors/player/slime.gd`
- Test: `prueba_2/tests/slime_animation_tests.gd`

**Interfaces:**
- Consumes: `slime_frames.tres` y el enum `State`.
- Produces: `_visual_animation() -> StringName` y `_update_sprite_animation() -> void`.

- [ ] **Step 1: Añadir el `AnimatedSprite2D`**

El nodo `Sprite` usa `slime_frames.tres`, autoplay `idle`, se dibuja delante de
los polígonos ocultos y debajo de `ScaleShell`.

- [ ] **Step 2: Implementar selección y orientación**

```gdscript
func _visual_animation() -> StringName:
	if _state in [State.LAUNCHING, State.DASHING, State.PART_DASH]:
		return &"jump"
	if _state == State.RECOVERING:
		return &"recover"
	if _continuous_moving:
		return &"walk"
	return &"idle"
```

`_update_sprite_animation()` solo llama `play()` cuando cambia el nombre y
actualiza `flip_h` desde `_facing.x`.

- [ ] **Step 3: Ejecutar GREEN y regresiones**

Run:

```powershell
godot --headless --path prueba_2 res://tests/slime_animation_tests.tscn
godot --headless --path prueba_2 --script res://tests/run_slime_audio_tests.gd
godot --headless --path prueba_2 res://tests/leg_mobility_tests.tscn
godot --headless --path prueba_2 res://tests/scale_shell_tests.tscn
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
```

Expected: todas en verde; combate `343 comprobaciones, 0 fallos`.

- [ ] **Step 4: Commit**

```powershell
git add prueba_2/actors/player/slime.gd prueba_2/actors/player/slime.tscn prueba_2/tests/slime_animation_tests.gd
git commit -m "feat: anima el slime según su movimiento"
```

### Task 4: Evidencia visual, documentación y primer push

**Files:**
- Modify: `prueba_2/tests/ui_visual_capture.gd`
- Modify: `docs/agents/ESTADO_ACTUAL.md`
- Modify: `docs/agents/REFERENCIA.md`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `art_raw/README.md`

**Interfaces:**
- Consumes: slime animado.
- Produces: captura visual y documentación reproducible.

- [ ] **Step 1: Añadir modo de captura `slime` y generar 1920 × 1080**

- [ ] **Step 2: Inspeccionar escala, pivote, orientación, barra y costra**

- [ ] **Step 3: Actualizar documentación y ejecutar arranque limpio**

- [ ] **Step 4: Commit, fusionar en `main` y verificar de nuevo**

- [ ] **Step 5: Push 1**

```powershell
git push origin main
```

Expected: `origin/main` contiene la animación del slime antes del balance.

### Task 5: Balance procedural RED→GREEN

**Files:**
- Create: `prueba_2/tests/map_balance_tests.gd`
- Modify: `prueba_2/core/map_generator.gd`

**Interfaces:**
- Consumes: `MapGenerator.NORMAL_CONTENT` y `generate_attempt(seed, attempt)`.
- Produces: pesos `60/30/10`, fáciles `1..3`, difíciles `4..7`.

- [ ] **Step 1: Escribir prueba focalizada**

Debe exigir la tabla exacta y recorrer al menos 2.000 intentos para comprobar:

```gdscript
MapGenerator.NORMAL_CONTENT == [[&"easy", 60], [&"hard", 30], [&"empty", 10]]
enemy_count >= 1 and enemy_count <= 3 # easy
enemy_count >= 4 and enemy_count <= 7 # hard
```

También muestrea `_weighted_choice()` 10.000 veces con tolerancia `0.02`.

- [ ] **Step 2: Ejecutar RED**

Run:

```powershell
godot --headless --path prueba_2 --script res://tests/map_balance_tests.gd
```

Expected: falla con tabla `50/30/20` y rangos `1` / `2..3`.

- [ ] **Step 3: Implementar mínimos cambios**

Cambiar solo `NORMAL_CONTENT`, la asignación de `enemy_count` y las dos reglas
correspondientes de `validate()`.

- [ ] **Step 4: Ejecutar GREEN y regresión de combate**

Expected: prueba focalizada verde, determinismo conservado y combate verde.

- [ ] **Step 5: Actualizar `ESTADO_ACTUAL.md` y `ARQUITECTURA.md`**

- [ ] **Step 6: Commit**

```powershell
git add prueba_2/core/map_generator.gd prueba_2/tests/map_balance_tests.gd docs/agents/ESTADO_ACTUAL.md docs/ARQUITECTURA.md
git commit -m "balance: reduce salas vacías y aumenta encuentros"
```

### Task 6: Segundo push y cierre

**Files:** Ninguno adicional salvo una corrección encontrada por pruebas.

- [ ] **Step 1: Reimportar y ejecutar toda la matriz final**

- [ ] **Step 2: Arranque controlado con `errors: []`**

- [ ] **Step 3: Fusionar el balance en `main`**

- [ ] **Step 4: Push 2**

```powershell
git push origin main
```

- [ ] **Step 5: Confirmar que `main == origin/main` y preservar el checkout local**
