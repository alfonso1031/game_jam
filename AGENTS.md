# AGENTS.md — instrucciones para agentes de IA

Repositorio de un juego 2D en **Godot 4.7.1** (GDScript). Este archivo es la guía
operativa mínima: dónde trabajar, cómo verificar y qué no romper. Se lee **primero**.

| Documento | Para qué |
|---|---|
| [`docs/CONVENCIONES.md`](docs/CONVENCIONES.md) | **Las reglas del proyecto**: arquitectura por feature, dirección de las dependencias, nombres, estilo. Son obligatorias |
| [`docs/agents/REFERENCIA.md`](docs/agents/REFERENCIA.md) | Medidas de sala, recetas (añadir sala/prop/habilidad), estilo, formato `.tscn` |
| [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md) | Cómo está construido el juego y por qué |
| [`docs/PLAN.md`](docs/PLAN.md) | Diseño original del MVP |

---

## 1. Dónde trabajar

| Carpeta | Estado |
|---|---|
| `prueba_2/` | **Proyecto activo.** Todo el trabajo va acá. |
| `prototypes/slime_charge_movement/` | Banco de pruebas del impulso cargado, proyecto Godot aparte con tests propios. Se itera acá antes de tocar `prueba_2`. |
| `prueba/` | Legacy abandonado. **No modificar.** Se conserva solo por historial. |

Escena de arranque: `prueba_2/ui/title.tscn`. La partida vive en
`prueba_2/game/main.tscn`. Requiere **Godot 4.7.1**; si el binario no está en el `PATH`,
su ubicación es específica de cada máquina.

`prueba_2/` se organiza **por feature**, no por tipo de archivo: `assets/`, `autoload/`,
`core/`, `game/`, `actors/`, `world/`, `ui/`. Cada `.tscn` va junto a su `.gd`. La tabla
completa de dónde va cada cosa está en
[`docs/agents/REFERENCIA.md`](docs/agents/REFERENCIA.md) §1.

Para probar la partida directo sin pasar por el título, correr con la escena como
argumento en vez de cambiar `run/main_scene`.

---

## 2. Cómo ejecutar y verificar

**Ningún cambio se da por bueno sin un arranque limpio.** Correr y leer la salida de debug:

Desde la raíz del repositorio:

```bash
godot --path prueba_2
```

En Windows, con el binario fuera del `PATH`, usar la variante `_console.exe` para ver la
salida:

```bash
"<ruta-a-godot>/Godot_v4.7.1-stable_win64_console.exe" --path prueba_2
```

Si hay MCP de Godot disponible (`@coding-solo/godot-mcp`): `run_project` →
`get_debug_output` → `stop_project`. El MCP **no** edita árboles de nodos ni scripts:
los `.tscn` y `.gd` se escriben a disco como texto y el MCP solo ejecuta y verifica.

### Qué significa "limpio"

- `errors` vacío, o solo este warning conocido y esperado:
  `The signal "room_changed" is declared but never explicitly used in the class`
  (se conecta desde otros scripts, GDScript no lo detecta).
- Un `Debugger Break` **siempre** es un fallo, aunque el proceso siga vivo.

### Tras un `git pull` que traiga assets

Los `.import` se versionan, pero los binarios importados viven en `.godot/`, que **no**.
Si el pull trae `.wav`, `.png` o similares, hay que reimportar una vez:

```bash
godot --headless --path prueba_2 --import
```

Sin esto los recursos fallan con `Could not preload resource file`. Ojo: **el juego puede
arrancar igual y romper después**, porque empieza en el título y el slime —que es quien
hace el `preload` del audio— no se carga hasta empezar la partida. Las suites de tests sí
lo detectan al instante.

---

## 3. Reglas duras (romper esto rompe el juego)

1. **Lo de `core/` se consume con `preload`, nunca por nombre global.** `palette.gd` y
   `layers.gd` **no** declaran `class_name` y **no** son autoloads. Siempre:
   ```gdscript
   const Palette := preload("res://core/palette.gd")
   const Layers := preload("res://core/layers.gd")
   ```
   Tres motivos, todos aprendidos rompiendo algo:
   - Un autoload con el mismo nombre que un `class_name` **impide arrancar**.
   - El registro global de clases vive en `.godot/`, que no se versiona: en un clon
     nuevo el nombre global no existe hasta abrir el editor, y el script falla con
     `Identifier "Palette" not declared`.
   - Con el registro presente, declarar además `class_name` provoca el warning
     `The constant "X" has the same name as a global class`.

   **No hace falta repetir el `preload` en una subclase:** GDScript hereda las
   constantes de la clase base. Los experimentos de `actors/enemies/` usan `Palette` y
   `Layers` a través de `enemy_base.gd`. Si se añade un script que las use **sin**
   heredar de una base que ya las tenga, hay que declararle su propio `preload`.

