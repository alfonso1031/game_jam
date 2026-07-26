# SLIME ESCAPE — estado actual autoritativo para IA

Fecha de corte: **2026-07-26**

Motor: **Godot 4.7.1**

Proyecto activo: **`prueba_2/`**

Este documento sintetiza el estado vigente del juego. Contiene solamente las decisiones
finales que ya sustituyeron propuestas anteriores y separa con claridad lo implementado
de lo aprobado pero pendiente.

## 1. Cómo interpretar el repositorio

Orden de autoridad cuando dos fuentes parezcan contradecirse:

1. el comportamiento y las constantes del código de `prueba_2/`;
2. este documento;
3. `AGENTS.md` y `docs/CONVENCIONES.md`;
4. `docs/ARQUITECTURA.md` y `docs/agents/REFERENCIA.md`;
5. especificaciones aprobadas que se declaren pendientes en este documento.

`docs/PLAN.md`, `docs/DIRECCION.md`, los documentos de
`docs/superpowers/plans/`, los prototipos y las especificaciones sustituidas son
**historial**, no reglas vigentes. No se deben recuperar de ellos valores, probabilidades
ni flujos antiguos.

## 2. Alcance actual

- Juego 2D cenital, con perspectiva visual 3/4, en resolución lógica **1920 × 1080**.
- El slime escapa de un laboratorio asimilando partes de criaturas.
- Solo está implementado el primer piso: **NIVEL -3 · CONTENCIÓN**.
- La ruta global conserva como orientación futura Bio-Laboratorios (-2),
  Mantenimiento (-1) y Superficie (0), pero esos pisos no forman parte de la generación
  activa.
- Una partida vive solo en memoria. No hay guardado, checkpoint ni respawn.

Estado visual de los enemigos del piso:

| Entidad | Mecánica | Arte actual |
|---|---|---|
| EXP01 · Ciempiés de Agujas | Implementada | `AnimatedSprite2D`, 6 poses |
| EXP02 · Arácnido Blindado | Implementada | `AnimatedSprite2D`, 6 poses |
| EXP03 · Saurio Escamado | Implementada | `AnimatedSprite2D`, 6 poses |
| EXP07 · Crustáceo Triturador | Implementada | `AnimatedSprite2D`, arte ilustrado entregado |
| Quimera Albina · boss | Implementada | `AnimatedSprite2D`, Idle de 7 frames + Angry de 16 frames ilustrados |

Ningún enemigo de Contención usa ya `Polygon2D` como cuerpo final. Las poses de EXP01,
EXP02 y EXP03 se componen con formas vectoriales desde
`tools/art/gen_containment_enemy_sheets.gd` y se procesan con
`tools/art/process_containment_enemy_sheets.gd`. **Son arte funcional, no una entrega
ilustrada a mano:** cuando diseño entregue hojas pintadas, se sustituye
`art_raw/enemigos/containment/<personaje>/source_sheet.png` respetando la rejilla 3 × 2 y
el orden de poses, y se vuelve a correr el procesador. El arte de EXP07 y la Quimera llegó
de diseño y no se ha redibujado. La Quimera usa sus 23 PNG transparentes desde
`art_raw/enemigos/containment/boss_chimera/{idle,angry}/`, procesados con
`tools/art/process_chimera_delivered_frames.gd`.

El protagonista también usa arte ilustrado entregado: `AnimatedSprite2D` con
`idle` de 5 frames, `walk` de 2, `jump` de 6 y `recover` de 12. Las cuatro hojas
originales se conservan en `art_raw/personaje/slime/`; el procesador
`prueba_2/tools/art/process_slime_delivered_sheets.gd` las recorta en común y genera los
25 PNG de runtime sin cambiar la colisión ni las reglas de movimiento.

## 3. Flujo de partida y controles

Flujo:

```text
portada ilustrada → menú → nueva run de Contención → salas dirigidas → preboss
→ Quimera Albina → recompensa y ruta de ascenso
```

Morir abre el resumen de la run. Desde allí solo se inicia una run nueva o se vuelve al
título.

