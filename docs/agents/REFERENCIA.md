# Referencia técnica para agentes

Material de consulta: medidas, recetas y convenciones. Las **reglas duras** y el flujo de
verificación están en [`AGENTS.md`](../../AGENTS.md), en la raíz del repositorio — ese
archivo se lee primero.

---

## 1. Dónde va cada archivo

Godot es composición de nodos, no ECS ni MVC. La organización es **por feature**: la
escena vive junto a su script, nunca en árboles paralelos `scenes/` y `scripts/`.

| Carpeta | Qué va |
|---|---|
| `assets/` | Arte, audio, fuentes. Hoy solo `icon.svg` |
| `autoload/` | Los tres singletons: `game_state`, `room_db`, `transition` |
| `core/` | Sin dependencias del juego: `palette.gd`, `layers.gd` |
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

1. Entrada en `RoomDB.ROOMS` (`autoload/room_db.gd`): `level`, `level_name`,
   `room_name`, `grid`, `scene`, `doors`. Opcional `is_boss`.
2. `.tscn` en `world/rooms/` con `world/rooms/room.gd` en la raíz, muros partidos donde
   vayan las puertas y un `Marker2D` `SpawnN` / `SpawnS` / `SpawnE` / `SpawnO` por lado.
3. Nada más. HUD y mapa se dibujan solos desde `RoomDB` + `GameState.visited`.

`RoomDB._validate()` corre al arrancar y hace `push_error` si una puerta apunta a una sala
inexistente o si la vuelta no es simétrica (`A.doors.E == B` exige `B.doors.O == A`).

> **Cuidado:** si se añade una dirección al `doors` de una sala, hay que abrir el hueco y
> la puerta en su `.tscn`. Declararlo solo en el `RoomDB` no crea nada. Este error ya se
> cometió: el pasillo tenía tres salidas declaradas y una sola abierta.

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

Evitar el índice del carril de puerta (`6` en N/S, `3` en E/O) del lado que tenga puerta.

`room.gd` los instancia en `_ready()`. Para un prop nuevo: escena en `world/props/`,
`preload` y un `@export var ... : Array[Vector2i]` en `world/rooms/room.gd`.

### Añadir una habilidad

`GameState.gain_ability(id)` / `GameState.has_ability(id)`. Sumar el id a `ABILITY_IDS`
en `ui/hud.gd` para que aparezca el slot. El estado vive **solo** en `GameState`,
nunca en el script del jugador — así sobrevive a los cambios de sala.

### Marcar un checkpoint de piso

Añadir `"is_checkpoint": true` a la sala de entrada del piso en `RoomDB.ROOMS`. La
transición registra automáticamente el nivel y el `Spawn<opuesto>` usado al entrar; no
se llama a `GameState.try_reach_checkpoint()` desde la sala.

Reglas del contrato:

- solo avanza si el `level` es mayor que el guardado;
- cura como máximo 2 medios corazones y emite la cantidad realmente curada;
- el respawn reutiliza el `Spawn` de entrada para no colocar al slime encima de enemigos;
- `reset_run()` debe borrar sala, nivel y spawn: no hay persistencia entre partidas.

---

## 4. Estilo de código

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
