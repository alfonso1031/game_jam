# SLIME ESCAPE — Arquitectura

Juego 2D cenital hecho en **Godot 4.7.1**. Un slime recién liberado escapa de un
laboratorio abandonado subiendo de nivel en nivel. Implementación del plan descrito en
[PLAN.md](PLAN.md).

> Si sos un agente de IA trabajando en este repo, leé primero [AGENTS.md](../AGENTS.md):
> tiene las reglas duras, los comandos de verificación y los errores ya cometidos.

- **Proyecto activo:** `prueba_2/`
- **Escena de arranque:** `res://ui/title.tscn` (la partida vive en `res://game/main.tscn`)
- **Prototipo aparte:** `prototypes/slime_charge_movement/` — banco de pruebas del impulso
  cargado, con sus propios tests. Ya está portado a `prueba_2` (§7), pero sigue siendo el
  lugar para iterar la sensación de movimiento sin tocar el juego.
- **Renderer:** `gl_compatibility` · **Resolución:** 1920 × 1080, pantalla completa

---

## 1. Cómo correrlo

Desde consola:

Desde la raíz del repositorio:

```bash
godot --path prueba_2
```

En Windows, con el binario fuera del `PATH`, usar la variante `_console.exe` para ver la
salida y **entrecomillar la ruta** (puede contener espacios):

```bash
"<ruta-a-godot>/Godot_v4.7.1-stable_win64_console.exe" --path prueba_2
```

O por el MCP de Godot (`@coding-solo/godot-mcp`): `run_project` + `get_debug_output`
para leer la salida de debug, `stop_project` para cerrarlo.

### Controles

| Acción | Tecla |
|---|---|
| Cargar impulso / lanzarse | mantener `WASD` / flechas y **soltar** |
| Mapa completo | `TAB` |
| Interactuar | `E` |
| Dash (tras vencer al boss) | `Shift` / `Espacio` |
| Pausa / cerrar mapa | `Esc` |
| Ventana / pantalla completa | `F11` |

---

## 2. Arquitectura y estructura de archivos

### Qué arquitectura usa Godot

Godot **no** es ECS ni MVC: es un motor de **composición de nodos**. Un nodo es a la vez
dato y comportamiento, y una escena es un árbol de nodos reutilizable como si fuera un
prefab. La "arquitectura" de un proyecto Godot son cuatro decisiones:

| Decisión | Cómo se aplica acá |
|---|---|
| **Organizar por feature, no por tipo** | Cada escena vive junto a su script (`door.tscn` + `door.gd` en la misma carpeta), en vez de árboles paralelos `scenes/` y `scripts/` |
| **Composición sobre herencia** | Un actor se arma con nodos hijos (`Area2D` de contacto, `PointLight2D`, `CollisionShape2D`) en lugar de cadenas de clases |
| **Señales hacia arriba, llamadas hacia abajo** | Un padre llama métodos de sus hijos; un hijo avisa con `signal`. El HUD nunca consulta la sala: escucha `room_changed` |
| **Estado global acotado, generación pura** | `RunManager` posee el ciclo/seed/mapa; `GameState` la vida/progreso; `Inventory` las partes; `Transition` cambia salas. `RunMap` y `MapGenerator` son `core/` puro |

La convención de carpetas es la que recomienda la propia documentación de Godot:
**agrupar por contexto del juego** (actores, mundo, ui) y no por extensión de archivo.

### Estructura

```
prueba_2/
├── project.godot            # 2D, gl_compatibility, autoloads, inputs, nombres de capas
├── assets/                  # icon.svg + audio/slime/ con los WAV procedurales
├── autoload/                # singletons registrados en project.godot
│   ├── game_state.gd        #   sala, visitadas, rejillas, habilidades, vida, F11
│   ├── inventory.gd         #   seis slots, partes, consumo y pasivas
│   ├── room_db.gd           #   catálogo de plantillas; ROOMS queda como legado
│   ├── run_manager.gd       #   seed, RunMap, recompensa de piso y resumen
│   └── transition.gd        #   fade, ensamblado y reposicionado
├── core/                    # sin dependencias del juego, lo importa todo el mundo
│   ├── palette.gd           #   colores IcyWitch (clase estática, NO autoload)
│   ├── layers.gd            #   capas de física por nombre en vez de números sueltos
│   ├── run_map.gd           #   modelo serializable de una generación
│   └── map_generator.gd     #   generación determinista + validador
├── game/                    # el ensamblaje de la partida
│   ├── main.tscn            #   partida + HUD + mapa local + ruta global + overlays
│   └── main.gd              #   inicia/reutiliza la partida y carga la entrada generada
├── actors/                  # cualquier cosa que se mueve y decide
│   ├── player/              #   slime.tscn + slime.gd
│   └── boss/                #   boss_core.tscn/gd + projectile.tscn/gd
├── world/                   # el escenario
│   ├── rooms/               #   ensamblador procedural + salas legacy
│   └── props/               #   door, elevator, lamp, tank, debris, puddle, gap, pickup
└── ui/                      # HUD, mapa/cuerpo/tooltips, ruta, pausa, título y resumen
```

