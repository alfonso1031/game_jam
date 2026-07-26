# EXP07 Claw Attack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrar los cinco fotogramas de `Claw_Ataque` como la animación de pellizco del Experimento 07 — Crustáceo Escudo y sincronizar el contacto visual con su daño existente.

**Architecture:** Los originales se guardan como fuentes y una herramienta GDScript genera fotogramas compactos con un recorte común. El `SpriteFrames` del enemigo reutiliza esos fotogramas en `pinch_windup` y en reversa durante `recover`; la máquina de estados conserva la autoridad del daño.

**Tech Stack:** Godot 4.7.1, GDScript tipado, `Image`, `AnimatedSprite2D`, recursos `.tres`, PNG transparente y pruebas headless.

## Global Constraints

- El arte pertenece al enemigo EXP07, no al slime.
- `PINCH_WINDUP` conserva 0,8 s, alcance 220 px y cono de 50 grados.
- `_pinch()` sigue siendo el único lugar que aplica daño y retroceso.
- `crusher_claw` continúa como drop, sin reutilizar esta animación corporal.
- Los cinco lienzos 1920 × 1080 no se usan directamente en runtime.

---

### Task 1: Fuentes, procesador reproducible y contrato

**Files:**
- Create: `prueba_2/assets/enemies/exp07_crustacean/source_attack/claw_attack_00.png`
- Create: `prueba_2/assets/enemies/exp07_crustacean/source_attack/claw_attack_01.png`
- Create: `prueba_2/assets/enemies/exp07_crustacean/source_attack/claw_attack_02.png`
- Create: `prueba_2/assets/enemies/exp07_crustacean/source_attack/claw_attack_03.png`
- Create: `prueba_2/assets/enemies/exp07_crustacean/source_attack/claw_attack_04.png`
- Create: `prueba_2/tools/art/process_exp07_claw_frames.gd`
- Create: `prueba_2/tests/exp07_attack_tests.gd`
- Create: `prueba_2/tests/exp07_attack_tests.tscn`

**Interfaces:**
- Produces: `exp07_pinch_00.png` a `exp07_pinch_04.png`, todos 192 × 108 y con registro común.
- Consumes: cinco originales transparentes de 1920 × 1080.

- [ ] **Step 1: Escribir la prueba que falla**

La prueba carga `exp07_crustacean_frames.tres` y exige:

```gdscript
_check(frames.has_animation(&"pinch_windup"), "existe windup")
_check(frames.get_frame_count(&"pinch_windup") == 5, "usa cinco fotogramas")
_check(not frames.get_animation_loop(&"pinch_windup"), "el ataque no hace loop")
_check(
	is_equal_approx(frames.get_animation_speed(&"pinch_windup"), 6.25),
	"cinco frames ocupan 0.8 segundos"
)
```

Para cada textura comprueba que mide 192 × 108 y que su ruta contiene
`exp07_pinch_`.

- [ ] **Step 2: Ejecutar y confirmar el fallo**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/exp07_attack_tests.tscn
```

- [ ] **Step 3: Copiar las fuentes con nombres estables**

```powershell
$assetTemp = Join-Path $env:TEMP 'gamejam-exp07-claw'
New-Item -ItemType Directory -Force -Path $assetTemp | Out-Null
Expand-Archive -LiteralPath 'C:\Users\jcbla\Downloads\Claw_Ataque-20260726T044638Z-1-001.zip' -DestinationPath $assetTemp -Force
$destination = 'prueba_2\assets\enemies\exp07_crustacean\source_attack'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
0..4 | ForEach-Object {
	$source = Join-Path $assetTemp ('Claw_Ataque\Timeline 1_{0:D4}.png' -f $_)
	$target = Join-Path $destination ('claw_attack_{0:D2}.png' -f $_)
	Copy-Item -LiteralPath $source -Destination $target
}
```

- [ ] **Step 4: Implementar el procesador**

El script carga las cinco imágenes, calcula la unión de `get_used_rect()`, añade
24 px de margen, recorta la misma región en todas y redimensiona a 192 × 108:

```gdscript
extends SceneTree

const SOURCE_DIR := "res://assets/enemies/exp07_crustacean/source_attack"
const OUTPUT_DIR := "res://assets/enemies/exp07_crustacean"
const OUTPUT_SIZE := Vector2i(192, 108)

func _init() -> void:
	var images: Array[Image] = []
	var union := Rect2i()
	for index in range(5):
		var image := Image.load_from_file(
			ProjectSettings.globalize_path(
				"%s/claw_attack_%02d.png" % [SOURCE_DIR, index]
			)
		)
		images.append(image)
		union = image.get_used_rect() if union.size == Vector2i.ZERO else union.merge(image.get_used_rect())
	union = union.grow(24).intersection(Rect2i(Vector2i.ZERO, images[0].get_size()))
	for index in range(images.size()):
		var frame := images[index].get_region(union)
		frame.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		var error := frame.save_png(
			ProjectSettings.globalize_path(
				"%s/exp07_pinch_%02d.png" % [OUTPUT_DIR, index]
			)
		)
		if error != OK:
			push_error(error_string(error))
			quit(1)
	quit(0)
