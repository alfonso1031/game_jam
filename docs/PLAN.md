# PLAN — MVP "SLIME ESCAPE" (Godot 4.7.1)

> **Documento histórico.** Es el plan original con el que se arrancó y se conserva tal
> cual para poder contrastar lo planeado con lo construido. Varias cosas cambiaron por el
> camino — sobre todo la estructura de carpetas (§2) y el movimiento del slime (§5), que
> pasó a ser un impulso cargado. Para el estado real ver
> [ARQUITECTURA.md](ARQUITECTURA.md).

Juego 2D cenital. Slime recién liberado escapa de un laboratorio abandonado subiendo
de nivel en nivel. Salas grandes conectadas por puertas, mapa/HUD que indica nivel y
sala, bosses que otorgan habilidades.

---

## 0. Estado actual del repo

| Cosa | Estado |
|---|---|
| `prueba/project.godot` | Existe. Configurado para **3D** (Forward+, Jolt Physics, d3d12). |
| `run/main_scene` | Apunta a `res://scenes/world.tscn` — **el archivo no existe** (roto). |
| `prueba/scenes/`, `prueba/scripts/` | Vacías. |
| Inputs | Solo `move_left/right/up/down` (WASD + flechas). |
| Godot binario | 4.7.1 instalado ✓ |
| MCP godot | Configurado, pero con scope solo en `prueba/` |

**Decisión:** reutilizar la carpeta `prueba/` (ahí vive el scope del MCP y el proyecto ya
está inicializado). Se reescribe `project.godot` para 2D. Nada que perder: está vacío.

### MCP de Godot — RESUELTO

El servidor `godot` (`@coding-solo/godot-mcp`, con `GODOT_PATH` apuntando al binario 4.7.1)
queda registrado en **tres** scopes:

- la raíz del repositorio
- `prueba/`
- `prueba_2/`

Los scopes son por directorio exacto, no heredan. Con los tres puestos, la sesión carga el
MCP se abra donde se abra. **Las herramientas solo aparecen en sesiones nuevas** — la sesión
donde se registró el servidor no lo ve.

**Plan B sin MCP** — el proyecto se puede correr y validar igual por consola:

```bash
godot --path prueba
```

### Qué hace y qué NO hace el MCP de Godot

`@coding-solo/godot-mcp` expone: lanzar el editor, correr el proyecto, leer la salida de
debug, detenerlo, info del proyecto, crear escenas simples, añadir nodos, cargar sprites,
UIDs. **No** edita árboles de nodos complejos ni scripts.

Por eso el flujo real es híbrido:
- **Escritura de `.tscn` y `.gd`** → directo a disco (formato de texto de Godot, estable).
- **MCP** → `run_project` + `get_debug_output` para verificar que arranca sin errores, y
  `launch_editor` cuando quieras revisarlo visualmente.

---

## 1. Paleta IcyWitch — asignación semántica

| Hex | Rol en el juego |
|---|---|
| `#313638` | Vacío fuera de sala, sombras, `CanvasModulate` base (oscuridad del lab) |
| `#32535f` | Suelo del laboratorio (baldosa base) |
| `#0a777a` | Muros, tuberías, marcos de puerta, estructura |
| `#4aa881` | **Cuerpo del slime**, biomasa, tanques de contención |
| `#73efe8` | Brillo/energía: núcleo del slime, luces frías, puertas abiertas, highlights |
| `#ecf3b0` | Luz cálida de lámparas, texto de UI, iconos de habilidad, alertas |

Se centraliza en `scripts/core/palette.gd` (clase estática) para que ningún color quede
hardcodeado en escenas.

---

## 2. Arquitectura de archivos

