# SLIME ESCAPE — Arquitectura

Juego 2D cenital hecho en **Godot 4.7.1**. Un slime recién liberado escapa de un
laboratorio abandonado subiendo de nivel en nivel.

> Si sos un agente de IA trabajando en este repo, leé primero [AGENTS.md](../AGENTS.md):
> tiene las reglas duras y el flujo de verificación. El contrato jugable consolidado,
> sin decisiones históricas solapadas, está en
> [agents/ESTADO_ACTUAL.md](agents/ESTADO_ACTUAL.md).

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
| Seleccionar parte (con `TAB` abierto) | `WASD` / flechas |
| Comer parte seleccionada (con `TAB` abierto) | `F` |
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

- grafo dirigido acíclico con camino principal de 6–8 hitos, bifurcación posterior al
  cuerpo y reconvergencia obligatoria;
- entrada/tutorial, cuerpo con primera parte en la segunda sala, preboss penúltimo y
  elección de boss al final;
- salas normales: fácil 50 %, difícil 30 %, vacía 20 %;
- `doors` guarda únicamente salidas y `entrances` las aberturas selladas ya consumidas;
- toda sala distinta del jefe tiene un camino futuro al jefe, que es el único sumidero;
- toda sala normal de combate y el preboss tienen una rejilla irreversible;
- destino de rejilla: vacío 40 %, combate 20 %, loot 40 %.

`RunMap.canonical_snapshot()` permite comparar generaciones y reproducir bugs con la seed.
`res://tests/run_map_tests.gd` valida invariantes y distribuciones sobre 1.000 seeds.
`core/room_backgrounds.gd` es el catálogo canónico de las 16 configuraciones cardinales:
sin puertas normales, 1, 2, 3 o 4 puertas. Las esquinas `NE` y `SO` espejan
horizontalmente los PNG `NO` y `ES`; el destino exclusivo de rejilla reserva una abertura
visual sin crear una puerta normal. `RoomDB.template_for()` solo conserva la fachada para
el ensamblador. `MapGenerator.validate()` rechaza cualquier descriptor sin plantilla antes
de que `Transition` pueda materializarlo.

### Primer hito: cuerpo y parte

`main_path[0]` siempre es `entry/tutorial`; `main_path[1]` siempre es
`body/body_reward`, conecta directamente con la entrada, tiene una entrada sellada, una
salida y no puede alojar rejilla. `MapGenerator` selecciona una parte inicial
desde `FIRST_PART_POOL` y la guarda en `reward_part_id`.

`ProceduralRoom` consulta las conexiones reales del descriptor, no IDs ni orientaciones
fijas:

- en la entrada, `BloodTrail` va del centro hacia la puerta que conduce al cuerpo;
- en la segunda sala, continúa desde la entrada sellada hasta `BODY_POSITION`, añade
  charco vectorial e instancia `BodySource` sin mostrar un cadáver humano provisional;
- salas normales no reciben cuerpo ni sangre narrativa.

`BodySource` crea un único `PartPickup`. La sala se marca en
`GameState.claimed_room_rewards` solo al recogerlo: salir antes conserva la recompensa,
volver después no la duplica y `reset_run()` la libera para la siguiente partida. Gotas,
arrastre y charco son PNG transparentes de estilo 2D plano; ninguno tiene colisión.

Las salas de Contención también reciben utilería desde
`core/containment_prop_catalog.gd`: la receta es determinista por ID de sala y
`ProceduralRoom` solo instancia las escenas elegidas. `cabinet`, `pipe` y `glass_tube`
son props reutilizables con colisión limitada a su base; la entrada conserva el
`broken_glass_tube` narrativo. El catálogo no coloca props sólidos en la fila 3 ni la
columna 6.

### Enemigos de Contención

Las salas normales seleccionan de forma determinista y con el mismo peso entre
`exp01`, `exp02`, `exp03` y `exp07`: cada tipo ocupa una de las cuatro posiciones del
pool (25 %). El preboss genera tres enemigos por defecto; sus dos acompañantes proceden
solo de `exp01`–`exp03` y el último enemigo siempre es un `exp07` marcado como líder.
Como `exp07` solo declara `crusher_claw` en `drop_parts`, derrotar al líder garantiza
la Tenaza Trituradora. El Crustáceo Triturador no tiene escudo ni bloquea ataques:
recibe daño desde cualquier dirección. Si el slime invade su espacio de 105 px, retrocede
en vez de quedar superpuesto o arrastrarlo.