2. **Warnings tratados como errores.** `var x := clamp(...)` y cualquier inferencia desde
   `Variant` rompe el arranque. Tipar explícito: `var x: float = clamp(...)`.
   Tampoco declarar variables locales que tapen propiedades de la clase base
   (ej. `var size` dentro de un `Control`).

3. **`_ready()` corre de hijos a padres.** El HUD no puede leer `GameState.current_room`
   en su `_ready()`, porque `main.gd` todavía no lo asignó. Todo lo que dependa del estado
   de sala se hace desde `room_changed`; la barra escucha `health_changed` y el panel
   corporal escucha `Inventory.slots_changed`. No sondear estado desde `_process()`.

4. **El jugador se coloca ANTES de añadir la sala al árbol** (`Transition._swap_room`).
   Si se añade primero, las puertas de la sala nueva detectan al jugador todavía en la
   posición de la puerta anterior y encadenan otra transición. Además las puertas nacen
   desarmadas (`_armed = false`) y solo se arman cuando el jugador sale del área.

5. **Filtrar por el grupo `player`, nunca por tipo de nodo.** El boss también es un
   `CharacterBody2D`. Puertas, proyectiles y pickups usan `body.is_in_group("player")`.

6. **Capas de colisión** — respetarlas al añadir cualquier cosa. Los nombres están en
   `project.godot` (`[layer_names]`) y los números en `core/layers.gd`; desde código usar
   `Layers.*`, nunca el número suelto.

   | Capa | Nombre | Valor | Quién |
   |---|---|---|---|
   | 1 | `world` | 1 | Mundo (muros, props sólidos) y jugador |
   | 2 | `boss` | 2 | Boss |
   | 3 | `gap` | 4 | Huecos: solo se atraviesan durante el dash |

   Jugador: `collision_layer = 1`, `collision_mask = 5`, grupo `player`.

7. **Rutas con espacio.** La ruta del repositorio puede contener espacios, así que
   cualquier ruta absoluta va **entre comillas** en los comandos. Dentro de la
   documentación usar siempre rutas relativas a la raíz del repositorio (`prueba_2/…`) o
   rutas de recurso (`res://…`), nunca rutas absolutas de una máquina concreta.

8. **Los overlays comparten `get_tree().paused`** (mapa corporal, ruta de piso, pausa y
   final). Cualquier overlay nuevo debe comprobar el estado antes de abrirse y usar
   `PROCESS_MODE_ALWAYS`, o queda uno encima de otro y sin forma de cerrarse.

9. **`RunManager` es la autoridad del ciclo de partida.** Una partida nueva siempre nace
   con `RunManager.start_new_run(seed)`; ese método limpia `GameState` e `Inventory`,
   genera `RunMap` y conserva la seed. No reiniciar autoloads por separado para empezar
   una partida.

10. **El slime se mueve con `move_and_collide()`, no con `move_and_slide()`.** El motor
    ya no usa `velocity` para desplazarlo, así que **asignar `player.velocity` no empuja
    nada**. Para empujar al jugador hay que llamar a `apply_knockback(from, force)`.

11. **Impulso cargado y DASH son dos mecánicas distintas.** El impulso cargado es el
    movimiento base (mantener dirección y soltar); el DASH es la recompensa del boss
    (`Shift`/`Espacio`). Solo el DASH da invulnerabilidad y apaga el bit 3 para cruzar
    huecos. No unificarlos ni copiar las reglas de uno al otro.

12. **No aflojar el anti-machaque.** Soltar la dirección antes de `MIN_CHARGE_TIME` no
    lanza y penaliza con `FIZZLE_RECOVERY_TIME`. Es deliberado: golpear teclas no puede
    equivaler a caminar, porque el movimiento continuo es una habilidad futura (piernas).
    Igual de deliberado es `WALL_RECOVERY_TIME`: chocar tiene que doler.

13. **Tocar las constantes del DASH cambia su alcance.** La velocidad no es constante
    (`_eased_speed()`), así que el alcance es la **integral de la curva**: hoy 382 px.
    Cruzar el hueco de `L2_BIOLAB` exige 210 px. Si el alcance baja de ahí, el hueco se
    vuelve infranqueable y **el juego se queda sin final**. Recalcular la integral antes
    de modificar `DASH_PEAK_SPEED`, `DASH_END_SPEED`, `DASH_EASE`, `DASH_RAMP`,
    `DASH_START` o `DASH_TIME`. En el impulso cargado esto no aplica: ahí la distancia la
    fija `_remaining` y el tramo base avanza uniforme a `CRAWL_SPEED`.

14. **No existen checkpoints ni respawn.** La vida máxima es `15 HP`, se empieza con
    `7 HP` y cada HP representa medio corazón. Completar Contención cura `+2 HP` una sola
    vez durante la partida actual y comer una parte cura `+2 HP`. Llegar a cero llama
    `RunManager.end_run()` y muestra el resumen; continuar exige una partida nueva.

