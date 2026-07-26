# Referencia técnica para agentes

Material de consulta: medidas, recetas y convenciones. Las **reglas duras** y el flujo de
verificación están en [`AGENTS.md`](../../AGENTS.md), en la raíz del repositorio — ese
archivo se lee primero. Para conocer qué está implementado, qué valores están vigentes y
qué trabajo sigue aprobado, consultar antes
[`ESTADO_ACTUAL.md`](ESTADO_ACTUAL.md); esta referencia no reemplaza ese contrato.

---

## 1. Dónde va cada archivo

Godot es composición de nodos, no ECS ni MVC. La organización es **por feature**: la
escena vive junto a su script, nunca en árboles paralelos `scenes/` y `scripts/`.

| Carpeta | Qué va |
|---|---|
| `assets/` | Arte, audio y fuentes |
| `autoload/` | `game_state`, `inventory`, `room_db`, `run_manager`, `transition` |
| `core/` | Sin dependencias del juego: paleta/capas y modelo/generador de mapa |
| `game/` | El ensamblaje de la partida: `main.tscn` + `main.gd` |
| `actors/` | Lo que se mueve y decide: `player/`, `boss/` |
| `world/` | El escenario: `rooms/`, `props/` |
| `ui/` | Pantallas y overlays |

Preguntas para ubicar algo nuevo:

- ¿Se mueve y toma decisiones? → `actors/`
- ¿Es escenario, con o sin colisión? → `world/props/`
- ¿Es una pantalla o un overlay? → `ui/`
- ¿Lo usan varios sistemas y no depende de ninguno? → `core/`
- ¿Tiene que sobrevivir al cambio de escena? → `autoload/`, y pensarlo dos veces

**Un `.tscn` y su `.gd` van siempre en la misma carpeta y con el mismo nombre.**

---

## 2. Layout de sala (no improvisar medidas)

| Elemento | Valor |
|---|---|
| Rejilla jugable | 13 × 7 celdas (`x` 0..12, `y` 0..6) |
| Celda | 120 × 120 px |
| Interior (suelo) | x `180…1740`, y `120…960` |
| Muro | banda de 120 px alrededor |
| Pantalla | 1920 × 1080, cámara fija centrada en (960, 540) |

- `cell_center(c) = Vector2(180, 120) + c * 120 + Vector2(60, 60)`
- **Carriles de puerta libres:** columna `x = 6` y fila `y = 3` no llevan props sólidos.
- Rejilla: `grate_direction` reserva una pared sin puerta. `Grate` usa
  `DOOR_POSITIONS[direction]`; el destino crea solo `GrateSpawn` según
  `grate_arrival_direction`. Nunca se materializa un retorno.
- Una puerta por lado como máximo, centrada. El muro se parte en **dos** `ColorRect` +
  **dos** `CollisionShape2D` y el `Area2D` de la puerta va en el medio.
- **El hueco del muro mide 240 px, no 120.** Las jambas en embudo de `door.tscn` lo
  estrechan hasta el paso útil de 120 px. Para un lado N/S el hueco va de `x` 840 a 1080;
  para E/O, de `y` 420 a 660. Si se deja el hueco en 120 px, las jambas se solapan con el
  muro y la puerta queda tapiada.
- Al partir un muro, el `CollisionShape2D` debe quedar centrado en su tramo. Un tramo que
  va de 1020 a 1860 tiene centro en **1440**, no en 1380. Este error ya se cometió y dejó
  huecos invisibles de 60 px.

---

## 3. Cómo hacer cambios típicos

### Añadir una sala

No se añade una escena por sala generada. `MapGenerator` crea el descriptor y
`RoomAssembler` usa `procedural_room.tscn` para abrir muros, puertas y `SpawnN/E/S/O`.

Para una combinación visual nueva:

1. añadir el PNG 1920×1080 en `assets/environment/rooms/`;
2. registrarlo en `core/room_backgrounds.gd` (`flip_h` permite reutilizar una variante
   espejada sin duplicar el PNG);
3. añadir el fixture a `_test_room_templates()` y `_test_procedural_room_assembly()`;
4. correr `combat_smoke.tscn` y `run_map_tests.gd`.

Cambiar topología o contenido exige actualizar `MapGenerator.validate()` y comprobar
1.000 seeds con `res://tests/run_map_tests.gd`. El validador también exige que cada
conjunto de puertas exista en el catálogo antes de aceptar una seed. `RoomDB.ROOMS` es
legado.

