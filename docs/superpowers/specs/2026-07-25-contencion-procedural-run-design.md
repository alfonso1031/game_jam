# Diseño: Contención procedural y ciclo de partida

## Estado del documento

Especificación aprobada para la siguiente implementación. El alcance jugable es
exclusivamente el primer piso, **NIVEL -3 · CONTENCIÓN**. Los pisos -2, -1 y 0
solo reciben contratos de extensión; no se generan ni se vuelven jugables en
esta fase.

Este documento sustituye, para la implementación nueva, tres comportamientos del
MVP actual:

- el grafo fijo de salas de `RoomDB.ROOMS`;
- el checkpoint como lugar de respawn después de morir;
- la necesidad de `squeeze` para atravesar rejillas.

También sustituye la irreversibilidad de slots descrita en
`docs/DIRECCION.md`: comer, perder o sacrificar una parte equipada vuelve a
liberar su slot.

## Objetivo

Construir una partida corta, rejugable y determinista en la que Contención se
organiza de forma distinta para cada semilla. El jugador empieza frágil, decide
entre conservar habilidades o consumirlas como recurso y, al morir, termina la
partida actual en lugar de reaparecer.

La generación debe crear decisiones, no laberintos imposibles. Toda semilla
aceptada tiene una ruta válida desde la celda inicial hasta el encuentro final,
respeta el máximo de salas y se puede reconstruir exactamente para depurarla.

## Contratos rastreados en el proyecto actual

La consulta de Graphify y la verificación directa del código muestran estas
relaciones actuales:

```text
GameState.damage_halves()
  └─ emite died
       └─ activa Main._on_died()
            ├─ llama GameState.reset_health()
            └─ llama Transition.respawn()

Transition.load_initial() / go_to() / respawn()
  ├─ escriben GameState.current_room
  ├─ escriben GameState.visited
  └─ emiten GameState.room_changed

GameState.health_changed
  ├─ redibuja HUD
  └─ redibuja InventoryUI

PauseMenu._restart() / _to_title()
  └─ llaman GameState.reset_run()
```

La implementación conservará las señales y la propiedad del estado, pero
`Main._on_died()` dejará de restaurar vida y llamar a `Transition.respawn()`.
Cuando `died` se emita, la partida terminará y mostrará el resumen.

## Unidad de vida

La interfaz deja de dibujar gotas o corazones discretos y usa una barra.

| Regla | Valor |
|---|---:|
| Vida máxima | `15 HP` |
| Vida al iniciar una partida | `5 HP` |
| Equivalencia de diseño | `1 HP = ½ corazón` |
| Comer una parte equipada | `+1 HP` |
| Completar Contención | `+2 HP`, limitado a 15 |
| Sacrificar una parte | `0 HP` de curación |

Internamente se puede conservar el nombre `health_halves` durante la migración:
un medio corazón actual equivale exactamente a un HP nuevo. La UI y la
documentación para el jugador deben hablar únicamente de HP.

Recibir daño nunca reduce la vida por debajo de cero. Si una mecánica existente
evita la muerte antes de emitir `GameState.died`, la partida continúa; una vez
emitido `died`, el final de partida es definitivo.

## Ciclo de una partida

```text
Título
  └─ Nueva partida
       ├─ seed nueva
       ├─ 5/15 HP
       ├─ inventario vacío
       └─ genera Contención
            ├─ explorar / combatir / elegir partes
            ├─ morir ──> resumen ──> nueva partida o título
            └─ superar el encuentro final
                 ├─ +2 HP
                 ├─ marca Contención superada en esta partida
                 └─ muestra la ruta de ascenso
```

No existe guardado en disco. Seed, mapa, vida, inventario, salas visitadas y
estadísticas viven solo durante la partida actual.

### Nueva partida

`start_new_run()` realiza una única operación lógica:

1. limpia todo el estado de la partida anterior;
2. elige o recibe una seed;
3. fija `max_hp = 15` y `hp = 5`;
4. vacía slots, pendientes y usos por sala;
5. genera y valida Contención;
6. carga la sala inicial;
7. comienza a registrar estadísticas.