| Acción | Control vigente |
|---|---|
| Dirección / movimiento | `WASD` o flechas |
| Interactuar con rejilla | `E` |
| Mapa corporal y local | `TAB` |
| Consumir parte | `F` |
| Habilidades de partes | números `1` a `6` |
| DASH de boss | `Shift` o `Espacio`, después de desbloquearlo |
| Pausa | `Esc` |
| Pantalla completa | `F11` |
| Vida infinita de prueba | botón en `TAB` o `V` con el overlay abierto |

La portada no enumera controles. La primera tecla o clic omite la introducción y muestra
el menú; no inicia la partida. Los controles básicos se enseñan como mural pasivo dentro
de la primera sala.

## 4. Vida, muerte y estado de la run

- Vida máxima base: **15 HP**.
- Vida inicial: **7 HP**.
- Cada HP mostrado representa **medio corazón**.
- Comer una parte cura **2 HP**.
- Completar Contención cura **2 HP**, una sola vez por run.
- Pagar una rejilla con vida cuesta **1 HP**.
- Llegar a cero termina la run; no restaura un checkpoint.
- `RunManager.start_new_run(seed)` es la única entrada válida para una nueva partida:
  limpia `GameState` e `Inventory`, genera el mapa y conserva la seed.
- `RunManager` conserva seed, mapa, pisos completados y resumen.
- `GameState` conserva vida, salas visitadas/limpias, habilidades, boss derrotado,
  recompensas y rejillas descubiertas/desbloqueadas.
- `Inventory` conserva las seis partes equipadas, enfriamientos y efectos.
- El modo de vida infinita dura durante la run actual y se apaga al iniciar otra. Evita
  perder HP, pero no elimina retroceso, destello ni invulnerabilidad temporal.

Consumir partes distintas de boss registra un bono permanente de **+0,5 % al daño básico
por parte**, con máximo de seis. El bono no multiplica el daño fijo de habilidades.

## 5. Partes, slots y habilidades

- Existen exactamente **seis slots genéricos**.
- No hay slot pendiente, séptimo slot ni pantalla de inventario separada.
- Cualquier parte puede ocupar cualquier slot libre compatible.
- No se puede equipar dos veces la misma parte ni dos partes con la misma `body_zone`.
- Si no existe slot compatible, el pickup permanece en el suelo.
- Comer, perder o sacrificar una parte libera su slot.
- Perder o sacrificar no cura.
- Con `TAB` abierto, `WASD` o flechas recorren solo tarjetas ocupadas; la seleccionada
  se agranda, ilumina borde y conexión, y `F` la consume.
- La interfaz no anuncia cuánto curará antes de consumir.
- Si hay en el suelo un duplicado exacto de una parte equipada, `F` consume directamente
  la copia suelta, cura 2 HP y conserva intacta la equipada.
- `PartsDB` es la única fuente de nombres, descripciones, tipo corporal, cooldown y efecto.
- Las habilidades activas de los slots se ejecutan con `1`–`6` mediante
  `actors/player/abilities/ability_runner.gd`.
- Las habilidades activas de boss comparten un bloqueo global de **0,6 s**.

Pool actual de la primera parte y del loot de rejillas:

- `acid_stinger`;
- `serrated_jaw`;
- `hydraulic_legs`;
- `bio_netcaster`.

## 6. Movimiento y combate del slime

### Sin una parte de pierna

- Mantener `WASD` o una flecha elige dirección y carga.
- Soltar inicia un arrastre recto; durante el trayecto no se puede girar.
- Carga mínima: **0,12 s**.
- Carga máxima: **1,0 s**.
- Distancia: **112–520 px**.
- Velocidad del arrastre: **480 px/s**, uniforme.
- Más carga aumenta distancia y duración, no la velocidad del tramo.
- Soltar antes del mínimo produce `fizzle` y **0,28 s** de recuperación.
- Chocar de frente con un muro produce **0,45 s** de recuperación.
- La barra de carga aparece sobre el slime.
- La secuencia `jump` comunica el impulso sin alterar la colisión circular. La deformación
  vectorial anterior permanece oculta como soporte interno.
- La embestida básica hace 1, 2 o 3 de daño según la potencia de carga.

### Con una o más partes de pierna