Dónde va cada cosa nueva:

- ¿Se mueve y toma decisiones? → `actors/`
- ¿Es parte del escenario, con o sin colisión? → `world/props/`
- ¿Es una pantalla o un overlay? → `ui/`
- ¿Lo necesitan varios sistemas y no depende de ninguno? → `core/`
- ¿Tiene que sobrevivir al cambio de escena? → `autoload/` (y pensarlo dos veces)

### Física

Godot no tiene una capa de física que uno escriba: se configura declarando **capas** y
**máscaras**. Los nombres viven en `project.godot` (`[layer_names]`), así que se leen en el
inspector, y los números en `core/layers.gd` para no dejar constantes mágicas sueltas.

| Capa | Nombre | Quién |
|---|---|---|
| 1 | `world` | Muros, props sólidos y el jugador |
| 2 | `boss` | El boss — no empuja físicamente al jugador; su contacto lo resuelve un `Area2D` |
| 3 | `gap` | Huecos del suelo; solo se atraviesan durante el DASH |

---

## 3. Paleta IcyWitch

Centralizada en `core/palette.gd`. **No es autoload y no declara `class_name`**: es un
script de constantes que se consume siempre con

```gdscript
const Palette := preload("res://core/palette.gd")
```

`core/layers.gd` sigue exactamente la misma regla. El motivo es que el registro global de
clases de Godot vive en `.godot/`, que no se versiona: en un clon nuevo el nombre global
no existe hasta abrir el editor, y un script que dependa de él falla al arrancar. El
`preload` funciona siempre. Declarar además `class_name` no aportaba nada y provocaba el
warning `The constant "X" has the same name as a global class`.

Las subclases **no** necesitan repetir el `preload`: GDScript hereda las constantes de la
clase base, y por eso los experimentos de `actors/enemies/` acceden a `Palette` y `Layers`
a través de `enemy_base.gd`.

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

La partida activa usa `RunManager.current_map`, una instancia de `RunMap` creada por
`MapGenerator`. `RoomDB.ROOMS` se conserva solo para escenas y pruebas legacy; la
navegación nueva no lo consulta.

`MapGenerator` es determinista por `(run_seed, generation_attempt)`, prueba hasta 128
propuestas y no relaja reglas. Contrato de Contención:

- camino principal de 6–8 salas y máximo 12 contando destinos de rejilla;
- entrada/tutorial, preboss penúltimo y elección de boss al final;
- salas normales: fácil 40 %, difícil 30 %, vacía 20 %, cierre 10 %;
- cierre con exactamente tres puertas y conservación del camino al boss;
- rejilla en 60 % de combates elegibles, mínimo una si existe combate, máximo una por
  origen y destinos exclusivos;
- destino de rejilla: vacío 40 %, combate 20 %, loot 40 %.

`RunMap.canonical_snapshot()` permite comparar generaciones y reproducir bugs con la seed.
`res://tests/run_map_tests.gd` valida invariantes y distribuciones sobre 1.000 seeds.
`RoomDB.template_for()` solo traduce el conjunto de puertas a uno de los 13 fondos.

### Flujo de transición (`transition.gd`)

1. `Door`/`Elevator` detecta al jugador → `Transition.go_to(target_id, dir)`.
2. Guard `_busy`: ignora llamadas concurrentes.
3. Fade a negro (0.25 s).
4. Se libera la sala vieja y `RoomAssembler` materializa el descriptor de `RunMap`.
5. **El jugador se coloca en el `Spawn<opuesto>` ANTES de añadir la sala al árbol.**
6. `GameState.current_room` / `visited` se actualizan; si la sala tiene rejilla se emite
   `grate_discovered`, y después `room_changed`.
