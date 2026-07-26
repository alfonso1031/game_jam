# Cuerpo, rastro y movimiento de gusano

**Estado:** diseño aprobado

**Alcance:** `NIVEL -3 · CONTENCIÓN`

**Seed de regresión:** `1785033756`

## Objetivo

La partida debe comunicar desde el primer minuto que el slime está buscando un
cuerpo. La ruta inicial usa sangre como guía, la segunda sala contiene el
cuerpo inerte y ese cuerpo entrega la primera parte. En paralelo, el movimiento
base deja de parecer un salto de resorte y pasa a sentirse como un organismo que
se arrastra sobre el vientre, sin eliminar la carga que determina la distancia.

El cambio también corrige dos problemas de lectura:

- el mapa local no debe revelar salas ni puertas antes de visitarlas;
- las puertas físicas, las conexiones del mapa y las pistas ambientales deben
  provenir del mismo descriptor de `RunMap`.

## 1. Ruta inicial y cuerpo

### Orden obligatorio

El camino principal conserva entre 6 y 8 salas, pero sus dos primeras posiciones
quedan fijadas:

1. `main_path[0]`: rol `entry`, contenido `tutorial`;
2. `main_path[1]`: rol `body`, contenido `body_reward`.

Los hitos existentes se mantienen:

- `main_path[-2]`: `preboss`;
- `main_path[-1]`: `boss_choice`.

La sala del cuerpo es siempre alcanzable directamente desde el tutorial por una
puerta normal bidireccional. No puede ser destino de rejilla, cierre, combate ni
ramificación.

### Primera parte

El cuerpo inerte contiene una recompensa determinada durante la generación. El
pool inicial es la unión de las partes de EXP-01 y EXP-02:

- `acid_stinger`;
- `serrated_jaw`;
- `hydraulic_legs`;
- `bio_netcaster`.

La elección usa el RNG de `(run_seed, generation_attempt)` y se guarda en el
descriptor de la segunda sala como `reward_part_id`. Por tanto, reiniciar con la
misma seed entrega la misma parte.

El cuerpo instancia la recompensa mediante el flujo existente de `part_pickup`:
al acercarse se equipa automáticamente si existe un slot compatible libre; si
los slots están llenos, la interfaz vigente permite gestionarla. Una marca de
partida en `GameState` registra que la recompensa de esa sala ya fue tomada.
Salir y volver a entrar no la duplica.

### Cuerpo provisional

El cuerpo es un prop cenital, inerte y sin colisión bloqueante. Por esta
iteración no habla, combate ni inicia una cinemática. Su única responsabilidad
jugable es alojar la primera parte.

El asset debe:

- leerse como un cuerpo humano abandonado en un laboratorio;
- mantener la perspectiva cenital y la paleta fría de Contención;
- tener sangre oscura alrededor sin ocultar la parte ofrecida;
- usar fondo transparente y no incluir texto.

## 2. Rastro de sangre

El rastro solo guía desde el tutorial hasta el cuerpo. Después de encontrarlo,
la exploración vuelve a depender de puertas y mapa.

### Distribución

- En la sala tutorial, las gotas parten de una zona cercana al centro y avanzan
  hacia la puerta cuyo destino es `main_path[1]`.
- En la sala del cuerpo, continúan desde la puerta de entrada hasta el prop.
- No aparecen en ramas, rejillas ni el resto del camino principal.

La orientación se calcula desde `RunMap.rooms[room_id]["doors"]`; no se codifican
direcciones fijas. Así funciona igual si la segunda sala queda al norte, este,
sur u oeste.

Se generan tres decals transparentes reutilizables:

1. gotas pequeñas;
2. mancha de arrastre;
3. charco final.

Los decals son puramente visuales: no tienen colisión, daño ni interacción. Se
colocan debajo de actores y pickups, pero encima del fondo.

## 3. Puertas y fuente de verdad

`RunMap` continúa siendo la única autoridad de navegación.

Para cada sala y dirección cardinal:

```text
RunMap.doors contiene dirección
    ⇔ existe Door<dirección>
    ⇔ existe Spawn<dirección>
    ⇔ el mapa puede dibujar esa conexión cuando ambos extremos fueron visitados
```

`RoomAssembler` materializa exactamente las claves del descriptor. `Door`
resuelve su destino desde el mismo diccionario al activarse; ninguna escena
mantiene un `target_id` independiente.

La seed `1785033756` se conserva como regresión. La prueba debe ensamblar todas
sus salas y comparar nodos `DoorN/E/S/O` y `SpawnN/E/S/O` contra las conexiones
generadas. También comprueba coordenadas y retornos bidireccionales.

## 4. Descubrimiento del mapa local

Una sala se descubre al entrar, no al verla como vecina.

- Solo se dibujan IDs cuyo valor en `GameState.visited` sea `true`.
- La sala actual también debe estar visitada por el flujo de transición.
- No existen tarjetas `?` para vecinos posibles.
- Un enlace normal aparece únicamente cuando sus dos extremos están visitados.
- Las muescas de puerta se dibujan únicamente para esos enlaces visibles.
- Una rejilla y su destino siguen apareciendo después de usarla y descubrir la
  conexión, respetando `discovered_grates`.

El layout se calcula con el subconjunto visible, no con todas las salas de la
seed. De ese modo el tamaño, posición y escala del mapa no filtran la extensión
del piso todavía oculto.

## 5. Movimiento de arrastre

### Control conservado