El inicio tiene contrato fijo por posición del camino, no por ID:

- `main_path[0]`: `entry/tutorial`;
- `main_path[1]`: `body/body_reward`, una entrada sellada, una salida y sin rejilla;
- `reward_part_id`: parte inicial determinista;
- `BloodTrail` resuelve su orientación leyendo `doors` y `entrances`;
- `BodySource` reclama la recompensa en `GameState` únicamente al recogerla.

Verificar con `room_story_tests.tscn`, `room_assembly_tests.tscn` y
`run_map_tests.gd`.

### Añadir decoración

No se toca el árbol de nodos. En la raíz del `.tscn` de la sala:

```
tanks = Array[Vector2i]([Vector2i(1, 1)])
debris = Array[Vector2i]([Vector2i(4, 5)])
puddles = Array[Vector2i]([Vector2i(3, 2)])
sign_text = "SECTOR C-3"
sign_cell = Vector2i(3, 0)
```

Las lámparas van **empotradas en el muro**, nunca en el suelo: se declaran por lado y por
índice de celda a lo largo de ese muro (`0..12` en N/S, `0..6` en E/O).

```
lamps_n = Array[int]([3, 9])
lamps_o = Array[int]([3])
dead_lamps_s = Array[int]([6])
```

Los focos actuales conservan `energy = 1.6` y amplían cobertura con
`texture_scale = 1.85`. Evitar el carril central de puerta y no usar decals narrativos
como fuentes de luz.

`room.gd` los instancia en `_ready()`. Para un prop nuevo: escena en `world/props/`,
`preload` y un `@export var ... : Array[Vector2i]` en `world/rooms/room.gd`.

### Props de Contención y rejilla

Las salas procedurales no declaran estos props en el `.tscn`: `core/containment_prop_catalog.gd`
devuelve la receta estable por `room_data["id"]` y `world/rooms/procedural_room.gd` la ensambla.
Usa solo las ocho celdas seguras y deja libres fila 3/columna 6; `entry` recibe siempre
`broken_glass_tube` en `(960, 500)` y los roles narrativos no reciben utilería aleatoria.

Las escenas `world/props/containment/` deben conservar el nodo `Sprite`, `footprint()` y una
colisión de base. Para una rejilla, no crear puertas:
`RunMap.set_grate(source, target, direction)` registra `grate_target`, `grate_source` y
`grate_arrival_direction`; `procedural_room.gd` instancia la fuente dentro de `120 × 120`
y en el destino solo crea `GrateSpawn`. `Transition.go_via_grate()` nunca ofrece regreso.
El sprite queda en el muro. `grate.gd::SENSOR_POSITIONS` desplaza solo el
`CollisionShape2D` `105 px` hacia el interior; no abrir el muro ni volver a centrar el
sensor, porque desde allí el jugador no puede alcanzarlo físicamente.

### Boss de Contención

- `role = &"boss_choice"` instancia `BossCore` y `ChimeraArena`; no usa el pool normal.
- Ciclo: `SEEK_CORNER → CORNER_AIM → POUNCE → RECOVER`; `CORNER_AIM` dura
  `[1.35, 1.08, 0.84]` s según fase y no muestra texto de acción.
- La posición del jugador se congela al entrar a `POUNCE`; no hay homing durante la
  embestida.
- `BossCore` usa capa 2, grupos `enemies`/`bosses`, `12 HP` y la firma normal de
  `take_damage(amount, from, knockback, break_shield)`.
- `player_projectile.tscn` conserva máscara `11` para incluir esa capa.
- Muerte: `dash`, `silent_claws`, sala limpia, boss derrotado y
  `RunManager.complete_floor(&"contencion")`.
- Arte runtime: `actors/boss/boss_core_frames.tres` sobre
  `assets/bosses/containment_chimera/animations/` y
  `assets/environment/containment/chimera_arena.png`. `chimera.png` queda solo como
  referencia de identidad.
- Fuentes ilustradas: siete PNG en
  `art_raw/enemigos/containment/boss_chimera/idle/` y dieciséis en
  `art_raw/enemigos/containment/boss_chimera/angry/`.
- Regenerar runtime: `godot --headless --path prueba_2 --script
  res://tools/art/process_chimera_delivered_frames.gd`; usa recorte común, lienzo
  `384 × 256` y ajuste máximo `350 × 205`.
