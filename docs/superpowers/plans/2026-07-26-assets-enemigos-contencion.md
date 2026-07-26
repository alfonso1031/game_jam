# Containment Enemy Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generar e integrar arte animado para EXP01, EXP02, EXP03 y la Quimera Albina, de modo que ningún enemigo de Contención dependa de un cuerpo `Polygon2D` o de un sprite estático.

**Architecture:** Las máquinas de estados existentes continúan siendo la única autoridad de movimiento, daño y tiempos. Cada personaje usa seis poses procesadas, un recurso `SpriteFrames` propio y una traducción `_visual_state()`; `enemy_base.gd` conserva la presentación compartida de los experimentos y `boss_core.gd` mantiene la presentación específica del jefe.

**Tech Stack:** Godot 4.7.1, GDScript, `AnimatedSprite2D`, recursos `.tres`, PNG con alfa, herramienta integrada de generación de imágenes y eliminación local de chroma key.

## Global Constraints

- Alcance: EXP01, EXP02, EXP03, EXP07 y la Quimera Albina del piso Contención.
- EXP07 conserva sus ocho imágenes, `SpriteFrames`, mecánicas y animaciones actuales.
- No cambiar vida, daño, velocidad, alcance, colisiones, drops ni probabilidades.
- Perspectiva cenital inclinada 3/4, orientación fuente hacia la derecha y estilo ilustrado orgánico de EXP07.
- Los PNG runtime deben tener alfa, pivote centrado, margen libre y ninguna sombra proyectada.
- Los originales generados viven fuera de `prueba_2`; Godot solo importa las poses procesadas.
- La entidad de recompensa de la segunda sala no se convierte en enemigo en este cambio.
- No añadir animaciones de muerte.
- No ejecutar suites automáticas, según la instrucción del equipo. La revisión será visual, estructural y mediante arranque jugable.
- No incluir cambios locales ajenos o archivos `.import` no relacionados en los commits de esta implementación.

---

### Task 1: Generar las cuatro hojas fuente

**Files:**
- Create: `art_raw/enemigos/containment/exp01_centipede/source_sheet.png`
- Create: `art_raw/enemigos/containment/exp02_spider/source_sheet.png`
- Create: `art_raw/enemigos/containment/exp03_saurian/source_sheet.png`
- Create: `art_raw/enemigos/containment/boss_chimera/source_sheet.png`
- Reference: `prueba_2/assets/enemies/exp07_crustacean/exp07_crustacean_00.png`
- Reference: `prueba_2/assets/bosses/containment_chimera/chimera.png`

**Interfaces:**
- Consumes: las referencias visuales existentes y las seis poses definidas en la especificación.
- Produces: cuatro hojas 3 × 2 con fondo uniforme `#ff00ff`, listas para extraer alfa y separar.

- [ ] **Step 1: Inspeccionar las referencias a resolución original**

Abrir con inspección visual:

```text
prueba_2/assets/enemies/exp07_crustacean/exp07_crustacean_00.png
prueba_2/assets/bosses/containment_chimera/chimera.png
```

Confirmar que EXP07 fija el medio, los planos de color y el detalle luminoso,
mientras la imagen de la Quimera fija identidad, proporción y paleta del jefe.

- [ ] **Step 2: Generar EXP01 con la referencia de EXP07**

Usar la herramienta integrada `image_gen` con
`exp07_crustacean_00.png` como referencia de estilo y este prompt:

```text
Use case: stylized-concept
Asset type: 2D game animation sprite sheet, six poses in a precise 3 columns by 2 rows layout
Primary request: create the EXP01 Needle Centipede for a top-down action game. Exactly the same creature in all six cells. Poses in reading order: body waves upward; body waves downward; segments compress before charging; spines rise and head lowers at maximum windup; fully stretched straight charge; stunned bent body with fallen spines.
Input images: Image 1 is the required illustration style reference only.
Subject: long segmented blue-gray biological centipede, short legs, backward needle spines, luminous eye or organ identifying the head on the right.
Style/medium: soft vector-like organic illustration, simple layered shapes, matching Image 1.
Composition/framing: wide 3:2 sheet, six equal square cells, one centered right-facing creature per cell, identical scale and registration, generous padding.
Lighting/mood: normal bright material colors, no baked lighting.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background.
Constraints: background is one uniform color with no texture; no cast shadow; no reflection; no labels; no numbers; no borders; no grid lines; do not use #ff00ff in the creature.
Avoid: realism, pixel art, extra creatures, detached body parts, inconsistent anatomy, front-facing poses, text, watermark.
```

Guardar exactamente el resultado seleccionado en
`art_raw/enemigos/containment/exp01_centipede/source_sheet.png`.

- [ ] **Step 3: Generar EXP02 con la referencia de EXP07**

Usar la misma referencia y este prompt:

```text
Use case: stylized-concept
Asset type: 2D game animation sprite sheet, six poses in a precise 3 columns by 2 rows layout
Primary request: create the EXP02 Armored Arachnid for a top-down action game. Exactly the same creature in all six cells. Poses in reading order: alternating diagonal leg support A; alternating diagonal leg support B; swollen abdomen and open web mouth before shooting; head extended while releasing web; body lifted with all legs spread before a slam; compressed low impact pose with legs planted.
Input images: Image 1 is the required illustration style reference only.
Subject: heavy octagonal gray-blue organic armor shell, eight mechanical-biological legs, web mouth on the right, readable abdomen.
Style/medium: soft vector-like organic illustration, simple layered shapes, matching Image 1.
Composition/framing: wide 3:2 sheet, six equal square cells, one centered right-facing creature per cell, identical scale and registration, generous padding for all legs.
Lighting/mood: normal bright material colors, no baked lighting.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background.
Constraints: background is one uniform color with no texture; shoot windup and slam windup must have clearly different silhouettes; no cast shadow; no labels; no borders; no grid lines; do not use #ff00ff in the creature.
Avoid: realism, pixel art, fewer or extra legs, inconsistent armor, text, watermark.
```

Guardar exactamente el resultado seleccionado en
`art_raw/enemigos/containment/exp02_spider/source_sheet.png`.

- [ ] **Step 4: Generar EXP03 con la referencia de EXP07**

Usar la misma referencia y este prompt:

```text
Use case: stylized-concept
Asset type: 2D game animation sprite sheet, six poses in a precise 3 columns by 2 rows layout
Primary request: create the EXP03 Scaled Saurian for a top-down action game. Exactly the same creature in all six cells. Poses in reading order: front-foot walking support; rear-foot walking support; tail begins coiling; body lowers and tail becomes fully tense; broad lateral tail sweep; exhausted recovery with fallen tail.
Input images: Image 1 is the required illustration style reference only.
Subject: eyeless reptile with wedge-shaped head on the right, thick tail on the left, gray-green overlapping scales, no visible eyes.
Style/medium: soft vector-like organic illustration, simple layered shapes, matching Image 1.
Composition/framing: wide 3:2 sheet, six equal square cells, one centered right-facing creature per cell, identical scale and registration, generous padding around the sweeping tail.
Lighting/mood: normal bright material colors, no baked lighting.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background.
Constraints: background is one uniform color with no texture; head and tail must be unmistakable; the creature must remain eyeless; no cast shadow; no labels; no borders; no grid lines; do not use #ff00ff in the creature.
Avoid: realism, pixel art, visible eyes, thin tail, inconsistent anatomy, text, watermark.
```

Guardar exactamente el resultado seleccionado en
`art_raw/enemigos/containment/exp03_saurian/source_sheet.png`.

- [ ] **Step 5: Generar la Quimera usando identidad y estilo**

Usar `chimera.png` como referencia de identidad y
`exp07_crustacean_00.png` como referencia de medio:

```text
Use case: stylized-concept
Asset type: 2D game boss animation sprite sheet, six poses in a precise 3 columns by 2 rows layout
Primary request: redraw the existing Albino Chimera as exactly the same boss in all six cells. Poses in reading order: wings moving upward during a corner burst; wings moving downward during a corner burst; body compresses and wings begin closing to aim; maximum compressed aim pose with bright frontal organ; body and wings stretched forward in a pounce; flattened disoriented recovery with open wings.
Input images: Image 1 is the identity, anatomy, proportions and palette reference. Image 2 is the required soft vector-like illustration style reference.
Subject: preserve the wide low albino winged chimera from Image 1, with a clearly solid central torso and non-solid-looking wings.
Style/medium: soft vector-like organic illustration, simple layered shapes, matching Image 2 while preserving Image 1.
Composition/framing: wide 3:2 sheet, six equal square cells, one centered right-facing boss per cell, identical scale and registration, generous padding around wings.
Lighting/mood: pale biological colors with a readable luminous frontal detail, no baked lighting.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background.
Constraints: background is one uniform color with no texture; preserve boss identity; no cast shadow; no labels; no borders; no grid lines; do not use #ff00ff in the creature.
Avoid: a new species, realistic fur or feathers, pixel art, detached wings, inconsistent anatomy, text, watermark.
```

Guardar exactamente el resultado seleccionado en
`art_raw/enemigos/containment/boss_chimera/source_sheet.png`.

- [ ] **Step 6: Validar visualmente las cuatro hojas**

Abrir las cuatro hojas y comprobar:

```text
exactamente seis poses por hoja;
misma criatura y escala dentro de cada hoja;
orden 3 × 2 correcto;
ningún elemento toca los límites de su celda;
fondo magenta uniforme;
sin texto, bordes, sombras ni elementos adicionales.
```

Si una hoja falla, repetir únicamente esa generación con una corrección
dirigida al defecto observado.

- [ ] **Step 7: Commit de las fuentes aprobadas**

```powershell
git add -- art_raw/enemigos/containment
git commit -m "art: add containment enemy source sheets"
```

---

### Task 2: Extraer transparencia y poses runtime

**Files:**
- Create: `art_raw/enemigos/containment/exp01_centipede/source_sheet_alpha.png`
- Create: `art_raw/enemigos/containment/exp02_spider/source_sheet_alpha.png`
- Create: `art_raw/enemigos/containment/exp03_saurian/source_sheet_alpha.png`
- Create: `art_raw/enemigos/containment/boss_chimera/source_sheet_alpha.png`
- Create: `prueba_2/tools/art/process_containment_enemy_sheets.gd`
- Create: `prueba_2/assets/enemies/exp01_centipede/*.png`
- Create: `prueba_2/assets/enemies/exp02_spider/*.png`
- Create: `prueba_2/assets/enemies/exp03_saurian/*.png`
- Create: `prueba_2/assets/bosses/containment_chimera/animations/*.png`

**Interfaces:**
- Consumes: hojas 3 × 2 con alfa y orden de poses fijo.
- Produces: seis PNG centrados por personaje y una herramienta reproducible de separación.

- [ ] **Step 1: Retirar el chroma key con la herramienta instalada**

Ejecutar una vez por hoja, usando el Python disponible en el workspace:

```powershell
$removeKey = 'C:\Users\jcbla\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py'
python $removeKey --input art_raw/enemigos/containment/exp01_centipede/source_sheet.png --out art_raw/enemigos/containment/exp01_centipede/source_sheet_alpha.png --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
python $removeKey --input art_raw/enemigos/containment/exp02_spider/source_sheet.png --out art_raw/enemigos/containment/exp02_spider/source_sheet_alpha.png --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
python $removeKey --input art_raw/enemigos/containment/exp03_saurian/source_sheet.png --out art_raw/enemigos/containment/exp03_saurian/source_sheet_alpha.png --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
python $removeKey --input art_raw/enemigos/containment/boss_chimera/source_sheet.png --out art_raw/enemigos/containment/boss_chimera/source_sheet_alpha.png --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
```