```

- [ ] **Step 5: Ejecutar el procesador e importar**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --script res://tools/art/process_exp07_claw_frames.gd
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --import
```

- [ ] **Step 6: Commit**

```powershell
git add prueba_2/assets/enemies/exp07_crustacean/source_attack prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_*.png prueba_2/tools/art/process_exp07_claw_frames.gd prueba_2/tests/exp07_attack_tests.gd prueba_2/tests/exp07_attack_tests.tscn
git commit -m "test: prepara arte de ataque del exp07"
```

### Task 2: Animación sincronizada con la máquina de estados

**Files:**
- Modify: `prueba_2/actors/enemies/exp07_crustacean_frames.tres`
- Modify: `prueba_2/actors/enemies/exp07_crustacean.gd`
- Modify: `prueba_2/tests/exp07_attack_tests.gd`
- Modify: `prueba_2/tests/check_enemy_animations.gd`

**Interfaces:**
- Consumes: `exp07_pinch_00.png` a `exp07_pinch_04.png`.
- Produces: animaciones `pinch_windup` de cinco frames a 6,25 FPS y `recover` invertida a 8,333333 FPS.

- [ ] **Step 1: Ampliar la prueba de estados**

Además del contrato de frames, instanciar EXP07, fijar
`_state = State.PINCH_WINDUP`, comprobar `_visual_state() == &"pinch_windup"`,
fijar `RECOVER` y comprobar `&"recover"`. Exigir que el último frame de windup
sea el primero de recover y que recover termine en el primer frame del ataque.

- [ ] **Step 2: Modificar `SpriteFrames`**

Añadir cinco `ext_resource` para los frames procesados. `pinch_windup` usa
00→04, no hace loop y usa velocidad 6,25. `recover` usa 04→00, no hace loop y
usa velocidad `8.333333`, ocupando 0,6 s.

- [ ] **Step 3: Mantener el daño en `_pinch()`**

No añadir señales de daño al sprite. En `exp07_crustacean.gd`, actualizar el
comentario de presentación para explicar que el último fotograma ocupa el tramo
0,64–0,8 s y `_pinch()` se ejecuta al terminar `PINCH_WINDUP`. Conservar:

```gdscript
func _pinch() -> void:
	hit_player_cone(PINCH_RANGE, PINCH_ARC, contact_damage, facing, PINCH_KNOCKBACK)
	_pinch_cd = PINCH_COOLDOWN
	_state = State.RECOVER
	_timer = RECOVER_TIME
	_strafe_sign *= -1.0
```

- [ ] **Step 4: Ejecutar pruebas**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/exp07_attack_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/check_enemy_animations.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/combat_smoke.tscn
```

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/actors/enemies/exp07_crustacean_frames.tres prueba_2/actors/enemies/exp07_crustacean.gd prueba_2/tests/exp07_attack_tests.gd prueba_2/tests/check_enemy_animations.gd
git commit -m "feat: anima el pellizco del crustaceo"
```

### Task 3: Captura, documentación y control de recursos

**Files:**
- Modify: `prueba_2/tests/ui_visual_capture.gd`
- Modify: `prueba_2/docs/ART_SPEC.md`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`

**Interfaces:**
- Produces: modo visual `exp07_attack`.

- [ ] **Step 1: Añadir fixture visual**

El modo `exp07_attack` instancia `exp07_crustacean.tscn` a escala normal, fija
`_state = PINCH_WINDUP`, reproduce la animación y captura cuando
`Sprite.frame == 4`.

- [ ] **Step 2: Documentar fuentes y runtime**

Registrar:

- originales 1920 × 1080 bajo `source_attack`;
- procesador reproducible;
- runtime 192 × 108;
- velocidades 6,25 y 8,333333;
- `_pinch()` como autoridad del daño;
- prohibición de reutilizar esta secuencia en el slime.

- [ ] **Step 3: Capturar y revisar**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- exp07_attack user://exp07-attack.png 1920x1080
```

Verificar que el cuerpo no salte de escala, el extremo del ataque sea legible y
el sprite no tenga un borde blanco.

- [ ] **Step 4: Verificación final**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --import
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/exp07_attack_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/check_enemy_animations.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/combat_smoke.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --quit-after 3
git ls-files --error-unmatch prueba_2/assets/enemies/exp07_crustacean/source_attack/claw_attack_00.png prueba_2/assets/enemies/exp07_crustacean/source_attack/claw_attack_01.png prueba_2/assets/enemies/exp07_crustacean/source_attack/claw_attack_02.png prueba_2/assets/enemies/exp07_crustacean/source_attack/claw_attack_03.png prueba_2/assets/enemies/exp07_crustacean/source_attack/claw_attack_04.png prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_00.png prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_01.png prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_02.png prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_03.png prueba_2/assets/enemies/exp07_crustacean/exp07_pinch_04.png
```

- [ ] **Step 5: Commit**

```powershell
git add prueba_2/tests/ui_visual_capture.gd prueba_2/docs/ART_SPEC.md docs/ARQUITECTURA.md docs/agents/REFERENCIA.md
git commit -m "docs: registra ataque ilustrado del exp07"
```