- `boss_core.gd` mapea búsqueda/recuperación a `idle` y aviso/embestida a `angry`.
  `_update_sprite_animation()` solo relanza al cambiar de nombre, así que `angry` continúa
  sin reiniciarse al comenzar `POUNCE`.

### Añadir una habilidad

`GameState.gain_ability(id)` / `GameState.has_ability(id)`. Si necesita tarjeta propia,
añadirla en `ui/body_panel.gd` junto con su curva al slime. El estado vive **solo** en
`GameState`, nunca en el script del jugador — así sobrevive a los cambios de sala.

### Cambiar HUD, tarjetas o mapas

- Barra: `hud.gd` escucha `health_changed`; `health_ratio()` usa
  `health_halves / max_health_halves`.
- Nombres y resúmenes: `PartsDB.display_name()` / `PartsDB.description()`. No copiar texto
  a un `.tscn`.
- Tarjetas: `body_panel.gd` escucha `Inventory.slots_changed`; un slot vacío no conserva
  ni tarjeta ni curva. Con `TAB` abierto, `WASD` o flechas recorren solo tarjetas ocupadas y
  `F` consume la seleccionada. La selección debe conservar escala, borde y conexión
  resaltados como una sola señal visual.
- Mapa local: `map_overlay.gd` lee `RunManager.current_map`, no `RoomDB.ROOMS`.
  `build_layout()` debe aceptar cruces cardinales sin solaparlas y solo recibir IDs
  visitados.
- Ruta global: `floor_route_overlay.gd` solo dibuja pisos, con Contención abajo y
  Superficie arriba; dura 3 s.
- Portada: `BackgroundContained` y `BackgroundEscaped` usan
  `prueba_2/assets/ui/title/title_contained.png` y
  `prueba_2/assets/ui/title/title_escaped.png`; `Menu` contiene `PlayButton` y
  `QuitButton` sobre la ilustración escapada. La primera tecla o clic solo omite la
  introducción: no activa `PlayButton` ni inicia la partida.
- Primera sala: `TutorialMural` enseña mantener dirección, cargar y soltar; es un prop
  pasivo del mundo y debe dejar libres spawn y puertas.
- Tema: `ui/game_theme.tres` se asigna en las raíces de portada, HUD, mapa, pausa,
  rejilla, ruta, resumen y final. No copiar StyleBox comunes en cada escena.
- Música: `ui/title.tscn::Music` usa `main_menu.ogg` a `-10 dB`;
  `game/main.tscn::Music` usa `containment_ambience.ogg` a `-13 dB`. Los `.opus` fuente
  viven en `assets/audio/music/source/`.
- Resolución lógica 1920×1080; comprobar también la salida 1280×720.

Pruebas:

```bash
godot --headless --path prueba_2 res://tests/hud_tests.tscn
godot --headless --path prueba_2 res://tests/part_tooltip_tests.tscn
godot --headless --path prueba_2 res://tests/body_panel_tests.tscn
godot --headless --path prueba_2 res://tests/map_overlay_tests.tscn
godot --headless --path prueba_2 res://tests/floor_route_tests.tscn
godot --headless --path prueba_2 res://tests/ui_theme_tests.tscn
godot --headless --path prueba_2 res://tests/containment_boss_tests.tscn
godot --headless --path prueba_2 res://tests/music_asset_tests.tscn
```

Captura reproducible (`modo` = `title_intro`, `title_menu`, `hud`, `map`, `tooltip`,
`route`, `tutorial`, `grate`, `exp07_attack`, `enemies`, `lighting`, `boss` o `slime`):

```powershell
& '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- map "<salida.png>" 1920x1080
& '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1280x720 res://tests/ui_visual_capture.tscn -- map "<salida-720p.png>" 1280x720
& '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- title_intro user://title-intro.png 1920x1080
& '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- title_menu user://title-menu.png 1920x1080
& '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- grate user://grate-wall-flow.png 1920x1080
& '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- exp07_attack user://exp07-attack.png 1920x1080
& '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- enemies user://containment-enemies.png 1920x1080
& '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- lighting user://lighting-test-mode.png 1920x1080
& '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- boss user://chimera-arena.png 1920x1080
& '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- slime user://slime-animation.png 1920x1080
```

### Arte animado de un enemigo de Contención

Pipeline reproducible, de crudo a runtime:

