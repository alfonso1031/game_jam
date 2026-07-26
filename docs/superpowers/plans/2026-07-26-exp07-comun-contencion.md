# EXP07 Common Containment Spawn Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar a EXP07 un 25 % del pool normal de enemigos de Contención y garantizar exactamente uno como líder de la sala preboss.

**Architecture:** `MapGenerator` conserva la autoridad de topología, contenido y cantidad. `procedural_room.gd` amplía su selector determinista con un pool normal de cuatro tipos y un pool de tres esbirros para preboss; el último índice preboss se resuelve explícitamente como `exp07`.

**Tech Stack:** Godot 4.7.1, GDScript tipado, escenas procedurales y pruebas headless.

## Global Constraints

- La entrada/tutorial y la sala del cuerpo siguen sin enemigos.
- EXP07 tiene el mismo peso que `exp01`, `exp02` y `exp03` en combates normales.
- Toda partida garantiza exactamente un EXP07 en el encuentro preboss.
- El EXP07 preboss es el líder y su único drop es `crusher_claw`.
- Una misma seed e ID de sala conservan el mismo reparto.
- No se modifica la cantidad de enemigos de `easy`, `hard` ni destinos de rejilla.
- No se fija un ID de sala ni una dirección cardinal.

---

### Task 1: Contrato de aparición normal y preboss

**Files:**
- Create: `prueba_2/tests/containment_enemy_spawn_tests.gd`
- Create: `prueba_2/tests/containment_enemy_spawn_tests.tscn`
- Modify: `prueba_2/world/rooms/procedural_room.gd`

**Interfaces:**
- Consumes: `procedural_room.tscn`, `EnemyDB.scene_for(type_id)` y el contrato `is_room_leader`.
- Produces: `CONTAINMENT_ENEMIES = ["exp01", "exp02", "exp03", "exp07"]`, `CONTAINMENT_MINIONS = ["exp01", "exp02", "exp03"]` y selección especial del último enemigo preboss.

- [ ] **Step 1: Crear la prueba que reproduce la ausencia de EXP07**

Crear `containment_enemy_spawn_tests.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/containment_enemy_spawn_tests.gd" id="1"]

[node name="ContainmentEnemySpawnTests" type="Node"]
script = ExtResource("1")
```

Crear `containment_enemy_spawn_tests.gd` con fixtures reales:

```gdscript
extends Node

const RoomScene := preload("res://world/rooms/procedural_room.tscn")
const EXP07_SCRIPT := "res://actors/enemies/exp07_crustacean.gd"

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_run()
	await _check_normal_rotation()
	await _check_preboss_guarantee()
	_finish()


func _check_normal_rotation() -> void:
	var exp07_count := 0
	var seen_types: Dictionary = {}
	for room_id in ["A", "B", "C", "D"]:
		var room: Node2D = await _spawn_room(room_id, &"normal", &"easy", 1)
		var enemies := _enemies(room)
		_check(enemies.size() == 1, "%s genera un enemigo" % room_id)
		if enemies.size() == 1:
			var script_path: String = _script_path(enemies[0])
			seen_types[script_path] = true
			if script_path == EXP07_SCRIPT:
				exp07_count += 1
		room.queue_free()
		await get_tree().process_frame
	_check(seen_types.size() == 4, "cuatro residuos generan cuatro tipos")
	_check(exp07_count == 1, "EXP07 ocupa una de cuatro apariciones normales")


func _check_preboss_guarantee() -> void:
	var room: Node2D = await _spawn_room("PREBOSS", &"preboss", &"preboss", 0)
	var enemies := _enemies(room)
	var exp07_enemies: Array[Node] = []
	for enemy: Node in enemies:
		if _script_path(enemy) == EXP07_SCRIPT:
			exp07_enemies.append(enemy)
	_check(enemies.size() == 3, "preboss genera tres enemigos")
	_check(exp07_enemies.size() == 1, "preboss contiene exactamente un EXP07")
	if exp07_enemies.size() == 1:
		var leader: Node = exp07_enemies[0]
		_check(bool(leader.get("is_room_leader")), "EXP07 es el líder preboss")
		var expected_drops: Array[String] = ["crusher_claw"]
		_check(leader.get("drop_parts") == expected_drops, "el líder entrega Tenaza Trituradora")
	room.queue_free()
	await get_tree().process_frame


func _spawn_room(
	room_id: String,
	role: StringName,
	content: StringName,
	enemy_count: int
) -> Node2D:
	var room: Node2D = RoomScene.instantiate()
	room.call("configure", {
		"id": room_id,
		"doors": {},
		"role": role,
		"content_type": content,
		"enemy_count": enemy_count,
		"one_way": {},
		"grate_target": "",
		"grate_source": "",
		"grate_direction": "",
		"closure_keep_direction": "",
		"reward_part_id": "",
	})
	add_child(room)
	await get_tree().process_frame
	return room


func _enemies(room: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in room.get_children():
		if child.is_in_group("enemies"):
			result.append(child)
	return result


func _script_path(enemy: Node) -> String:
	var script: Script = enemy.get_script() as Script
	return script.resource_path if script != null else ""


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	for failure: String in failures:
		push_error(failure)
	print(
		"PASS: containment EXP07 spawning"
		if failures.is_empty()
		else "FAIL: containment EXP07 spawning"
	)
	get_tree().quit(0 if failures.is_empty() else 1)
```

