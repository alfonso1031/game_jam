# Charged Slime Movement Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an isolated Godot 4 prototype where a top-down slime charges a direction, displays charge in a bar, and commits to a collision-aware launch when the direction is released.

**Architecture:** The prototype is a self-contained Godot project under `prototypes/slime_charge_movement/`. Pure charge calculations live in a `RefCounted` utility, the player controller owns the movement state machine, and separate drawing nodes render the slime and charge bar without changing the collision shape. A lightweight headless test runner validates calculations and controller invariants without adding third-party test dependencies.

**Tech Stack:** Godot Engine 4.7.1, GDScript, Godot headless runner, `@coding-solo/godot-mcp` through Codex MCP.

## Global Constraints

- Keep every prototype-owned file under `prototypes/slime_charge_movement/`.
- Do not modify or register scenes belonging to other team members.
- Use a dedicated `project.godot` whose main scene is `res://scenes/main.tscn`.
- Support keyboard input with `WASD` and arrow keys.
- Normalize diagonal direction so diagonal launches do not gain distance.
- A launch cannot be steered or cancelled after release.
- Use a logical resolution of `1920 x 1080`.
- Use a minimum launch distance of `112 px`, maximum distance of `520 px`, maximum charge time of `1.0 s`, launch speed of `1040 px/s`, and recovery time of `0.12 s`.
- Keep collision geometry stable; squash and stretch affect only the visual node.
- Do not add third-party Godot plugins or art assets.

---

### Task 1: Isolated Godot project and charge calculation tests

**Files:**
- Create: `prototypes/slime_charge_movement/project.godot`
- Create: `prototypes/slime_charge_movement/tests/run_tests.gd`
- Create: `prototypes/slime_charge_movement/scripts/charge_motion.gd`

**Interfaces:**
- Consumes: Godot 4 `Vector2`, `clampf()`, and `lerpf()`.
- Produces: `ChargeMotion.normalized_power(charge_time, max_charge_time) -> float` and `ChargeMotion.launch_distance(power, minimum_distance, maximum_distance) -> float`.

- [ ] **Step 1: Create the isolated Godot project**

Create `project.godot` with:

```ini
[application]
config/name="Slime Charge Movement Prototype"
run/main_scene="res://scenes/main.tscn"

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/window_width_override=1920
window/size/window_height_override=1080
window/stretch/mode="canvas_items"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false

[input]
move_left={"deadzone":0.5,"events":[Object(InputEventKey,"physical_keycode":65),Object(InputEventKey,"physical_keycode":4194311)]}
move_right={"deadzone":0.5,"events":[Object(InputEventKey,"physical_keycode":68),Object(InputEventKey,"physical_keycode":4194313)]}
move_up={"deadzone":0.5,"events":[Object(InputEventKey,"physical_keycode":87),Object(InputEventKey,"physical_keycode":4194320)]}
move_down={"deadzone":0.5,"events":[Object(InputEventKey,"physical_keycode":83),Object(InputEventKey,"physical_keycode":4194322)]}
```

- [ ] **Step 2: Write the failing charge calculation tests**

Create `tests/run_tests.gd`:

```gdscript
extends SceneTree

const ChargeMotion = preload("res://scripts/charge_motion.gd")

var failures := 0

func _init() -> void:
    _assert_close(ChargeMotion.normalized_power(0.5, 1.0), 0.5, "half charge")
    _assert_close(ChargeMotion.normalized_power(2.0, 1.0), 1.0, "charge clamp")
    _assert_close(ChargeMotion.launch_distance(0.0, 112.0, 520.0), 112.0, "minimum distance")
    _assert_close(ChargeMotion.launch_distance(1.0, 112.0, 520.0), 520.0, "maximum distance")
    _assert_close(ChargeMotion.safe_direction(Vector2(1.0, 1.0)).length(), 1.0, "normalized diagonal")
    if failures == 0:
        print("PASS: all slime movement tests")
    quit(failures)

func _assert_close(actual: float, expected: float, label: String) -> void:
    if not is_equal_approx(actual, expected):
        failures += 1
        push_error("%s: expected %s, received %s" % [label, expected, actual])
```