7. Fade in.

El jugador vive en `main.tscn`, **no** dentro de la sala — sobrevive a los cambios.

### Ciclo de partida y vida

`RunManager.start_new_run(seed)` limpia `GameState`/`Inventory`, genera Contención y
mantiene todo solo en memoria. Máximo `15 HP`, inicio `5 HP`; cada HP es medio corazón.
Completar Contención cura `+2 HP` una sola vez. Comer parte cura `+1 HP`; comer, perder o
sacrificar libera el slot.

Una rejilla cuesta una parte equipada elegida o `1 HP`, sin bandera `squeeze`. Con `1 HP`
la UI debe pedir confirmación y el jugador puede elegir morir. A cero no hay respawn:
`RunManager.end_run()` emite un resumen con zona, salas, consumidas, sacrificadas y seed.

---

## 5. Layout de sala (rejilla tipo Isaac)

| Elemento | Valor |
|---|---|
| Rejilla jugable | 13 × 7 celdas |
| Celda | 120 × 120 px |
| Interior (suelo) | 1560 × 840 px → x `180…1740`, y `120…960` |
| Muro | banda de 120 px alrededor |
| Cámara | fija por sala, centrada, `zoom = 1.0`, sin scroll |

Las puertas van centradas en cada lado, con **hueco físico real**: el muro se parte en dos
`ColorRect` + dos `CollisionShape2D` y el `Area2D` de la puerta ocupa el medio.

### Puertas en embudo

El hueco del muro mide **240 px** (2 celdas), pero las jambas de la escena de puerta lo
estrechan en diagonal hasta un paso útil de **120 px**:

```
 \                 /     ← boca de 240 px, hacia la sala
  |               |
  |               |      ← paso de 120 px
```

Entrar deja de exigir puntería: llegar torcido roza la diagonal y la **deflexión rasante**
(§7) desvía al slime hacia adentro en vez de frenarlo en seco. Sin esa deflexión el embudo
no serviría de nada — tocar la diagonal contaría como choque frontal.

Las jambas viven en `door.tscn` / `elevator.tscn`, dibujadas mirando al este, y la escena
se rota según `direction`. La geometría se escribe **una vez** y vale para las cuatro
orientaciones.

**Carriles de puerta:** la columna `x = 6` y la fila `y = 3` se dejan libres de props
sólidos para no bloquear las entradas.

---

## 6. Decoración data-driven (`room.gd`)

Cada sala declara sus props por **coordenada de celda**, no por píxel:

```gdscript
tanks = Array[Vector2i]([Vector2i(1, 1)])
debris = Array[Vector2i]([Vector2i(4, 5)])
puddles = Array[Vector2i]([Vector2i(3, 2)])
sign_text = "CELDA C-3 · BIOMATERIAL"
sign_cell = Vector2i(3, 0)
```

Las **lámparas son aparte**, porque van empotradas en el muro y no en el suelo. Se declaran
por lado y por índice de celda a lo largo de ese muro (0..12 en N/S, 0..6 en E/O):

```gdscript
lamps_n = Array[int]([3, 9])
lamps_o = Array[int]([3])
dead_lamps_s = Array[int]([6])
```

Cada sala mantiene **al menos tres lámparas activas**; las declaradas en `dead_lamps_*`
no cuentan. La luz se reparte entre paredes sin ocupar el índice central de una pared con
puerta (`6` en N/S, `3` en E/O). Para aclarar una sala se redistribuyen o agregan focos:
no se cambia la energía, el radio, el color ni el parpadeo común de `lamp.tscn`.

Puestas en el suelo se leían como objetos que se pueden recoger; empotradas en la banda de
muro se leen como instalación del laboratorio. En los muros laterales el aplique se rota
90° para quedar vertical. Al no ocupar celdas del suelo, además dejaron de competir con
tanques y escombros por el espacio.

`room.gd` los instancia en `_ready()`; `cell_center()` traduce celda → píxeles y
`wall_lamp_position()` hace lo propio con los apliques. Añadir props a una sala **no
requiere tocar el árbol de nodos** ni los `ext_resource` del `.tscn`.