- [ ] **Step 2: Ejecutar la prueba y confirmar el fallo**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/containment_enemy_spawn_tests.tscn
```

Expected: `FAIL: containment EXP07 spawning`; la rotación solo genera tres
tipos y el preboss no garantiza EXP07.

- [ ] **Step 3: Aplicar la selección mínima en `procedural_room.gd`**

Reemplazar el pool:

```gdscript
const CONTAINMENT_ENEMIES: Array[String] = ["exp01", "exp02", "exp03", "exp07"]
const CONTAINMENT_MINIONS: Array[String] = ["exp01", "exp02", "exp03"]
```

Modificar `_spawn_enemies()`:

```gdscript
	var is_preboss: bool = _room_data.get("role", &"") == &"preboss"
	if is_preboss and enemy_count == 0:
		enemy_count = 3
	for index in range(enemy_count):
		var pool: Array[String] = CONTAINMENT_MINIONS if is_preboss else CONTAINMENT_ENEMIES
		var type_index: int = (_stable_room_index() + index) % pool.size()
		var type_id: String = pool[type_index]
		if is_preboss and index == enemy_count - 1:
			type_id = "exp07"
```

No modificar posiciones, cantidad, sellado ni regla de líder:

```gdscript
enemy.is_room_leader = index == enemy_count - 1
```

- [ ] **Step 4: Ejecutar la prueba y confirmar que pasa**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/containment_enemy_spawn_tests.tscn
```

Expected: `PASS: containment EXP07 spawning`.

- [ ] **Step 5: Confirmar el cambio**

```powershell
git add prueba_2/world/rooms/procedural_room.gd prueba_2/tests/containment_enemy_spawn_tests.gd prueba_2/tests/containment_enemy_spawn_tests.tscn
git commit -m "feat: hace comun al exp07 en contencion"
```

### Task 2: Invariantes, documentación y versión jugable

**Files:**
- Modify: `docs/ARQUITECTURA.md`
- Verify: `prueba_2/tests/run_map_tests.gd`
- Verify: `prueba_2/tests/combat_smoke.gd`
- Verify: `prueba_2/tests/exp07_attack_tests.gd`

**Interfaces:**
- Consumes: selector de enemigos de Task 1.
- Produces: regla documentada, 1.000 seeds válidas y una versión jugable actualizada.

- [ ] **Step 1: Documentar el reparto**

En la sección de generación procedural de `docs/ARQUITECTURA.md`, registrar:

```markdown
En Contención, los combates normales rotan de forma determinista entre
`exp01`, `exp02`, `exp03` y `exp07`, con peso equivalente. El preboss usa
`exp01–03` como esbirros y fuerza un único `exp07` como último enemigo y líder,
garantizando el encuentro y el drop `crusher_claw`.
```

- [ ] **Step 2: Verificar generación y combate**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --script res://tests/run_map_tests.gd
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/containment_enemy_spawn_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/exp07_attack_tests.tscn
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 res://tests/combat_smoke.tscn
```

Expected: `PASS` en las cuatro suites; `run_map_tests.gd` valida 1.000 seeds y
`combat_smoke.tscn` termina con cero fallos.

- [ ] **Step 3: Confirmar documentación**

```powershell
git add docs/ARQUITECTURA.md
git commit -m "docs: registra reparto del exp07 en contencion"
```

- [ ] **Step 4: Reimportar y abrir la versión jugable**

```powershell
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --headless --path prueba_2 --import
& 'C:\Users\jcbla\Downloads\Godot_v4.7.1-stable_win64.exe' --path prueba_2
```

Verificación humana pendiente: recorrer los combates del primer piso, comprobar
que EXP07 aparece antes del boss y evaluar si 25 % produce la frecuencia
deseada sin elevar demasiado la dificultad.
