# Delivered Chimera Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Containment boss placeholder poses with the delivered 7-frame Idle and 16-frame Angry animations while preserving every gameplay rule.

**Architecture:** Keep raw 1920 × 1080 source frames outside the Godot project under `art_raw/`, and generate compact, pivot-stable runtime PNGs through a dedicated Godot processing script. The boss exposes only two logical animations: `idle` for seeking/recovery and `angry` for aiming/pouncing, so the Angry sequence continues across the state transition without restarting.

**Tech Stack:** Godot 4.7.1, GDScript, Godot `Image` processing, `SpriteFrames`, PowerShell, Git.

## Global Constraints

- Active project: `prueba_2/`; never modify `prueba/`.
- Preserve `MAX_HEALTH = 12`, phase speeds, `AIM_TIME`, `RECOVER_TIME`, collision layers, drops, rewards and the `SEEK_CORNER → CORNER_AIM → POUNCE → RECOVER` state machine.
- Warnings are errors; every new GDScript local inferred from `Variant` must have an explicit type.
- Art frames never apply damage or trigger gameplay transitions.
- Raw source PNGs live under `art_raw/`; optimized runtime PNGs live under `prueba_2/assets/`.
- The original ZIP must be copied to the repository root but must not be committed because it is 121,646,803 bytes.
- Preserve existing unrelated working-tree changes, especially `.import` files and `alt_enemies/`.
- Verification requires Godot 4.7.1, clean debug output and explicit reporting of human gameplay checks.

---

### Task 1: Lock the New Boss Animation Contract with a Failing Test

**Files:**
- Modify: `prueba_2/tests/containment_boss_tests.gd:38-58`

**Interfaces:**
- Consumes: `BossCore._visual_state() -> StringName`, `BossCore._update_sprite_animation() -> void`, and `$Sprite: AnimatedSprite2D`.
- Produces: a regression contract requiring `idle` with 7 frames, `angry` with 16 frames, the approved state mapping and no restart across `CORNER_AIM → POUNCE`.

- [ ] **Step 1: Replace the placeholder animation assertions**

Use this contract inside the existing `if frames != null:` block:

```gdscript
		_check(
			frames.has_animation(&"idle")
			and frames.get_frame_count(&"idle") == 7,
			"la Quimera reproduce los 7 fotogramas de Idle"
		)
		_check(
			frames.has_animation(&"angry")
			and frames.get_frame_count(&"angry") == 16,
			"la Quimera reproduce los 16 fotogramas de Angry"
		)
		_check(
			sprite.autoplay == "idle",
			"la Quimera usa Idle como animación por defecto"
		)
```

Add state-mapping checks before the existing pounce-target checks:

```gdscript
	boss.set("_state", 0)
	_check(boss.call("_visual_state") == &"idle", "buscar esquina usa Idle")
	boss.set("_state", 1)
	_check(boss.call("_visual_state") == &"angry", "apuntar usa Angry")
	boss.set("_state", 2)
	_check(boss.call("_visual_state") == &"angry", "embestir mantiene Angry")
	boss.set("_state", 3)
	_check(boss.call("_visual_state") == &"idle", "recuperarse vuelve a Idle")
```

Add continuity verification:

```gdscript
	if sprite != null and frames != null and frames.has_animation(&"angry"):
		sprite.play(&"angry")
		sprite.frame = 5
		boss.set("_state", 2)
		boss.call("_update_sprite_animation")
		_check(
			sprite.animation == &"angry" and sprite.frame == 5,
			"Angry no se reinicia al comenzar POUNCE"
		)
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
& (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source --headless --path prueba_2 res://tests/containment_boss_tests.tscn
```

Expected: non-zero exit with failures stating that `idle`/`angry` are absent or have the wrong frame counts. Any parse error must be fixed before continuing because it is not the intended failure.

- [ ] **Step 3: Commit the failing contract**

```powershell
git add -- prueba_2/tests/containment_boss_tests.gd
git commit -m "test: exige la animación entregada de la Quimera"
```

---

### Task 2: Preserve and Process the Delivered Source Art

**Files:**
- Copy locally: `Nivel_1-20260726T183847Z-1-001.zip`
- Create: `art_raw/enemigos/containment/boss_chimera/idle/chimera_idle_source_00.png` through `chimera_idle_source_06.png`
- Create: `art_raw/enemigos/containment/boss_chimera/angry/chimera_angry_source_00.png` through `chimera_angry_source_15.png`
- Create: `prueba_2/tools/art/process_chimera_delivered_frames.gd`
- Generate: `prueba_2/assets/bosses/containment_chimera/animations/chimera_idle_00.png` through `chimera_idle_06.png`
- Generate: `prueba_2/assets/bosses/containment_chimera/animations/chimera_angry_00.png` through `chimera_angry_15.png`
- Delete: the six obsolete `chimera_seek_*`, `chimera_aim_*`, `chimera_pounce_*` and `chimera_recover_*` runtime PNGs and their `.import` metadata

