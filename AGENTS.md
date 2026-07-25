# AGENTS.md — instrucciones para agentes de IA

Repositorio de un juego 2D en **Godot 4.7.1** (GDScript). Este archivo es la guía
operativa: qué tocar, qué no romper y cómo verificar. Para el diseño completo ver
[PLAN.md](PLAN.md); para la arquitectura ver [DOCUMENTACION.md](DOCUMENTACION.md).

---

## 1. Dónde trabajar

| Carpeta | Estado |
|---|---|
| `prueba_2/` | **Proyecto activo.** Todo el trabajo va acá. |
| `prototypes/slime_charge_movement/` | Banco de pruebas del impulso cargado, proyecto Godot aparte con tests propios. Se itera acá antes de tocar `prueba_2`. |
| `prueba/` | Legacy abandonado. **No modificar.** Se conserva solo por historial. |

Escena de arranque: `prueba_2/scenes/ui/title.tscn`. La partida vive en
`prueba_2/scenes/main.tscn`. Godot: `C:\Godot\Godot_v4.7.1-stable_win64.exe`.

Para probar la partida directo sin pasar por el título, correr con la escena como
argumento en vez de cambiar `run/main_scene`.

---

## 2. Cómo ejecutar y verificar

**Ningún cambio se da por bueno sin un arranque limpio.** Correr y leer la salida de debug:

```bash
"C:/Godot/Godot_v4.7.1-stable_win64_console.exe" --path "C:/ALFONSO/projects/Game Jam/prueba_2"
```

Si hay MCP de Godot disponible (`@coding-solo/godot-mcp`): `run_project` →
`get_debug_output` → `stop_project`. El MCP **no** edita árboles de nodos ni scripts:
los `.tscn` y `.gd` se escriben a disco como texto y el MCP solo ejecuta y verifica.

### Qué significa "limpio"

- `errors` vacío, o solo este warning conocido y esperado:
  `The signal "room_changed" is declared but never explicitly used in the class`
  (se conecta desde otros scripts, GDScript no lo detecta).
- Un `Debugger Break` **siempre** es un fallo, aunque el proceso siga vivo.

---

## 3. Reglas duras (romper esto rompe el juego)

1. **`Palette` no es autoload.** Es `scripts/core/palette.gd` con `class_name Palette`.
   Un autoload con ese nombre choca con el `class_name`. Además el cache de `class_name`
   no existe si nunca se abrió el editor, así que **siempre** usar:
   ```gdscript
   const Palette := preload("res://scripts/core/palette.gd")
   ```
   Nunca referenciar `Palette` "a pelo" desde un script.

2. **Warnings tratados como errores.** `var x := clamp(...)` y cualquier inferencia desde
   `Variant` rompe el arranque. Tipar explícito: `var x: float = clamp(...)`.
   Tampoco declarar variables locales que tapen propiedades de la clase base
   (ej. `var size` dentro de un `Control`).

3. **`_ready()` corre de hijos a padres.** El HUD no puede leer `GameState.current_room`
   en su `_ready()`, porque `main.gd` todavía no lo asignó. Todo lo que dependa del estado
   de sala se hace desde la señal `room_changed`, con guard de sala vacía en `_draw()`.

4. **El jugador se coloca ANTES de añadir la sala al árbol** (`Transition._swap_room`).
   Si se añade primero, las puertas de la sala nueva detectan al jugador todavía en la
   posición de la puerta anterior y encadenan otra transición. Además las puertas nacen
   desarmadas (`_armed = false`) y solo se arman cuando el jugador sale del área.

5. **Filtrar por el grupo `player`, nunca por tipo de nodo.** El boss también es un
   `CharacterBody2D`. Puertas, proyectiles y pickups usan `body.is_in_group("player")`.

6. **Capas de colisión** — respetarlas al añadir cualquier cosa:

   | Capa | Valor | Quién |
   |---|---|---|
   | 1 | 1 | Mundo (muros, props sólidos) y jugador |
   | 2 | 2 | Boss |
   | 3 | 4 | Huecos: solo se atraviesan durante el dash |

   Jugador: `collision_layer = 1`, `collision_mask = 5`, grupo `player`.