```
prueba/
├── project.godot                    # reescrito: 2D, inputs, autoloads, ventana
├── scenes/
│   ├── main.tscn                    # raíz: RoomHost + Player + HUD + FadeLayer
│   ├── player/slime.tscn
│   ├── rooms/
│   │   ├── room_base.tscn           # plantilla: suelo, muros, marcadores de puerta
│   │   ├── l3_celda.tscn            # Nivel -3 · Celda de Contención (inicio)
│   │   ├── l3_pasillo.tscn
│   │   ├── l3_almacen.tscn
│   │   ├── l3_nucleo.tscn           # sala de BOSS 1
│   │   ├── l2_ascensor.tscn
│   │   ├── l2_biolab.tscn
│   │   └── l2_esclusa.tscn          # salida provisional (fin del MVP)
│   ├── props/
│   │   ├── door.tscn                # Area2D + marcador de spawn
│   │   ├── elevator.tscn            # puerta especial que cambia de nivel
│   │   ├── ability_pickup.tscn
│   │   └── lamp.tscn                # PointLight2D parpadeante
│   ├── boss/boss_core.tscn          # BOSS 1 "Núcleo de Contención"
│   └── ui/
│       ├── hud.tscn                 # nivel + nombre de sala + habilidades
│       └── map_overlay.tscn         # mapa completo (TAB)
└── scripts/
    ├── core/palette.gd              # constantes de color IcyWitch
    ├── autoload/game_state.gd       # AUTOLOAD: sala actual, nivel, visitadas, habilidades
    ├── autoload/room_db.gd          # AUTOLOAD: grafo de salas (data-driven)
    ├── autoload/transition.gd       # AUTOLOAD: fade + carga/descarga de salas
    ├── player/slime.gd
    ├── rooms/room.gd
    ├── props/door.gd, elevator.gd, ability_pickup.gd, lamp.gd
    ├── boss/boss_core.gd
    └── ui/hud.gd, map_overlay.gd
```

**Sin assets de arte.** Todo se dibuja con `Polygon2D`, `ColorRect`, `_draw()` y
`GradientTexture2D` generadas en el `.tscn`. Cero PNGs que producir → MVP en tiempo de jam.

---

## 3. Sistema de salas — data-driven (pieza central)

El grafo de salas vive en **un solo diccionario** en `room_db.gd`. Añadir una sala = añadir
una entrada + un `.tscn`. Nada de cablear transiciones a mano.

```gdscript
# scripts/autoload/room_db.gd
const ROOMS := {
    "L3_CELDA": {
        "level": -3,
        "level_name": "CONTENCIÓN",
        "room_name": "Celda de Contención",
        "grid": Vector2i(0, 0),                 # posición en el minimapa de ese nivel
        "scene": "res://scenes/rooms/l3_celda.tscn",
        "doors": { "E": "L3_PASILLO" },
    },
    "L3_PASILLO": {
        "level": -3, "level_name": "CONTENCIÓN",
        "room_name": "Pasillo de Servicio",
        "grid": Vector2i(1, 0),
        "scene": "res://scenes/rooms/l3_pasillo.tscn",
        "doors": { "W": "L3_CELDA", "N": "L3_ALMACEN", "E": "L3_NUCLEO" },
    },
    # ... etc
}
```

Reglas:
- Direcciones: `"N" | "S" | "E" | "O"` (opuestos: N↔S, E↔O).
- Cada `.tscn` de sala tiene `Marker2D` nombrados `SpawnN`, `SpawnS`, `SpawnE`, `SpawnO`.
- Consistencia validada al arrancar: si `A.doors.E == B` entonces `B.doors.O` debe ser `A`.
  Si no, `push_error` con el ID — atrapa errores de datos antes de jugar.

### Flujo de transición

1. Slime toca el `Area2D` de una `Door` con dirección `E`.
2. `Door` emite → `Transition.go_to(target_id, "E")`.
3. Fade a `#313638` (0.25 s) sobre un `CanvasLayer`.
4. Se libera la sala actual (`queue_free`), se instancia la nueva bajo `RoomHost`.
5. El jugador se coloca en el `Marker2D` **opuesto** (`SpawnO`), con un pequeño empuje hacia adentro.
6. `Camera2D.limit_*` se recalcula con los límites de la nueva sala.
7. `GameState.current_room = target_id`, `visited[target_id] = true`.
8. Se emite `room_changed` → HUD y minimapa se actualizan solos.
9. Fade in.

Ventaja: una sola sala en memoria a la vez, y el HUD nunca se desincroniza porque escucha
la señal en lugar de consultar en `_process`.

---

## 4. Salas grandes + cámara

