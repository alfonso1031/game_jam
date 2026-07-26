# Boss, Rejillas, Audio y UI de Contención Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Entregar Contención con boss Quimera procedural, rejillas utilizables, dos pistas musicales y una presentación visual unificada.

**Architecture:** `BossCore` conserva su escena y contratos externos, pero adopta una máquina de estados de embestida y la interfaz de daño usada por el grupo `enemies`. `ProceduralRoom` ensambla boss, arena y recompensas según el rol. Las rejillas corrigen solo su sensor. Música y tema se componen desde las escenas de título/partida, sin autoload nuevo.

**Tech Stack:** Godot 4.7.1, GDScript tipado, escenas `.tscn`, PNG transparente, audio Ogg/Opus y pruebas headless.

**Estado:** implementado y verificado el 26-07-2026. Importación limpia, 28/28 suites
verdes y arranque Godot MCP con `errors: []`.

## Global Constraints

- Preservar vida `7/15 HP`, curación `+2 HP` y ausencia de respawn.
- Preservar `40/30/20/10` para salas y `40/20/40` para destino de rejilla.
- Máximo una rejilla por sala, destino exclusivo, parte o `1 HP`, retorno gratuito.
- Resolución lógica 1920×1080 y comprobación adicional 1280×720.
- Mantener rutas `res://`, arquitectura por feature, capas de `Layers` y colores de `Palette`.
- No incluir los `.clip` de trabajo en runtime; sí versionar todos los assets usados.

---

### Task 1: Preparar assets runtime y música

**Files:**
- Create: `prueba_2/assets/bosses/containment_chimera/source/chimera_reference.png`
- Create: `prueba_2/assets/bosses/containment_chimera/chimera.png`
- Create: `prueba_2/assets/environment/containment/chimera_arena.png`
- Create: `prueba_2/assets/audio/music/main_menu.ogg`
- Create: `prueba_2/assets/audio/music/containment_ambience.ogg`
- Preserve: `prueba_2/assets/audio/music/source/main_menu.opus`
- Preserve: `prueba_2/assets/audio/music/source/containment_ambience.opus`
- Test: `prueba_2/tests/music_asset_tests.gd`
- Test: `prueba_2/tests/music_asset_tests.tscn`

**Interfaces:**
- Produces: recursos `Texture2D` y `AudioStream` cargables mediante las rutas anteriores.

- [x] **Step 1: Escribir el test de carga**

```gdscript
extends Node

const MENU := preload("res://assets/audio/music/main_menu.ogg")
const GAMEPLAY := preload("res://assets/audio/music/containment_ambience.ogg")
const CHIMERA := preload("res://assets/bosses/containment_chimera/chimera.png")
const ARENA := preload("res://assets/environment/containment/chimera_arena.png")

func _ready() -> void:
	assert(MENU != null and GAMEPLAY != null)
	assert(CHIMERA.get_size().x > 0 and ARENA.get_size().x > 0)
	get_tree().quit()
```

- [x] **Step 2: Verificar RED**

Run: `godot --headless --path prueba_2 res://tests/music_asset_tests.tscn`
Expected: FAIL porque los recursos todavía no existen.

- [x] **Step 3: Copiar fuentes, generar PNG transparentes e importar audio**

Usar la ilustración recibida como referencia de identidad. El runtime no lleva fondo ni
texto; la arena es cenital y deja libre el centro. Copiar los dos `.opus` con nombres sin
espacios y ejecutar `godot --headless --path prueba_2 --import`.

- [x] **Step 4: Verificar GREEN**

Run: `godot --headless --path prueba_2 res://tests/music_asset_tests.tscn`
Expected: `PASS: music and presentation assets`.

- [x] **Step 5: Commit**

```powershell
git add prueba_2/assets/bosses prueba_2/assets/environment/containment/chimera_arena.png prueba_2/assets/audio/music prueba_2/tests/music_asset_tests.*
git commit -m "feat: incorpora arte y musica de contencion"
```

### Task 2: Implementar IA y combate de la Quimera

**Files:**
- Modify: `prueba_2/actors/boss/boss_core.gd`
- Modify: `prueba_2/actors/boss/boss_core.tscn`
- Modify: `prueba_2/actors/player/abilities/player_projectile.tscn`
- Create: `prueba_2/tests/containment_boss_tests.gd`
- Create: `prueba_2/tests/containment_boss_tests.tscn`

**Interfaces:**
- Produces: `signal died(boss)`, `take_damage(amount, from, knockback, break_shield)` y
  estados `SEEK_CORNER`, `CORNER_AIM`, `POUNCE`, `RECOVER`.
- Consumes: grupo `player`, `GameState`, `RunManager`, `AbilityPickup` y `PartPickup`.

- [x] **Step 1: Escribir el test del ciclo**