7. **Rutas con espacio.** El proyecto vive en `C:\ALFONSO\projects\Game Jam\` — siempre
   entre comillas en cualquier comando.

8. **Los overlays comparten `get_tree().paused`** (mapa, pausa, final). Cualquier overlay
   nuevo debe comprobar el estado antes de abrirse y usar `PROCESS_MODE_ALWAYS`, o queda
   uno encima de otro y sin forma de cerrarse.

9. **`GameState` sobrevive a los cambios de escena.** Al volver al título o reiniciar hay
   que llamar a `GameState.reset_run()`, o la partida nueva arranca con las salas visitadas
   y las habilidades de la anterior.

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

13. **Tocar las constantes del DASH cambia su alcance.** La velocidad ya no es constante
    (`_eased_speed()`), así que el alcance es la **integral de la curva**: hoy 326 px.
    Cruzar el hueco de `L2_BIOLAB` exige 210 px. Si el alcance baja de ahí, el hueco se
    vuelve infranqueable y **el juego se queda sin final**. Recalcular la integral antes
    de modificar `DASH_PEAK_SPEED`, `DASH_END_SPEED`, `DASH_EASE`, `DASH_RAMP` o
    `DASH_TIME`. En el impulso cargado esto no aplica: ahí la distancia la fija
    `_remaining` y la curva solo reparte el tiempo.

---

## 4. Layout de sala (no improvisar medidas)

| Elemento | Valor |
|---|---|
| Rejilla jugable | 13 × 7 celdas (`x` 0..12, `y` 0..6) |
| Celda | 120 × 120 px |
| Interior (suelo) | x `180…1740`, y `120…960` |
| Muro | banda de 120 px alrededor |
| Pantalla | 1920 × 1080, cámara fija centrada en (960, 540) |

- `cell_center(c) = Vector2(180, 120) + c * 120 + Vector2(60, 60)`
- **Carriles de puerta libres:** columna `x = 6` y fila `y = 3` no llevan props sólidos.
- Una puerta por lado como máximo, centrada, de 1 celda. El muro se parte en **dos**
  `ColorRect` + **dos** `CollisionShape2D` y el `Area2D` de la puerta va en el medio.
- Al partir un muro, el `CollisionShape2D` debe quedar centrado en su tramo. Un tramo que
  va de 1020 a 1860 tiene centro en **1440**, no en 1380. Este error ya se cometió y dejó
  huecos invisibles de 60 px.

---

## 5. Cómo hacer cambios típicos

### Añadir una sala

1. Entrada en `RoomDB.ROOMS` (`scripts/autoload/room_db.gd`): `level`, `level_name`,
   `room_name`, `grid`, `scene`, `doors`. Opcional `is_boss`.
2. `.tscn` en `scenes/rooms/` con `scripts/rooms/room.gd` en la raíz, muros partidos donde
   vayan las puertas y un `Marker2D` `SpawnN` / `SpawnS` / `SpawnE` / `SpawnO` por lado.
3. Nada más. HUD y mapa se dibujan solos desde `RoomDB` + `GameState.visited`.

`RoomDB._validate()` corre al arrancar y hace `push_error` si una puerta apunta a una sala
inexistente o si la vuelta no es simétrica (`A.doors.E == B` exige `B.doors.O == A`).

> **Cuidado:** si se añade una dirección al `doors` de una sala, hay que abrir el hueco y
> la puerta en su `.tscn`. Declararlo solo en el `RoomDB` no crea nada.

### Añadir decoración

No se toca el árbol de nodos. En la raíz del `.tscn` de la sala:

```
lamps = Array[Vector2i]([Vector2i(2, 1)])
dead_lamps = Array[Vector2i]([Vector2i(9, 1)])
tanks = Array[Vector2i]([Vector2i(1, 1)])
debris = Array[Vector2i]([Vector2i(4, 5)])
puddles = Array[Vector2i]([Vector2i(3, 2)])
sign_text = "SECTOR C-3"
sign_cell = Vector2i(3, 0)
```

`room.gd` los instancia en `_ready()`. Para un prop nuevo: escena en `scenes/props/`,
`preload` y un `@export var ... : Array[Vector2i]` en `room.gd`.

### Añadir una habilidad

`GameState.gain_ability(id)` / `GameState.has_ability(id)`. Sumar el id a `ABILITY_IDS`
en `scripts/ui/hud.gd` para que aparezca el slot. El estado vive **solo** en `GameState`,
nunca en el script del jugador — así sobrevive a los cambios de sala.

---

## 6. Estilo de código

- Tabs para indentar (estándar de Godot).
- Tipado estático siempre: `func f(x: float) -> void:`, `var v: Vector2 = ...`.
- Constantes en `SCREAMING_SNAKE_CASE` arriba del archivo; miembros privados con `_`.
- Comentarios en **español**, solo donde el "por qué" no se ve en el código. No comentar
  lo obvio.
- Nada de `print()` de depuración en el código que se entrega.
- Sin assets de arte: todo con `Polygon2D`, `ColorRect`, `_draw()` y `GradientTexture2D`.
- Colores **siempre** desde `Palette`, nunca hardcodeados en scripts.

### Paleta (IcyWitch)

`VOID #313638` · `FLOOR #32535f` · `WALL #0a777a` · `SLIME_BODY #4aa881` ·
`SLIME_CORE #73efe8` · `WARM_LIGHT #ecf3b0`

---

## 7. Formato de los `.tscn`

Se escriben a mano como texto. Al añadir un `[ext_resource]` hay que **subir `load_steps`**
en la cabecera: vale el número total de recursos (`ext_resource` + `sub_resource`) más 1.

Instanciar una escena hija:

```
[node name="DoorE" parent="." instance=ExtResource("2")]
position = Vector2(1800, 540)
direction = "E"
```

Grupos: `[node name="Slime" type="CharacterBody2D" groups=["player"]]`.

---

## 8. Antes de dar algo por terminado

1. El proyecto arranca limpio (§2).
2. Si se tocaron salas o puertas: recorrer el grafo completo a pie, ida y vuelta por cada
   puerta. Los bugs de transición no aparecen en la salida de debug.
3. Si se tocó el HUD o el mapa: verificar que el nombre de sala cambia al cruzar cada
   puerta y que `TAB` abre y cierra.
4. Actualizar `DOCUMENTACION.md` (tabla de estado del plan y sección afectada).
5. Reportar honestamente qué quedó sin verificar. El balance de combate y la sensación de
   movimiento **no se pueden validar leyendo la salida de debug** — decir explícitamente
   que hace falta que un humano lo juegue.