- Equipar cualquier parte cuyo tipo sea `pierna` reemplaza la carga por movimiento
  continuo normal con `WASD` o flechas a **280 px/s**.
- Perder la última pierna restaura inmediatamente el movimiento cargado.
- Una y dos piernas usan hoy el mismo movimiento. El conteo queda disponible para futuras
  variantes, pero no se debe inventar una diferencia todavía.

### DASH

- Es una habilidad distinta del movimiento base.
- Se obtiene al derrotar a la Quimera Albina.
- Dura **0,32 s**, tiene cooldown de **0,8 s**, pico de **2200 px/s**, final de
  **300 px/s** y alcance integrado de **382 px**.
- Da invulnerabilidad y permite cruzar huecos al desactivar temporalmente la colisión
  contra la capa `gap`.
- Cambiar sus constantes exige recalcular el alcance; no se debe aplicar su curva al
  arrastre base.

El slime se desplaza con `move_and_collide()`. Asignar `velocity` desde otro objeto no lo
empuja; debe usarse `apply_knockback(from, force)`.

### Presentación animada

| Estado de gameplay | Animación visual |
|---|---|
| `IDLE`, `CHARGING` | `idle` |
| Movimiento continuo con piernas | `walk` |
| `LAUNCHING`, `DASHING`, `PART_DASH` | `jump` |
| `RECOVERING` | `recover` |

`idle` y `walk` repiten; `jump` y `recover` no se reinician mientras permanezca
el mismo estado. La fuente mira a la derecha y `flip_h` refleja el sprite cuando
`_facing.x < 0`. El lienzo común es de **128 × 128 px**, con el arte ajustado a
**96 × 96 px** alrededor del mismo pivote; la hitbox circular sigue teniendo
radio **45 px**. `ScaleShell` permanece por encima del sprite y la barra de carga
conserva su posición. Los frames son presentación: el script y sus temporizadores
siguen siendo la única autoridad del gameplay.

## 7. Generación procedural de Contención

Autoridad: `core/map_generator.gd` produce un `RunMap` determinista por
`(seed, attempt)`.

- Máximo de intentos: **128**.
- Camino principal: **6–8 hitos**.
- Presupuesto total: **24 salas**.
- El grafo es un DAG: no tiene ciclos ni retorno normal.
- `doors` contiene solo salidas futuras.
- `entrances` conserva las entradas consumidas y selladas.
- El boss es el único sumidero.
- Toda sala distinta del boss tiene al menos una ruta futura hacia él.
- Siempre existe una bifurcación real después de la sala del cuerpo y ambas ramas vuelven
  a converger.

Orden obligatorio:

1. `entry/tutorial`: primera sala, una sola salida.
2. `body/body_reward`: segunda sala, una entrada sellada, una salida, sin rejilla.
3. Salas normales y una bifurcación.
4. `preboss`: penúltimo hito, tres enemigos y combate obligatorio.
5. `boss_choice`: último hito, Quimera Albina.

Probabilidades de contenido normal:

| Tipo | Probabilidad | Enemigos |
|---|---:|---:|
| Combate fácil | 60 % | 1–3 |
| Combate difícil | 30 % | 4–7 |
| Vacía | 10 % | 0 |

Las puertas normales de una sala con enemigos se sellan hasta limpiar el combate. Las
salas ya limpias no regeneran enemigos durante esa run.

### Segunda sala

- Siempre entrega la primera parte aleatoria de la run.
- Un rastro de sangre vectorial guía desde la primera sala.
- No se muestra un cadáver humano.
- El runtime actual usa `BodySource` sobre un charco como fuente narrativa provisional.
- El monstruo que finalmente debe entregar esa parte todavía no tiene diseño ni assets
  aprobados; no se debe inventar su IA dentro de otro cambio.
- La recompensa se marca como reclamada al recogerla y no reaparece durante esa run.

## 8. Rejillas

- Solo aparecen en salas normales de combate, salas de rama con combate y el preboss.
- Toda sala elegible tiene exactamente una.
- No aparecen en salas vacías, entrada, segunda sala, destinos de rejilla ni boss.
- Máximo una rejilla por sala.
- La rejilla ocupa **120 × 120 px**, el mismo tamaño funcional de una puerta, montada en
  una pared libre.