Reiniciar desde pausa crea una partida nueva, incluida una seed nueva. Para
reproducir un fallo, las pruebas y herramientas de depuración pueden pasar una
seed explícita.

### Muerte

Al emitirse `GameState.died`:

1. se bloquean entradas y transiciones nuevas;
2. se registra la causa si está disponible;
3. se termina la partida actual;
4. se abre un resumen con zona, salas visitadas, partes comidas, partes
   sacrificadas y seed;
5. el jugador elige nueva partida o volver al título.

No se conserva el mapa y no se reaparece en la última sala. Empezar otra partida
vuelve a `5/15 HP`, inventario vacío y una generación nueva.

### Hito de piso

Superar Contención es un hito de progreso, no un checkpoint de respawn:

- se concede `+2 HP` una sola vez;
- la curación se limita a `15 HP`;
- se marca el piso como superado en la partida actual;
- se muestra durante `3.0 s` la ruta de ascenso;
- no se escribe un archivo de guardado;
- no cambia la regla de muerte definitiva.

## Modelo procedural

### Semilla y reintentos

La entrada del generador es el par:

```text
(run_seed, generation_attempt)
```

Para una misma pareja, el resultado debe ser idéntico. Si una propuesta no pasa
el validador, el generador incrementa `generation_attempt` y vuelve a intentar
con una derivación determinista de la misma `run_seed`.

Se permiten como máximo `128` intentos. Si ninguno cumple las reglas, la partida
no arranca: se muestra un error de generación con seed e intento. Está prohibido
relajar reglas silenciosamente para aceptar un mapa inválido.

### Tamaño y estructura

- El camino principal tiene entre `6` y `8` salas, contando inicio y final.
- El mapa completo tiene como máximo `12` salas.
- El límite de 12 incluye ramificaciones y destinos de rejilla.
- Las salas ocupan coordenadas enteras sin repetirse.
- Una sala puede conectar por `N`, `E`, `S` y `O`; las configuraciones en cruz
  son válidas.
- Las ramas normales deben reconectar con el grafo principal o terminar en una
  rejilla.
- Las puertas normales son bidireccionales, salvo que una plantilla declare
  explícitamente una puerta de un solo sentido.
- Una puerta de un solo sentido puede impedir volver, pero nunca puede cortar la
  única ruta restante hacia el encuentro final.

### Hitos obligatorios

Toda generación contiene, en este orden sobre una ruta alcanzable:

1. **Entrada / tutorial**.
2. **Preboss**.
3. **Boss y elección humana**.

El tutorial entrega aleatoriamente una parte básica de `EXP-01` o `EXP-02`. La
elección final presenta la parte del experimento y su alternativa humana según
el contrato narrativo de `docs/DIRECCION.md`.

Los hitos son roles de sala, no IDs fijos. El generador elige una plantilla
compatible para cada rol.

## Contenido de salas

Después de fijar la topología y los hitos, las salas normales reciben contenido
con esta distribución:

| Tipo | Probabilidad | Contenido |
|---|---:|---|
| Combate fácil | 40% | 1 enemigo |
| Combate difícil | 30% | 2–3 enemigos |
| Vacía | 20% | Sin combate ni loot obligatorio |
| Evento de cierre | 10% | 3 salidas iniciales; 2 se cierran |

Estas probabilidades no se aplican a entrada/tutorial, preboss, boss/elección ni
a los destinos exclusivos de rejilla.

### Evento de cierre

La sala nace con tres salidas transitables. Al activarse el evento, dos se
cierran y una permanece. El validador debe demostrar que la salida conservada
mantiene una ruta hasta el boss. La elección puede variar por seed, pero nunca
puede producir un softlock.

## Rejillas

Una rejilla es una salida opcional y costosa; no exige la bandera `squeeze`.

### Aparición

