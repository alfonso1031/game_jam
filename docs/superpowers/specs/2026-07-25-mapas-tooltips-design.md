# Diseño: mapas de zona, ruta de ascenso y tooltips de partes

## Estado del documento

Especificación aprobada para acompañar la primera implementación procedural de
Contención. Define tres superficies distintas:

1. mapa local del piso actual;
2. ruta global entre pisos;
3. panel corporal con partes equipadas y descripciones.

No implementa el contenido jugable de los pisos -2, -1 y 0.

## Objetivo

Separar dos preguntas que hoy aparecen mezcladas:

- **¿Dónde estoy dentro de esta zona?** → mapa local estilo *Binding of Isaac*.
- **¿Cuánto falta para salir?** → ruta vertical de ascenso entre pisos.

El panel corporal debe comunicar además qué habilidades forman parte del slime.
Las tarjetas no flotan como inventario independiente: cada parte equipada se
conecta visualmente al cuerpo y explica su función al pasar el cursor.

## Base arquitectónica rastreada

El grafo actual muestra que:

- `Transition` actualiza `GameState.current_room` y `visited`, y luego emite
  `room_changed`;
- `HUD` escucha `room_changed` y `health_changed`;
- `MapOverlay._draw()` lee `GameState` y `RoomDB`;
- `InventoryUI` escucha los cambios de inventario y vida;
- todos los overlays comparten `get_tree().paused`.

La UI nueva conserva ese flujo: señales hacia la UI y lectura de estado, sin que
la UI modifique el mapa o las reglas de la partida. La diferencia es que el mapa
local leerá la instancia `RunMap` de `RunManager`, no el grafo fijo de
`RoomDB.ROOMS`.

## Resolución y escalado

El diseño objetivo es `1920 × 1080`. Todos los paneles usan anchors y offsets
relativos; no se asume que la ventana conserve esa resolución.

- El mapa se centra usando los límites reales de las coordenadas generadas.
- El tamaño de celda baja si el grafo no cabe en su panel.
- Texto y tarjetas conservan su tamaño mínimo legible.
- Tooltips se mantienen completamente dentro del viewport.
- Se verifican al menos `1920 × 1080` y `1280 × 720`.

## 1. Mapa local de Contención

### Alcance

TAB abre un overlay pausado que muestra **solo el piso actual**. En esta fase
siempre será Contención.

El mapa usa las coordenadas y conexiones reales de `RunMap`. No contiene una
lista fija de salas ni supone un pasillo horizontal. Debe representar:

- conexiones norte, este, sur y oeste;
- habitaciones con una, dos, tres o cuatro puertas;
- habitaciones en cruz;
- ramas y reconexiones;
- sala actual, visitadas y vecinas conocidas;
- roles especiales cuando el jugador ya los descubrió.

### Información revelada

- La sala actual se destaca.
- Las salas visitadas muestran su celda completa.
- Una sala conectada a una visitada, pero todavía no recorrida, aparece como
  silueta con `?`.
- El resto permanece oculto.
- El mapa no revela de antemano boss, loot ni el destino de una rejilla.
- Una conexión de rejilla aparece solo después de usarla.

Esta regla conserva la lectura tipo *Binding of Isaac* sin convertir el mapa en
una guía completa de la seed.

### Geometría

Cada habitación ocupa una celda lógica. El dibujo se deriva de:

```text
posición de sala = origen_del_panel + (grid - grid_min) * paso
```

Las conexiones se dibujan entre centros de celdas adyacentes. Los huecos de
puerta se colocan en el lado correspondiente, incluido el caso de cuatro puertas
simultáneas.

El algoritmo calcula `grid_min`, `grid_max`, ancho y alto del mapa generado,
elige el mayor tamaño de celda que quepa en el panel y centra el resultado. No
hay coordenadas visuales especiales por ID de sala.

### Estados visuales

| Estado | Tratamiento |
|---|---|
| Sala actual | relleno brillante y borde de alto contraste |
| Visitada | relleno secundario |
| Conocida sin visitar | contorno y `?` |
| Oculta | no se dibuja |
| Conexión normal | línea sólida |
| Conexión de rejilla descubierta | línea orgánica/discontinua |

