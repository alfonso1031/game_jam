# Diseño: consumo de partes desde el mapa corporal

## Objetivo

Convertir el panel corporal de `TAB` en la única interfaz para gestionar las
partes asimiladas. El jugador debe poder elegir con las flechas una de sus seis
partes equipadas y consumirla con `F`, sin abrir una pantalla de inventario
separada ni manejar partes pendientes.

## Decisiones aprobadas

- Existen exactamente seis espacios de partes asimiladas.
- No existe un séptimo espacio ni un estado de parte pendiente.
- La pantalla separada de inventario y su acceso con `I` se eliminan.
- `TAB` continúa abriendo el mapa local y el cuerpo asimilado.
- Las flechas seleccionan únicamente tarjetas que contienen una parte.
- `F` consume la parte seleccionada y cura medio corazón mediante la regla
  existente.
- La parte seleccionada se distingue con más luminosidad, borde más grueso,
  una ampliación ligera y su conexión al slime resaltada.
- Consumir o perder una parte libera inmediatamente su espacio.

## Arquitectura

### Autoridad de las seis partes

`prueba_2/autoload/inventory.gd` conserva su nombre para no romper los sistemas
de combate que ya consultan sus modificadores, pero deja de representar un
inventario con objetos en espera. Su estado se reduce a:

```gdscript
const SLOT_COUNT := 6
var slots: Array[String] = ["", "", "", "", "", ""]
```

Se eliminan `pending`, `pending_changed`, `consume_pending()`,
`place_in_slot()` y el flujo que desplaza una parte equipada a una reserva.
`pick_up()` equipa una parte solo cuando existe un espacio compatible libre;
si no existe, devuelve `false` y no modifica el estado.

El nombre `Inventory` queda como detalle interno compatible con los actores y
autoloads actuales. Para el jugador, la interfaz y el lenguaje visible hablan
únicamente del cuerpo y sus seis partes.

### Pickup cuando los seis espacios están ocupados

`prueba_2/world/props/part_pickup.gd` no recoge ni destruye una parte que no
pueda equiparse. Mientras el jugador esté encima mostrará una indicación breve
para abrir `TAB`, elegir una parte y consumirla.

Al liberar un espacio, el pickup vuelve a intentar equiparse automáticamente
mientras el jugador continúe dentro de su área. Esto evita pérdidas,
duplicados y estados ocultos.

### Eliminación de la pantalla separada

`prueba_2/game/main.tscn` deja de instanciar `InventoryLayer` e `InventoryUI`.
Los archivos `prueba_2/ui/inventory_ui.gd` y
`prueba_2/ui/inventory_ui.tscn` se eliminan, junto con las acciones
`inventory` que solo servía a esa pantalla. La acción existente `consume`,
asignada a `F`, pasa a ser atendida por el mapa únicamente mientras `TAB` está
abierto.

### Selección dentro de `TAB`

`prueba_2/ui/map_overlay.gd` mantiene la autoridad de abrir, cerrar y pausar el
overlay. Cuando se abre:

1. solicita al panel corporal seleccionar la primera parte equipada;
2. entrega las acciones de dirección al panel;
3. entrega `F` como confirmación de consumo;
4. cierra normalmente con `TAB` o `Esc`.

`prueba_2/ui/body_panel.gd` mantiene el índice seleccionado. La navegación usa
la posición real de las seis tarjetas alrededor del slime:

- para cada pulsación calcula qué tarjetas ocupadas están en esa dirección;
- prioriza el menor desvío angular;
- usa la distancia como desempate;
- si no existe una tarjeta válida en esa dirección, conserva la selección.

Así las flechas se sienten espaciales y no dependen del orden numérico de los
slots. Los huecos vacíos y la tarjeta de `DASH` no forman parte de la selección
de consumo.

### Consumo y continuidad de selección

Antes de consumir, el panel comprueba que:

- exista una parte seleccionada;
- el espacio aún contenga esa parte;
- la vida no esté al máximo, conservando la protección existente contra
  desperdiciar una parte sin curación.

Si `Inventory.consume_slot()` tiene éxito, se mantiene el flujo actual:
liberar el espacio, recalcular pasivas, curar medio corazón y registrar la
parte consumida en `RunManager`.

Después del cambio de slots:

- si la selección sigue ocupada, se conserva;
- si fue consumida o perdida, se selecciona la parte restante más cercana a la
  tarjeta anterior;
- si no queda ninguna, se limpia la selección.

## Tratamiento visual

La tarjeta seleccionada utiliza un estilo propio con:

- fondo más claro y opaco que el estado hover;
- borde de `5 px` en el color luminoso del slime;
- escala aproximada de `1.06`;
- texto de mayor contraste.

La curva entre esa tarjeta y el slime se dibuja sobre las demás, con un trazo
luminoso más ancho. El tooltip permanece visible y anclado a la tarjeta
seleccionada aunque el cursor esté en otra zona. El efecto no desplaza la
tarjeta ni altera la geometría usada para navegar.

## Mensajes de estado

El panel corporal mostrará un mensaje breve cerca de la parte seleccionada:

- `F · COMER (+½ CORAZÓN)` cuando puede consumirse;
- `VIDA AL MÁXIMO` cuando consumirla no produciría curación.

No se añaden explicaciones generales al mapa ni vuelve la UI de inventario.

## Pruebas

### Automatizadas

- La escena principal no instancia `InventoryUI`.
- El proyecto no declara la acción `inventory`.
- `Inventory` contiene exactamente seis slots y no expone estado pendiente.
- Un pickup sin espacio permanece en el mundo.
- Un pickup se equipa cuando se libera un espacio.
- Abrir `TAB` selecciona la primera parte equipada.
- Las cuatro direcciones omiten huecos vacíos.
- `F` consume únicamente la parte seleccionada.
- Consumir cura medio corazón, libera el slot y actualiza la selección.
- Con vida máxima no se consume la parte.
- La selección visual y la conexión resaltada corresponden al mismo slot.
- Sin partes equipadas, las flechas y `F` no producen cambios.

### Manuales

- Abrir `TAB` con varias distribuciones de partes y comprobar que las flechas
  siguen su posición alrededor del slime.
- Confirmar que la tarjeta seleccionada se reconoce claramente a 1920×1080.
- Consumir varias partes consecutivas y comprobar que la selección nunca queda
  sobre un hueco vacío.
- Llenar los seis espacios, acercarse a otro pickup, consumir una parte desde
  `TAB` y verificar que el pickup se equipa sin duplicarse.
- Confirmar que `I` no abre ninguna pantalla.

## Documentación afectada

- `docs/ARQUITECTURA.md`: autoridad de partes, pickups llenos y consumo desde
  el panel corporal.
- `docs/agents/REFERENCIA.md`: controles de `TAB`, flechas y `F`.
- `AGENTS.md`: regla dura de seis partes sin estado pendiente.

## Fuera de alcance

- Reordenar manualmente las partes entre slots.
- Consumir una parte con un clic del mouse.
- Cambiar la curación de medio corazón.
- Cambiar las habilidades o modificadores de las partes.
- Añadir confirmación secundaria antes de consumir.
- Rediseñar el mapa local del lado derecho.