**Interfaces:**
- Consumes: transparent 1920 × 1080 PNGs from the ZIP.
- Produces: `process_chimera_delivered_frames.gd`, whose `_init()` generates exactly 23 RGBA8 PNGs on a shared 384 × 256 canvas.

- [ ] **Step 1: Copy the original archive to the repository root**

Use `Copy-Item -LiteralPath` and verify both size and SHA-256:

```powershell
Copy-Item -LiteralPath 'C:\Users\jcbla\Downloads\Nivel_1-20260726T183847Z-1-001.zip' -Destination '.\Nivel_1-20260726T183847Z-1-001.zip'
Get-FileHash -Algorithm SHA256 -LiteralPath '.\Nivel_1-20260726T183847Z-1-001.zip'
Get-Item -LiteralPath '.\Nivel_1-20260726T183847Z-1-001.zip' | Select-Object Length
```

Expected length: `121646803`.

- [ ] **Step 2: Extract and rename only the 23 source PNGs**

Create the two `art_raw` folders and extract:

- `Nivel_1/Idle/Timeline 1_0000.png` through `_0006.png` to the seven snake-case Idle paths.
- `Nivel_1/Animacion/Timeline 1_0000.png` through `_0015.png` to the sixteen snake-case Angry paths.

Do not extract the two sprite sheets, `.clip` files, `Chimera.png` or MP4 because they remain preserved in the root ZIP.

- [ ] **Step 3: Write the focused processor**

The processor must define:

```gdscript
extends SceneTree

const SOURCE_ROOT := "res://../art_raw/enemigos/containment/boss_chimera"
const OUTPUT_DIR := "res://assets/bosses/containment_chimera/animations"
const CANVAS_SIZE := Vector2i(384, 256)
const FIT_SIZE := Vector2i(350, 205)
const CROP_MARGIN := 12
const IDLE_COUNT := 7
const ANGRY_COUNT := 16
```

It must:

- load all 23 images as RGBA8;
- reject missing, empty or fully transparent images with `push_error()` and `quit(1)`;
- merge every `get_used_rect()` into one `shared_crop`;
- grow the shared crop by `CROP_MARGIN`;
- compute one aspect-preserving scale bounded by `FIT_SIZE`;
- resize through `_multiply_alpha(source, true)`, Lanczos resize and `_multiply_alpha(work, false)`;
- center each resized frame on a transparent `CANVAS_SIZE` image;
- save stable runtime names;
- print `CHIMERA_ANIMATION_OK idle=7 angry=16`.

- [ ] **Step 4: Run the processor**

```powershell
& (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source --headless --path prueba_2 --script res://tools/art/process_chimera_delivered_frames.gd
```

Expected: exit `0`, one shared crop/scale report and `CHIMERA_ANIMATION_OK idle=7 angry=16`.

- [ ] **Step 5: Validate generated dimensions before wiring resources**

Run a Godot validation script or PowerShell image inspection and verify:

- 23 generated PNGs;
- every PNG is 384 × 256;
- every PNG contains non-zero alpha;
- all files use the approved `chimera_idle_XX` or `chimera_angry_XX` names.

- [ ] **Step 6: Commit source art, processor and generated PNGs**

Stage only the 23 source PNGs, processor and 23 generated PNGs. Do not stage the root ZIP or unrelated `.import` files.

```powershell
git add -- art_raw/enemigos/containment/boss_chimera prueba_2/tools/art/process_chimera_delivered_frames.gd prueba_2/assets/bosses/containment_chimera/animations
git commit -m "feat: procesa la animación ilustrada de la Quimera"
```

---

### Task 3: Wire Idle and Angry into the Boss State Machine

**Files:**
- Modify: `prueba_2/actors/boss/boss_core_frames.tres`
- Modify: `prueba_2/actors/boss/boss_core.gd:183-205`
- Modify: `prueba_2/actors/boss/boss_core.tscn:48-52`
- Test: `prueba_2/tests/containment_boss_tests.gd`

**Interfaces:**
- Consumes: the 23 optimized PNGs produced by Task 2.
- Produces: `SpriteFrames` animations named `idle` and `angry`; `_visual_state() -> StringName` maps the approved state pairs.

- [ ] **Step 1: Replace `boss_core_frames.tres`**

Define 23 `Texture2D` external resources. The resource must contain:

```gdscript
"name": &"idle",
"speed": 7.0,
"loop": true
```

with frames `chimera_idle_00..06`, and:

```gdscript
"name": &"angry",
"speed": 8.0,
"loop": true
```

with frames `chimera_angry_00..15` in numeric order. Retain intentional duplicate source poses because they encode holds from the delivered sequence.

- [ ] **Step 2: Change the visual state mapping**

Replace `_visual_state()` with:

```gdscript
func _visual_state() -> StringName:
	match _state:
		State.CORNER_AIM, State.POUNCE:
			return &"angry"
		_:
			return &"idle"
```

Do not change `_update_sprite_animation()`: its current equality guard is what preserves the Angry frame across `CORNER_AIM → POUNCE`.

- [ ] **Step 3: Change the scene default animation**

Set both properties on `$Sprite`:

```text
animation = &"idle"
autoplay = "idle"
```

- [ ] **Step 4: Import the new PNGs**

```powershell
& (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source --headless --path prueba_2 --import
```

Expected: all 23 new runtime PNGs import without `Could not preload resource file`, parse errors or `Debugger Break`.

- [ ] **Step 5: Run the focused test and verify GREEN**

```powershell
& (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source --headless --path prueba_2 res://tests/containment_boss_tests.tscn
```

Expected: exit `0`, zero failures and `PASS: containment boss`.

- [ ] **Step 6: Run the animation and combat regression suites**

```powershell
& (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source --headless --path prueba_2 res://tests/check_enemy_animations.tscn
& (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source --headless --path prueba_2 res://tests/combat_smoke.tscn
```

Expected: exit `0` for both, `ANIM_CHECK_OK` and combat smoke with zero failures.

- [ ] **Step 7: Commit the runtime integration**

```powershell
git add -- prueba_2/actors/boss/boss_core_frames.tres prueba_2/actors/boss/boss_core.gd prueba_2/actors/boss/boss_core.tscn prueba_2/tests/containment_boss_tests.gd prueba_2/assets/bosses/containment_chimera/animations
git commit -m "feat: anima la Quimera con Idle y Angry"
```

---

### Task 4: Document and Visually Verify the Delivered Art

**Files:**
- Modify: `docs/agents/ESTADO_ACTUAL.md`
- Modify: `docs/agents/REFERENCIA.md`
- Modify: `docs/ARQUITECTURA.md`
- Generate locally: boss captures at 1920 × 1080 and 1280 × 720

**Interfaces:**
- Consumes: the verified runtime integration from Task 3.
- Produces: authoritative documentation and visual evidence for the final handoff.

- [ ] **Step 1: Update authoritative current state**

Change the Quimera art row and pending-art section to state:

- the hand-illustrated delivery is now runtime art;
- Idle has 7 frames and Angry has 16 frames;
- only EXP01, EXP02 and EXP03 remain generated placeholder art.

- [ ] **Step 2: Update the authoring recipe**

Document:

- raw paths under `art_raw/enemigos/containment/boss_chimera/`;
- processor command `res://tools/art/process_chimera_delivered_frames.gd`;
- shared crop, 384 × 256 canvas and 350 × 205 fit;
- `idle`/`angry` state mapping and continuity across aiming/pouncing.

- [ ] **Step 3: Update architecture**

Replace the six-pose Quimera description with the two-animation pipeline and explain that shared animation names prevent restart across the state transition while gameplay timers remain authoritative.

- [ ] **Step 4: Generate both boss captures**

Use the non-console Godot executable next to the console binary:

```powershell
$godotDir = Split-Path -Parent (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source
$godotGui = Join-Path $godotDir 'Godot_v4.7.1-stable_win64.exe'
& $godotGui --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- boss user://chimera-delivered-1920.png 1920x1080
& $godotGui --path prueba_2 --windowed --resolution 1280x720 res://tests/ui_visual_capture.tscn -- boss user://chimera-delivered-1280.png 1280x720
```

Inspect both PNGs for scale, pivot, orientation, visibility, health bar overlap and arena fit.

- [ ] **Step 5: Run final clean verification loop**

Run fresh:

```powershell
& (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source --headless --path prueba_2 --import
& (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source --headless --path prueba_2 res://tests/containment_boss_tests.tscn
& (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source --headless --path prueba_2 res://tests/check_enemy_animations.tscn
& (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source --headless --path prueba_2 res://tests/combat_smoke.tscn
& (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source --headless --path prueba_2 --quit-after 180
```

If any command fails or emits an unexpected error, return to the smallest failing task, fix only its root cause and rerun the entire final loop.

- [ ] **Step 6: Commit documentation**

```powershell
git add -- docs/agents/ESTADO_ACTUAL.md docs/agents/REFERENCIA.md docs/ARQUITECTURA.md
git commit -m "docs: registra el arte final de la Quimera"
```

- [ ] **Step 7: Open the game for human review**

After every final command passes, launch visibly:

```powershell
$godotDir = Split-Path -Parent (Get-Command 'Godot_v4.7.1-stable_win64_console.exe').Source
$godotGui = Join-Path $godotDir 'Godot_v4.7.1-stable_win64.exe'
Start-Process -FilePath $godotGui -ArgumentList @('--path', (Resolve-Path 'prueba_2').Path)
```

Leave the game open. Report that automated tests and captures passed, while combat feel still requires the user to play the boss encounter.