```bash
godot --headless --path prueba_2 --script res://tools/art/gen_containment_enemy_sheets.gd
godot --headless --path prueba_2 --script res://tools/art/process_containment_enemy_sheets.gd
godot --headless --path prueba_2 --script res://tools/art/process_chimera_delivered_frames.gd
godot --headless --path prueba_2 --import
godot --headless --path prueba_2 res://tests/check_enemy_animations.tscn
```

- El generador escribe tres hojas 3 × 2 con fondo `#ff00ff` en
  `art_raw/enemigos/containment/<personaje>/source_sheet.png`. El orden de las seis
  poses es contrato: cambiarlo obliga a cambiar `names` en el procesador.
- Para sustituir EXP01, EXP02 o EXP03 por arte pintado a mano **basta con reemplazar su
  `source_sheet.png`** respetando la rejilla 3 × 2 y el orden de poses.
- El procesador usa **un recorte común a las seis poses**, no uno por pose: es lo que
  conserva escala y punto de apoyo entre fotogramas. Mismo criterio que
  `process_exp07_claw_frames.gd`.
- El croma se retira midiendo `min(r, b) - g` y deshaciendo la composición sobre el
  magenta; por eso no quedan orlas. Antes de escalar se premultiplica el alfa, o el
  borde se ensucia de negro.
- La Quimera no pertenece a ese generador provisional: su procesador carga 23 PNG con
  alfa, calcula un único recorte para Idle y Angry y genera
  `chimera_{idle,angry}_XX.png`.

Para integrarlo en el juego, por experimento:

1. `expXX_*_frames.tres` junto al actor, con las animaciones nombradas igual que los
   estados;
2. en el `.tscn`, sustituir `Body: Polygon2D` por `Sprite: AnimatedSprite2D` con
   `sprite_frames` y `autoplay`;
3. en el `.gd`, un `_visual_state() -> StringName` que traduzca el enum `State`.

Las velocidades de los avisos se calculan para que el último fotograma coincida con la
llamada que aplica el ataque (`windup` de EXP01 a 3,076923 FPS = 0,65 s, `tail_windup`
de EXP03 a 6 FPS = 0,5 s, etc.). **Si cambia el tiempo del estado, hay que recalcular la
velocidad.** El arte nunca aplica daño.

### Ataque ilustrado del EXP07

- Fuentes: cinco PNG transparentes 1920 × 1080 en
  `assets/enemies/exp07_crustacean/source_attack/`.
- Regenerar runtime: `godot --headless --path prueba_2 --script
  res://tools/art/process_exp07_claw_frames.gd`; produce cinco frames 192 × 108
  con recorte común.
- `pinch_windup`: 00→04 a 6,25 FPS durante 0,8 s. `recover`: 04→00 a
  8,333333 FPS durante 0,6 s.
- `_pinch()` es la única autoridad del daño. No conectar daño a frames ni
  reutilizar este arte en el slime o en el pickup `crusher_claw`.

### Arte animado del slime

- Fuentes: cuatro hojas RGBA en `art_raw/personaje/slime/`, con celdas exactas
  de 320 × 320: `idle=5`, `walk=2`, `jump=6`, `recover=12`.
- Regenerar runtime: `godot --headless --path prueba_2 --script
  res://tools/art/process_slime_delivered_sheets.gd`; después ejecutar
  `godot --headless --path prueba_2 --import`.
- El procesador valida dimensiones, cantidad y alfa, calcula un único recorte
  para los 25 frames y los centra en lienzos de 128 × 128 con ajuste 96 × 96.
  No recortar ni escalar cada pose por separado.
- `prueba_2/actors/player/slime_frames.tres` repite `idle`/`walk` y deja
  `jump`/`recover` sin loop. `slime.gd::_visual_animation()` traduce el estado:
  reposo/carga → `idle`, movimiento con piernas → `walk`,
  lanzamiento/DASH → `jump`, recuperación → `recover`.
- La fuente mira a la derecha; `_update_sprite_animation()` solo refleja
  horizontalmente desde `_facing`. `ScaleShell` y la barra siguen sobre el
  sprite. Los frames no gobiernan colisión, daño ni duración de estados.

### Cambiar movimiento base

- Sin piernas, mantener dirección carga y soltar inicia el arrastre.
- Cualquier parte de tipo `pierna` cambia a movimiento continuo a `280 px/s`; perder la
  última restaura la carga. `Inventory` expone el conteo para futuras reglas de una o dos.