No cambia el esquema de entrada:

1. mantener una dirección inicia y acumula carga;
2. la barra muestra potencia y umbrales;
3. soltar antes de `MIN_CHARGE_TIME` produce fizzle;
4. soltar una carga válida recorre una distancia entre `112` y `520 px`.

DASH, invulnerabilidad, embestida, knockback y partes equipadas siguen siendo
sistemas separados.

### Perfil de desplazamiento

El impulso base deja la curva de pico rápido y frenada exponencial. El objetivo
inicial es una velocidad de arrastre cercana a `480 px/s`, con una entrada y
salida visuales breves para evitar un corte seco. La distancia continúa siendo
la autoridad: una carga mayor dura más tiempo en vez de alcanzar una velocidad
mucho mayor.

Esto produce aproximadamente:

| Carga | Distancia | Duración orientativa |
|---|---:|---:|
| mínima válida | 112 px | 0,23 s |
| media | 316 px | 0,66 s |
| completa | 520 px | 1,08 s |

La constante de velocidad se deja centralizada para afinar sensación después
de jugar; las distancias y umbrales de daño no cambian en esta iteración.

### Deformación de un solo cuerpo

Se conserva un único `Polygon2D` y la colisión circular vigente. No se añaden
segmentos físicos ni articulaciones.

La silueta gana suficientes vértices longitudinales para deformar regiones:

- al cargar, solo el tercio frontal se estira en la dirección elegida;
- el vientre queda ancho y bajo, comunicando contacto con el suelo;
- la parte trasera se comprime;
- durante el avance, una onda longitudinal desplaza la compresión del frente
  hacia atrás y la cola alcanza al resto;
- en reposo queda una ondulación mínima, sin trasladar al personaje.

La deformación es presentación. `move_and_collide()` conserva la autoridad de
posición y colisión, y el estiramiento visual se limita para no atravesar muros
de forma engañosa.

## 6. Iluminación

Las lámparas de sala amplían su cobertura aproximadamente un 35 %:

- `PointLight2D.texture_scale`: `1.0 → 1.35`;
- energía base: permanece en `1.6`;
- mismo color, textura, frecuencia de parpadeo y bajones;
- las lámparas averiadas siguen apagadas.

No se agregan focos nuevos en esta iteración. El objetivo es reducir huecos
oscuros ampliando el radio, sin aumentar la intensidad declarada de cada foco.

## 7. Estructura propuesta

| Componente | Responsabilidad |
|---|---|
| `core/map_generator.gd` | Fijar la segunda sala, elegir `reward_part_id` y validar el hito |
| `core/run_map.gd` | Transportar los datos de recompensa en el descriptor |
| `world/rooms/procedural_room.gd` | Instanciar rastro y cuerpo según rol/direcciones |
| `world/props/body_source.*` | Mostrar cuerpo y alojar la recompensa de una sola toma |
| `world/props/blood_trail.*` | Distribuir decals sin lógica de navegación propia |
| `autoload/game_state.gd` | Recordar recompensas de sala reclamadas durante la partida |
| `ui/map_overlay.gd` | Mostrar únicamente salas y enlaces descubiertos |
| `actors/player/slime.gd` | Aplicar velocidad uniforme y deformación peristáltica |
| `world/props/lamp.tscn` | Ampliar radio sin cambiar energía |

Los assets finales viven en:

```text
prueba_2/assets/environment/blood/
prueba_2/assets/environment/body/
```

## 8. Verificación

### Generación y puertas

- 1.000 seeds conservan 6–8 salas, máximo 12 y todos los invariantes previos.
- En cada seed, `main_path[1]` tiene rol `body` y un `reward_part_id` válido.
- La misma seed conserva mapa y recompensa.
- La seed `1785033756` ensambla puertas y spawns exactamente como su mapa.

### Mapa

- Al iniciar solo aparece el tutorial.
- Al entrar al cuerpo aparecen exactamente tutorial, cuerpo y su enlace.
- Una vecina no visitada no aparece como `?` ni altera el layout.
- Rejillas permanecen ocultas hasta descubrirlas.

### Cuerpo y sangre

- El rastro apunta a la puerta de la segunda sala en las cuatro orientaciones.
- La segunda sala coloca el cuerpo y continúa el rastro desde la entrada.
- Tomar la parte, salir y volver no genera una copia.

### Movimiento

- Carga mínima y máxima conservan sus distancias dentro de tolerancia.
- La velocidad del tramo central permanece aproximadamente constante.
- Cargar no traslada el `CharacterBody2D`.
- Fizzle, colisión, embestida, DASH y knockback mantienen sus contratos.
- La deformación vuelve a reposo sin deriva en posición o rotación.

### Iluminación y visuales

- `energy` sigue siendo `1.6` y `texture_scale` pasa a `1.35`.
- Capturas en 1920×1080 comprueban cuerpo, sangre, cobertura lumínica y silueta
  cargando/moviéndose.
- La sensación de arrastre, legibilidad de la sangre y ritmo de `480 px/s`
  requieren una prueba manual; los tests solo validan sus límites objetivos.

## Fuera de alcance

- Animación esquelética o cuerpo compuesto por segmentos físicos.
- Cinemática, diálogo o decisión narrativa al encontrar el cuerpo.
- Sangre como daño, pista interactiva o sistema procedural fuera de las dos
  primeras salas.
- Cambiar el alcance del DASH o el balance de partes.
- Generar los pisos -2, -1 y 0.