Instanciar boss y jugador. Comprobar que `CORNER_AIM` deja velocidad cero, que
`_pounce_target` conserva la instantánea aunque el jugador se mueva y que `POUNCE` usa
una velocidad no nula hacia esa instantánea.

- [x] **Step 2: Escribir el test de daño y recompensas**

Aplicar `12` puntos de daño, capturar `died`, comprobar
`GameState.bosses_defeated[room_id]`, DASH, `silent_claws` y
`RunManager.completed_floors["contencion"]`.

- [x] **Step 3: Verificar RED**

Run: `godot --headless --path prueba_2 res://tests/containment_boss_tests.tscn`
Expected: FAIL por estados e interfaz ausentes.

- [x] **Step 4: Reescribir `BossCore` con la máquina mínima**

```gdscript
enum State {SEEK_CORNER, CORNER_AIM, POUNCE, RECOVER, DEAD}
const CORNERS: Array[Vector2] = [
	Vector2(330, 270), Vector2(1590, 270),
	Vector2(1590, 810), Vector2(330, 810),
]

func _enter_corner_aim() -> void:
	_state = State.CORNER_AIM
	velocity = Vector2.ZERO
	_timer = _aim_time()
	_pounce_target = _player.global_position
```

El lanzamiento no recalcula `_pounce_target`. `_draw()` muestra la línea telegráfica y
el sprite usa escala/rotación para comunicar ráfaga, espera e impacto.

- [x] **Step 5: Habilitar ataques existentes contra capa boss**

Cambiar `PlayerProjectile.collision_mask` de `9` a `11`; BossCore pertenece al grupo
`enemies`, conserva `collision_layer = 2` y expone la misma firma de daño.

- [x] **Step 6: Verificar GREEN**

Run: `godot --headless --path prueba_2 res://tests/containment_boss_tests.tscn`
Expected: PASS.

- [x] **Step 7: Commit**

```powershell
git add prueba_2/actors/boss prueba_2/actors/player/abilities/player_projectile.tscn prueba_2/tests/containment_boss_tests.*
git commit -m "feat: implementa embestidas de la quimera"
```

### Task 3: Materializar boss y arena en el mapa procedural

**Files:**
- Modify: `prueba_2/world/rooms/procedural_room.gd`
- Modify: `prueba_2/tests/containment_boss_tests.gd`

**Interfaces:**
- Consumes: descriptor `role = &"boss_choice"`.
- Produces: hijos `ChimeraArena` y `Boss` solo en la última sala.

- [x] **Step 1: Añadir fixture procedural al test**

Construir una sala `boss_choice`, añadirla al árbol y comprobar un solo Boss, decal
debajo de actores y ausencia de enemigos normales.

- [x] **Step 2: Verificar RED**

Run: `godot --headless --path prueba_2 res://tests/containment_boss_tests.tscn`
Expected: FAIL porque `ProceduralRoom` no instancia el boss.

- [x] **Step 3: Ensamblar boss y decal por rol**

`configure()` crea el decal; `_ready()` llama `_spawn_boss()` antes de enemigos. El boss
recibe el ID generado y posición `ROOM_CENTER`.

- [x] **Step 4: Verificar GREEN y mapa**

Run: test del boss y `godot --headless --path prueba_2 --script res://tests/run_map_tests.gd`.

- [x] **Step 5: Commit**

```powershell
git add prueba_2/world/rooms/procedural_room.gd prueba_2/tests/containment_boss_tests.gd
git commit -m "feat: integra la quimera al final procedural"
```

### Task 4: Corregir interacción real de rejillas

**Files:**
- Modify: `prueba_2/world/props/grate.gd`
- Modify: `prueba_2/tests/grate_flow_tests.gd`

**Interfaces:**
- Produces: sensor de interacción desplazado hacia el interior según `wall_direction`.

- [x] **Step 1: Extender el test con jugador físico**

Añadir `CharacterBody2D` grupo `player`, capa `1`, círculo de colisión y colocarlo en
`grate.position + SENSOR_OFFSETS[direction]`. Tras dos frames comprobar
`_player_near == true`.

- [x] **Step 2: Verificar RED**

Run: `godot --headless --path prueba_2 res://tests/grate_flow_tests.tscn`
Expected: FAIL porque el sensor sigue dentro del muro.

- [x] **Step 3: Desplazar solo el sensor**

```gdscript
const SENSOR_OFFSETS := {
	"N": Vector2(0, 105), "S": Vector2(0, -105),
	"O": Vector2(105, 0), "E": Vector2(-105, 0),
}

func _fit_visual() -> void:
	$CollisionShape2D.position = SENSOR_OFFSETS[wall_direction]
```

- [x] **Step 4: Verificar GREEN y costo**

Run: `grate_flow_tests.tscn` y `grate_cost_ui_tests.tscn`.

- [x] **Step 5: Commit**

