# Mapa dirigido, rejillas de huida y sangre vectorial

**Estado:** aprobado el 26 de julio de 2026  
**Alcance:** primer piso, Contención  
**Proyecto activo:** `prueba_2/`

## Objetivo

Reestructurar Contención como un mapa procedural ramificado en el que todas
las conexiones avanzan hacia el jefe. Ninguna puerta ni rejilla permite
regresar a una sala anterior. Cada sala generada debe conservar al menos una
ruta dirigida hasta el jefe.

Además:

- la segunda sala entrega la primera parte sin mostrar el cadáver humano
  provisional;
- las rejillas de huida aparecen claramente en combates escapables;
- la sangre usa una estética plana y vectorial 2D, coherente con el juego.

## Invariantes del recorrido

El grafo de salas es dirigido y acíclico.

1. El jefe es el único nodo sin salidas.
2. Toda sala distinta del jefe tiene al menos una ruta dirigida hasta él.
3. Toda conexión aumenta la capa topológica: no hay ciclos ni aristas de
   retorno.
4. Al cruzar una puerta o una rejilla, la conexión de entrada queda
   inutilizable.
5. Las ramas pueden separarse y reconectarse, pero no terminar en callejones
   sin salida.
6. Ninguna rejilla puede ser necesaria para alcanzar al jefe: siempre existe
   una ruta formada por puertas.
7. Debe existir al menos una bifurcación real después de la segunda sala.

Representación conceptual:

```text
INICIO → CUERPO → BIFURCACIÓN ─→ COMBATE ───────┐
                         └─→ VACÍA → DIFÍCIL ──┤
                                               ↓
                       PREBOSS ───────────────→ JEFE
                          └─rejilla→ DESTINO ─→ JEFE
```

La geometría puede girar en N/E/S/O, formar cruces y tener múltiples entradas
selladas. La flecha representa el sentido jugable, no una orientación
cardinal fija.

## Hitos obligatorios

### Sala 1: inicio

- Rol `entry`.
- Contenido tutorial.
- Exactamente una salida dirigida.
- No contiene rejilla.

### Sala 2: primera parte

- Rol `body`.
- Conserva dos puertas visibles: entrada y avance.
- La entrada está cerrada e inutilizable después de llegar.
- La salida continúa hacia la primera capa procedural.
- Entrega una parte aleatoria de `FIRST_PART_POOL`, una sola vez por partida.
- No contiene rejilla.

### Preboss

- Conserva el encuentro de EXP07.
- Se considera un combate difícil escapable.
- La salida normal al jefe se habilita al derrotar el encuentro.
- La rejilla permite abandonar EXP07 y conduce a una ruta alternativa que
  también termina en el jefe.

### Jefe

- Es el único sumidero del grafo.
- No contiene rejilla ni salida.
- Todas las ramas de puertas y todos los destinos de rejilla pueden alcanzarlo.

## Generación de salas y ramas

La generación se divide en dos presupuestos:

- **Grafo de puertas:** mantiene una ruta crítica de 6–8 salas y añade ramas
  hasta un máximo de 12 salas conectadas por puertas.
- **Destinos de rejilla:** se reservan después, uno por cada combate
  escapable. No consumen el presupuesto de 12 salas de puertas, pero sí
  forman parte del grafo dirigido y deben reconectarse a una capa posterior.

El generador crea primero la ruta crítica y reserva el jefe. Después añade al
menos una bifurcación y reconecta cada rama a una sala de una capa posterior.
Finalmente asigna contenido y añade las rutas de rejilla.

Las salas procedurales comunes, tanto en la ruta crítica como en ramas, usan:

| Contenido | Probabilidad |
|---|---:|
| Combate fácil | 50 % |
| Combate difícil | 30 % |
| Vacía | 20 % |

`closure` deja de formar parte de la tabla normal. La suma y las proporciones
se verifican sobre un conjunto amplio de semillas, sin sesgar las semillas
aceptadas mediante reintentos por falta de espacio.

## Modelo de conexiones dirigidas

`RunMap` debe distinguir:

- salidas transitables hacia delante;
- entradas visuales ya consumidas;
- llegadas desde rejilla;
- capa topológica de cada sala.

Las puertas visibles se construyen con la unión de entradas y salidas. Solo
las salidas generan un área capaz de llamar a `Transition.go_to()`. Una
entrada se representa cerrada y nunca vuelve a habilitarse.

El mapa local dibuja las conexiones conocidas respetando su sentido, pero
mantiene la regla actual de no revelar salas antes de visitarlas.

## Rejillas de huida

### Fuente

Una rejilla jugable solo se origina en:

- combate fácil normal;
- combate difícil normal;
- preboss.

Cada uno de esos combates tiene exactamente una rejilla en una pared libre.
Las salas `entry`, `body`, vacías, loot, jefe y los combates obligatorios
provenientes de una rejilla no originan rejillas.