- Rango válido: `112–520 px`, calculado desde el umbral `MIN_CHARGE_TIME = 0.12`.
- El tramo base avanza uniforme a `CRAWL_SPEED = 480 px/s`; más carga aumenta duración.
- La deformación de `Body`/`Core` no mueve el `CharacterBody2D` ni cambia el círculo de
  colisión de radio `45`.
- El DASH conserva `_eased_speed()` y sus constantes propias; no copiarle el perfil base.

Pruebas:

```bash
godot --headless --path prueba_2 --script res://tests/slime_movement_tests.gd
godot --headless --path prueba_2 --script res://tests/run_slime_audio_tests.gd
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
```

### Ciclo de partida y rejillas

- Nueva partida: `RunManager.start_new_run(seed)`; máximo 15 HP, inicio 7 HP.
- TAB expone `MODO PRUEBA · VIDA INFINITA`; clic o `V` lo alternan. El flag vive en
  `GameState`, persiste entre salas y se apaga con `reset_run()`. Bloquea solo la pérdida
  de HP: el golpe conserva invulnerabilidad temporal y retroceso.
- Completar Contención: `RunManager.complete_floor(&"contencion")`, cura +2 HP una vez.
- Comer: `TAB` abre el mapa corporal, las flechas seleccionan y `F` llama
  `Inventory.consume_slot()`. Cura +2 HP y libera el slot; `Tab` solo muestra `F · COMER`.
- Duplicado en el suelo: si `Inventory.has_part(part_id)`, el pickup muestra
  `F · COMER` y llama `consume_loose_duplicate()`. Cura +2 HP, emite `collected` y no
  modifica slot, cooldown ni usos de la copia equipada.
- Perder/sacrificar: liberan slot y no curan.
- Cuerpo lleno: el séptimo pickup permanece en el mundo; no existe parte pendiente ni
  pantalla separada con `I`.
- Rejilla: `RunManager.pay_grate_cost(slot, confirm_lethal)`; parte equipada o 1 HP. Pagar
  ejecuta `GameState.unlock_grate(source_id)` para la partida actual; entrar por la fuente
  desbloqueada viaja una sola vez hacia delante. `grate_source` es solo metadato.
- Generación: `_add_grates()` procesa fuentes por capa ascendente; una sala futura recibe
  todas sus `entrances` antes de elegir `grate_direction`. `validate()` rechaza paredes
  compartidas entre una abertura y una rejilla.
- A 1 HP se exige confirmación; morir llama `RunManager.end_run()`. No hay respawn.
- Penumbra global: `main.tscn::Darkness = Color(0.32, 0.35, 0.37, 1)`. No aclarar
  fondos individuales. Las lámparas conservan energía `1.6`, radio `1.85`, parpadeo y
  estado fundido.

---

## 4. Estilo de código

- Tabs para indentar (estándar de Godot).
- Tipado estático siempre: `func f(x: float) -> void:`, `var v: Vector2 = ...`.
- Constantes en `SCREAMING_SNAKE_CASE` arriba del archivo; miembros privados con `_`.
- Comentarios en **español**, solo donde el "por qué" no se ve en el código. No comentar
  lo obvio.
- Nada de `print()` de depuración en el código que se entrega.
- Reutilizar los fondos y escenas existentes antes de crear assets nuevos.
- Colores **siempre** desde `Palette`, nunca hardcodeados en scripts.

### Paleta (IcyWitch)

`VOID #313638` · `FLOOR #32535f` · `WALL #0a777a` · `SLIME_BODY #4aa881` ·
`SLIME_CORE #73efe8` · `WARM_LIGHT #ecf3b0`

---

## 5. Formato de los `.tscn`

Se escriben a mano como texto. Al añadir un `[ext_resource]` hay que **subir `load_steps`**
en la cabecera: vale el número total de recursos (`ext_resource` + `sub_resource`) más 1.

Instanciar una escena hija:

```
[node name="DoorE" parent="." instance=ExtResource("2")]
position = Vector2(1800, 540)
direction = "E"
```

Grupos: `[node name="Slime" type="CharacterBody2D" groups=["player"]]`.

Arrays tipados como propiedad de un nodo:

```
lamps = Array[Vector2i]([Vector2i(2, 1), Vector2i(10, 5)])
```