- Solo una sala de combate elegible puede recibir rejilla.
- Cada sala tiene como máximo una rejilla.
- No todas las salas de combate deben tenerla.
- Cada combate elegible tiene `60%` de probabilidad de recibirla.
- Si el mapa tiene al menos un combate elegible, debe existir al menos una
  rejilla en la generación aceptada.
- Dos rejillas nunca comparten sala de destino.
- El destino cuenta dentro del máximo de 12 salas.

Primero se hace el roll de `60%` de cada combate elegible. Si todos fallan, el
generador promueve de forma determinista uno de esos combates para cumplir el
mínimo de una rejilla.

### Destinos

Los destinos exclusivos de rejilla usan:

| Tipo | Probabilidad |
|---|---:|
| Sala vacía | 40% |
| Combate | 20% |
| Loot | 40% |

Una sala de loot exclusiva no necesita entrada normal. Puede tener una salida
normal hacia adelante si la topología validada la permite.

### Coste

Al intentar atravesar:

1. si hay una parte equipada, el jugador elige cuál sacrificar;
2. la parte desaparece y su slot queda libre;
3. si no hay partes equipadas, la rejilla cuesta `1 HP`;
4. con `1 HP`, se pide confirmación explícita;
5. confirmar reduce a `0 HP` y termina la partida;
6. cancelar deja al jugador en la sala.

Sacrificar no cura. Atravesar una rejilla nunca consume un objeto adicional.

## Partes y slots

Los slots representan partes actualmente asimiladas, no decisiones permanentes.

- Equipar ocupa un slot compatible.
- Comer una parte equipada la elimina, libera el slot y cura `1 HP`.
- Perder una parte la elimina y libera el slot, sin curar.
- Sacrificarla en una rejilla la elimina y libera el slot, sin curar.
- El jugador puede conservar una habilidad activa o gastar esa parte para
  curarse/escapar; esa tensión es deliberada.
- Una parte que ya no está equipada deja de aportar habilidad, modificadores y
  apariencia corporal.

## Arquitectura propuesta

### Responsabilidades

| Componente | Ubicación | Responsabilidad |
|---|---|---|
| `RunMap` | `prueba_2/core/run_map.gd` | Modelo puro de salas, coordenadas, conexiones, roles y contenido |
| `MapGenerator` | `prueba_2/core/map_generator.gd` | Generación determinista y validación sin instanciar nodos |
| `RoomDB` | `prueba_2/autoload/room_db.gd` | Catálogo de plantillas y metadatos; deja de ser el mapa de una partida |
| `RunManager` | `prueba_2/autoload/run_manager.gd` | Ciclo de partida, seed, `RunMap`, estadísticas e hitos |
| `GameState` | `prueba_2/autoload/game_state.gd` | HP y estado persistente del jugador durante la partida |
| `Inventory` | `prueba_2/autoload/inventory.gd` | Partes equipadas, slots y operaciones de comer/perder/sacrificar |
| `RoomAssembler` | `prueba_2/world/rooms/room_assembler.gd` | Instancia una plantilla con el contenido descrito por `RunMap` |
| `Transition` | `prueba_2/autoload/transition.gd` | Cambia entre IDs de la instancia actual y coloca al jugador |
| `main.gd` | `prueba_2/game/main.gd` | Ensambla servicios, jugador, sala y overlays |

`core/` no conoce autoloads, escenas ni nodos del juego. `MapGenerator` recibe
datos simples y devuelve un `RunMap`; no modifica `GameState`, `Inventory` ni el
árbol de escenas.

`RunManager` es una excepción documentada a la regla antigua de “todo estado del
jugador en GameState”: no duplica vida ni inventario. Solo es autoridad sobre la
identidad y ciclo de la partida, el mapa generado y sus estadísticas.

### Datos mínimos

Cada sala generada conserva:

```gdscript
{
	"id": String,
	"grid": Vector2i,
	"template_id": String,
	"role": StringName,
	"content_type": StringName,
	"doors": Dictionary,       # dirección -> room_id
	"one_way": Dictionary,     # dirección -> bool
	"grate_target": String,
	"visited": bool,
	"cleared": bool,
}
```