- [ ] **Step 2: Crear la configuración del procesador**

Crear `process_containment_enemy_sheets.gd` con esta configuración exacta:

```gdscript
extends SceneTree

const CONFIG := {
	"exp01_centipede": {
		"source": "res://../art_raw/enemigos/containment/exp01_centipede/source_sheet_alpha.png",
		"output": "res://assets/enemies/exp01_centipede",
		"canvas": Vector2i(160, 160),
		"fit": Vector2i(104, 104),
		"names": [
			"exp01_approach_00", "exp01_approach_01",
			"exp01_windup_00", "exp01_windup_01",
			"exp01_charge_00", "exp01_rest_00",
		],
	},
	"exp02_spider": {
		"source": "res://../art_raw/enemigos/containment/exp02_spider/source_sheet_alpha.png",
		"output": "res://assets/enemies/exp02_spider",
		"canvas": Vector2i(160, 160),
		"fit": Vector2i(100, 100),
		"names": [
			"exp02_reposition_00", "exp02_reposition_01",
			"exp02_shoot_windup_00", "exp02_shoot_release_00",
			"exp02_slam_windup_00", "exp02_slam_impact_00",
		],
	},
	"exp03_saurian": {
		"source": "res://../art_raw/enemigos/containment/exp03_saurian/source_sheet_alpha.png",
		"output": "res://assets/enemies/exp03_saurian",
		"canvas": Vector2i(160, 160),
		"fit": Vector2i(112, 96),
		"names": [
			"exp03_walk_00", "exp03_walk_01",
			"exp03_tail_windup_00", "exp03_tail_windup_01",
			"exp03_tail_sweep_00", "exp03_recover_00",
		],
	},
	"boss_chimera": {
		"source": "res://../art_raw/enemigos/containment/boss_chimera/source_sheet_alpha.png",
		"output": "res://assets/bosses/containment_chimera/animations",
		"canvas": Vector2i(384, 256),
		"fit": Vector2i(350, 205),
		"names": [
			"chimera_seek_00", "chimera_seek_01",
			"chimera_aim_00", "chimera_aim_01",
			"chimera_pounce_00", "chimera_recover_00",
		],
	},
}
```

- [ ] **Step 3: Implementar separación, recorte y centrado**

Completar el script con estas firmas:

```gdscript
func _init() -> void:
	for config: Dictionary in CONFIG.values():
		_process_sheet(config)
	quit()


func _process_sheet(config: Dictionary) -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(config["source"]))
	assert(sheet != null and not sheet.is_empty(), "No carga hoja: %s" % config["source"])
	assert(sheet.get_width() % 3 == 0, "El ancho no admite tres columnas")
	assert(sheet.get_height() % 2 == 0, "El alto no admite dos filas")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(config["output"]))
	var cell_size := Vector2i(sheet.get_width() / 3, sheet.get_height() / 2)
	var names: Array = config["names"]
	for index in range(6):
		var cell := sheet.get_region(Rect2i(
			Vector2i(index % 3, index / 3) * cell_size,
			cell_size
		))
		var bounds := _alpha_bounds(cell)
		assert(bounds.size.x > 0 and bounds.size.y > 0, "Pose vacía: %s" % names[index])
		var pose := cell.get_region(bounds)
		var fitted := _fit_centered(pose, config["canvas"], config["fit"])
		var destination: String = "%s/%s.png" % [config["output"], names[index]]
		var result := fitted.save_png(ProjectSettings.globalize_path(destination))
		assert(result == OK, "No guarda pose: %s" % destination)


func _alpha_bounds(image: Image) -> Rect2i:
	var min_point := Vector2i(image.get_width(), image.get_height())
	var max_point := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.02:
				continue
			min_point.x = mini(min_point.x, x)
			min_point.y = mini(min_point.y, y)
			max_point.x = maxi(max_point.x, x)
			max_point.y = maxi(max_point.y, y)
	if max_point.x < min_point.x:
		return Rect2i()
	return Rect2i(min_point, max_point - min_point + Vector2i.ONE)


func _fit_centered(source: Image, canvas_size: Vector2i, fit_size: Vector2i) -> Image:
	var ratio := minf(
		float(fit_size.x) / float(source.get_width()),
		float(fit_size.y) / float(source.get_height())
	)
	var size := Vector2i(
		maxi(1, roundi(source.get_width() * ratio)),
		maxi(1, roundi(source.get_height() * ratio))
	)
	source.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var at := (canvas_size - size) / 2
	canvas.blit_rect(source, Rect2i(Vector2i.ZERO, size), at)
	return canvas
```