- [ ] **Step 3: Run the tests and verify the missing implementation fails**

Run:

```powershell
godot --headless --path prototypes/slime_charge_movement --script res://tests/run_tests.gd
```

Expected: failure because `res://scripts/charge_motion.gd` does not exist.

- [ ] **Step 4: Implement the pure charge calculations**

Create `scripts/charge_motion.gd`:

```gdscript
class_name ChargeMotion
extends RefCounted

static func normalized_power(charge_time: float, max_charge_time: float) -> float:
    if max_charge_time <= 0.0:
        return 1.0
    return clampf(charge_time / max_charge_time, 0.0, 1.0)

static func launch_distance(power: float, minimum_distance: float, maximum_distance: float) -> float:
    return lerpf(minimum_distance, maximum_distance, clampf(power, 0.0, 1.0))

static func safe_direction(raw_direction: Vector2) -> Vector2:
    return raw_direction.normalized() if not raw_direction.is_zero_approx() else Vector2.ZERO
```

- [ ] **Step 5: Run the calculation tests**

Run:

```powershell
godot --headless --path prototypes/slime_charge_movement --script res://tests/run_tests.gd
```

Expected: `PASS: all slime movement tests` and exit code `0`.

- [ ] **Step 6: Commit the calculation foundation**

```powershell
git add prototypes/slime_charge_movement/project.godot prototypes/slime_charge_movement/tests/run_tests.gd prototypes/slime_charge_movement/scripts/charge_motion.gd
git commit -m "test: define charged slime movement calculations"
```

---

### Task 2: Player state machine and collision-aware committed launch

**Files:**
- Create: `prototypes/slime_charge_movement/scripts/player.gd`
- Create: `prototypes/slime_charge_movement/scenes/player.tscn`
- Modify: `prototypes/slime_charge_movement/tests/run_tests.gd`

**Interfaces:**
- Consumes: `ChargeMotion.normalized_power()`, `ChargeMotion.launch_distance()`, and `ChargeMotion.safe_direction()`.
- Produces: `Player.MovementState`, `Player.begin_charge(direction)`, `Player.update_charge(direction, delta)`, `Player.release_charge()`, `Player.get_charge_power()`, and read-only state through `current_state`.

- [ ] **Step 1: Add failing controller-state tests**

Append these calls inside `_init()` before the final result:

```gdscript
var player_script := load("res://scripts/player.gd")
var player = player_script.new()
player.begin_charge(Vector2.RIGHT)
player.update_charge(Vector2.RIGHT, 0.5)
_assert_equal(player.current_state, player.MovementState.CHARGING, "charging state")
_assert_close(player.get_charge_power(), 0.5, "controller half charge")
player.release_charge()
_assert_equal(player.current_state, player.MovementState.LAUNCHING, "launch state")
_assert_close(player.remaining_distance, 316.0, "half-charge launch distance")
player.queue_free()
```

Add:

```gdscript
func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
    if actual != expected:
        failures += 1
        push_error("%s: expected %s, received %s" % [label, expected, actual])
```

- [ ] **Step 2: Run the tests and verify the controller is missing**

Run:

```powershell
godot --headless --path prototypes/slime_charge_movement --script res://tests/run_tests.gd
```

Expected: failure loading `res://scripts/player.gd`.

- [ ] **Step 3: Implement the controller state machine**

Create `scripts/player.gd` as a `CharacterBody2D` with:

```gdscript
class_name SlimePlayer
extends CharacterBody2D

enum MovementState { IDLE, CHARGING, LAUNCHING, RECOVERING }

@export var max_charge_time := 1.0
@export var minimum_distance := 112.0
@export var maximum_distance := 520.0
@export var launch_speed := 1040.0
@export var recovery_time := 0.12

var current_state := MovementState.IDLE
var charge_time := 0.0
var charge_direction := Vector2.DOWN
var remaining_distance := 0.0
var recovery_remaining := 0.0

@onready var visual: Node2D = get_node_or_null("Visual")
@onready var charge_bar: Node2D = get_node_or_null("ChargeBar")

func _physics_process(delta: float) -> void:
    var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    match current_state:
        MovementState.IDLE:
            if not input_direction.is_zero_approx():
                begin_charge(input_direction)
        MovementState.CHARGING:
            if input_direction.is_zero_approx():
                release_charge()
            else:
                update_charge(input_direction, delta)
        MovementState.LAUNCHING:
            _advance_launch(delta)
        MovementState.RECOVERING:
            _advance_recovery(delta)

func begin_charge(direction: Vector2) -> void:
    current_state = MovementState.CHARGING
    charge_time = 0.0
    charge_direction = ChargeMotion.safe_direction(direction)
    _sync_feedback()

func update_charge(direction: Vector2, delta: float) -> void:
    if current_state != MovementState.CHARGING:
        return
    var safe := ChargeMotion.safe_direction(direction)
    if not safe.is_zero_approx():
        charge_direction = safe
        charge_time = minf(charge_time + delta, max_charge_time)
    _sync_feedback()

func release_charge() -> void:
    if current_state != MovementState.CHARGING:
        return
    remaining_distance = ChargeMotion.launch_distance(
        get_charge_power(), minimum_distance, maximum_distance
    )
    current_state = MovementState.LAUNCHING
    _sync_feedback()

func get_charge_power() -> float:
    return ChargeMotion.normalized_power(charge_time, max_charge_time)

func _advance_launch(delta: float) -> void:
    var requested_distance := minf(launch_speed * delta, remaining_distance)
    velocity = charge_direction * launch_speed
    var collision := move_and_collide(charge_direction * requested_distance)
    remaining_distance -= requested_distance
    if collision != null or remaining_distance <= 0.001:
        _begin_recovery(collision != null)

func _begin_recovery(collided: bool) -> void:
    velocity = Vector2.ZERO
    remaining_distance = 0.0
    recovery_remaining = recovery_time
    current_state = MovementState.RECOVERING
    if visual != null and visual.has_method("play_impact"):
        visual.play_impact(charge_direction, collided)
    _sync_feedback()

func _advance_recovery(delta: float) -> void:
    recovery_remaining -= delta
    if recovery_remaining <= 0.0:
        current_state = MovementState.IDLE
        charge_time = 0.0
        _sync_feedback()

func _sync_feedback() -> void:
    if charge_bar != null and charge_bar.has_method("set_charge"):
        charge_bar.set_charge(get_charge_power(), current_state == MovementState.CHARGING)
    if visual != null and visual.has_method("set_movement_feedback"):
        visual.set_movement_feedback(current_state, charge_direction, get_charge_power())
```

- [ ] **Step 4: Create the physical player scene**

Create `scenes/player.tscn` with a `CharacterBody2D` root, a circular
`CollisionShape2D` of radius `44`, an empty `Visual` `Node2D`, and an empty
`ChargeBar` `Node2D` at `(0, -84)`. Attach `player.gd` to the root.

- [ ] **Step 5: Run the headless tests**

Run:

```powershell
godot --headless --path prototypes/slime_charge_movement --script res://tests/run_tests.gd
```

Expected: all tests pass, including `half-charge launch distance`.

- [ ] **Step 6: Commit the controller**

```powershell
git add prototypes/slime_charge_movement/scripts/player.gd prototypes/slime_charge_movement/scenes/player.tscn prototypes/slime_charge_movement/tests/run_tests.gd
git commit -m "feat: add committed charge movement controller"
```

---

### Task 3: Slime drawing, charge bar, and feedback animation

**Files:**
- Create: `prototypes/slime_charge_movement/scripts/slime_visual.gd`
- Create: `prototypes/slime_charge_movement/scripts/charge_bar.gd`
- Modify: `prototypes/slime_charge_movement/scenes/player.tscn`

**Interfaces:**
- Consumes: `SlimePlayer.MovementState`, charge direction, and normalized charge power.
- Produces: `SlimeVisual.set_movement_feedback(state, direction, power)`, `SlimeVisual.play_impact(direction, collided)`, and `ChargeBar.set_charge(power, visible)`.