- Nunca comparte pared con puerta o entrada.
- No usa `squeeze` ni un objeto adicional.
- Para cruzarla se sacrifica una parte equipada o se paga 1 HP.
- A 1 HP se pide una segunda confirmación; el jugador puede elegir usarla y morir.
- La rejilla permite huir de un combate sin limpiar la sala.
- Cruzarla es irreversible: el destino solo crea `GrateSpawn`, sin rejilla de retorno.
- Los destinos son exclusivos, no se comparten y no pueden encadenar otra rejilla.
- El destino siempre conserva una salida normal futura hacia el boss.
- La rejilla del preboss lleva a un destino que vuelve a conectar con el boss.

Probabilidades del destino:

| Destino | Probabilidad | Regla |
|---|---:|---|
| Vacío | 40 % | Sin combate |
| Combate | 20 % | 1–2 enemigos; combate obligatorio |
| Loot | 40 % | Una parte aleatoria, una sola vez |

## 9. Enemigos y boss del primer piso

Pool normal con el mismo peso:

| Enemigo | Aparición | Vida | Conducta | Drop posible |
|---|---:|---:|---|---|
| EXP01 · Ciempiés de Agujas | 25 % | 2 | Zigzag, aviso de 0,65 s, embestida recta y descanso | `acid_stinger`, `serrated_jaw` |
| EXP02 · Arácnido Blindado | 25 % | 3 | Mantiene distancia, dispara red o aplasta en área | `hydraulic_legs`, `bio_netcaster` |
| EXP03 · Saurio Escamado | 25 % | 3 | Presión constante; coletazo si el jugador lo flanquea | `whip_tail`, `scaled_skin` |
| EXP07 · Crustáceo Triturador | 25 % | 4 | Mantiene espacio y telegrafía un cono corto con la tenaza | `crusher_claw` |

El EXP07 no tiene escudo. Recibe daño desde cualquier dirección, retrocede si invade el
espacio del slime y su cono mide **150 px / 50°**. Su animación de ataque pertenece al
enemigo, no al slime.

El preboss genera tres enemigos: dos elegidos entre EXP01–EXP03 y un EXP07 final marcado
como líder. Esto garantiza la oportunidad de obtener `crusher_claw`.

### Quimera Albina

- Vida: **12 HP**.
- Ciclo: `SEEK_CORNER → CORNER_AIM → POUNCE → RECOVER`.
- Esquinas: `(330,270)`, `(1590,270)`, `(1590,810)`, `(330,810)`.
- Elige una esquina distinta, llega en una ráfaga, se detiene, avisa y después se lanza.
- Al comenzar la embestida congela la posición objetivo; no hace homing.
- El aviso es visual: línea discontinua, objetivo y barra de vida. No se muestra texto
  describiendo la acción.
- No tiene escudo.
- Solo `POUNCE` causa daño de contacto y retroceso. El script envía un impacto de
  1 corazón, equivalente a **2 HP de la barra**.

| Fase | Vida | Velocidad a esquina | Embestida | Aviso | Recuperación |
|---|---:|---:|---:|---:|---:|
| 1 | 12–9 | 620 px/s | 950 px/s | 1,35 s | 0,64 s |
| 2 | 8–5 | 720 px/s | 1080 px/s | 1,08 s | 0,52 s |
| 3 | 4–1 | 820 px/s | 1220 px/s | 0,84 s | 0,42 s |

Al morir:

- abre las salidas;
- marca sala y boss como completados;
- entrega la habilidad `dash`;
- entrega la parte `silent_claws`;
- completa Contención y cura 2 HP;
- abre la ruta de ascenso.

## 10. UI y mapas