| Prop | Colisión | Qué es |
|---|---|---|
| `lamp` | no | Aplique **empotrado en el muro** con `PointLight2D` cálida y parpadeo irregular por `Timer`; `dead = true` la deja apagada |
| `tank` | sí | Tanque de contención roto con biomasa derramada |
| `debris` | sí | Escombro geométrico |
| `puddle` | no | Mancha de biomasa en el suelo |
| cartel | no | `Label` en `#ecf3b0` generado desde `sign_text` |

`CanvasModulate` en `main.tscn` (nodo `Darkness`) da la oscuridad base — **un solo color
que tocar** si el juego se ve muy oscuro o muy claro.

---

## 7. El slime (`slime.gd`)

### Impulso cargado — movimiento base

El slime **no tiene piernas**: no camina, acumula energía y se lanza. Portado desde
`prototypes/slime_charge_movement/` (ver su
[DASH_DEFINITION.md](../prototypes/slime_charge_movement/docs/DASH_DEFINITION.md)).

```
IDLE ──mantener dirección──▶ CHARGING ──soltar──▶ LAUNCHING ──▶ RECOVERING ──▶ IDLE
```

1. Mantener `WASD`/flechas carga el impulso; la dirección se corrige mientras se mantiene.
2. Una barra sobre el slime muestra la potencia.
3. Al soltar **todas** las direcciones, se lanza. En vuelo no se gira ni se cancela.
4. El recorrido termina al consumir su distancia **o al chocar con una pared**.

| Constante | Valor | Significado |
|---|---:|---|
| `MAX_CHARGE_TIME` | 1.0 s | Carga completa |
| `MIN_CHARGE_TIME` | 0.12 s | **Mínimo para que haya impulso** |
| `MIN_DISTANCE` | 112 px | Distancia con carga mínima |
| `MAX_DISTANCE` | 520 px | Distancia con carga completa |
| `LAUNCH_PEAK_SPEED` | 2100 px/s | Velocidad de crucero |
| `LAUNCH_END_SPEED` | 120 px/s | Velocidad al llegar |
| `LAUNCH_START` | 0.18 | Fracción del pico con la que despega |
| `LAUNCH_RAMP` | 0.28 | Tramo del recorrido en el que acelera |
| `RECOVERY_TIME` | 0.12 s | Pausa tras un recorrido limpio |
| `WALL_RECOVERY_TIME` | 0.45 s | **Aturdimiento al chocar contra una pared** |
| `FIZZLE_RECOVERY_TIME` | 0.28 s | Penalización por soltar antes del mínimo |

`distancia = lerp(112, 520, carga / 1.0)`. Las diagonales se normalizan: no dan ventaja.

### Curva de velocidad

El recorrido **no** va a velocidad constante — eso era lo que lo hacía sentir tosco.
`_eased_speed()` reparte el tiempo con este perfil, compartido por el impulso y el DASH:

```
velocidad = fin + (pico − fin) · restante^ease         ← frenada exponencial
          · lerp(START, 1.0, smoothstep(arranque))     ← salida acelerada
```

- **Despega al 18 % del pico** y tarda el primer 28 % del recorrido en alcanzarlo: el
  arranque se siente pesado, como un cuerpo blando que se despega del suelo.
- La amplitud de la exponencial es alta a propósito (2100 → 120 px/s): entre el crucero y
  la llegada hay casi 18×, así que el frenado se nota como un frenado y no como un corte.
- `END_SPEED` es **finita a propósito**: si tendiera a cero, el recorrido se arrastraría
  sin terminar nunca.
- **La distancia no cambia**, la controla `_remaining`. Solo cambia cómo se reparte el
  tiempo, así que toda la calibración de alcance sigue valiendo.

Duración resultante del impulso cargado:

| Carga | Distancia | Duración |
|---|---:|---:|
| Mínima | 112 px | 0.14 s |
| Media | 316 px | 0.39 s |
| Completa | 520 px | 0.65 s |

El cuerpo se estira en proporción a la velocidad real (`_speed_ratio`), no a un valor fijo:
se afila al salir y se redondea solo mientras frena. Todo el suavizado visual usa
`1 − exp(−k·delta)`, así que es independiente del framerate.