- **Resolución base: 1920 × 1080** (Full HD), a pantalla completa. Viewport lógico 1080p con
  `canvas_items` + `aspect = expand` → nítido en cualquier pantalla sin tocar nada.
- Tamaño de sala: **una pantalla exacta, sin scroll** — layout tipo *The Binding of Isaac*
  (referencia dada por el usuario).
- `Camera2D` **fija por sala**, centrada, `zoom = 1.0`. No sigue al jugador. Se elimina todo
  el cálculo de `limit_*` y el smoothing: se coloca al cargar la sala y no se toca más.

### Layout exacto de la sala (rejilla tipo Isaac)

| Elemento | Valor |
|---|---|
| Rejilla jugable | **13 × 7 celdas** |
| Celda | **120 × 120 px** |
| Interior (suelo) | **1560 × 840 px**, centrado → x `180…1740`, y `120…960` |
| Grosor del muro | **120 px**, dibujado hacia afuera del interior |
| Huella exterior | 1800 × 1080 px dentro de la pantalla de 1920 × 1080 |
| Vacío visible | banda de `#313638` en los bordes, donde se apoya el HUD |

- **Marco de muro** (`#0a777a` con borde interior más oscuro `#313638`): banda continua de
  120 px alrededor del suelo. Detallado con paneles, remaches y tuberías dibujados con
  `Polygon2D` — es lo que da el aire de "sala industrial cerrada" de la referencia.
- **Suelo** `#32535f` con baldosas de 120 px insinuadas por líneas de baja opacidad, más
  manchas y grietas sueltas.
- **Puertas: una por lado como máximo**, centrada en el muro (celda central de cada lado),
  **1 celda de ancho = 120 px**, metida como hueco/alcoba en la banda del muro.
  - Cerrada → placa `#0a777a` oscura con barras.
  - Abierta → hueco con brillo `#73efe8`.
  - Sellada por boss → placa con luz de alerta `#ecf3b0` parpadeante.
- **Props alineados a la rejilla** (rocas, tanques rotos, escombros, charcos de biomasa):
  ocupan celdas enteras y se colocan por coordenada de celda, no por píxel. Es lo que hace
  que la sala se lea ordenada como en la referencia en vez de un revoltijo.
- Las **celdas del borde** de la rejilla se dejan libres de props frente a cada puerta, para
  no bloquear la entrada.
- **Escala del slime: ~90 px de diámetro** (3/4 de celda) → cabe holgado por los pasillos de
  una celda y la sala se lee grande a su lado.
- Límites por sala: `room.gd` expone `bounds: Rect2` y `Transition` los aplica a la cámara →
  la cámara nunca muestra el vacío fuera de la sala.
- Muros: `StaticBody2D` con `CollisionShape2D` rectangulares en el perímetro + obstáculos
  internos (tanques, mesas, escombros) para que la sala grande no se sienta vacía.

---

## 5. El slime

`CharacterBody2D` con `slime.gd`:

- Movimiento 8 direcciones con `move_and_slide()`, `SPEED = 220`, aceleración/fricción
  suaves (`lerp`) → sensación viscosa, no de tanque.
- **Squash & stretch procedural**: el cuerpo es un `Polygon2D` circular; su `scale` se
  deforma según la velocidad (se estira en la dirección del movimiento) y rebota con un
  `sin(time)` de respiración cuando está quieto. Esto es lo que lo hace *leer* como slime
  sin una sola línea de arte.
- Cuerpo `#4aa881`, núcleo interior `#73efe8` con opacidad pulsante.
- `PointLight2D` hijo con `GradientTexture2D` radial en `#73efe8`, energía baja → el slime
  se ilumina a sí mismo y al suelo alrededor. Es la fuente de luz principal del juego.
- Rastro: `GPUParticles2D` de gotas que quedan atrás (barato, vende el personaje).
- Habilidades se consultan vía `GameState.has_ability("dash")` — el script no guarda estado
  propio, así sobrevive a los cambios de sala.

---

## 6. HUD y mapa (requisito explícito del MVP)

### HUD permanente (`hud.tscn`)

Va en un `CanvasLayer` **por encima de la sala**, apoyado en la banda exterior y solapando
el marco de muro — igual que en la referencia. No consume espacio del área jugable.

