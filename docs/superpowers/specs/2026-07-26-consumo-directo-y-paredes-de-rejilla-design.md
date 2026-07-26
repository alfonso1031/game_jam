# Consumo directo de duplicados y reserva de paredes de rejilla

## Objetivo

Evitar que una parte duplicada obligue a abrir `TAB` y corregir los mapas donde
una entrada generada posteriormente ocupa la misma pared que una rejilla ya
asignada.

## Consumo directo desde el suelo

`PartPickup` conserva la recogida automática cuando existe un slot compatible.
Si el jugador ya tiene equipada exactamente la misma `part_id`, el pickup
permanece en el suelo y muestra `F · COMER`.

Al pulsar `F` dentro de su área:

1. se digiere la copia del suelo;
2. se curan `2 HP` mediante el flujo normal de digestión;
3. la copia equipada permanece en su slot, con su cooldown y usos intactos;
4. se emite `collected(part_id)` para que la recompensa de sala quede reclamada;
5. el pickup desaparece.

No se permite consumir directamente una parte diferente. Si no es un duplicado
exacto y no hay slot compatible, se mantiene el mensaje que dirige al mapa
corporal.

`Inventory` expondrá una operación pública para digerir una parte suelta válida
sin alterar `slots`. `PartPickup` será responsable de comprobar proximidad,
duplicado e input; no duplicará la curación ni las señales.

## Reserva de paredes de rejilla

La causa del bloqueo es el orden actual de `_add_grates()`: las fuentes se
procesan desde las capas altas hacia las bajas. Una fuente baja puede crear
después un destino que reconecta a una sala alta y añadirle una `entrance` sobre
la pared que esa sala ya había reservado como `grate_direction`.

Las fuentes se procesarán por capa ascendente. Así, toda reconexión procedente de
una capa anterior registra primero su entrada y la sala futura elige después su
rejilla únicamente entre las paredes todavía libres.

`MapGenerator.validate()` comprobará además que `grate_direction` no aparezca en
la unión de `doors` y `entrances`. Si una combinación futura viola el contrato,
se rechaza ese intento de generación en vez de llegar al `assert` durante la
transición.

El `assert` de `ProceduralRoom` se conserva como defensa del ensamblador: un
descriptor inválido no debe materializar una rejilla encima de una abertura.

## Alcance

- No cambia el coste ni los porcentajes de las rejillas.
- No cambia la curación de comer una parte: sigue siendo `2 HP`.
- No reemplaza ni reinicia la parte equipada.
- No habilita el consumo directo de partes nuevas o diferentes.
- No modifica el mapa corporal ni los controles de habilidades.
- Por instrucción del usuario, no se ejecutarán suites automatizadas; se
  entregará el juego abierto para validación manual.