15. **La iluminación conserva intensidad, no cobertura antigua.** Cada foco usa energía
    `1.6` y `texture_scale = 1.85`; no bajar intensidad al ampliar el radio. Respetar el
    carril central de puertas y no convertir los decals narrativos en luces.

16. **Contención se genera, no se enumera en `RoomDB.ROOMS`.** `MapGenerator` y `RunMap`
    viven en `core/`, son deterministas por `(seed, attempt)` y no pueden importar
    autoloads ni escenas. Camino principal `6–8`, máximo `12` salas. Antes de cambiar sus
    reglas, ejecutar `res://tests/run_map_tests.gd`, que valida 1.000 seeds.

17. **Una rejilla nunca requiere `squeeze`.** Si se usa, el jugador elige sacrificar una
    parte equipada o pagar `1 HP`; a `1 HP` la UI debe pedir confirmación y puede matar.
    Máximo una rejilla por sala, destinos exclusivos y mínimo una si el mapa contiene
    combate elegible. Fuente y retorno usan paredes libres opuestas, caben en `120 × 120`
    y su destino adyacente se elige `40 %` vacío, `40 %` loot y `20 %` combate.

18. **El mapa de `TAB` es local y procedural.** Lee `RunManager.current_map`, nunca
    `RoomDB.ROOMS`, y debe admitir vecinos N/E/S/O simultáneos. Solo muestra salas
    visitadas; una puerta hacia lo desconocido no revela el destino ni una rejilla lo
    descubre por anticipado. La ruta global es otro overlay: cuatro pisos, Contención
    abajo y Superficie arriba, sin nodos de habitaciones.

19. **`PartsDB` es la única fuente de nombres y descripciones de partes.** Tooltips y
    tarjetas llaman `display_name()` / `description()`; no duplicar textos en escenas.
    Comer, perder o sacrificar una parte debe retirar tarjeta, tooltip y curva por la
    señal `slots_changed`.

20. **La primera sala enseña movimiento dentro del mundo.** `TutorialMural` aparece solo
    en `entry/tutorial` y explica mantener dirección, cargar y soltar. La portada no
    enumera controles; pausa, pantalla completa y DASH esperan el futuro menú con botones.
    El mapa corporal se abre con `TAB`. El mural es pasivo, no pausa y no puede bloquear
    spawn ni puertas.

21. **El cuerpo es el segundo hito, no contenido aleatorio.** `main_path[1]` usa rol
    `body`, contenido `body_reward`, dos puertas y ninguna rejilla. El rastro se orienta
    desde las conexiones de `RunMap`; la parte se reclama al recogerla y no reaparece
    durante esa partida. No fijar IDs de sala ni una dirección cardinal.

22. **Solo existen las seis partes equipadas.** `Inventory` mantiene exactamente seis
    slots por compatibilidad interna, pero no hay `pending`, séptimo espacio ni pantalla
    separada con `I`. Si el cuerpo está lleno, el pickup permanece en el mundo. Consumir
    se hace únicamente desde `TAB`: flechas para elegir una tarjeta ocupada y `F` para
    comerla.

---

## 4. Antes de dar algo por terminado

1. El proyecto arranca limpio (§2).
2. Si se tocaron salas o puertas: recorrer el grafo completo a pie, ida y vuelta por cada
   puerta. Los bugs de transición no aparecen en la salida de debug.
3. Si se tocó el HUD o el mapa: verificar que el nombre de sala cambia al cruzar cada
   puerta, que `TAB` abre/cierra, que una cruz N/E/S/O no se solapa y que el tooltip no
   sale del viewport en 1920×1080 ni 1280×720.
4. Actualizar [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md) (tabla de estado del plan y
   sección afectada).
5. Reportar honestamente qué quedó sin verificar. El balance de combate y la sensación de
   movimiento **no se pueden validar leyendo la salida de debug** — decir explícitamente
   que hace falta que un humano lo juegue.

Para cambios del ciclo procedural, correr además:

```bash
godot --headless --path prueba_2 --script res://tests/run_map_tests.gd
godot --headless --path prueba_2 res://tests/run_lifecycle_tests.tscn
godot --headless --path prueba_2 res://tests/combat_smoke.tscn
```

Para cambios visuales de HUD/mapa:

```bash
godot --headless --path prueba_2 res://tests/hud_tests.tscn
godot --headless --path prueba_2 res://tests/part_tooltip_tests.tscn
godot --headless --path prueba_2 res://tests/body_panel_tests.tscn
godot --headless --path prueba_2 res://tests/map_overlay_tests.tscn
godot --headless --path prueba_2 res://tests/floor_route_tests.tscn
```