- **Arriba-izquierda:** vida del slime, como gotas/núcleos en `#4aa881` (llenas) y contorno
  `#313638` (vacías).
- **Arriba-centro, sobre el muro superior:** `NIVEL -3 · CONTENCIÓN` y debajo, más pequeño,
  `Celda de Contención`. Texto `#ecf3b0`. Es el requisito de "que diga en qué nivel y sala está".
- **Arriba-derecha:** **minimapa del nivel actual** — misma posición que la referencia.
  Cuadrícula dibujada con `_draw()` desde los `grid` del `RoomDB`.
- **Columna izquierda:** slots de habilidad, apilados. Vacío = contorno `#0a777a`;
  obtenida = relleno `#73efe8` con nombre.
- Tamaños para 1080p: nivel 40 px, nombre de sala 26 px, etiquetas 20 px. Con `canvas_items`
  el HUD escala solo — no hay que duplicar layouts.

### Overlay de mapa completo (TAB)
- Pausa el juego (`get_tree().paused = true`, HUD en `PROCESS_MODE_ALWAYS`).
- Muestra **los niveles apilados verticalmente**, de abajo (-3) hacia arriba (0), reforzando
  visualmente el objetivo "subir para salir".
- Por sala: no visitada = solo contorno tenue `#32535f`; visitada = relleno `#0a777a`;
  actual = `#73efe8` con pulso; sala de boss = marca `#ecf3b0`.
- Líneas entre salas conectadas; icono de ascensor donde se cambia de nivel.
- Leyenda + objetivo: `OBJETIVO: LLEGAR A SUPERFICIE (NIVEL 0)`.

Todo el mapa se dibuja desde `RoomDB` + `GameState.visited` → **cero mantenimiento manual**
cuando se añadan salas después de la jam.

---

## 7. Ambientación: laboratorio abandonado

Barato en tiempo, alto en impacto:

- `CanvasModulate` global en `#313638` → oscuridad base; todo se ve por luces.
- Lámparas (`lamp.tscn`): `PointLight2D` en `#ecf3b0` con parpadeo por `Timer` aleatorio.
  Algunas muertas (apagadas) → sensación de abandono.
- Luces de emergencia en `#0a777a` en pasillos.
- Props geométricos: tanques de contención rotos (`#4aa881` derramándose), mesas volcadas,
  paneles rotos, charcos de biomasa.
- Grietas y manchas en el suelo con `Polygon2D` de baja opacidad.
- Carteles de texto por sala (`Label` en `#ecf3b0`, tipo estarcido): `SECTOR C-3`,
  `PELIGRO — BIOMATERIAL`, `SALIDA ↑`. Narración ambiental sin cinemáticas.
- Sin audio en el MVP (se deja el `AudioStreamPlayer` cableado y mudo, listo para pegar
  sonidos después).

---

## 8. Boss y habilidades

Sistema de habilidades: `GameState.abilities: Dictionary`, señal `ability_gained(id)`.

**MVP incluye 1 boss funcional** (`L3_NUCLEO`, "Núcleo de Contención"):
- `CharacterBody2D` estático-ish que persigue lento al jugador y dispara proyectiles
  radiales en ráfagas cada 2 s. 3 fases por vida (más rápido conforme baja).
- Puertas de la sala se sellan al entrar (`#0a777a` → rojo/oscuro) y se abren al morir.
- Al morir suelta `ability_pickup.tscn` → **DASH** (`Shift`): impulso corto, invulnerable
  durante el desplazamiento, cooldown 0.8 s. Se usa para cruzar un hueco en `L2_BIOLAB`
  → la habilidad abre progresión real, no es solo decorado.

**Boss 2 queda como stub estructurado** (escena + entrada en el RoomDB, sin IA) para que
después de la jam sea rellenar, no rediseñar.

---

## 9. Niveles del MVP

| Nivel | Nombre | Salas | Contenido |
|---|---|---|---|
| **-3** | CONTENCIÓN | Celda (inicio) · Pasillo · Almacén · **Núcleo (BOSS 1)** | Tutorial de movimiento, primera puerta, boss → DASH |
| **-2** | BIO-LABORATORIOS | Ascensor · Biolab · Esclusa | Requiere DASH para cruzar; Esclusa = fin del MVP con cartel "CONTINUARÁ" |