El estado visitada/limpia puede vivir en `GameState`, pero `RunMap` debe exponer
una API única para que UI, transición y ensamblador no conozcan su almacenamiento
interno.

### Señales

Contrato inicial de `RunManager`:

```gdscript
signal run_started(seed: int)
signal map_generated(run_map: RefCounted)
signal floor_completed(floor_id: StringName, healed_hp: int)
signal run_ended(summary: Dictionary)
```

La UI escucha señales y lee snapshots. Nunca decide contenido, modifica el mapa
ni sondea el estado cada frame.

## Validación obligatoria

Una propuesta solo es aceptable si cumple todo:

- entre 6 y 8 salas en el camino principal;
- máximo 12 salas en total;
- coordenadas únicas;
- hitos obligatorios presentes y en orden;
- boss alcanzable desde la entrada;
- toda sala alcanzable por alguna ruta válida;
- cada conexión normal apunta a una sala existente;
- direcciones y desplazamientos de coordenadas coinciden;
- reciprocidad de puertas, salvo `one_way`;
- ninguna puerta de un solo sentido corta la única ruta al boss;
- cada rol tiene una plantilla compatible con sus puertas;
- eventos de cierre conservan la ruta al boss;
- máximo una rejilla por sala;
- rejillas solo en fuentes elegibles;
- al menos una rejilla cuando existe combate elegible;
- destinos de rejilla únicos;
- distribución de contenido perteneciente a su tabla;
- ningún destino hace superar el máximo de salas.

## Pruebas

### Generador headless

Ejecutar al menos `1.000` seeds:

- cero mapas inválidos después de sus reintentos;
- mismo `(seed, attempt)` produce JSON estructural idéntico;
- todas las reglas del validador se prueban por separado con fixtures inválidos;
- proporciones globales de salas normales dentro de ±5 puntos porcentuales de
  `40/30/20/10`;
- aparición de rejilla dentro de ±5 puntos de `60%` sobre combates elegibles;
- destinos de rejilla dentro de ±5 puntos de `40/20/40`;
- ninguna seed aceptada excede 12 salas ni comparte destinos de rejilla.

### Ciclo de partida

- una nueva partida inicia en `5/15 HP` con inventario vacío;
- comer libera slot y cura exactamente `1 HP`;
- perder y sacrificar liberan slot sin curar;
- una rejilla sin partes cuesta `1 HP`;
- confirmar una rejilla con `1 HP` termina la partida;
- cancelar no cambia vida, sala ni inventario;
- completar Contención cura una sola vez hasta `2 HP`;
- `GameState.died` termina la partida y no llama `Transition.respawn()`;
- reiniciar genera una partida y seed nuevas;
- pasar una seed explícita reproduce el mismo mapa.

### Integración

- el proyecto arranca sin errores ni warnings nuevos;
- todas las plantillas y escenas generadas cargan;
- se puede recorrer cada dirección declarada;
- no se encadenan transiciones al aparecer junto a una puerta;
- el resumen de muerte refleja seed y estadísticas reales.

## Documentación que cambiará con la implementación

- `docs/ARQUITECTURA.md`: generación, transición, vida, muerte y ciclo de partida.
- `docs/CONVENCIONES.md`: propiedad separada entre `RunManager`, `GameState` e
  `Inventory`.
- `docs/DIRECCION.md`: slots reutilizables y rejillas sin `squeeze`.
- `docs/agents/REFERENCIA.md`: plantilla de sala procedural y reglas de validación.
- `AGENTS.md`: eliminar el respawn de checkpoint y añadir invariantes del generador.

## Fuera de alcance

- Generar o jugar Bio-Laboratorios, Mantenimiento o Superficie.
- Persistencia en disco o selección de partida guardada.
- Editor visual de mapas.
- Generación procedural de geometría dentro de una plantilla.
- Balance definitivo de enemigos, partes o bosses.
- Cambiar el movimiento cargado, el DASH o su audio.