```powershell
git add prueba_2/world/props/grate.gd prueba_2/tests/grate_flow_tests.gd
git commit -m "fix: acerca la interaccion de las rejillas"
```

### Task 5: Integrar música en título y partida

**Files:**
- Modify: `prueba_2/ui/title.gd`
- Modify: `prueba_2/ui/title.tscn`
- Modify: `prueba_2/game/main.gd`
- Modify: `prueba_2/game/main.tscn`
- Modify: `prueba_2/tests/music_asset_tests.gd`

**Interfaces:**
- Produces: nodo `Music` en ambas escenas y bucle por señal `finished`.

- [x] **Step 1: Extender test de escenas**

Instanciar título y main, comprobar `Music.stream != null`, pista correcta y volumen
menor o igual a `-8 dB`.

- [x] **Step 2: Verificar RED**

Run: `music_asset_tests.tscn`; esperado FAIL por nodos ausentes.

- [x] **Step 3: Añadir reproductores**

Título usa `main_menu.ogg` a `-10 dB`; partida usa `containment_ambience.ogg` a
`-13 dB`. Los scripts reconectan `finished` a `play`.

- [x] **Step 4: Verificar GREEN**

Run: `music_asset_tests.tscn`; esperado PASS.

- [x] **Step 5: Commit**

```powershell
git add prueba_2/ui/title.* prueba_2/game/main.* prueba_2/tests/music_asset_tests.gd
git commit -m "feat: ambienta menu y partida con musica"
```

### Task 6: Unificar UI y completar arena

**Files:**
- Create: `prueba_2/ui/game_theme.tres`
- Modify: `prueba_2/ui/title.tscn`
- Modify: `prueba_2/ui/hud.gd`
- Modify: `prueba_2/ui/hud.tscn`
- Modify: `prueba_2/ui/map_overlay.gd`
- Modify: `prueba_2/ui/map_overlay.tscn`
- Modify: `prueba_2/ui/pause_menu.tscn`
- Modify: `prueba_2/ui/grate_cost_overlay.tscn`
- Modify: `prueba_2/ui/run_summary.tscn`
- Modify: `prueba_2/ui/floor_route_overlay.tscn`
- Create: `prueba_2/tests/ui_theme_tests.gd`
- Create: `prueba_2/tests/ui_theme_tests.tscn`

**Interfaces:**
- Produces: tema compartido y paneles legibles sin añadir controles explicativos a la
  portada.

- [x] **Step 1: Escribir contratos visuales**

Comprobar que las escenas usan `game_theme.tres`, que título mantiene solo JUGAR/SALIR,
que HUD conserva salud/minimapa y que mapa muestra el encabezado local.

- [x] **Step 2: Verificar RED**

Run: `ui_theme_tests.tscn`; esperado FAIL por tema y encabezado ausentes.

- [x] **Step 3: Crear tema y aplicar jerarquía**

Definir StyleBoxFlat para botones/paneles/focus y asignar `theme` en raíces. Añadir panel
de menú, marco de HUD y encabezado dibujado `MAPA LOCAL · CONTENCIÓN`.

- [x] **Step 4: Verificar suites de UI**

Run: HUD, tooltip, body panel, map overlay, floor route, title y ui cleanup.

- [x] **Step 5: Capturar 1920×1080 y 1280×720**

Generar portada, HUD, mapa, rejilla y arena con `ui_visual_capture.tscn`; inspeccionar que
no haya solapamientos ni texto fuera del viewport.

- [x] **Step 6: Commit**

```powershell
git add prueba_2/ui prueba_2/tests/ui_cleanup_tests.gd
git commit -m "feat: unifica la interfaz de contencion"
```

### Task 7: Documentación y verificación final

**Files:**
- Modify: `docs/ARQUITECTURA.md`
- Modify: `docs/agents/REFERENCIA.md`

- [x] **Step 1: Documentar boss, música, sensor y tema**

Actualizar ciclo del boss, recompensas, rutas de assets, sensor interior y comandos.

- [x] **Step 2: Ejecutar verificación completa**

```powershell
godot --headless --path prueba_2 --import
godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
godot --headless --path prueba_2 res://tests/run_lifecycle_tests.tscn
godot --headless --path prueba_2 res://tests/containment_boss_tests.tscn
godot --headless --path prueba_2 res://tests/grate_flow_tests.tscn
godot --headless --path prueba_2 res://tests/grate_cost_ui_tests.tscn
godot --headless --path prueba_2 res://tests/music_asset_tests.tscn
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
```

- [x] **Step 3: Arranque con Godot MCP**

`run_project` → `get_debug_output` → confirmar errores vacíos → dejar versión jugable.

- [x] **Step 4: Commit**

```powershell
git add docs/ARQUITECTURA.md docs/agents/REFERENCIA.md
git commit -m "docs: explica cierre completo de contencion"
```