Total: **7 salas, 2 niveles, 1 boss, 1 habilidad**. Alcance realista de jam, y la estructura
soporta añadir el nivel -1 y el 0 sin tocar código — solo datos y `.tscn`.

---

## 10. Configuración de `project.godot` (reescritura)

- Quitar: `3d/physics_engine="Jolt Physics"` (irrelevante en 2D).
- Ventana: `viewport_width=1920`, `viewport_height=1080`, `stretch/mode="canvas_items"`,
  `stretch/aspect="expand"`, `window/size/mode=3` (pantalla completa). Sin overrides de
  desarrollo — el juego ocupa la pantalla entera. `F11` alterna a ventana.
- `run/main_scene = "res://scenes/main.tscn"` (arregla el enlace roto actual).
- Renderer: `gl_compatibility` en lugar de Forward+ — arranca más rápido, menos superficie
  de fallo con drivers, y en 2D no se pierde nada.
- Autoloads: `Palette`, `GameState`, `RoomDB`, `Transition`.
- Inputs nuevos, además de los WASD existentes:
  - `interact` → `E`
  - `map` → `TAB`
  - `dash` → `Shift` / `Space`
  - `pause` → `Esc`
  - `fullscreen` → `F11`

---

## 11. Orden de ejecución

| # | Paso | Verificación |
|---|---|---|
| 1 | Reescribir `project.godot` + `palette.gd` + autoloads vacíos | El proyecto abre sin errores |
| 2 | `main.tscn` + `slime.tscn` + una sala de prueba | El slime se mueve, cámara sigue, squash visible |
| 3 | `room.gd`, `door.tscn`, `transition.gd`, `room_db.gd` con 2 salas | Ir y volver entre 2 salas sin perder al jugador |
| 4 | Las 7 salas + ascensor + validador del grafo | Recorrer el mapa completo a pie |
| 5 | `hud.tscn` + `map_overlay.tscn` | Nivel/sala correctos siempre; TAB abre el mapa; visitadas se marcan |
| 6 | Ambientación: `CanvasModulate`, lámparas, props, carteles | Se ve a laboratorio abandonado |
| 7 | Boss 1 + pickup + DASH + puerta con hueco | Boss muere → DASH → progresión a nivel -2 |
| 8 | Pulido: fade, pausa, pantalla de título mínima, "CONTINUARÁ" | Partida completa de principio a fin |

**Verificación en cada paso:** `run_project` + `get_debug_output` por MCP (o el comando de
consola del apartado 0). Ningún paso se da por bueno sin arranque limpio.

---

## 12. Riesgos y decisiones tomadas

| Riesgo | Mitigación |
|---|---|
| MCP de Godot no cargado | Resuelto: registrado en los 3 scopes (§0). Requiere sesión nueva |
| El MCP no escribe árboles de nodos complejos | Los `.tscn`/`.gd` se escriben a disco directamente; el MCP solo ejecuta y verifica |
| Salas grandes se sienten vacías | Obstáculos internos + carteles + luces desiguales; densidad de props revisada por sala |
| Alcance de jam se desborda | Boss 2 nace como stub; audio pospuesto; cero pipeline de arte |
| Cambios de sala pierden el estado del jugador | El jugador vive en `main.tscn`, **no** dentro de la sala; solo se recarga la sala |
| Rutas con espacio (`Game Jam`) rompen comandos | Todas las rutas siempre entre comillas |

---

## 13. Definición de "listo" para el MVP

- [ ] El slime se mueve en 8 direcciones con deformación viscosa y se autoilumina
- [ ] 7 salas grandes recorribles por puertas, en 2 niveles, con ascensor entre ellos
- [ ] El HUD muestra nivel y sala en todo momento y se actualiza al cruzar cada puerta
- [ ] TAB abre un mapa con niveles apilados, salas visitadas y posición actual
- [ ] Estética completa en paleta IcyWitch, con oscuridad y luces de lab abandonado
- [ ] Boss 1 derrotable → otorga DASH → el DASH desbloquea el paso al nivel -2
- [ ] El proyecto arranca sin errores en la salida de debug