**Caída del botín.** Lo que sueltan los experimentos y el boss no aparece armado: el
pickup nace inerte y `start_drop()` reproduce un salto corto —el brillo sube, cae, se
aplasta al aterrizar y el nombre entra en fundido— antes de volverse recogible, unos
`0,85 s` en total. La demora existe para que el jugador vea qué soltó: sin ella el slime
absorbe la parte en el mismo frame de la muerte, muchas veces sin enterarse. El pickup
**no** se desplaza durante la animación, solo su brillo, para no aterrizar dentro de un
muro. Los pickups colocados a mano (`BodySource`, salas loot) nacen armados y no llaman
`start_drop()`.

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
mantiene todo solo en memoria. Máximo `15 HP`, inicio `7 HP`; cada HP es medio corazón.
Completar Contención cura `+2 HP` una sola vez. Comer parte cura `+2 HP`; comer, perder o
sacrificar libera el slot.

Una conexión de rejilla queda modelada en ambos extremos: `grate_target` desde la sala de
origen y `grate_source` como metadato de llegada. La entrada cuesta una parte equipada
elegida o `1 HP`, sin bandera `squeeze`; al pagar,
`GameState.unlock_grate(source_id)` persiste solo durante la partida. El destino crea
`GrateSpawn`, pero no instancia otra rejilla: no existe retorno. Con `1 HP` la UI debe
pedir confirmación y el jugador puede elegir morir. A cero no hay respawn:
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

La rejilla no ocupa una celda de prop. `grate_direction` elige una pared sin abertura:
`Grate` usa `DOOR_POSITIONS[direction]`; el destino usa `grate_arrival_direction` para
ubicar un único `GrateSpawn`. El PNG conserva su aspecto dentro de `120 × 120`, recibe
un halo cian tenue y no existe sensor de regreso. `grate.tscn` es un `Area2D` con prompt;
abre el selector solo en el origen todavía bloqueado y
`Transition.go_via_grate()` conserva el mismo fundido de una puerta.

La textura permanece centrada en el muro, pero el `CollisionShape2D` de interacción se
desplaza `105 px` hacia el interior según la pared. El muro no pierde colisión; el sensor
alcanza `GrateSpawn` y permite mostrar el prompt sin exigir que el jugador atraviese una
pared sólida.

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
no se cambia la energía, el color ni el parpadeo común de `lamp.tscn`. La cobertura global
usa `texture_scale = 1.85` con energía `1.6`.

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

`CanvasModulate` en `main.tscn` (nodo `Darkness`) da la penumbra base con
`Color(0.32, 0.35, 0.37, 1)`: toda la sala permanece legible sin parecer
iluminada de día. Es **el único color que tocar** si el ambiente general se ve
muy oscuro o muy claro. Las lámparas se mantienen aparte a energía `1.6`,
`texture_scale = 1.85`, con su parpadeo y estado fundido.

---

## 7. El slime (`slime.gd`)

### Movimiento base según las piernas

`slime.gd` deriva el modo desde las partes equipadas; no guarda una habilidad paralela.
`Inventory.equipped_count_for_slot(PartsDB.SLOT_PIERNA)` permite además diferenciar en el
futuro reglas para una o dos piernas.

| Piernas equipadas | Movimiento |
|---:|---|
| 0 | Impulso cargado |
| 1 o más | Movimiento continuo a `280 px/s` |

El tipo lo decide el catálogo, no el nombre: **cualquier** parte con `"slot": SLOT_PIERNA`
enciende el movimiento continuo. Por eso el catálogo y el nombre visible tienen que decir
lo mismo — la parte de EXP-03 se llama **Pierna Escamada** justamente porque su `slot` es
`pierna`. Bautizarla "Piel" mientras contaba como pierna hacía que equiparla pareciera
regalar las Patas Hidráulicas.