- HUD permanente: barra de biomasa `HP actual / 15 HP` y minimapa procedural.
- `TAB` abre un overlay pausado con cuerpo a la izquierda y mapa local a la derecha.
- El mapa local lee `RunManager.current_map`, nunca el catálogo legacy `RoomDB.ROOMS`.
- Solo muestra salas visitadas.
- Una puerta desconocida no revela su destino.
- Una rejilla no revela su destino hasta visitarlo.
- El layout admite vecinos simultáneos N/E/S/O y cuartos en cruz.
- Los tooltips siguen la tarjeta/cursor y obtienen sus textos de `PartsDB`.
- La ruta global es otro overlay: muestra pisos, no habitaciones. Contención está abajo y
  el ascenso apunta a Superficie arriba.
- La ruta aparece **3 s** tras completar el piso y se puede continuar antes con `E`,
  `Espacio` o `TAB`.
- La UI de gameplay no contiene textos explicativos redundantes.
- Todos los overlays que pausan usan `PROCESS_MODE_ALWAYS` y coordinan
  `get_tree().paused` para no superponerse.
- `ui/game_theme.tres` es el tema compartido; no duplicar estilos comunes.

## 11. Salas, arte, iluminación y audio

### Sala

| Elemento | Valor |
|---|---|
| Viewport lógico | 1920 × 1080 |
| Rejilla interior | 13 × 7 celdas |
| Celda | 120 × 120 px |
| Suelo | 1560 × 840 px, x `180…1740`, y `120…960` |
| Muro | banda de 120 px |
| Cámara | fija, centrada, sin scroll |
| Hueco visual de puerta | 240 px |
| Paso útil entre jambas | 120 px |

Las filas/celdas centrales de acceso se mantienen libres. El catálogo procedural de props
no bloquea la fila 3 ni la columna 6.

### Dirección visual

- Estilo 2D ilustrado/vectorial de formas orgánicas y planos suaves.
- Perspectiva cenital inclinada 3/4.
- Sangre estilizada, no realista, sin colisión.
- Assets integrados bajo `prueba_2/assets/`; formas procedurales solo como fallback
  intencional.
- Los PNG de runtime tienen alfa, pivote centrado y sin sombras horneadas.
- La orientación fuente estándar es hacia la derecha, salvo EXP07, cuyo arte existente
  está invertido y se corrige solo en su script.
- El arte no define daño, alcance ni tiempos; los scripts siguen siendo autoridad.
- El arte crudo de enemigos vive en `art_raw/enemigos/containment/`, fuera del proyecto
  Godot; solo entran las poses procesadas. EXP01–03 conservan hojas 3 × 2; la Quimera
  conserva siete fuentes `idle` y dieciséis `angry`.
- El arte crudo del jugador vive en `art_raw/personaje/slime/`: cuatro hojas RGBA
  de celdas 320 × 320. Solo los 25 fotogramas centrados entran en
  `prueba_2/assets/player/slime/animations/`.
- Cada experimento con arte traduce su estado con `_visual_state()`; si el nombre no
  existe en su `SpriteFrames`, `enemy_base.gd` cae al `autoplay` en vez de romper.
- Las velocidades de los avisos están calculadas para que el último fotograma coincida
  con la llamada que aplica el ataque. Cambiar el tiempo de un estado obliga a
  recalcular la velocidad del `SpriteFrames`.

### Iluminación

- Todo el cuarto debe seguir siendo legible bajo una penumbra tenue.
- `CanvasModulate` aplica la oscuridad global.
- Las lámparas mantienen energía **1,6** y `texture_scale = 1,85`.
- Se amplía cobertura sin bajar la intensidad de los focos.
- Hay al menos tres focos activos por sala, además de variantes fundidas.
- Los decals narrativos no se convierten en fuentes de luz.

### Audio

- Menú: `assets/audio/music/main_menu.ogg`, `-10 dB`.
- Contención: `assets/audio/music/containment_ambience.ogg`, `-13 dB`.
- Efectos viscosos/biológicos del slime:
  `assets/audio/slime/` y `actors/player/slime_audio.gd`.
- La carga usa un loop cuyo pitch y volumen crecen con la potencia; también hay sonidos
  de carga plena, fizzle, lanzamiento, impacto, recuperación y DASH.
- Los audios originales y el generador se documentan en `tools/audio/README.md`.
- Tras traer assets nuevos de Git debe ejecutarse una importación de Godot porque
  `.godot/` no se versiona:

```bash
godot --headless --path prueba_2 --import
```

## 12. Arquitectura y archivos que mandan

Organización por feature: cada `.tscn` vive junto a su `.gd`.

| Autoridad | Responsabilidad |
|---|---|
| `prueba_2/core/map_generator.gd` | Reglas y probabilidades del mapa |
| `prueba_2/core/run_map.gd` | Modelo del grafo procedural |
| `prueba_2/core/parts_db.gd` | Catálogo único de partes |
| `prueba_2/core/room_backgrounds.gd` | 16 combinaciones cardinales de fondo |
| `prueba_2/autoload/run_manager.gd` | Ciclo, seed, mapa y resumen |
| `prueba_2/autoload/game_state.gd` | Vida y progreso de la run |
| `prueba_2/autoload/inventory.gd` | Seis slots y efectos equipados |
| `prueba_2/autoload/transition.gd` | Cambio irreversible entre salas |
| `prueba_2/world/rooms/procedural_room.gd` | Ensamblaje de contenido |
| `prueba_2/actors/player/slime.gd` | Movimiento, embestida y DASH |
| `prueba_2/actors/player/abilities/ability_runner.gd` | Habilidades `1`–`6` |
| `prueba_2/actors/enemies/` | IA de experimentos |
| `prueba_2/actors/boss/boss_core.gd` | Quimera Albina |
| `prueba_2/ui/map_overlay.gd` | TAB, navegación corporal y mapa local |

Dirección de dependencias:

- `core/` es puro: no importa escenas, nodos ni autoloads.
- `autoload/` puede consumir `core/`.
- `actors/` y `world/` consumen `core/` y autoloads, pero no `ui/`.
- `ui/` escucha señales y no gobierna actores ni salas.
- `game/` ensambla los sistemas.

`Palette` y `Layers` no son clases globales ni autoloads: se consumen siempre con
`preload`. Los colores y capas nunca se escriben como valores sueltos.

## 13. Invariantes que no se deben romper

1. El proyecto activo es `prueba_2/`; `prueba/` es legacy.
2. Warnings de GDScript se tratan como errores; usar tipado explícito.
3. El jugador se coloca antes de añadir la sala nueva al árbol.
4. Puertas, pickups y proyectiles filtran por grupo `player`, no por clase.
5. La navegación procedural es dirigida y no permite volver.
6. Toda sala alcanza el boss y el boss es el único sumidero.
7. Una rejilla no comparte pared, destino ni retorno.
8. La segunda sala siempre contiene la primera recompensa y nunca una rejilla.
9. Solo hay seis slots; no reintroducir `pending` ni inventario separado.
10. Impulso cargado, movimiento con piernas y DASH son mecánicas distintas.
11. Nombres y descripciones de partes no se duplican fuera de `PartsDB`.
12. La UI reacciona a señales; no sondea estado global en `_process()`.
13. Las máquinas de estado, hitboxes y scripts deciden el gameplay; los frames visuales
    no aplican daño.
14. Los assets usados por escenas/scripts deben existir y versionarse; no depender solo
    de caché `.godot/`.

## 14. Estado de trabajo pendiente aprobado

El cambio de assets animados de Contención está **ejecutado**: hojas funcionales de seis
poses para EXP01, EXP02 y EXP03; arte ilustrado entregado para EXP07; Idle de 7 frames
más Angry de 16 frames para la Quimera Albina; y las cuatro animaciones ilustradas del
slime (`5/2/6/12`). Todo se procesa a PNG con alfa y `SpriteFrames` sin cambiar vidas,
daños, velocidades, tiempos, colisiones, drops ni probabilidades. La fuente de recompensa
de la segunda sala sigue siendo un prop, no un enemigo; no hay animaciones de muerte.

Queda pendiente, sin plazo ni especificación aprobada:

- sustituir las poses generadas de EXP01, EXP02 y EXP03 por entregas ilustradas cuando
  existan, cambiando sus `source_sheet.png` en `art_raw/enemigos/containment/`;
- el diseño del monstruo que entrega la parte de la segunda sala.

No hay ninguna otra especificación histórica que deba asumirse pendiente automáticamente.
