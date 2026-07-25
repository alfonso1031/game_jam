# Slime Audio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generar once efectos WAV originales, viscosos y biológicos, conectarlos al prototipo del impulso cargado y portar la integración al juego activo.

**Architecture:** Un generador Python determinista crea el mismo paquete de audio dentro de las dos raíces Godot. Cada proyecto contiene un componente `SlimeAudio` idéntico que encapsula tres reproductores 2D; los controladores del jugador solo notifican las transiciones de su máquina de estados.

**Tech Stack:** Python 3 estándar (`wave`, `math`, `random`, `struct`, `unittest`), Godot 4.7.1, GDScript con tipado estático, WAV PCM mono de 16 bits a 48 kHz.

## Global Constraints

- Trabajar primero en `prototypes/slime_charge_movement/` y portar después a `prueba_2/`.
- No modificar `prueba/`.
- No incorporar grabaciones, muestras, paquetes ni dependencias de terceros.
- Generar once WAV mono PCM16 a `48 kHz`, con pico máximo de `-1 dBFS`.
- Mantener intactas las constantes, distancias, curva de velocidad, invulnerabilidad, cooldown y máscaras de colisión.
- Mantener el reposo sonoro desactivado por defecto.
- Usar tabs, tipado estático y comentarios en español en GDScript.
- Conservar fuera de los commits el cambio local preexistente en `prototypes/slime_charge_movement/project.godot`.
- El proyecto activo debe arrancar sin errores ni `Debugger Break`.

---

## File Map

**Generator and provenance**

- Create: `tools/audio/generate_slime_audio.py` — synthesis, normalization, WAV writing, and CLI.
- Create: `tools/audio/test_generate_slime_audio.py` — standard-library tests for count, format, duration, peak, and loop seam.
- Create: `tools/audio/README.md` — reproduction command and statement that no third-party samples are used.

**Generated output**

- Create: `prototypes/slime_charge_movement/audio/slime/*.wav` — eleven generated files.
- Create: `prueba_2/audio/slime/*.wav` — identical copies for the active Godot project.

**Prototype**

- Create: `prototypes/slime_charge_movement/scripts/slime_audio.gd` — isolated audio component.
- Modify: `prototypes/slime_charge_movement/scenes/player.tscn` — `SlimeAudio` node and audio players.
- Modify: `prototypes/slime_charge_movement/scripts/player.gd` — transition notifications only.
- Modify: `prototypes/slime_charge_movement/tests/run_tests.gd` — component and transition tests.

**Active game**

- Create: `prueba_2/scripts/player/slime_audio.gd` — byte-for-byte functional copy of the component.
- Modify: `prueba_2/scenes/player/slime.tscn` — `SlimeAudio` node and audio players.
- Modify: `prueba_2/scripts/player/slime.gd` — notifications for charge, fizzle, launch, DASH, impact, recovery, and knockback.
- Create: `prueba_2/tests/run_slime_audio_tests.gd` — headless audio integration smoke test.

**Documentation**

- Modify: `prototypes/slime_charge_movement/README.md` — generated assets and test commands.
- Modify: `DOCUMENTACION.md` — active-game audio behavior and reproducibility.

---

### Task 1: Deterministic Procedural Audio Pack

**Files:**

- Create: `tools/audio/test_generate_slime_audio.py`
- Create: `tools/audio/generate_slime_audio.py`
- Create: `tools/audio/README.md`
- Create: `prototypes/slime_charge_movement/audio/slime/*.wav`
- Create: `prueba_2/audio/slime/*.wav`

**Interfaces:**

- Produces: `generate_assets(output_dirs: Sequence[Path], seed: int = 73421) -> dict[str, list[float]]`
- Produces: eleven files named by `ASSET_DURATIONS`.
- Consumes: Python standard library only.

- [ ] **Step 1: Write the failing generator test**

Create `tools/audio/test_generate_slime_audio.py` with these exact expectations:

```python
from __future__ import annotations

import math
import struct
import tempfile
import unittest
import wave
from pathlib import Path

import generate_slime_audio as generator


class SlimeAudioGenerationTests(unittest.TestCase):
    def test_generates_expected_pcm_pack(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            generator.generate_assets([output])

            self.assertEqual(
                sorted(path.name for path in output.glob("*.wav")),
                sorted(generator.ASSET_DURATIONS),
            )

            for name, duration in generator.ASSET_DURATIONS.items():
                path = output / name
                with wave.open(str(path), "rb") as source:
                    self.assertEqual(source.getnchannels(), 1, name)
                    self.assertEqual(source.getsampwidth(), 2, name)
                    self.assertEqual(source.getframerate(), generator.SAMPLE_RATE, name)
                    expected_frames = round(duration * generator.SAMPLE_RATE)
                    self.assertLessEqual(abs(source.getnframes() - expected_frames), 1, name)
                    frames = source.readframes(source.getnframes())

                samples = struct.unpack(f"<{len(frames) // 2}h", frames)
                peak = max(abs(sample) for sample in samples)
                self.assertLessEqual(peak, generator.MAX_PCM_PEAK, name)
                self.assertGreater(peak, 2048, name)

    def test_charge_loop_has_matching_boundaries(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            generator.generate_assets([output])
            with wave.open(str(output / "slime_charge_loop.wav"), "rb") as source:
                frames = source.readframes(source.getnframes())
            samples = struct.unpack(f"<{len(frames) // 2}h", frames)
            self.assertLessEqual(abs(samples[0] - samples[-1]), 256)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test and verify that the generator is absent**

Run from the repository root:

```powershell
python tools/audio/test_generate_slime_audio.py
```

Expected: failure importing `generate_slime_audio`.

- [ ] **Step 3: Implement the deterministic synthesizer**

Create `tools/audio/generate_slime_audio.py` with:

```python
SAMPLE_RATE = 48_000
MAX_PCM_PEAK = 29_195  # floor(32767 * 10 ** (-1 / 20))
DEFAULT_SEED = 73_421