- [ ] **Step 4: Ejecutar el procesador**

```powershell
& 'C:\Users\jcbla\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --script res://tools/art/process_containment_enemy_sheets.gd
```

Usar el ejecutable Godot 4.7.1 detectado en la máquina, sin cambiar el
`project.godot`.

- [ ] **Step 5: Validar los 24 PNG runtime**

Comprobar con inspección de imagen:

```text
cada PNG tiene alfa;
las cuatro esquinas son transparentes;
el personaje queda centrado;
no existe halo magenta;
ninguna pose está cortada;
los seis archivos de cada personaje conservan escala compatible.
```

- [ ] **Step 6: Commit de poses y procesador**

```powershell
git add -- art_raw/enemigos/containment prueba_2/tools/art/process_containment_enemy_sheets.gd prueba_2/assets/enemies/exp01_centipede prueba_2/assets/enemies/exp02_spider prueba_2/assets/enemies/exp03_saurian prueba_2/assets/bosses/containment_chimera/animations
git commit -m "art: process animated containment enemy poses"
```

---

### Task 3: Crear los recursos SpriteFrames

**Files:**
- Create: `prueba_2/actors/enemies/exp01_centipede_frames.tres`
- Create: `prueba_2/actors/enemies/exp02_spider_frames.tres`
- Create: `prueba_2/actors/enemies/exp03_saurian_frames.tres`
- Create: `prueba_2/actors/boss/boss_core_frames.tres`

**Interfaces:**
- Consumes: los 24 PNG runtime de Task 2.
- Produces: animaciones nombradas exactamente como las máquinas de estados.

- [ ] **Step 1: Crear las animaciones de EXP01**

Definir:

```text
approach: [approach_00, approach_01, approach_00], loop=true, speed=6.0
windup: [windup_00, windup_01], loop=false, speed=3.076923
charge: [charge_00], loop=false, speed=1.0
rest: [rest_00], loop=false, speed=1.0
```

Cada entrada será un `ext_resource Texture2D` a la carpeta
`assets/enemies/exp01_centipede/`.

- [ ] **Step 2: Crear las animaciones de EXP02**

Definir:

```text
reposition: [reposition_00, reposition_01], loop=true, speed=4.0
shoot_windup: [shoot_windup_00, shoot_release_00], loop=false, speed=2.666667
slam_windup: [slam_windup_00, slam_impact_00], loop=false, speed=2.222222
recover: [slam_impact_00, reposition_01], loop=false, speed=3.0
```

Cada entrada será un `ext_resource Texture2D` a la carpeta
`assets/enemies/exp02_spider/`.

- [ ] **Step 3: Crear las animaciones de EXP03**

Definir:

```text
walk: [walk_00, walk_01], loop=true, speed=5.0
tail_windup: [tail_windup_00, tail_windup_01, tail_sweep_00], loop=false, speed=6.0
recover: [recover_00, walk_00], loop=false, speed=3.636364
```

Cada entrada será un `ext_resource Texture2D` a la carpeta
`assets/enemies/exp03_saurian/`.

- [ ] **Step 4: Crear las animaciones de la Quimera**

Definir:

```text
seek_corner: [seek_00, seek_01], loop=true, speed=7.0
corner_aim: [aim_00, aim_01], loop=true, speed=3.0
pounce: [pounce_00], loop=false, speed=1.0
recover: [recover_00, seek_00], loop=false, speed=4.0
```

Cada entrada será un `ext_resource Texture2D` a
`assets/bosses/containment_chimera/animations/`.

- [ ] **Step 5: Comprobar referencias**

```powershell
rg -n 'res://assets/(enemies|bosses)/' prueba_2/actors/enemies/*_frames.tres prueba_2/actors/boss/boss_core_frames.tres
git diff --check
```

Esperado: cada una de las 24 rutas apunta a un PNG existente y no hay errores
de formato.

- [ ] **Step 6: Commit de recursos**

```powershell
git add -- prueba_2/actors/enemies/exp01_centipede_frames.tres prueba_2/actors/enemies/exp02_spider_frames.tres prueba_2/actors/enemies/exp03_saurian_frames.tres prueba_2/actors/boss/boss_core_frames.tres
git commit -m "feat: define containment enemy sprite animations"
```

---

### Task 4: Integrar EXP01

**Files:**
- Modify: `prueba_2/actors/enemies/exp01_centipede.gd`
- Modify: `prueba_2/actors/enemies/exp01_centipede.tscn`

**Interfaces:**
- Consumes: animaciones `approach`, `windup`, `charge` y `rest`.
- Produces: `_visual_state() -> StringName` para `enemy_base.gd`.

- [ ] **Step 1: Añadir la traducción de estado visual**

Añadir:

```gdscript
func _visual_state() -> StringName:
	match _state:
		State.APPROACH:
			return &"approach"
		State.WINDUP:
			return &"windup"
		State.CHARGE:
			return &"charge"
		State.REST:
			return &"rest"
	return &"approach"
```

- [ ] **Step 2: Sustituir el polígono por el sprite**

En la escena, añadir el `ext_resource` de
`exp01_centipede_frames.tres`, eliminar `Body: Polygon2D` y crear:

```ini
[node name="Sprite" type="AnimatedSprite2D" parent="."]
sprite_frames = ExtResource("2")
animation = &"approach"
autoplay = "approach"
```

No tocar los dos `CircleShape2D`, propiedades del enemigo, hitbox ni drop.

- [ ] **Step 3: Verificar carga estructural**

```powershell
& 'C:\Users\jcbla\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --import
```

Esperado: Godot importa los PNG y la escena no informa recursos faltantes.

- [ ] **Step 4: Commit de EXP01**

```powershell
git add -- prueba_2/actors/enemies/exp01_centipede.gd prueba_2/actors/enemies/exp01_centipede.tscn prueba_2/assets/enemies/exp01_centipede/*.import
git commit -m "feat: animate needle centipede"
```

---

### Task 5: Integrar EXP02

**Files:**
- Modify: `prueba_2/actors/enemies/exp02_spider.gd`
- Modify: `prueba_2/actors/enemies/exp02_spider.tscn`

**Interfaces:**
- Consumes: animaciones `reposition`, `shoot_windup`, `slam_windup` y `recover`.
- Produces: `_visual_state() -> StringName` para `enemy_base.gd`.

- [ ] **Step 1: Añadir la traducción de estado visual**

```gdscript
func _visual_state() -> StringName:
	match _state:
		State.REPOSITION:
			return &"reposition"
		State.SHOOT_WINDUP:
			return &"shoot_windup"
		State.SLAM_WINDUP:
			return &"slam_windup"
		State.RECOVER:
			return &"recover"
	return &"reposition"
```

- [ ] **Step 2: Sustituir el polígono por el sprite**

```ini
[node name="Sprite" type="AnimatedSprite2D" parent="."]
sprite_frames = ExtResource("2")
animation = &"reposition"
autoplay = "reposition"
```

No tocar vida, movimiento, proyectil, área de aplastamiento, hitboxes o drops.

- [ ] **Step 3: Importar y cargar la escena**

```powershell
& 'C:\Users\jcbla\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --import
```