- [ ] **Step 1: Implement the charge bar drawing node**

Create `scripts/charge_bar.gd`:

```gdscript
class_name SlimeChargeBar
extends Node2D

var charge_power := 0.0
var should_show := false

func set_charge(power: float, show_bar: bool) -> void:
    charge_power = clampf(power, 0.0, 1.0)
    should_show = show_bar
    visible = should_show
    queue_redraw()

func _draw() -> void:
    var outer := Rect2(-68.0, -12.0, 136.0, 24.0)
    draw_style_box(_box(Color("#15242a"), 12.0), outer)
    var fill_width := 124.0 * charge_power
    if fill_width > 0.0:
        var color := Color("#58d68d").lerp(Color("#f7dc6f"), charge_power)
        draw_style_box(_box(color, 8.0), Rect2(-62.0, -6.0, fill_width, 12.0))

func _box(color: Color, radius: float) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.corner_radius_top_left = int(radius)
    box.corner_radius_top_right = int(radius)
    box.corner_radius_bottom_left = int(radius)
    box.corner_radius_bottom_right = int(radius)
    return box
```

- [ ] **Step 2: Implement the procedural slime visual**

Create `scripts/slime_visual.gd` with custom drawing for a teal body, highlight,
eyes, and shadow. Store a tween and animate only `scale`, `rotation`, and
`position`; never modify the parent `CharacterBody2D` or its collision shape.

Feedback targets:

```gdscript
func set_movement_feedback(state: int, direction: Vector2, power: float) -> void:
    match state:
        SlimePlayer.MovementState.CHARGING:
            _tween_transform(
                Vector2(1.0 + power * 0.12, 1.0 - power * 0.18),
                direction.angle() + PI / 2.0,
                -direction * power * 5.0
            )
        SlimePlayer.MovementState.LAUNCHING:
            _tween_transform(Vector2(0.78, 1.28), direction.angle() + PI / 2.0, Vector2.ZERO)
        _:
            _tween_transform(Vector2.ONE, 0.0, Vector2.ZERO)
```

`play_impact()` must squash to `Vector2(1.28, 0.72)` for a collision or
`Vector2(1.12, 0.88)` for a normal stop, then return to `Vector2.ONE`.

- [ ] **Step 3: Attach both drawing scripts**

Modify `scenes/player.tscn` so `Visual` uses `slime_visual.gd` and `ChargeBar`
uses `charge_bar.gd`. Set `ChargeBar.visible = false`.

- [ ] **Step 4: Parse and smoke-test the player scene**

Run:

```powershell
godot --headless --path prototypes/slime_charge_movement --editor --quit
godot --headless --path prototypes/slime_charge_movement --script res://tests/run_tests.gd
```

Expected: project imports without parser errors and all tests pass.

- [ ] **Step 5: Commit visual feedback**

```powershell
git add prototypes/slime_charge_movement/scripts/slime_visual.gd prototypes/slime_charge_movement/scripts/charge_bar.gd prototypes/slime_charge_movement/scenes/player.tscn
git commit -m "feat: visualize slime charge and movement feedback"
```

---

### Task 4: Isolated arena and playable main scene

**Files:**
- Create: `prototypes/slime_charge_movement/scripts/arena.gd`
- Create: `prototypes/slime_charge_movement/scenes/main.tscn`
- Modify: `prototypes/slime_charge_movement/tests/run_tests.gd`

**Interfaces:**
- Consumes: `res://scenes/player.tscn`.
- Produces: playable `res://scenes/main.tscn` and an arena with static collision.

- [ ] **Step 1: Add a failing scene-instantiation smoke test**

Append inside `_init()`:

```gdscript
var main_scene := load("res://scenes/main.tscn")
_assert_true(main_scene != null, "main scene loads")
var main_instance = main_scene.instantiate()
root.add_child(main_instance)
await process_frame
_assert_true(main_instance.get_node_or_null("Player") != null, "main scene has player")
main_instance.queue_free()
```

Add:

```gdscript
func _assert_true(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error("%s: expected true" % label)
```