**Anti-machaque.** Soltar antes de `MIN_CHARGE_TIME` no lanza nada y deja al slime
0.28 s inmóvil. El umbral es corto a propósito — castiga el machaque sin volver torpe un
toque rápido intencionado. Golpear teclas de dirección repetidamente no produce desplazamiento —
el movimiento continuo es una **habilidad futura** (piernas), no algo que se pueda
improvisar con la mecánica base. La barra dibuja una marca en el umbral mínimo y el
relleno se queda en color de muro hasta superarlo.

**Castigo por chocar.** Estrellarse contra una pared corta el recorrido en seco y cuesta
0.45 s de aturdimiento, casi cuatro veces la recuperación normal. Lanzarse a ciegas sale
caro. Aplica igual al DASH de habilidad.

**Deflexión en impactos rasantes.** No todo choque corta el recorrido. Se compara la
dirección con la normal de la superficie:

- **Frontal** (`-dir · normal >= GRAZE_DOT`, hoy `0.85`) → se corta y aturde 0.45 s.
- **Rasante** → el slime se desliza por la superficie y **el recorrido continúa en la
  dirección desviada**.

Sin esto, rozar cualquier esquina mataba el impulso y las jambas en embudo de las puertas
no servirían de nada: golpearlas contaría como choque. Aplica igual al DASH.

> El impulso cargado **no** atraviesa huecos ni da invulnerabilidad: cruzar huecos sigue
> siendo exclusivo del DASH. Un hueco golpeado de frente sigue frenando en seco.

### DASH de habilidad

Recompensa del boss, mecánica aparte: ver §9. `Shift`/`Espacio`, 0.32 s con la misma curva
(pico 2200 px/s → 300 px/s, arranque al 30 %), invulnerable, cooldown 0.8 s, atraviesa
huecos. Se lanza en la última dirección cargada y no se puede usar en pleno impulso ni en
recuperación.

> **Calibración crítica:** la integral de la curva da **382 px** de alcance. Cruzar el hueco
> de `L2_BIOLAB` exige 210 px (120 de hueco + 90 de diámetro del slime), así que el margen
> es de 172 px. Cualquier retoque de `DASH_PEAK_SPEED`, `DASH_END_SPEED`, `DASH_EASE`,
> `DASH_RAMP`, `DASH_START` o `DASH_TIME` **cambia el alcance** y puede volver el hueco
> infranqueable, dejando el juego sin final. Recalcular antes de tocarlos.

### Audio del slime

`prueba_2/assets/audio/slime/` contiene los once WAV originales generados por
`tools/audio/generate_slime_audio.py`; el mismo generador actualiza también la
copia del prototipo. Todos se sintetizan desde cero, sin samples de terceros.
`SlimeAudio` (`actors/player/slime_audio.gd`) reproduce y varía esos recursos,
pero **no** posee ni cambia el estado de movimiento: `slime.gd` decide los eventos.

| Evento de juego | Evento de `SlimeAudio` | Resultado |
|---|---|---|
| Empieza a cargar | `begin_charge()` / `update_charge(power)` | Inicia el loop y adapta tono y volumen a la barra. |
| Carga completa | `charge_full()` | Confirma el máximo una vez por carga. |
| Soltar antes del mínimo | `fizzle()` | Detiene el loop y reproduce el fallo. |
| Lanzamiento del impulso | `launch()` | Detiene el loop y alterna variaciones de lanzamiento. |
| DASH de habilidad | `dash()` | Detiene el loop y reproduce el DASH. |
| Impacto contra pared | `impact()` | Alterna variaciones de impacto. |
| Recuperación limpia | `recover()` | Alterna variaciones de recuperación. |

El loop de carga cambia de tono de `0.85` a `1.18` y de `-20` a `-8 dB` según la
potencia. Existe un recurso idle, pero permanece apagado por defecto.

### Importación reproducible de Godot

En un checkout nuevo se versionan los sidecars `.import` de los WAV y los `.uid`
de scripts; `.godot/` se ignora. Tras regenerar audio o antes de cualquier suite
de scripts, ejecutar primero el editor en modo headless para importar cada
proyecto, y solo después sus pruebas:

```powershell
& "<ruta-a-godot>/Godot_v4.7.1-stable_win64_console.exe" `
  --headless --editor --path prototypes/slime_charge_movement --quit
& "<ruta-a-godot>/Godot_v4.7.1-stable_win64_console.exe" `
  --headless --editor --path prueba_2 --quit
```

### Presentación