Esperado: no hay referencias rotas del Arácnido.

- [ ] **Step 4: Commit de EXP02**

```powershell
git add -- prueba_2/actors/enemies/exp02_spider.gd prueba_2/actors/enemies/exp02_spider.tscn prueba_2/assets/enemies/exp02_spider/*.import
git commit -m "feat: animate armored arachnid"
```

---

### Task 6: Integrar EXP03

**Files:**
- Modify: `prueba_2/actors/enemies/exp03_saurian.gd`
- Modify: `prueba_2/actors/enemies/exp03_saurian.tscn`

**Interfaces:**
- Consumes: animaciones `walk`, `tail_windup` y `recover`.
- Produces: `_visual_state() -> StringName` para `enemy_base.gd`.

- [ ] **Step 1: Añadir la traducción de estado visual**

```gdscript
func _visual_state() -> StringName:
	match _state:
		State.WALK:
			return &"walk"
		State.TAIL_WINDUP:
			return &"tail_windup"
		State.RECOVER:
			return &"recover"
	return &"walk"
```

- [ ] **Step 2: Sustituir el polígono por el sprite**

```ini
[node name="Sprite" type="AnimatedSprite2D" parent="."]
sprite_frames = ExtResource("2")
animation = &"walk"
autoplay = "walk"
```

No tocar la comprobación de flanqueo, el cono del coletazo, la colisión o los
drops.

- [ ] **Step 3: Importar y cargar la escena**

```powershell
& 'C:\Users\jcbla\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --import
```

Esperado: no hay referencias rotas del Saurio.

- [ ] **Step 4: Commit de EXP03**

```powershell
git add -- prueba_2/actors/enemies/exp03_saurian.gd prueba_2/actors/enemies/exp03_saurian.tscn prueba_2/assets/enemies/exp03_saurian/*.import
git commit -m "feat: animate scaled saurian"
```

---

### Task 7: Integrar la Quimera Albina

**Files:**
- Modify: `prueba_2/actors/boss/boss_core.gd`
- Modify: `prueba_2/actors/boss/boss_core.tscn`

**Interfaces:**
- Consumes: animaciones `seek_corner`, `corner_aim`, `pounce` y `recover`.
- Produces: selección de animación sin reinicio por fotograma.

- [ ] **Step 1: Cambiar el tipo del sprite en el script**

```gdscript
@onready var sprite: AnimatedSprite2D = $Sprite
```

- [ ] **Step 2: Añadir selección de animación**

```gdscript
func _visual_state() -> StringName:
	match _state:
		State.SEEK_CORNER:
			return &"seek_corner"
		State.CORNER_AIM:
			return &"corner_aim"
		State.POUNCE:
			return &"pounce"
		State.RECOVER:
			return &"recover"
	return &"seek_corner"


func _update_sprite_animation() -> void:
	var wanted := _visual_state()
	if sprite.animation != wanted:
		sprite.play(wanted)
```

Llamar `_update_sprite_animation()` una vez desde `_update_visual()`, antes de
aplicar `flip_h`, escala, rotación y modulación.

- [ ] **Step 3: Adaptar la escala runtime**

Conservar el estiramiento mecánico, sustituyendo la base `0.22` por `1.0`:

```gdscript
sprite.scale = Vector2(stretch, squash)
```

- [ ] **Step 4: Sustituir Sprite2D en la escena**

Reemplazar la textura estática por:

```ini
[ext_resource type="SpriteFrames" path="res://actors/boss/boss_core_frames.tres" id="2"]

[node name="Sprite" type="AnimatedSprite2D" parent="."]
sprite_frames = ExtResource("2")
animation = &"seek_corner"
autoplay = "seek_corner"
```

No tocar sombra, luz, cápsulas, barra de vida, línea de apuntado, fases o drops.

- [ ] **Step 5: Importar y cargar el jefe**

```powershell
& 'C:\Users\jcbla\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --import
```