Los colores salen de `core/palette.gd`; no se introducen hexadecimales en el
script.

### Datos y actualización

`MapOverlay` se actualiza al:

- recibir `RunManager.map_generated`;
- recibir `GameState.room_changed`;
- abrirse con TAB;
- descubrir una conexión especial.

No usa `_process()` para consultar cambios. Mientras está abierto pausa el juego
y usa `PROCESS_MODE_ALWAYS` para poder cerrarse.

## 2. Ruta global de ascenso

### Propósito

Es una pantalla breve de progreso macro, inspirada en una ruta completa de
ascenso. No muestra las salas generadas de cada piso.

El orden visual es vertical:

```text
NIVEL 0  · SUPERFICIE       ← objetivo, arriba
NIVEL -1 · MANTENIMIENTO
NIVEL -2 · BIO-LABORATORIOS
NIVEL -3 · CONTENCIÓN       ← origen, abajo
```

Contención nunca aparece arriba de Superficie. La lectura siempre es subir desde
el fondo hasta el nivel 0.

### Cuándo aparece

Al superar Contención:

1. `RunManager.floor_completed` concede la curación correspondiente;
2. la transición de sala queda bloqueada;
3. se muestra `FloorRouteOverlay`;
4. Contención cambia a estado superado;
5. el overlay permanece `3.0 s`;
6. se cierra automáticamente y continúa el flujo disponible.

Puede cerrarse antes con la acción de continuar si la transición ya está lista.
Como comparte pausa con mapa y menú, comprueba que ningún otro overlay esté
abierto y usa `PROCESS_MODE_ALWAYS`.

### Contenido

Cada piso es un único nodo con nombre y estado:

| Estado | Uso |
|---|---|
| Superado | Contención después del boss |
| Actual | Piso que se está recorriendo |
| Futuro | Piso aún no implementado o alcanzado |
| Objetivo | Superficie |

No se dibujan diamantes por habitación, semillas, ramificaciones locales ni
miniaturas del mapa procedural. Esos detalles pertenecen exclusivamente al mapa
local.

## 3. Cuerpo, slots y tooltips

### Composición

El slime se coloca como centro visual del panel corporal. Cada slot equipado se
distribuye alrededor del cuerpo y se conecta con una curva orgánica.

La conexión:

- nace en el borde del slime, no en su centro;
- termina en el borde más cercano de la tarjeta;
- usa una curva suave con dos puntos de control;
- tiene una base oscura y un trazo interior de color;
- varía levemente su curvatura por slot para evitar una estrella rígida;
- se dibuja detrás de tarjetas, texto y tooltip;
- desaparece al liberarse el slot.

Debe sentirse como un tendón viscoso que forma parte del slime, no como una línea
de diagrama. La curva no cambia la lógica de equipamiento.

### Interacción del tooltip

Al colocar el cursor sobre una tarjeta equipada:

1. se identifica el slot bajo el cursor;
2. se consulta `PartsDB` por ID;
3. aparece el tooltip junto al cursor;
4. el tooltip se desplaza si tocaría un borde de pantalla;
5. al abandonar la tarjeta se oculta;
6. si el slot se libera mientras está visible, se cierra.

La posición se calcula cada vez que cambia el cursor, pero la UI no consulta el
inventario cada frame. El tooltip no captura clics ni bloquea la navegación por
teclado.

Para mando o teclado, enfocar una tarjeta produce la misma descripción junto a
la tarjeta seleccionada.

### Fuente única de texto

Los nombres y descripciones viven en `core/parts_db.gd`. El panel no contiene
copias hardcodeadas.

Descripciones aprobadas:

| Parte | Descripción breve |
|---|---|
| Mandíbula Serrada | Mordisco a corta distancia. |
| Mano de Micelio | Dispara una línea de raíz que inmoviliza al primer enemigo tocado. |
| Tenaza Trituradora | Ataque cónico frontal. |
| Piel Escamada | Endurecimiento instantáneo que bloquea el siguiente impacto recibido. |
| Cola de Látigo | Barrido giratorio de 360 grados que repele a los enemigos alrededor. |