- **Squash & stretch procedural:** se comprime en el eje del lanzamiento mientras carga y
  retrocede como un resorte; se estira en vuelo; queda aplastado en la recuperación;
  quieto, respira con un `sin(t)`. Solo geometría, sin arte.
- Núcleo `#73efe8` con opacidad pulsante y `PointLight2D` propia → el slime es la
  fuente de luz principal.
- Las habilidades se consultan con `GameState.has_ability("dash")`, nunca se guardan en
  el propio script → sobreviven al cambio de sala.
- **El empuje va por `apply_knockback(from, force)`**, no por `velocity`: con
  `move_and_collide()` el motor ya no usa `velocity` para desplazar al cuerpo.

---

## 8. HUD y mapa

**`hud.tscn` (CanvasLayer, siempre visible)**
- Arriba-izquierda: barra de biomasa `HP actual / 15 HP`; un HP equivale a medio corazón.
- Arriba-centro: `NIVEL -3 · CONTENCIÓN` + nombre de sala.
- Arriba-derecha: minimapa de la generación activa, escalado desde el `grid`.

La vida se actualiza por `health_changed` y el mapa por `room_changed`; no sondea estado
desde `_process()`.

**`map_overlay.tscn` (TAB)**
- Pausa el juego (`PROCESS_MODE_ALWAYS` para poder cerrarse).
- Mitad izquierda: `BodyPanel` distribuye las seis partes equipadas alrededor del slime.
  Cada tarjeta y la habilidad DASH tienen una curva orgánica hasta el borde del cuerpo.
  `Inventory.slots_changed` retira de inmediato tarjeta, curva y tooltip al liberar slot.
- El hover o foco abre `PartTooltip` con nombre/descripción de `PartsDB`; sigue el cursor
  por eventos de entrada y se limita a un margen de 8 px del viewport.
- Mitad derecha: **solo el mapa local de Contención** desde
  `RunManager.current_map`. Admite cruces N/E/S/O y calcula escala/origen por los extremos
  reales del `grid`; nunca asume una lista fija.
- Muestra actual, visitadas y vecinas de visitadas. Los destinos de rejilla aparecen
  después de `GameState.discover_grate()` y usan enlace discontinuo.

**`floor_route_overlay.tscn`**
- Reacciona a `RunManager.floor_completed`; no contiene habitaciones.
- Orden visual superior→inferior: Superficie (0), Mantenimiento (-1),
  Bio-laboratorios (-2), Contención (-3).
- Contención queda al fondo y el ascenso apunta hacia arriba. Permanece `3.0 s`, pausa la
  partida y admite continuar antes con `E`, `Espacio` o `TAB`.

La base lógica es 1920×1080 con stretch `canvas_items`; la captura de regresión también se
escala a 1280×720 para comprobar clipping.

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
PERSIGUE  →  DISPARA (ráfaga radial)  →  VULNERABLE  →  [RECOIL si lo golpeás]  →  PERSIGUE …
```

- **PERSIGUE:** avanza lento hacia el jugador, coraza cerrada. Tocarlo **te hace daño**.
- **DISPARA:** se frena, se pone `#ecf3b0` y lanza una ráfaga radial de proyectiles.
- **VULNERABLE:** núcleo `#73efe8` abierto y pulsando. Tocarlo **le hace daño** y te empuja.
- **RECOIL:** tras recibir un golpe sale despedido y **no hace daño por contacto** durante
  0.9 s. Sin este estado el jugador seguía solapado con la hitbox y comía daño en el frame
  siguiente al golpe — era el bug de "le pego y igual me lastima".

3 fases según vida (4 golpes): cada fase acelera la persecución, acorta la ventana
vulnerable y suma proyectiles por ráfaga.

| Fase | Vida | Velocidad | Proyectiles | Ventana vulnerable |
|---|---|---|---|---|
| 1 | 4–3 | 45 | 6 | 3.4 s |
| 2 | 2 | 65 | 8 | 3.0 s |
| 3 | 1 | 85 | 10 | 2.6 s |

El jugador tiene **5 de vida**. Los proyectiles van a 250 px/s.

El estado se telegrafía en pantalla: barra de vida sobre el boss y cartel de estado
(`NÚCLEO SELLADO` / `¡CUIDADO!` / `¡NÚCLEO EXPUESTO — CHOCALO!`), más un cartel en la sala.