- [ ] **Step 2: Run the tests and verify the main scene is missing**

Run:

```powershell
godot --headless --path prototypes/slime_charge_movement --script res://tests/run_tests.gd
```

Expected: failure loading `res://scenes/main.tscn`.

- [ ] **Step 3: Implement the arena**

Create `scripts/arena.gd` as a `Node2D` that draws the laboratory floor and
creates four boundary walls plus three internal obstacles. Each obstacle must
pair a `StaticBody2D` and `CollisionShape2D` with a matching `Polygon2D`.
Use a play area from `(128, 128)` to `(1792, 952)`, wall thickness `64`, and
obstacle rectangles `(480, 320, 192, 96)`, `(1240, 640, 240, 96)`, and
`(860, 470, 200, 140)`.

- [ ] **Step 4: Create the playable main scene**

Create `scenes/main.tscn` containing:

- `Node2D` root named `Main`.
- `Arena` with `arena.gd`.
- A `Player` instance at `(960, 780)`.
- A fixed `Camera2D` at `(960, 540)`.
- A `CanvasLayer` with title, control instructions, and the text
  `Mantén una dirección para cargar. Suelta para impulsarte.`

- [ ] **Step 5: Run automated smoke tests and the project**

Run:

```powershell
godot --headless --path prototypes/slime_charge_movement --script res://tests/run_tests.gd
godot --path prototypes/slime_charge_movement --editor
```

Expected: tests pass; the editor opens the isolated project and `F6/F5` launches
the arena without referencing any team scene.

- [ ] **Step 6: Commit the playable arena**

```powershell
git add prototypes/slime_charge_movement/scripts/arena.gd prototypes/slime_charge_movement/scenes/main.tscn prototypes/slime_charge_movement/tests/run_tests.gd
git commit -m "feat: add isolated slime movement test arena"
```

---

### Task 5: MCP setup, technical documentation, and final verification

**Files:**
- Create: `prototypes/slime_charge_movement/README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: installed Godot executable and the completed prototype.
- Produces: a documented run/test workflow and a configured Codex MCP server named `godot`.

- [ ] **Step 1: Install and locate Godot**

Run:

```powershell
winget install --id GodotEngine.GodotEngine --exact --accept-package-agreements --accept-source-agreements
where.exe godot
godot --version
```

Expected: Godot `4.7.1` is available and its executable path is printed.

- [ ] **Step 2: Configure the Godot MCP server**

Resolve the executable and pass its exact path:

```powershell
$godotExecutable = (Get-Command godot).Source
codex mcp add godot --env "GODOT_PATH=$godotExecutable" --env DEBUG=true -- npx -y @coding-solo/godot-mcp
codex mcp list
```

Expected: `godot` appears as an enabled STDIO server. Codex must be restarted
before the new MCP tools can be used by a new task.

- [ ] **Step 3: Write the prototype documentation**

Create `prototypes/slime_charge_movement/README.md` covering:

- Purpose and isolation from the team project.
- Controls and the four movement states.
- Exact tunable values and file responsibilities.
- How to open, run, and test the prototype.
- How collisions and visual deformation work.
- The future transition from charge movement to continuous leg movement.
- Godot MCP configuration and restart requirement.

- [ ] **Step 4: Ignore generated local state**

Append to the root `.gitignore`:

```gitignore
graphify-out/
prototypes/slime_charge_movement/.godot/
```

- [ ] **Step 5: Run final automated verification**

Run:

```powershell
godot --headless --path prototypes/slime_charge_movement --editor --quit
godot --headless --path prototypes/slime_charge_movement --script res://tests/run_tests.gd
git diff --check
git status --short
```

Expected: no parser/import errors, all tests pass, no whitespace errors, and
only intentional prototype/documentation changes remain.

- [ ] **Step 6: Commit documentation and configuration notes**

```powershell
git add .gitignore prototypes/slime_charge_movement/README.md prototypes/slime_charge_movement/docs/IMPLEMENTATION_PLAN.md
git commit -m "docs: explain isolated slime movement prototype"
```