La puerta de avance normal permanece sellada mientras existan enemigos. La
rejilla se mantiene disponible para huir sin completar el combate y conserva
el coste ya definido: sacrificar una parte o pagar vida.

### Destino

Cruzar una rejilla es irreversible. El destino no materializa una rejilla de
retorno. En su lugar contiene una o más salidas por puertas hacia una capa
posterior del grafo.

| Destino | Probabilidad | Regla |
|---|---:|---|
| Vacío | 40 % | Salida abierta hacia delante |
| Combate obligatorio | 20 % | Sin rejilla; salida sellada hasta vencer |
| Loot | 40 % | Una parte aleatoria y salida hacia delante |

El combate obligatorio encontrado tras huir no ofrece una segunda huida. Así
se evita una cadena recursiva de rejillas y se conserva el riesgo de la
decisión.

La rejilla del preboss conecta a un destino cuya siguiente salida alcanza al
jefe sin regresar a EXP07.

### Visibilidad

La rejilla conserva tamaño equivalente a una puerta y montaje sobre pared.
Para que no desaparezca en la penumbra:

- el sprite recibe mayor luminancia;
- un borde cian plano usa `Palette.SLIME_CORE`;
- un halo tenue no altera la iluminación general de la sala;
- el texto `E · USAR REJILLA` solo aparece dentro del sensor.

## Loot y persistencia

Una sala loot de rejilla instancia exactamente un `PartPickup` con un
`part_id` determinado por la semilla. La recompensa se registra por ID de
sala y no reaparece después de reclamarla durante la partida actual.

Se conservan las reglas existentes:

- no se duplica una parte ya equipada;
- si los seis slots están llenos, el pickup permanece en el mundo;
- no existe inventario pendiente.

## Segunda sala sin cadáver provisional

`BodySource` conserva únicamente la autoridad de la recompensa.

- Se elimina el nodo `Sprite2D` que usa `inert_body.png`.
- Se eliminan `inert_body.png` y su sidecar `.import` del repositorio.
- No se crea silueta, cápsula ni monstruo provisional.
- El rastro termina en un charco plano y en el `PartPickup`.
- Cuando exista el asset definitivo del monstruo, podrá añadirse como
  presentación sin cambiar la lógica de recompensa.

La eliminación del asset es recuperable desde el historial de Git.

## Sangre vectorial 2D

Se reemplazan, manteniendo sus rutas de runtime:

- `assets/environment/blood/blood_drops.png`;
- `assets/environment/blood/blood_drag.png`;
- `assets/environment/blood/blood_pool.png`.

Los tres recursos serán PNG con alfa y lenguaje visual compartido:

- formas planas y bordes limpios;
- vista cenital;
- dos tonos borgoña y un contorno oscuro;
- pequeñas facetas o cortes geométricos;
- sin textura fotográfica, brillo húmedo, volumen realista, reflejos ni
  sombras proyectadas;
- contraste suficiente sobre `Palette.VOID` y `Palette.FLOOR`;
- sin texto ni marcas de agua.

Se generan como una familia visual y después se ajustan las regiones y escalas
de `blood_trail.gd` a las dimensiones finales.

## Validación

### Generación

Sobre al menos 1.000 semillas:

- sala 1 tiene una salida;
- sala 2 tiene una entrada cerrada y una salida;
- existe al menos una bifurcación;
- el grafo no contiene ciclos;
- ninguna conexión tiene inversa transitable;
- el jefe es el único nodo sin salidas;
- desde cada sala existe un camino dirigido al jefe;
- las ramas se reconectan;
- las salas normales se aproximan a 50/30/20;
- toda sala escapable tiene una rejilla y ninguna sala inválida la origina;
- los destinos se aproximan a 40/20/40;
- ningún destino de rejilla permite regresar a su fuente.

### Ensamblaje y flujo

- Las entradas se dibujan cerradas y no responden a interacción.
- Las salidas viajan únicamente hacia delante.
- Huir deja inaccesible la sala abandonada.
- El combate obligatorio no contiene rejilla.
- La ruta de puertas hasta el jefe existe aunque se ignoren todas las
  rejillas.
- La segunda sala no contiene el sprite humano y sí conserva la primera parte.
- El loot se reclama una sola vez.

### Visual

- Captura de una rejilla sobre cada orientación N/E/S/O.
- Captura del rastro entre inicio y segunda sala.
- Inspección de alfa y cobertura de los tres PNG.
- Arranque real del juego sin warnings ni recursos faltantes.

## Fuera de alcance

- Crear o inventar el monstruo definitivo de la segunda sala.
- Cambiar el coste de las rejillas.
- Cambiar el combate, recompensa o assets de EXP07.
- Implementar pisos posteriores a Contención.