Al entrar, el boss **sella solo las salidas listadas en `sealed_directions`** (por defecto
`["N"]`, el ascensor de progresión). **La puerta de vuelta queda abierta a propósito**: si
se sellan todas y el jugador todavía no entendió la mecánica, queda encerrado sin salida.
Al morir, abre lo sellado y suelta el pickup de **DASH**. `GameState.bosses_defeated` evita
que reaparezca.

### DASH

`Shift` / `Espacio`. DASH con curva eased durante `0.32 s`: pico de `2200 px/s`, final
de `300 px/s` y alcance integrado de `382 px`; cooldown 0.8 s e invulnerable mientras
dura. Durante el dash el jugador apaga el bit 3 de su máscara → **atraviesa los huecos**.

`L2_BIOLAB` tiene un hueco vertical de una celda que parte la sala en dos: sin dash no se
llega a la esclusa. La habilidad abre progresión real, no es decorado.

### Daño y muerte

`GameState.damage()` emite `health_changed` (el HUD se redibuja) y `died` al llegar a 0.
`main.gd` escucha `died` → `RunManager.end_run(&"death")`. `run_summary.tscn` pausa y
permite iniciar una partida nueva o volver al título; nunca restaura vida ni reaparece.
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

## 11. Flujo de pantallas y pausa

```
title.tscn ──cualquier tecla──▶ main.tscn ──morir──▶ run_summary
     ▲                             │                      │
     └──────── TÍTULO ─────────────┴── pausa ─────────────┘
```

- **Título** (`ui/title.gd`): llama a `GameState.reset_run()` al entrar, así que volver al
  título siempre limpia la partida. Ignora la acción `fullscreen` para que `F11` no
  arranque el juego.
- **Pausa** (`ui/pause_menu.gd`, `Esc`): CONTINUAR / REINICIAR / TÍTULO.
- **Resumen** (`ui/run_summary.gd`): escucha `RunManager.run_ended`, muestra seed y
  decisiones de la partida, y ofrece nueva partida o título.

**Los overlays comparten `get_tree().paused`**, así que cada uno comprueba el estado antes
de abrirse: mapa, inventario, ruta, pausa y resumen no se apilan entre sí. Todos usan
`PROCESS_MODE_ALWAYS` para poder cerrarse con el juego pausado.

`F11` lo maneja `GameState._unhandled_input` — es autoload, así que funciona en todas las
escenas y también en pausa.

`Transition.setup()` resetea el guard `_busy` y el alfa del fade: al reiniciar la escena
podrían haber quedado trabados a mitad de una transición.

---

## 12. Estado del plan

| # | Paso | Estado |
|---|---|---|
| 1 | `project.godot` + paleta + autoloads | ✅ |
| 2 | `main.tscn` + slime + sala de prueba | ✅ |
| 3 | `RunMap`, generador, ensamblador y transiciones procedurales | ✅ |
| 4 | Contención: 6–8 hitos, cierres, reconexiones y rejillas | ✅ |
| 5 | HUD + overlay de mapa | ✅ |
| 6 | Ambientación: oscuridad, mínimo 3 lámparas activas por sala, props, carteles | ✅ |
| 7 | Boss 1 + pickup + DASH + hueco | ✅ |
| 8 | Ciclo de muerte sin respawn y resumen reproducible | ✅ |
| 9 | Barra 5/15, tooltips, cuerpo conectado y mapas local/global | ✅ |

**Alcance actual:** Contención procedural (nivel -3). Los niveles -2, -1 y 0 son contratos
futuros y no se simulan con salas fijas durante la partida activa.

---

## 13. Notas de mantenimiento

- **Añadir una plantilla:** registrar el fondo en `RoomDB.TEMPLATES`; el generador crea
  descriptores y `RoomAssembler` abre muros/puertas/spawns.
- **Añadir un prop:** escena en `world/props/` + `preload` y un array `@export` en
  `world/rooms/room.gd`.
- El MCP de Godot **no** edita árboles de nodos complejos: los `.tscn`/`.gd` se escriben a
  disco directamente y el MCP solo ejecuta y verifica (`run_project` + `get_debug_output`).
- `tests/ui_visual_capture.tscn` construye una cruz cardinal con seis partes y permite
  capturar `map`, `tooltip`, `route` o `hud`; el tercer argumento fija el tamaño físico
  final de la evidencia cuando el viewport lógico sigue siendo 1080p.
