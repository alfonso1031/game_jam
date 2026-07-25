# Diseño: checkpoints por piso e iluminación de salas

## Objetivo

Reducir el castigo por morir sin eliminar el costo del combate. La partida debe
recordar el piso más avanzado alcanzado, curar parcialmente al jugador cuando
progresa y usar ese punto para reaparecer. En paralelo, las trece salas deben
tener una distribución de luz suficiente sin perder la atmósfera del
laboratorio.

El checkpoint existe solamente durante la partida actual. No se escribe ningún
archivo de guardado y `GameState.reset_run()` elimina todo su estado.

## Decisiones aprobadas

- Hay un checkpoint explícito en la entrada de cada piso.
- Los checkpoints son `L3_CELDA`, `L2_ASCENSOR`, `L1_ASCENSOR` y
  `L0_VESTIBULO`.
- Alcanzar por primera vez un checkpoint más avanzado cura un corazón
  (`2` medios corazones).
- La curación se limita a la vida máxima.
- Volver a un piso anterior no mueve el checkpoint ni vuelve a curar.
- Reentrar al checkpoint actual tampoco vuelve a curar.
- Al morir se conserva el progreso de la partida y se reaparece con vida
  completa en el checkpoint más avanzado.
- El aviso de checkpoint permanece visible durante `3.0 s` y no pausa el juego.
- Las trece salas tendrán al menos tres focos encendidos.
- La energía, el radio, el color y el parpadeo de los focos no cambian.

## Arquitectura

### Datos de nivel

`prueba_2/autoload/room_db.gd` marcará con `is_checkpoint = true` las cuatro
salas de entrada. El checkpoint es una propiedad explícita del diseño del
nivel; no se deduce automáticamente de cualquier conexión entre pisos.

### Estado de la partida

`prueba_2/autoload/game_state.gd` será la única autoridad del checkpoint y
expondrá:

```gdscript
signal checkpoint_reached(room_id: String, healed_halves: int)

var checkpoint_room: String = ""
var checkpoint_level: int = -999
var checkpoint_spawn: String = ""

func set_initial_checkpoint(room_id: String, level: int, spawn_name: String = "") -> void
func try_reach_checkpoint(room_id: String, level: int, spawn_name: String) -> bool
```

`set_initial_checkpoint()` establece `L3_CELDA` sin curar ni mostrar el aviso.
`try_reach_checkpoint()` solo acepta un nivel numéricamente superior al
checkpoint actual. Si avanza:

1. actualiza `checkpoint_room`, `checkpoint_level` y `checkpoint_spawn`;
2. calcula la curación real hasta un máximo de dos medios corazones;
3. llama al mecanismo existente de curación para emitir `health_changed`;
4. emite `checkpoint_reached` una sola vez;
5. devuelve `true`.

`reset_run()` limpia el checkpoint junto con el resto del progreso.

### Activación durante una transición

`prueba_2/autoload/transition.gd` ya conoce la sala de destino, el punto de
entrada y consulta `RoomDB`. Después de completar el cambio de sala y actualizar
`GameState.current_room`, comprobará `is_checkpoint`.

- La carga inicial llama `set_initial_checkpoint()` y no concede recompensa.
- Una transición normal llama `try_reach_checkpoint()` con el `Spawn` usado
  para entrar.
- `respawn()` nunca activa ni recompensa un checkpoint.

Así se evita curar al morir, al retroceder o al atravesar repetidamente el mismo
ascensor.

### Muerte y reaparición

`prueba_2/game/main.gd` sustituirá el destino fijo `L3_CELDA` por
`GameState.checkpoint_room` y reaparecerá en `GameState.checkpoint_spawn`.
Mantendrá el comportamiento actual de recuperar la vida completa al morir.

`L2_ASCENSOR`, `L1_ASCENSOR` y `L0_VESTIBULO` contienen enemigos; dos tienen un
líder en el centro exacto de la sala. Guardar el punto de entrada evita
reaparecer encima del enemigo. En el recorrido lineal actual, los tres
checkpoints superiores conservan `SpawnS`, junto al ascensor por el que llegó
el jugador.

