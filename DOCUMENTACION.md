# SLIME ESCAPE — Documentación técnica

Juego 2D cenital hecho en **Godot 4.7.1**. Un slime recién liberado escapa de un
laboratorio abandonado subiendo de nivel en nivel. Implementación del plan descrito en
[PLAN.md](PLAN.md).

- **Proyecto activo:** `prueba_2/`
- **Escena principal:** `res://scenes/main.tscn`
- **Renderer:** `gl_compatibility` · **Resolución:** 1920 × 1080, pantalla completa

---

## 1. Cómo correrlo

Desde consola:

```bash
"C:/Godot/Godot_v4.7.1-stable_win64_console.exe" --path "C:/ALFONSO/projects/Game Jam/prueba_2"
```

O por el MCP de Godot (`@coding-solo/godot-mcp`): `run_project` + `get_debug_output`
para leer la salida de debug, `stop_project` para cerrarlo.

### Controles

| Acción | Tecla |
|---|---|
| Mover | `WASD` / flechas |
| Mapa completo | `TAB` |
| Interactuar | `E` |
| Dash (tras vencer al boss) | `Shift` / `Espacio` |
| Pausa / cerrar mapa | `Esc` |
| Ventana / pantalla completa | `F11` |

---

## 2. Estructura de archivos

```
prueba_2/
├── project.godot                 # 2D, gl_compatibility, autoloads, inputs
├── scenes/
│   ├── main.tscn                 # raíz: Darkness + RoomHost + Player + HUD + Map + Fade
│   ├── player/slime.tscn
│   ├── rooms/                    # 7 salas + test_room
│   ├── props/                    # door, elevator, lamp, tank, debris, puddle
│   └── ui/                       # hud, map_overlay
└── scripts/
    ├── core/palette.gd           # colores IcyWitch (clase estática, NO autoload)
    ├── autoload/
    │   ├── game_state.gd         # sala actual, visitadas, habilidades, vida
    │   ├── room_db.gd            # grafo de salas + validador
    │   └── transition.gd         # fade, swap de sala, reposicionado
    ├── main.gd                   # arranca en L3_CELDA
    ├── player/slime.gd
    ├── rooms/room.gd             # bounds + decoración data-driven
    ├── props/                    # door.gd, elevator.gd, lamp.gd
    └── ui/                       # hud.gd, map_overlay.gd
```

---

## 3. Paleta IcyWitch

Centralizada en `scripts/core/palette.gd`. **No es autoload** — es una clase con
constantes; se usa con `const Palette := preload("res://scripts/core/palette.gd")`.

| Constante | Hex | Uso |
|---|---|---|
| `VOID` | `#313638` | Vacío, sombras, fondo de paneles del HUD |
| `FLOOR` | `#32535f` | Suelo del laboratorio |
| `WALL` | `#0a777a` | Muros, marcos, estructura |
| `SLIME_BODY` | `#4aa881` | Cuerpo del slime, biomasa |
| `SLIME_CORE` | `#73efe8` | Núcleo, luces frías, puertas abiertas |
| `WARM_LIGHT` | `#ecf3b0` | Lámparas cálidas, texto de UI, carteles |

---

## 4. Sistema de salas (data-driven)

Todo el grafo vive en `RoomDB.ROOMS`. Añadir una sala = una entrada + un `.tscn`.

```gdscript
"L3_PASILLO": {
    "level": -3,
    "level_name": "CONTENCIÓN",
    "room_name": "Pasillo de Servicio",
    "grid": Vector2i(1, 0),          # posición en el minimapa del nivel
    "scene": "res://scenes/rooms/l3_pasillo.tscn",
    "doors": {"O": "L3_CELDA", "N": "L3_ALMACEN", "E": "L3_NUCLEO"},
},
```

Direcciones `N | S | E | O`. `RoomDB._validate()` corre al arrancar y hace `push_error`
si una puerta apunta a una sala inexistente o si la vuelta no es simétrica.

### Mapa del MVP

```
NIVEL -3 · CONTENCIÓN
      ALMACÉN
         │ N
CELDA ─E─ PASILLO ─E─ NÚCLEO (boss)
                          │ N (ascensor)
NIVEL -2 · BIO-LABORATORIOS
                      ASCENSOR ─E─ BIOLAB ─E─ ESCLUSA
```

### Flujo de transición (`transition.gd`)

1. `Door`/`Elevator` detecta al jugador → `Transition.go_to(target_id, dir)`.
2. Guard `_busy`: ignora llamadas concurrentes.
3. Fade a negro (0.25 s).
4. Se libera la sala vieja, se instancia la nueva.
5. **El jugador se coloca en el `Spawn<opuesto>` ANTES de añadir la sala al árbol.**
6. `GameState.current_room` / `visited` se actualizan y se emite `room_changed`.
7. Fade in.