Se conservan los nombres actuales **Piel Escamada** y **Cola de Látigo**. No se
renombran a Pierna Escamada ni Zarcillo de Látigo en esta fase.

### Slots liberados

El panel reacciona a `Inventory.slots_changed`:

- parte equipada → tarjeta, curva y tooltip disponible;
- parte comida/perdida/sacrificada → tarjeta vacía y curva eliminada;
- el orden visual del resto no cambia durante esa actualización.

Esto comunica inmediatamente que el jugador recuperó capacidad para elegir otra
parte.

## Arquitectura propuesta

| Componente | Responsabilidad |
|---|---|
| `ui/map_overlay.gd` | Dibuja el mapa local desde un snapshot de `RunMap` |
| `ui/floor_route_overlay.gd` | Dibuja y temporiza la ruta entre pisos |
| `ui/body_panel.gd` | Distribuye slime, tarjetas y conexiones orgánicas |
| `ui/part_tooltip.gd` | Presenta nombre y descripción sin duplicar datos |
| `core/parts_db.gd` | Fuente de nombres, descripción e iconografía |
| `autoload/run_manager.gd` | Expone mapa actual y progreso de pisos |
| `autoload/game_state.gd` | Expone sala actual, visitadas y HP |
| `autoload/inventory.gd` | Expone slots y partes equipadas |

Los `.tscn` viven junto a sus `.gd`. `game/main.tscn` ensambla los overlays; ni
actores ni salas importan `ui/`.

## Pruebas

### Mapa local

- una fixture en cruz dibuja las cuatro conexiones;
- mapas altos, anchos y asimétricos quedan centrados;
- ninguna celda sale del panel a `1920 × 1080` ni `1280 × 720`;
- solo se muestran sala actual, visitadas y vecinas conocidas;
- boss, loot y rejilla no se filtran antes de descubrirse;
- TAB abre, pausa, cierra y no se superpone con pausa u otro overlay;
- cambiar de sala provoca exactamente un redibujado solicitado por señal.

### Ruta de ascenso

- el orden es Contención abajo y Superficie arriba;
- no aparecen habitaciones generadas dentro de los pisos;
- completar Contención cambia su estado una sola vez;
- permanece `3.0 s` y se puede continuar antes;
- no concede curación adicional al abrirse otra vez;
- los pisos futuros permanecen como nodos sin contenido jugable.

### Tooltips y cuerpo

- cada parte aprobada muestra el texto exacto de `PartsDB`;
- el tooltip sigue al cursor y nunca sale del viewport;
- foco por teclado/mando muestra la misma información;
- cada slot equipado tiene una sola conexión al slime;
- una conexión nace y termina en los bordes correctos;
- comer, perder o sacrificar elimina tarjeta, tooltip y conexión;
- slots vacíos no muestran descripciones obsoletas.

### Verificación visual manual

- comprobar que las curvas se leen como extensiones orgánicas del cuerpo;
- revisar cruces entre curvas, tarjetas y textos con todos los slots ocupados;
- confirmar legibilidad del mapa con una sala en cruz;
- confirmar que la ruta global comunica “subir” sin parecer otro mapa local.

## Documentación que cambiará con la implementación

- `docs/ARQUITECTURA.md`: separar mapa local y ruta global.
- `docs/agents/REFERENCIA.md`: escalado del mapa, clamping de tooltip y curvas.
- `AGENTS.md`: overlays sin solaparse, sin sondeo de estado y con prueba a
  `1920 × 1080`.

## Fuera de alcance

- Mapas locales jugables para los pisos -2, -1 y 0.
- Dibujar las habitaciones de todos los pisos en la ruta global.
- Cambiar efectos mecánicos de las habilidades.
- Crear arte rasterizado nuevo para tarjetas o cuerpo.
- Guardar mapas o progreso entre partidas.
