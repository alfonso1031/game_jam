# Movilidad por piernas, anticipación del boss e input de TAB

## Objetivo

Mejorar la lectura del ataque de la Quimera, eliminar los textos que revelan su
próxima acción y hacer que asimilar una parte de tipo `pierna` transforme el
movimiento base del slime. El panel corporal de `TAB` debe poder navegarse tanto
con WASD como con las flechas.

## Alcance

Este cambio modifica únicamente:

- la anticipación y presentación del ataque de la Quimera de Contención;
- la selección entre movimiento cargado y movimiento continuo del slime;
- la consulta de partes equipadas por su tipo corporal;
- la navegación por teclado del panel corporal de `TAB`;
- las pruebas y documentación de estos contratos.

No cambia el daño, la velocidad de embestida, la vida ni las recompensas del
boss. Tampoco cambia el funcionamiento de las habilidades activas, el DASH o el
consumo de partes.

## Anticipación de la Quimera

La máquina de estados conserva:

`SEEK_CORNER → CORNER_AIM → POUNCE → RECOVER`.

Los tiempos de `CORNER_AIM` aumentan aproximadamente un 50 % y quedan en:

| Fase | Vida | Anticipación |
|---|---:|---:|
| 1 | 9–12 HP | 1,35 s |
| 2 | 5–8 HP | 1,08 s |
| 3 | 1–4 HP | 0,84 s |

La posición de ataque continúa congelándose al comenzar la embestida. La línea
discontinua y el círculo objetivo siguen siendo la advertencia jugable. El nodo
`StateLabel`, el método que lo actualiza y textos como `RÁFAGA HACIA ESQUINA`,
`FIJA TU POSICIÓN`, `¡EMBESTIDA!` y `RECUPERANDO` se eliminan por completo. La
barra de vida permanece.

## Movilidad habilitada por piernas

Los seis huecos del inventario continúan siendo genéricos. Una parte cuenta como
pierna cuando `PartsDB.slot_of(part_id) == PartsDB.SLOT_PIERNA`, sin importar en
qué hueco esté equipada.

`Inventory` expondrá una consulta que cuente partes equipadas por tipo. La
implementación actual activa el movimiento continuo con una o más piernas, pero
la cantidad exacta queda disponible para futuras variantes:

| Piernas equipadas | Movimiento actual |
|---:|---|
| 0 | Impulso cargado existente |
| 1 o más | Movimiento continuo |

En el futuro, el mismo conteo podrá distinguir formas de desplazamiento para una
o dos piernas sin introducir listas de IDs ni modificar cada parte existente.

### Movimiento continuo

- Lee `Input.get_vector("move_left", "move_right", "move_up", "move_down")`.
- Se desplaza a `280 px/s`.
- Usa `move_and_collide()`, igual que el contrato actual del slime.
- WASD y flechas producen el mismo vector mediante las acciones existentes.
- La dirección actualiza la orientación visual y la dirección de apuntado.
- Mantiene el arrastre visual orgánico del slime mientras avanza.
- No inicia carga, no muestra la barra y no reproduce audio de carga.
- Con entrada cero queda quieto.

El DASH de habilidad, los DASH de partes y el knockback conservan prioridad. El
estado `root` impide el movimiento continuo. Las habilidades numéricas siguen
funcionando sin cambios.

Cuando `Inventory.slots_changed` indica que apareció la primera pierna, cualquier
carga incompleta se cancela limpiamente y el slime pasa a reposo continuo.
Cuando se come, sacrifica o pierde la última pierna, el movimiento vuelve
inmediatamente al modo cargado. La transición no consume vida, habilidad ni
recarga.

## Navegación del panel corporal

Con `TAB` abierto, `A/D/W/S` y las flechas izquierda/derecha/arriba/abajo llaman
a la misma navegación espacial de `BodyPanel`. Cada pulsación mueve la selección
una sola vez hacia la tarjeta ocupada más cercana en esa dirección.

Los controles existentes permanecen:

- `F`: comer la parte seleccionada;
- `V`: alternar vida infinita de prueba;
- `TAB` o `Esc`: cerrar el overlay.

No se añade texto explicativo nuevo a la interfaz.

## Arquitectura y datos

- `PartsDB` continúa siendo la fuente del tipo corporal de cada parte.
- `Inventory` agrega una consulta pura de conteo; no guarda un segundo estado
  derivado.
- `Slime` conserva el control de su propia máquina de movimiento y reacciona a
  `slots_changed`.
- `MapOverlay` traduce eventos de teclado a direcciones y delega la selección a
  `BodyPanel`.
- El boss mantiene su máquina de estados; solo cambian anticipación y
  presentación.

## Casos límite

- Equipar una pierna durante carga cancela la carga y detiene su audio.
- Perder la última pierna durante movimiento deja al slime en `IDLE`.
- Dos o más piernas no aumentan todavía la velocidad.
- Una parte cuyo nombre mencione piernas pero cuyo `slot` no sea `SLOT_PIERNA`
  no activa la movilidad.
- Con `TAB` abierto el juego permanece pausado y las teclas no mueven al slime.
- La eliminación del texto del boss no elimina la línea de anticipación ni la
  barra de vida.

## Verificación

Las pruebas automatizadas deben cubrir:

1. conteo de cero, una y dos partes de tipo pierna;
2. movimiento cargado sin piernas;
3. movimiento continuo a `280 px/s` con una pierna;
4. ausencia de barra/carga en modo continuo;
5. retorno al modo cargado al perder la última pierna;
6. prioridad de `root`, DASH y knockback;
7. navegación de `TAB` mediante teclas físicas WASD y flechas;
8. tiempos de anticipación del boss por fase;
9. ausencia de `StateLabel` y conservación de barra, línea y objetivo;
10. regresiones de combate, inventario, mapa y arranque limpio.

La sensación de velocidad, la legibilidad de la anticipación y el arrastre
continuo requieren además una prueba humana en la versión jugable.