El jugador vive en `main.tscn`, **no** dentro de la sala — sobrevive a los cambios.

---

## 5. Layout de sala (rejilla tipo Isaac)

| Elemento | Valor |
|---|---|
| Rejilla jugable | 13 × 7 celdas |
| Celda | 120 × 120 px |
| Interior (suelo) | 1560 × 840 px → x `180…1740`, y `120…960` |
| Muro | banda de 120 px alrededor |
| Cámara | fija por sala, centrada, `zoom = 1.0`, sin scroll |

Las puertas van centradas en cada lado (1 celda), con **hueco físico real**: el muro se
parte en dos `ColorRect` + dos `CollisionShape2D` y el `Area2D` de la puerta ocupa el medio.

**Carriles de puerta:** la columna `x = 6` y la fila `y = 3` se dejan libres de props
sólidos para no bloquear las entradas.

---

## 6. Decoración data-driven (`room.gd`)

Cada sala declara sus props por **coordenada de celda**, no por píxel:

```gdscript
lamps = Array[Vector2i]([Vector2i(2, 1), Vector2i(10, 5)])
dead_lamps = Array[Vector2i]([Vector2i(9, 1)])
tanks = Array[Vector2i]([Vector2i(1, 1)])
debris = Array[Vector2i]([Vector2i(4, 5)])
puddles = Array[Vector2i]([Vector2i(3, 2)])
sign_text = "CELDA C-3 · BIOMATERIAL"
sign_cell = Vector2i(3, 0)
```

`room.gd` los instancia en `_ready()` y `cell_center()` traduce celda → píxeles. Añadir
props a una sala **no requiere tocar el árbol de nodos** ni los `ext_resource` del `.tscn`.

| Prop | Colisión | Qué es |
|---|---|---|
| `lamp` | no | `PointLight2D` cálida con parpadeo irregular por `Timer`; `dead = true` la deja apagada |
| `tank` | sí | Tanque de contención roto con biomasa derramada |
| `debris` | sí | Escombro geométrico |
| `puddle` | no | Mancha de biomasa en el suelo |
| cartel | no | `Label` en `#ecf3b0` generado desde `sign_text` |

`CanvasModulate` en `main.tscn` (nodo `Darkness`) da la oscuridad base — **un solo color
que tocar** si el juego se ve muy oscuro o muy claro.

---

## 7. El slime (`slime.gd`)

- `CharacterBody2D`, 8 direcciones, `SPEED = 220`, aceleración/fricción por `lerp`
  exponencial → sensación viscosa.
- **Squash & stretch procedural:** el `Polygon2D` se estira en la dirección del
  movimiento; quieto, respira con un `sin(t)`. Sin arte, solo geometría.
- Núcleo `#73efe8` con opacidad pulsante y `PointLight2D` propia → el slime es la
  fuente de luz principal.
- Las habilidades se consultan con `GameState.has_ability("dash")`, nunca se guardan en
  el propio script → sobreviven al cambio de sala.

---

## 8. HUD y mapa

**`hud.tscn` (CanvasLayer, siempre visible)**
- Arriba-izquierda: vida en gotas.
- Arriba-centro: `NIVEL -3 · CONTENCIÓN` + nombre de sala.
- Arriba-derecha: minimapa **del nivel actual**, con panel de fondo y celdas escaladas y
  centradas automáticamente según el `grid` de las salas de ese nivel.
- Izquierda: panel `HABILIDADES` con los slots.

Se redibuja por señal `room_changed` / `ability_gained`, nunca en `_process`.

**`map_overlay.tscn` (TAB)**
- Pausa el juego (`PROCESS_MODE_ALWAYS` para poder cerrarse).
- Niveles apilados verticalmente, de -3 abajo hacia arriba → refuerza "subir para salir".
- Sala actual en `#73efe8`, visitadas en `#0a777a`, no visitadas en contorno; sala de boss
  con anillo `#ecf3b0` (flag `is_boss` en el `RoomDB`).

Todo se dibuja desde `RoomDB` + `GameState.visited` → cero mantenimiento al añadir salas.

---

## 9. Boss 1, DASH y progresión

### Capas de colisión

| Capa | Valor | Quién |
|---|---|---|
| 1 | 1 | Mundo (muros, props sólidos) y jugador |
| 2 | 2 | Boss — no empuja físicamente al jugador, el contacto lo resuelve su `Area2D` |
| 3 | 4 | **Huecos** — el jugador solo los atraviesa durante el dash |

El jugador tiene `collision_mask = 5` (mundo + huecos) y está en el grupo `player`.
Puertas, proyectiles y pickups filtran por ese grupo, **no** por tipo de nodo (el boss
también es un `CharacterBody2D`).

### Ciclo del boss (`boss_core.gd`)

El slime no tiene ataque, así que el daño se hace por posicionamiento:

```
PERSIGUE  →  DISPARA (ráfaga radial)  →  VULNERABLE  →  PERSIGUE …
```

- **PERSIGUE:** avanza lento hacia el jugador, coraza cerrada. Tocarlo **te hace daño**.
- **DISPARA:** se frena, se pone `#ecf3b0` y lanza una ráfaga radial de proyectiles.
- **VULNERABLE:** núcleo `#73efe8` abierto y pulsando. Tocarlo **le hace daño** y te empuja.

3 fases según vida (6 golpes): cada fase acelera la persecución, acorta la ventana
vulnerable y suma proyectiles por ráfaga.

| Fase | Vida | Velocidad | Proyectiles | Ventana vulnerable |
|---|---|---|---|---|
| 1 | 6–5 | 55 | 8 | 1.9 s |
| 2 | 4–3 | 85 | 10 | 1.6 s |
| 3 | 2–1 | 120 | 12 | 1.3 s |

Al entrar en la sala el boss **sella las salidas** (`set_sealed(true)` en cualquier hijo
de la sala que tenga ese método → puerta y ascensor). Al morir las abre y suelta el
pickup de **DASH**. `GameState.bosses_defeated` evita que reaparezca.

### DASH

`Shift` / `Espacio`. Impulso de 1200 px/s durante 0.22 s, cooldown 0.8 s, invulnerable
mientras dura. Durante el dash el jugador apaga el bit 3 de su máscara → **atraviesa los
huecos**.

`L2_BIOLAB` tiene un hueco vertical de una celda que parte la sala en dos: sin dash no se
llega a la esclusa. La habilidad abre progresión real, no es decorado.

### Daño y muerte

`GameState.damage()` emite `health_changed` (el HUD se redibuja) y `died` al llegar a 0.
`main.gd` escucha `died` → restaura la vida y `Transition.respawn("L3_CELDA")`.
El jugador tiene 1 s de invulnerabilidad con parpadeo tras cada golpe.

---

## 10. Bugs encontrados y resueltos

| Bug | Causa | Solución |
|---|---|---|
| `Class "Palette" hides an autoload singleton` | `class_name Palette` + autoload con el mismo nombre | Se sacó `Palette` de `[autoload]`; es clase estática |
| `Identifier "Palette" not declared` | El cache de `class_name` no existe si nunca se abrió el editor | `const Palette := preload(...)` en cada script que la usa |
| `Parser Error: variable type inferred from Variant` | `var x := clamp(...)` con warnings-as-errors | Tipado explícito `var x: float = clamp(...)` |
| HUD crasheaba al arrancar | `_ready()` de los hijos corre **antes** que el del padre → `current_room` vacío | El HUD se dibuja solo desde la señal `room_changed`, con guard de sala vacía |
| Muro con hueco invisible de 60 px | `CollisionShape2D` del tramo derecho mal centrado (x=1380 en vez de 1440) | Corregido en las 4 salas afectadas |
| **Al entrar al pasillo saltaba de largo a la sala siguiente** | Al instanciar la sala nueva, el jugador seguía en la posición de la puerta anterior (ej. x=1800) y disparaba la puerta equivalente de la sala nueva | 1) El jugador se coloca **antes** de añadir la sala al árbol · 2) las puertas nacen "desarmadas" y solo disparan si el jugador salió del área antes · 3) guard `_busy` en `Transition` |

---

## 11. Estado del plan

| # | Paso | Estado |
|---|---|---|
| 1 | `project.godot` + paleta + autoloads | ✅ |
| 2 | `main.tscn` + slime + sala de prueba | ✅ |
| 3 | `room.gd`, puertas, transiciones, `room_db` | ✅ |
| 4 | Las 7 salas + ascensor + validador | ✅ |
| 5 | HUD + overlay de mapa | ✅ |
| 6 | Ambientación: oscuridad, lámparas, props, carteles | ✅ |
| 7 | Boss 1 + pickup + DASH + hueco | ✅ |
| 8 | Pulido: pausa, título, "CONTINUARÁ" | ⬜ pendiente |

---

## 12. Notas de mantenimiento

- **Añadir una sala:** entrada en `RoomDB.ROOMS` + `.tscn` con muros partidos donde vayan
  las puertas + `Marker2D` `SpawnN/S/E/O`. El HUD y el mapa se actualizan solos.
- **Añadir un prop:** escena en `scenes/props/` + `preload` y un array `@export` en
  `room.gd`.
- El MCP de Godot **no** edita árboles de nodos complejos: los `.tscn`/`.gd` se escriben a
  disco directamente y el MCP solo ejecuta y verifica (`run_project` + `get_debug_output`).
- Los dos `WARNING` de señales declaradas y no usadas en `game_state.gd` son esperados
  (`ability_gained` se conecta pero aún no se emite hasta el paso 7).