Esperado: `boss_core.tscn` carga con su `AnimatedSprite2D` y las cuatro
animaciones existen.

- [ ] **Step 6: Commit del jefe**

```powershell
git add -- prueba_2/actors/boss/boss_core.gd prueba_2/actors/boss/boss_core.tscn prueba_2/assets/bosses/containment_chimera/animations/*.import
git commit -m "feat: animate containment chimera boss"
```

---

### Task 8: Documentar y entregar la versión jugable

**Files:**
- Modify: `prueba_2/docs/ART_SPEC.md`
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`

**Interfaces:**
- Consumes: rutas, nombres de animación y herramientas ya integradas.
- Produces: documentación operativa y una versión ejecutable para revisión manual.

- [ ] **Step 1: Actualizar la especificación de arte**

Registrar:

```text
EXP01, EXP02 y EXP03 ya no usan Polygon2D;
cada uno usa seis poses procesadas y su SpriteFrames;
la Quimera usa seis poses y cuatro animaciones;
EXP07 continúa siendo la referencia y no fue redibujado;
process_containment_enemy_sheets.gd reproduce el recorte y centrado.
```

- [ ] **Step 2: Actualizar arquitectura y referencia operativa**

Documentar el flujo:

```text
máquina de estados -> _visual_state() -> AnimatedSprite2D;
arte crudo fuera de prueba_2;
poses runtime dentro de assets;
SpriteFrames junto al actor;
daño y tiempos continúan en los scripts de IA.
```

- [ ] **Step 3: Confirmar que no quedan polígonos en enemigos de Contención**

```powershell
rg -n 'name="Body" type="Polygon2D"' prueba_2/actors/enemies/exp01_centipede.tscn prueba_2/actors/enemies/exp02_spider.tscn prueba_2/actors/enemies/exp03_saurian.tscn prueba_2/actors/enemies/exp07_crustacean.tscn
```

Esperado: ninguna coincidencia.

- [ ] **Step 4: Confirmar que todos los recursos están rastreados**

```powershell
git ls-files --error-unmatch art_raw/enemigos/containment/exp01_centipede/source_sheet.png art_raw/enemigos/containment/exp02_spider/source_sheet.png art_raw/enemigos/containment/exp03_saurian/source_sheet.png art_raw/enemigos/containment/boss_chimera/source_sheet.png
git ls-files --error-unmatch prueba_2/actors/enemies/exp01_centipede_frames.tres prueba_2/actors/enemies/exp02_spider_frames.tres prueba_2/actors/enemies/exp03_saurian_frames.tres prueba_2/actors/boss/boss_core_frames.tres
git status --short
```

Esperado: los ocho recursos nombrados están rastreados; `git status` no muestra
archivos nuevos de esta feature sin incluir.

- [ ] **Step 5: Iniciar la versión jugable**

```powershell
& 'C:\Users\jcbla\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe' --path prueba_2
```

Revisión manual solicitada al usuario:

```text
EXP01 alterna locomoción, se comprime, embiste y queda aturdido;
EXP02 diferencia visualmente disparo y aplastamiento;
EXP03 no tiene ojos y el coletazo termina en la pose extendida;
EXP07 sigue atacando y muriendo como antes;
la Quimera cambia de pose en esquina, aviso, salto y recuperación;
el golpe ocurre después del aviso, no antes;
ningún sprite se queda pegado visualmente al slime;
no hay texturas faltantes ni bordes magenta.
```

- [ ] **Step 6: Commit de documentación**

```powershell
git add -- prueba_2/docs/ART_SPEC.md docs/ARQUITECTURA.md docs/agents/REFERENCIA.md
git commit -m "docs: document containment enemy animations"
```

- [ ] **Step 7: Preparar el resumen de entrega**

Informar:

```text
enemigos incluidos;
cantidad y rutas de assets;
recursos y scripts modificados;
que no se ejecutaron suites automáticas por instrucción;
que el juego quedó abierto para la prueba manual.
```