Si por un estado inválido no existe checkpoint, usará `START_ROOM` como
respaldo. El inventario, las habilidades, los bosses derrotados y las salas
limpias continúan en memoria como ahora.

## Aviso visual

Se añadirá un componente de UI aislado:

```text
prueba_2/ui/checkpoint_notice.tscn
prueba_2/ui/checkpoint_notice.gd
```

El componente escuchará `GameState.checkpoint_reached` y se montará desde
`prueba_2/game/main.tscn`. Mostrará:

```text
CHECKPOINT ALCANZADO
+1 CORAZÓN
```

La segunda línea reflejará la curación real. Si el jugador ya tiene la vida
completa, solo se mostrará `CHECKPOINT ALCANZADO`. El aviso aparecerá sin
pausar y su ciclo completo durará `3.0 s`, con un desvanecido durante los
últimos `0.35 s`. Un evento nuevo reinicia su temporizador en vez de apilar
avisos.

## Iluminación

La corrección será completamente data-driven en los `.tscn` de cada sala,
modificando únicamente `lamps_n`, `lamps_s`, `lamps_e` y `lamps_o`.
Los focos fundidos no cuentan para el mínimo de tres.

Las salas que ya cumplen el mínimo conservarán su distribución. Las cuatro que
actualmente tienen solo dos focos activos recibirán uno:

| Sala | Distribución resultante |
|---|---|
| `L3_PASILLO` | Dos focos arriba y uno centrado abajo. El foco inferior deja de estar fundido. |
| `L3_NUCLEO` | Dos focos abajo y uno en la pared este, evitando las puertas norte y oeste. |
| `L1_TALLER` | Dos focos abajo más uno centrado en esa misma pared; se conservan los fundidos superiores. |
| `L1_DEPOSITO` | Los dos focos laterales más uno centrado arriba. El foco superior deja de estar fundido. |

No se colocarán focos sobre el centro de una pared que tenga puerta o ascensor.
Los focos fundidos restantes se conservan como ambientación.

## Pruebas

### Automatizadas

- El estado inicial apunta a `L3_CELDA` sin curar.
- Alcanzar `L2_ASCENSOR` avanza el checkpoint y cura como máximo dos medios
  corazones.
- Repetir el mismo checkpoint no cura.
- Retroceder a un nivel inferior no cambia el checkpoint.
- Los checkpoints avanzan en orden hasta `L0_VESTIBULO`.
- Cada checkpoint conserva el `Spawn` por el que se alcanzó.
- `reset_run()` elimina el checkpoint.
- La curación nunca supera `max_health_halves`.
- Las trece escenas de sala cargan.
- Cada sala declara al menos tres focos activos.
- Ningún foco activo comparte pared e índice con un foco fundido.
- La escena de aviso carga y responde al contrato de la señal.

### Manuales

- Recorrer los cuatro pisos y confirmar un solo aviso por piso durante tres
  segundos.
- Llegar herido a un piso nuevo y comprobar la curación de un corazón.
- Volver a un piso anterior, morir y confirmar la reaparición en el checkpoint
  más avanzado y junto a su ascensor, no en el centro ocupado por enemigos.
- Morir varias veces sin recibir curación adicional de checkpoint.
- Recorrer las trece salas y comprobar que no hay focos sobre puertas, zonas
  quemadas por exceso de luz ni rincones críticos ilegibles.

## Documentación afectada

- `docs/ARQUITECTURA.md`: flujo de checkpoint, muerte y regla de iluminación.
- `docs/agents/REFERENCIA.md`: checkpoints de piso y mínimo de focos.
- `AGENTS.md`: el checkpoint no retrocede ni concede curación repetible.

## Fuera de alcance

- Guardado persistente en disco.
- Selector manual de checkpoint.
- Estaciones físicas de guardado.
- Cambios a la dificultad, daño, drops o número de enemigos.
- Nuevos sonidos o arte para el aviso.
- Cambios de energía, alcance, color o parpadeo de las lámparas.