Sin piernas, el slime no camina: acumula energía y se lanza. Este modo fue portado desde
`prototypes/slime_charge_movement/` (ver
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
| `CRAWL_SPEED` | 480 px/s | Velocidad uniforme del arrastre base |
| `RECOVERY_TIME` | 0.12 s | Pausa tras un recorrido limpio |
| `WALL_RECOVERY_TIME` | 0.45 s | **Aturdimiento al chocar contra una pared** |
| `FIZZLE_RECOVERY_TIME` | 0.28 s | Penalización por soltar antes del mínimo |

La barra y el audio usan la carga total `carga / 1.0`; la distancia empieza a contar
después del umbral válido:

```
potencia_recorrido = clamp((carga − 0.12) / (1.0 − 0.12), 0, 1)
distancia = lerp(112, 520, potencia_recorrido)
```

Las diagonales se normalizan: no dan ventaja.

### Arrastre uniforme

El tramo `LAUNCHING` usa `_remaining` como autoridad y avanza a `480 px/s` multiplicados
por buffs/estados. Cargar más aumenta la **duración y distancia**, no crea un pico de
velocidad. El último frame se recorta a la distancia pendiente para terminar exactamente
en 112–520 px.

Duración resultante del impulso cargado:

| Carga | Distancia | Duración |
|---|---:|---:|
| Mínima válida | 112 px | 0.23 s |
| Media del rango válido | 316 px | 0.66 s |
| Completa | 520 px | 1.08 s |

La carga deforma el frente de los `Polygon2D` y el arrastre recorre una onda longitudinal
corta. Es presentación pura: `CharacterBody2D` no se desplaza mientras carga y su única
colisión sigue siendo el círculo de radio `45`. Al volver a reposo, cada punto interpola
hacia su polígono base. El DASH conserva aparte su escala rápida y `_eased_speed()`.

**Anti-machaque sin piernas.** Soltar antes de `MIN_CHARGE_TIME` no lanza nada y deja al slime
0.28 s inmóvil. El umbral es corto a propósito — castiga el machaque sin volver torpe un
toque rápido intencionado. Golpear teclas de dirección repetidamente no produce desplazamiento —
no se puede improvisar el movimiento continuo con la mecánica base. Al equipar cualquier
parte de tipo `pierna`, la carga y su barra desaparecen y `WASD`/flechas desplazan al
slime directamente. Consumir o perder la última pierna restaura la carga. La barra dibuja
una marca en el umbral mínimo y el relleno se queda en color de muro hasta superarlo.

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

Recompensa del boss, mecánica aparte: ver §9. `Shift`/`Espacio`, 0.32 s con su curva
(pico 2200 px/s → 300 px/s, arranque al 30 %), invulnerable, cooldown 0.8 s, atraviesa
huecos. Se lanza en la última dirección cargada y no se puede usar en pleno impulso ni en
recuperación.

> **Calibración crítica:** la integral de la curva da **382 px** de alcance. Cruzar el hueco
> de `L2_BIOLAB` exige 210 px (120 de hueco + 90 de diámetro del slime), así que el margen
> es de 172 px. Cualquier retoque de `DASH_PEAK_SPEED`, `DASH_END_SPEED`, `DASH_EASE`,
> `DASH_RAMP`, `DASH_START` o `DASH_TIME` **cambia el alcance** y puede volver el hueco
> infranqueable, dejando el juego sin final. Recalcular antes de tocarlos.

### Costra de la Pierna Escamada

El escudo de `EFFECT_BUFF` con `flags: {"shield": 1}` no tenía ninguna presentación: se
ponía y se gastaba sin señal, así que la parte se sentía pasiva aunque se activa con su
tecla numérica. `ScaleShell` es un `Line2D` cerrado y dentado que cuelga de la raíz del
slime, **no** de `Body`: no lo deforma el arrastre ni lo gira la mira, y por eso se lee
como una costra rígida encima y no como parte del cuerpo.

- Al activarla, la costra nace de fuera hacia dentro (`SHELL_POP_TIME`) y late mientras
  aguanta.
- Al comerse el golpe se abre hacia fuera y se apaga en `SHELL_FLASH_TIME`.
- El escudo sigue gastándose con el golpe, no con el reloj: si el buff caduca antes de
  recibir daño, la costra permanece.

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

### Música de pantallas

La música no vive en `SlimeAudio`: cada pantalla posee su propio
`AudioStreamPlayer` llamado `Music`.

| Pantalla | Recurso runtime | Volumen |
|---|---|---:|
| Portada | `assets/audio/music/main_menu.ogg` | `-10 dB` |
| Partida | `assets/audio/music/containment_ambience.ogg` | `-13 dB` |

Los `.opus` recibidos se conservan en `assets/audio/music/source/`; Ogg Vorbis es el
formato runtime que Godot importa de forma reproducible. `finished` vuelve a llamar
`play()`, y el cambio de escena libera el reproductor anterior antes de iniciar el nuevo.

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

- **Deformación peristáltica:** durante la carga se estira solo el frente; durante el
  arrastre una onda longitudinal recorre el mismo cuerpo. Los puntos regresan al polígono
  base en reposo y nunca gobiernan la colisión.
- Núcleo `#73efe8` con opacidad pulsante y `PointLight2D` propia → el slime es la
  fuente de luz principal.
- Las habilidades se consultan con `GameState.has_ability("dash")`, nunca se guardan en
  el propio script → sobreviven al cambio de sala.
- **El empuje va por `apply_knockback(from, force)`**, no por `velocity`: con
  `move_and_collide()` el motor ya no usa `velocity` para desplazar al cuerpo.

---

### Ataque ilustrado del EXP07

`actors/enemies/exp07_crustacean_frames.tres` separa el avance del ataque. Las
cinco fuentes de `assets/enemies/exp07_crustacean/source_attack/` conservan los
lienzos transparentes de 1920 × 1080; `tools/art/process_exp07_claw_frames.gd`
usa un recorte común y produce los cinco PNG runtime de 192 × 108.

`PINCH_WINDUP` dura 0,8 s y reproduce 00→04 a 6,25 FPS. Al vencer el
temporizador, `_pinch()` aplica una sola vez el cono de 150 px, 50° y su
retroceso; después `RECOVER` reproduce 04→00 a 8,333333 FPS durante 0,6 s. El
sprite nunca aplica daño por señales y esta secuencia no pertenece al slime.

### Arte animado de los enemigos de Contención

Ningún enemigo del piso usa ya `Polygon2D` como cuerpo final. El flujo, de
izquierda a derecha, es siempre el mismo:

```
máquina de estados → _visual_state() → AnimatedSprite2D → SpriteFrames
```

- El **arte crudo vive fuera de `prueba_2/`**, en
  `art_raw/enemigos/containment/<personaje>/source_sheet.png`: cuatro hojas 3 × 2
  con fondo croma `#ff00ff` y las seis poses en orden fijo.
- Las **poses de runtime** viven en `assets/enemies/exp0{1,2,3}_*/` y
  `assets/bosses/containment_chimera/animations/`, ya con alfa y centradas.
- El **`SpriteFrames` vive junto al actor**: `actors/enemies/*_frames.tres` y
  `actors/boss/boss_core_frames.tres`.
- El **daño y los tiempos siguen en los scripts de IA.** Ningún fotograma
  dispara un ataque; las animaciones solo tienen que terminar antes que el
  temporizador que lo aplica.

Dos herramientas reproducen el pipeline entero:

| Herramienta | Qué hace |
|---|---|
| `tools/art/gen_containment_enemy_sheets.gd` | Compone las cuatro hojas fuente con formas orgánicas y las escribe en `art_raw/` |
| `tools/art/process_containment_enemy_sheets.gd` | Quita el croma, separa las seis poses con **un recorte común** y las centra en el lienzo de runtime |

El recorte común es lo que conserva la escala y el punto de apoyo entre poses:
ajustar cada una por separado haría que la embestida estirada y la pose encogida
salieran del mismo tamaño. Es el mismo criterio de
`process_exp07_claw_frames.gd`.

`enemy_base.gd` se sigue encargando del volteo horizontal, el destello de daño y
los estados alterados, y cae al `autoplay` si `_visual_state()` pide un nombre
que el `SpriteFrames` no trae. `tests/check_enemy_animations.tscn` recorre el
enum `State` de cada experimento y falla si algún estado pide una animación que
no existe.

| Experimento | Locomoción | Aviso | Resto |
|---|---|---|---|
| EXP01 | `approach` 6 FPS | `windup` 3,076923 FPS = 0,65 s | `charge`, `rest` |
| EXP02 | `reposition` 4 FPS | `shoot_windup` 2,666667 FPS = 0,75 s · `slam_windup` 2,222222 FPS = 0,9 s | `recover` |
| EXP03 | `walk` 5 FPS | `tail_windup` 6 FPS = 0,5 s | `recover` 3,636364 FPS = 0,55 s |
| EXP07 | `advance` 6 FPS | `pinch_windup` 6,25 FPS = 0,8 s | `recover` 8,333333 FPS = 0,6 s |

Cada velocidad de aviso está calculada para que la última pose coincida con la
llamada que aplica el ataque. **Si cambia el tiempo del estado, hay que
recalcular la velocidad del `SpriteFrames`.**

## 8. HUD y mapa

**`hud.tscn` (CanvasLayer, siempre visible)**
- Arriba-izquierda: bloque `BIOMASA` y barra `HP actual / 15 HP`; un HP equivale a medio
  corazón.
- Arriba-derecha: minimapa de la generación activa, escalado desde el `grid`.

La vida se actualiza por `health_changed` y el mapa por `room_changed`; no sondea estado
desde `_process()`.

**`map_overlay.tscn` (TAB)**
- Pausa el juego (`PROCESS_MODE_ALWAYS` para poder cerrarse).
- Mitad izquierda: `BodyPanel` distribuye las seis partes equipadas alrededor del slime.
  Cada tarjeta y la habilidad DASH tienen una curva orgánica hasta el borde del cuerpo.
  `Inventory.slots_changed` retira de inmediato tarjeta, curva y tooltip al liberar slot.
- Al abrirlo selecciona la primera parte equipada. Las flechas navegan espacialmente
  entre tarjetas ocupadas y `F` consume la seleccionada para curar `2 HP`. La interfaz no
  anuncia la cantidad antes de comer. La
  tarjeta activa se amplía, ilumina su borde y resalta su conexión al slime.
- El botón `MODO PRUEBA · VIDA INFINITA` se alterna con clic o `V` mientras TAB está
  abierto. Persiste entre salas de la run, pero una partida nueva lo apaga. Solo bloquea
  la pérdida de HP: destello, invulnerabilidad temporal y retroceso siguen ocurriendo.
- El hover abre `PartTooltip` con nombre/descripción de `PartsDB`; la selección por
  teclado lo mantiene anclado a su tarjeta.
- Mitad derecha: **solo el mapa local de Contención** desde
  `RunManager.current_map`. Admite cruces N/E/S/O y calcula escala/origen por los extremos
  reales del `grid`; nunca asume una lista fija.
- `game_theme.tres` unifica botones, foco de teclado y paneles de portada, HUD, mapa,
  pausa, costo de rejilla, ruta, resumen y final. El encabezado y la leyenda del mapa
  describen solo estado jugable, no vuelven a introducir tutoriales en overlays.
- Muestra exclusivamente salas visitadas. Las puertas hacia espacios desconocidos no
  revelan nodos ni destinos de rejilla por anticipado.
- No existe una pantalla de inventario ni una parte pendiente. `Inventory` conserva el
  nombre de autoload como autoridad interna de los seis slots. Si el cuerpo está lleno,
  un pickup permanece en el suelo hasta que el jugador consume o pierde una parte.

**Portada ilustrada**
- `ui/title.tscn` superpone `BackgroundContained`, `BackgroundEscaped` y `Menu`.
  Los fondos son `prueba_2/assets/ui/title/title_contained.png` y
  `prueba_2/assets/ui/title/title_escaped.png`; el segundo aparece tras la introducción
  y el menú contiene `PlayButton` y `QuitButton`.
- La primera tecla o clic solo omite la introducción: no activa `PlayButton` ni inicia
  una partida. Después, los botones controlan JUGAR y SALIR.

**Tutorial ambiental**
- `TutorialMural` pertenece al mundo y aparece una sola vez en `entry/tutorial`.
- Enseña mantener dirección, cargar y soltar mediante pictogramas; no pausa, no procesa
  input y su huella deja libres el spawn y las puertas.

**`floor_route_overlay.tscn`**
- Reacciona a `RunManager.floor_completed`; no contiene habitaciones.
- Orden visual superior→inferior: Superficie (0), Mantenimiento (-1),
  Bio-laboratorios (-2), Contención (-3).
- Contención queda al fondo y el ascenso apunta hacia arriba. Permanece `3.0 s`, pausa la
  partida y admite continuar antes con `E`, `Espacio` o `TAB`.

La base lógica es 1920×1080 con stretch `canvas_items`; la captura de regresión también se
escala a 1280×720 para comprobar clipping.

**`grate_cost_overlay.tscn`**
- Vive en `GrateLayer` (capa 18), por encima del mapa y del fundido normal, y pertenece al
  grupo `grate_cost_ui`.
- Al abrirse pausa la partida y ofrece solo slots ocupados más `½ CORAZÓN`; la tarjeta activa
  escala a `1.08` y usa borde cálido.
- Cancelar no cambia estado. Pagar una parte o vida desbloquea la fuente y viaja; el retorno
  ya desbloqueado no abre el selector.

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

La Quimera Albina anima con `actors/boss/boss_core_frames.tres` sobre las poses de
`assets/bosses/containment_chimera/animations/`, tiene `12 HP`, pertenece a los grupos
`enemies` y `bosses`, y recibe la misma firma `take_damage()` que los experimentos
normales. Los proyectiles del slime incluyen la capa 2 en su máscara
(`11 = mundo + boss + enemigos`).

`_update_visual()` traduce el estado con `_visual_state()` y solo relanza la animación
cuando cambia; el estiramiento mecánico se conserva, pero la escala base pasó de `0.22`
a `1.0` porque las poses ya vienen al tamaño de juego (350 × 205 px, la misma huella que
tenía el `Sprite2D` estático). `assets/bosses/containment_chimera/chimera.png` se
conserva solo como referencia de identidad para redibujar; ya no es arte de runtime.

```
BUSCA ESQUINA → FIJA POSICIÓN → EMBESTIDA → RECUPERA → BUSCA OTRA ESQUINA …
```

- **BUSCA ESQUINA:** elige una esquina distinta entre `(330,270)`, `(1590,270)`,
  `(1590,810)` y `(330,810)` y llega en una ráfaga de velocidad.
- **FIJA POSICIÓN:** se detiene, mira al jugador y dibuja una línea discontinua hasta su
  posición. No muestra texto que anuncie el estado.
- **EMBESTIDA:** congela esa posición al empezar y se lanza hacia ella sin corregir el
  rumbo. Solo este estado aplica un impacto de 1 corazón (`2 HP` de la barra) y
  retroceso.
- **RECUPERA:** frena antes de elegir la siguiente esquina.

Tres fases según vida aceleran desplazamiento/embestida y reducen aviso/recuperación:

| Fase | Vida | Esquina | Embestida | Aviso | Recuperación |
|---|---:|---:|---:|---:|---:|
| 1 | 12–9 | 620 px/s | 950 px/s | 1.35 s | 0.64 s |
| 2 | 8–5 | 720 px/s | 1080 px/s | 1.08 s | 0.52 s |
| 3 | 4–1 | 820 px/s | 1220 px/s | 0.84 s | 0.42 s |

`procedural_room.gd` materializa un único `BossCore` cuando
`role == &"boss_choice"` y añade debajo `ChimeraArena`, un decal cenital que marca anillo
y cuatro esquinas. No genera enemigos normales en esa sala.

Al entrar sella las puertas de la sala. Al morir las abre, marca sala/boss como
completados durante la run, suelta **DASH** y `silent_claws`, y llama una sola vez a
`RunManager.complete_floor(&"contencion")`. Esa llamada cura `+2 HP` y dispara la ruta de
ascenso. `GameState.bosses_defeated` evita que reaparezca.

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

### Fin por escape

Matar al jefe llama a `RunManager.complete_floor(&"contencion")`, que cura y saca el aviso
`floor_route_overlay`. Al cerrarse ese aviso —por sus 3 s o por tecla— emite
`dismissed(floor_id)`, y `main.gd` responde con `RunManager.end_run(&"escape")`. Contención
es el único piso jugable, así que superarlo **termina la partida**: el resumen entra con el
fondo y el titular de fuga. Si en el futuro hay más pisos, este enlace de `main.gd` es el
único punto que hay que cambiar.

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
title.tscn ──primera tecla/clic──▶ menú ──JUGAR──▶ main.tscn ──morir────────▶ run_summary
     ▲                                             │      └──jefe muerto────▶ (muerte/escape)
     └────────────────── TÍTULO ◀── pausa ─────────┴───────────────────────────────┘
```

- **Título** (`ui/title.gd`): llama a `GameState.reset_run()` al entrar, así que volver al
  título siempre limpia la partida. La primera tecla o clic omite la introducción sin
  activar `PlayButton`; ignora la acción `fullscreen` para que `F11` no altere ese flujo.
- **Pausa** (`ui/pause_menu.gd`, `Esc`): CONTINUAR / REINICIAR / TÍTULO.
- **Resumen** (`ui/run_summary.gd`): escucha `RunManager.run_ended`, muestra seed y
  decisiones de la partida, y ofrece nueva partida o título. La clave `reason` elige
  fondo, titular y color desde la tabla `OUTCOMES`:

  | `reason` | Fondo en `assets/ui/summary/` | Titular | Lo dispara |
  |---|---|---|---|
  | `death` | `run_summary_death.png` | TE CONTUVIERON | `GameState.died` → `main.gd` |
  | `escape` | `run_summary_escape.png` | ESCAPASTE | cerrar el aviso de Contención superada |
  | cualquier otra | `run_summary_bg.png` | PARTIDA TERMINADA | reserva; hoy nada lo emite |

  Al aparecer corre una entrada de ~0,5 s (fondo en fundido con zoom de 1,06 a 1,0, velo,
  panel que sube 40 px y líneas escalonadas); `visible` se pone en `true` antes del tween,
  así que el resumen no depende de la animación para existir.

**Los overlays comparten `get_tree().paused`**, así que cada uno comprueba el estado antes
de abrirse: mapa corporal, ruta, pausa y resumen no se apilan entre sí. Todos usan
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
| 6 | Ambientación: focos a energía 1.6/radio 1.85, cuerpo, sangre y mural | ✅ |
| 7 | Boss 1 + pickup + DASH + hueco | ✅ |
| 8 | Ciclo de muerte sin respawn y resumen reproducible | ✅ |
| 9 | Barra 5/15, tooltips, cuerpo conectado y mapas local/global | ✅ |
| 10 | Arte animado de EXP01, EXP02, EXP03 y Quimera Albina | ✅ |

**Alcance actual:** Contención procedural (nivel -3). Los niveles -2, -1 y 0 son contratos
futuros y no se simulan con salas fijas durante la partida activa.

---

## 13. Notas de mantenimiento

- **Añadir una plantilla:** registrarla en `core/room_backgrounds.gd`; `RoomDB.TEMPLATES`
  referencia ese catálogo, el generador valida su existencia y `RoomAssembler` aplica el
  fondo, su orientación y abre muros/puertas/spawns.
- **Añadir un prop:** escena en `world/props/` + `preload` y un array `@export` en
  `world/rooms/room.gd`.
- El MCP de Godot **no** edita árboles de nodos complejos: los `.tscn`/`.gd` se escriben a
  disco directamente y el MCP solo ejecuta y verifica (`run_project` + `get_debug_output`).
- `tests/ui_visual_capture.tscn` construye fixtures reproducibles y permite capturar
  `title_intro`, `title_menu`, `hud`, `map`, `tooltip`, `route`, `tutorial`, `grate`,
  `exp07_attack`, `enemies`, `lighting` o `boss`; el tercer
  argumento fija el tamaño físico final cuando el viewport lógico sigue siendo 1080p.
  `enemies` congela EXP01, EXP02, EXP03 y EXP07 en su pose de locomoción y en el
  último fotograma de su aviso, que es la comparación que hay que mirar.
  `grate` materializa `CENTER` con su conexión, muestra el prompt y abre el selector con dos
  partes sin cambiar `GameState.current_room`.
  Para registrar la portada a 1920×1080:

  ```powershell
  & '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- title_intro user://title-intro.png 1920x1080
  & '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- title_menu user://title-menu.png 1920x1080
  & '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- exp07_attack user://exp07-attack.png 1920x1080
  & '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- enemies user://containment-enemies.png 1920x1080
  & '<ruta-a-godot>/Godot_v4.7.1-stable_win64.exe' --path prueba_2 --windowed --resolution 1920x1080 res://tests/ui_visual_capture.tscn -- lighting user://lighting-test-mode.png 1920x1080
  ```
- `combat_smoke.tscn` ensambla las 16 configuraciones cardinales, incluidas `NE`, `SO` y
  el destino de rejilla sin puertas normales. `run_map_tests.gd` comprueba además que cada
  sala de 1.000 seeds aceptadas tenga una plantilla renderizable.