ASSET_DURATIONS = {
    "slime_charge_loop.wav": 1.00,
    "slime_charge_full.wav": 0.18,
    "slime_fizzle.wav": 0.28,
    "slime_launch_01.wav": 0.24,
    "slime_launch_02.wav": 0.26,
    "slime_dash.wav": 0.30,
    "slime_impact_01.wav": 0.34,
    "slime_impact_02.wav": 0.38,
    "slime_recover_01.wav": 0.22,
    "slime_recover_02.wav": 0.25,
    "slime_idle.wav": 1.60,
}
```

Implement these typed helpers:

```python
def envelope(position: float, attack: float, release: float) -> float
def sine_sample(phase: float) -> float
def low_pass(samples: list[float], coefficient: float) -> list[float]
def normalize(samples: list[float], peak: float = 10 ** (-1 / 20)) -> list[float]
def make_loopable(samples: list[float], crossfade_seconds: float = 0.04) -> list[float]
def write_pcm16(path: Path, samples: list[float]) -> None
def render_asset(name: str, duration: float, rng: random.Random) -> list[float]
def generate_assets(
    output_dirs: Sequence[Path],
    seed: int = DEFAULT_SEED,
) -> dict[str, list[float]]
```

Use the following exact synthesis recipes inside `render_asset()`:

| Family | Oscillators | Noise/filter | Envelope and pitch motion |
|---|---|---|---|
| Charge loop | 46 Hz + 73 Hz + periodic 5 Hz bubbles | low-pass coefficient `0.055` | periodic components only; 40 ms boundary crossfade |
| Full charge | 92 Hz + chirp 180→310 Hz | low-pass coefficient `0.09` | attack 5 ms, release 150 ms |
| Fizzle | chirp 170→54 Hz | low-pass coefficient `0.07` | attack 3 ms, release 260 ms |
| Launch | chirp 82→235 Hz plus 41 Hz body | low-pass coefficient `0.12` | attack 2 ms, release to file end |
| DASH | chirp 64→310 Hz plus 32 Hz body | low-pass coefficient `0.15` | attack 2 ms, two bubble impulses |
| Impact | chirp 105→38 Hz plus 29 Hz thump | low-pass coefficient `0.18` | attack 1 ms, release to file end |
| Recover | chirp 68→145→62 Hz | low-pass coefficient `0.08` | attack 4 ms, release to file end |
| Idle | 37 Hz + 0.9 Hz amplitude modulation | low-pass coefficient `0.035` | seamless 80 ms boundary crossfade |

Use a fresh deterministic child seed for each filename so adding another asset
does not change existing files. Derive it with:

```python
asset_seed = int.from_bytes(
    hashlib.sha256(f"{seed}:{name}".encode("utf-8")).digest()[:8],
    "little",
)
```

Do not use Python's process-randomized `hash()`. Convert normalized floats to
signed little-endian PCM16, clamp to `[-MAX_PCM_PEAK, MAX_PCM_PEAK]`, and write
atomically after creating the output directory.

The CLI must resolve the repository as `Path(__file__).resolve().parents[2]` and
write to:

```python
repo / "prototypes/slime_charge_movement/audio/slime"
repo / "prueba_2/audio/slime"
```

- [ ] **Step 4: Generate and test the two output copies**

Run:

```powershell
python tools/audio/generate_slime_audio.py
python tools/audio/test_generate_slime_audio.py
```

Expected: `Ran 2 tests` and `OK`; both output folders contain eleven WAV files.

Verify identical copies:

```powershell
$prototype = Get-ChildItem prototypes/slime_charge_movement/audio/slime/*.wav
foreach ($file in $prototype) {
    $active = Join-Path "prueba_2/audio/slime" $file.Name
    if ((Get-FileHash $file.FullName).Hash -ne (Get-FileHash $active).Hash) {
        throw "Audio distinto: $($file.Name)"
    }
}
```

- [ ] **Step 5: Document generation and provenance**

Create `tools/audio/README.md` stating:

- Run `python tools/audio/generate_slime_audio.py` from the repository root.
- The generator uses only Python's standard library.
- Every waveform is synthesized mathematically; no third-party sample is embedded.
- Generated files are copied to both Godot projects because `res://` cannot cross
  a project root.
- Human listening is still required for aesthetic approval.

- [ ] **Step 6: Commit the generator and audio pack**

```powershell
git add tools/audio prototypes/slime_charge_movement/audio/slime prueba_2/audio/slime
git commit -m "feat: generate original slime audio pack"
```

---

### Task 2: Reusable SlimeAudio Component in the Prototype

**Files:**

- Create: `prototypes/slime_charge_movement/scripts/slime_audio.gd`
- Modify: `prototypes/slime_charge_movement/scenes/player.tscn`
- Modify: `prototypes/slime_charge_movement/scripts/player.gd`
- Modify: `prototypes/slime_charge_movement/tests/run_tests.gd`

**Interfaces:**

- Consumes: WAV files under `res://audio/slime/`.
- Produces:
  - `begin_charge() -> void`
  - `update_charge(power: float) -> void`
  - `charge_full() -> void`
  - `fizzle() -> void`
  - `launch() -> void`
  - `dash() -> void`
  - `impact() -> void`
  - `recover() -> void`
  - `stop_charge() -> void`
  - `is_charge_playing() -> bool`
  - `get_charge_pitch() -> float`
  - `last_event: StringName`

- [ ] **Step 1: Add a failing component test**

In `tests/run_tests.gd`, call `await _test_audio_component()` before
`await _test_main_scene()` and add:

```gdscript
func _test_audio_component() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	_assert_true(player_scene != null, "player scene with audio loads")
	if player_scene == null:
		return

	var player := player_scene.instantiate()
	root.add_child(player)
	await process_frame
	var audio := player.get_node_or_null("SlimeAudio")
	_assert_true(audio != null, "player contains SlimeAudio")
	if audio != null:
		audio.begin_charge()
		audio.update_charge(0.5)
		_assert_true(audio.is_charge_playing(), "charge loop starts")
		_assert_close(audio.get_charge_pitch(), 1.015, "charge pitch follows power")
		audio.charge_full()
		_assert_equal(audio.last_event, &"charge_full", "full charge fires once")
		audio.stop_charge()
		_assert_true(not audio.is_charge_playing(), "charge loop stops")
	player.free()
```

- [ ] **Step 2: Run the prototype tests and verify failure**

```powershell
& "C:\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path prototypes/slime_charge_movement `
  --script res://tests/run_tests.gd
```

Expected: failure because `SlimeAudio` does not exist.

- [ ] **Step 3: Implement the isolated component**

Create `scripts/slime_audio.gd` extending `Node2D`.

Preload all streams from `res://audio/slime/`. Use these children:

```text
SlimeAudio
├── ChargeLoop     AudioStreamPlayer2D
├── EffectA        AudioStreamPlayer2D
├── EffectB        AudioStreamPlayer2D
└── Idle           AudioStreamPlayer2D
```

Set `max_distance = 1400.0` and `attenuation = 1.0` on all four players. Keep
`Idle.autoplay = false`.

The component must:

- Duplicate `slime_charge_loop.wav` in `_ready()` and set its
  `AudioStreamWAV.loop_mode` to `LOOP_FORWARD`.
- Clamp charge power to `[0, 1]`.
- Calculate `pitch_scale = lerpf(0.85, 1.18, power)`.
- Calculate `volume_db = lerpf(-20.0, -8.0, power)`.
- Call `charge_full()` from `update_charge()` when the clamped power reaches
  `1.0`.
- Guard `charge_full()` with `_full_played`.
- Alternate `EffectA` and `EffectB`.
- Alternate the two launch, impact, and recovery streams before applying a
  pitch variation from `0.96` to `1.04`.
- Set `last_event` to `&"charge"`, `&"charge_full"`, `&"fizzle"`,
  `&"launch"`, `&"dash"`, `&"impact"`, `&"recover"`, or `&"stop_charge"`.
- Stop the charge loop inside `fizzle()`, `launch()`, and `dash()`.

- [ ] **Step 4: Add the component node to the prototype scene**

Increase `load_steps` in `scenes/player.tscn` from `5` to `6`, add the script as
an `ext_resource`, and append the `SlimeAudio` tree described above.

- [ ] **Step 5: Connect prototype state transitions**

In `scripts/player.gd`:

```gdscript
@onready var slime_audio: Node = get_node_or_null("SlimeAudio")
```

Make these notifications without changing movement values:

- `begin_charge()`: call `slime_audio.begin_charge()`.
- `update_charge()`: call `slime_audio.update_charge(get_charge_power())`.
- `release_charge()`: call `slime_audio.launch()`.
- `_begin_recovery(collided)`: call `slime_audio.impact()` when collided,
  otherwise `slime_audio.recover()`.

Guard every call with `slime_audio != null` so the controller remains
instantiable in its existing unit test without a scene tree.

- [ ] **Step 6: Extend the transition assertions**

After instantiating the full player scene in `_test_audio_component()`:

```gdscript
player.begin_charge(Vector2.RIGHT)
player.update_charge(Vector2.RIGHT, 0.5)
_assert_equal(audio.last_event, &"charge", "charging updates audio")
player.release_charge()
_assert_equal(audio.last_event, &"launch", "release plays launch")
```

- [ ] **Step 7: Run the complete prototype suite**

```powershell
& "C:\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path prototypes/slime_charge_movement `
  --script res://tests/run_tests.gd
```

Expected: `PASS: all slime movement tests`, exit code `0`, and no parser errors.

- [ ] **Step 8: Commit the prototype integration**

```powershell
git add prototypes/slime_charge_movement/scripts/slime_audio.gd `
  prototypes/slime_charge_movement/scenes/player.tscn `
  prototypes/slime_charge_movement/scripts/player.gd `
  prototypes/slime_charge_movement/tests/run_tests.gd
git commit -m "feat: add biological audio to slime prototype"
```

---

### Task 3: Port Audio to the Active Game

**Files:**

- Create: `prueba_2/scripts/player/slime_audio.gd`
- Modify: `prueba_2/scenes/player/slime.tscn`
- Modify: `prueba_2/scripts/player/slime.gd`
- Create: `prueba_2/tests/run_slime_audio_tests.gd`

**Interfaces:**

- Consumes: the Task 2 `SlimeAudio` API and active states
  `IDLE`, `CHARGING`, `LAUNCHING`, `RECOVERING`, `DASHING`.
- Produces: audible events without changing the state machine's numerical
  contract.

- [ ] **Step 1: Add a failing active-game smoke test**

Create `prueba_2/tests/run_slime_audio_tests.gd`:

```gdscript
extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/player/slime.tscn") as PackedScene
	_assert_true(scene != null, "active slime scene loads")
	if scene == null:
		quit(1)
		return

	var player := scene.instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	var audio := player.get_node_or_null("SlimeAudio")
	_assert_true(audio != null, "active slime contains SlimeAudio")
	if audio != null:
		player._begin_charge(Vector2.RIGHT)
		player._update_charge(1.0)
		_assert_equal(audio.last_event, &"charge_full", "full charge is audible")
		player._release_charge()
		_assert_equal(audio.last_event, &"launch", "launch is audible")

		var fizzle_player := scene.instantiate()
		root.add_child(fizzle_player)
		await process_frame
		fizzle_player.set_physics_process(false)
		var fizzle_audio := fizzle_player.get_node("SlimeAudio")
		fizzle_player._begin_charge(Vector2.RIGHT)
		fizzle_player._release_charge()
		_assert_equal(fizzle_audio.last_event, &"fizzle", "short charge fizzles")
		fizzle_player.free()

		player._start_dash()
		_assert_equal(audio.last_event, &"dash", "dash has distinct audio")

	player.free()
	if failures == 0:
		print("PASS: active slime audio tests")
	else:
		print("FAIL: %d active slime audio test(s)" % failures)
	quit(failures)

func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures += 1
		push_error("%s: expected %s, received %s" % [label, expected, actual])
```

- [ ] **Step 2: Run the smoke test and verify failure**

```powershell
& "C:\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path prueba_2 `
  --script res://tests/run_slime_audio_tests.gd
```

Expected: failure because the active scene lacks `SlimeAudio`.

- [ ] **Step 3: Copy the component and add the active scene nodes**

Copy the Task 2 component to `prueba_2/scripts/player/slime_audio.gd`. Add the
same four-child `SlimeAudio` tree to `prueba_2/scenes/player/slime.tscn`, and
increase `load_steps` from `5` to `6`.

Verify the functional scripts remain identical:

```powershell
$prototype = Get-Content -Raw prototypes/slime_charge_movement/scripts/slime_audio.gd
$active = Get-Content -Raw prueba_2/scripts/player/slime_audio.gd
if ($prototype -ne $active) { throw "Los componentes de audio divergieron" }
```

- [ ] **Step 4: Notify active-game transitions**

Add:

```gdscript
@onready var slime_audio: Node = $SlimeAudio
```

Then update the existing functions:

- `_begin_charge()`: `slime_audio.begin_charge()`.
- `_update_charge()`: `slime_audio.update_charge(_charge_power())`.
- `_release_charge()` below the minimum: `slime_audio.fizzle()` before recovery.
- `_release_charge()` at or above the minimum: `slime_audio.launch()`.
- `_advance_launch()` collision branch: `slime_audio.impact()`.
- `_advance_launch()` clean completion branch: `slime_audio.recover()`.
- `_start_dash()`: `slime_audio.dash()`.
- `_advance_dash()` collision branch: `slime_audio.impact()`.
- `_advance_dash()` clean completion branch: `slime_audio.recover()`.
- `apply_knockback()` while charging: `slime_audio.stop_charge()`.

Do not play `recover()` after `impact()`: the wet wall hit already includes the
body settling.

- [ ] **Step 5: Run the active audio test**

```powershell
& "C:\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path prueba_2 `
  --script res://tests/run_slime_audio_tests.gd
```

Expected: `PASS: active slime audio tests` and exit code `0`.

- [ ] **Step 6: Run the active game and inspect debug output**

Launch the gameplay scene directly without changing `run/main_scene`:

```powershell
& "C:\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --path prueba_2 `
  res://scenes/main.tscn
```

Exercise:

1. Start and cancel a charge before `0.18 s`.
2. Release a half charge.
3. Hold to full charge and confirm a single full-charge cue.
4. Finish a launch in open space.
5. Hit a wall.
6. If the ability is available, use the DASH and hit a wall with it.

Expected: one appropriate sound per transition, responsive charge pitch, no
audio loop remaining after release, and no `Debugger Break`.

- [ ] **Step 7: Commit the active-game port**

```powershell
git add prueba_2/scripts/player/slime_audio.gd `
  prueba_2/scenes/player/slime.tscn `
  prueba_2/scripts/player/slime.gd `
  prueba_2/tests/run_slime_audio_tests.gd
git commit -m "feat: integrate slime audio in active game"
```

---

### Task 4: Documentation and Final Regression Verification

**Files:**

- Modify: `prototypes/slime_charge_movement/README.md`
- Modify: `DOCUMENTACION.md`

**Interfaces:**

- Consumes: final commands and paths from Tasks 1–3.
- Produces: reproducible usage and verification instructions for both developers.

- [ ] **Step 1: Document the prototype audio**

Add an `## Audio original` section to the prototype README covering:

- `audio/slime/` contains eleven generated WAV files.
- `scripts/slime_audio.gd` owns playback and variation.
- `python tools/audio/generate_slime_audio.py` regenerates both project copies.
- The charge loop changes pitch and volume with the bar.
- Idle audio remains off by default.

- [ ] **Step 2: Document the active integration**

In `DOCUMENTACION.md` section 7, add:

- The event mapping for charge, full charge, fizzle, launch, DASH, wall impact,
  and clean recovery.
- `SlimeAudio` does not own movement state.
- All sounds are synthesized from scratch without third-party samples.
- The generator location and active audio folder.

- [ ] **Step 3: Run automated regression checks**

```powershell
python tools/audio/test_generate_slime_audio.py

& "C:\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path prototypes/slime_charge_movement `
  --script res://tests/run_tests.gd

& "C:\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path prueba_2 `
  --script res://tests/run_slime_audio_tests.gd
```

Expected: Python `OK`, prototype `PASS: all slime movement tests`, and active
game `PASS: active slime audio tests`.

- [ ] **Step 4: Verify no movement constants changed**

```powershell
git diff b14a08d -- prueba_2/scripts/player/slime.gd |
  Select-String -Pattern '^[+-]const (MAX_CHARGE|MIN_CHARGE|MIN_DISTANCE|MAX_DISTANCE|LAUNCH_|RECOVERY_TIME|WALL_RECOVERY_TIME|FIZZLE_RECOVERY_TIME|DASH_)'
```

Expected: no output.

- [ ] **Step 5: Verify worktree scope**

```powershell
git status --short
git diff --check
```

Expected: only the preexisting `prototypes/slime_charge_movement/project.godot`
change remains outside the task commits; no whitespace errors.

- [ ] **Step 6: Commit documentation**

```powershell
git add prototypes/slime_charge_movement/README.md DOCUMENTACION.md
git commit -m "docs: explain slime audio generation and events"
```

- [ ] **Step 7: Report the human-listening boundary**

Report automated results separately from manual listening. State explicitly
whether charge readability, biological character, loudness balance, and
repetition were heard by a human; headless and parser checks cannot establish
those qualities.
