# Diseño: ajustes de jugabilidad de Contención

Fecha: 2026-07-26
Estado: aprobado

## Objetivo

Corregir la integración de las rejillas para que formen parte de las paredes,
impedir físicamente atravesar puertas selladas y ajustar iluminación, vida,
curación y texto de consumo sin cambiar el alcance del primer piso.

## Rejillas empotradas en paredes

La rejilla deja de ser un prop grande colocado dentro del área jugable. Fuente
y destino se representan como salidas murales: el sprite conserva su relación
de aspecto y se ajusta dentro de un área máxima exacta de `120 × 120`, el mismo
espacio ocupado por el hueco funcional de una puerta.

Cada conexión conserva una dirección explícita:

- la rejilla fuente se coloca en una pared libre de la sala de combate;
- la sala destino coloca el retorno en la pared opuesta;
- los puntos de aparición quedan dentro de la sala, separados de la pared;
- una pared con puerta normal no puede alojar también una rejilla;
- sigue existiendo como máximo una rejilla por sala;
- dos rejillas no pueden compartir destino.

El generador solo considera elegibles las salas de combate que tengan una pared
libre y una celda adyacente disponible para el destino. No se permite colocar
un destino lejano y luego dibujar una rejilla sin relación espacial con él. Si
un intento no puede satisfacer una conexión obligatoria, se descarta y se
genera otro mediante el mecanismo de reintentos existente.

## Contenido de la sala tras la rejilla

La distribución es:

| Contenido | Probabilidad |
|---|---:|
| Vacía | 40 % |
| Loot | 40 % |
| Combate | 20 % |

Estos pesos ya existen en `MapGenerator`; se conservan y se protegen mediante
pruebas para evitar cambios accidentales. La sala de combate contiene entre uno
y dos enemigos, según el contrato actual.

## Puertas selladas

La puerta mantiene su validación lógica antes de llamar a `Transition`, pero
además activa una barrera física mientras está sellada.

- La barrera ocupa el hueco transitable de la puerta.
- La colisión está deshabilitada cuando la puerta está abierta.
- `set_sealed(true)` muestra el bloqueo y habilita la colisión.
- `set_sealed(false)` oculta el bloqueo y deshabilita la colisión.
- Los cambios de colisión que ocurran durante el paso de física se aplican de
  forma diferida.

Así, una puerta cerrada no puede cruzarse aunque el jugador continúe empujando
contra el borde.

## Iluminación

Las lámparas conservan su energía base `1.6`; se aumenta únicamente el radio de
la textura luminosa. El nuevo valor debe cubrir mejor el centro de una sala
1920 × 1080 sin quemar los focos ni modificar el parpadeo.

El valor de `PointLight2D.texture_scale` pasa de `1.35` a `1.85`. El ajuste se
validará con una captura real para confirmar que cubre mejor el centro sin
quemar los focos.

## Vida y consumo de partes

La vida continúa expresándose en unidades de medio corazón:

- vida máxima base: `15 HP`;
- vida inicial: `7 HP`;
- comer una parte equipada cura `2 HP`;
- la curación se limita a la vida máxima;
- consumir mantiene los efectos existentes: libera el slot, elimina la
  habilidad/modificador correspondiente y registra la parte consumida.

La recompensa al completar el piso ya cura `2 HP` y no cambia.

## Interfaz de `Tab`

La selección, el resaltado y las restricciones de consumo permanecen iguales.
Solo cambia el texto:

- parte consumible seleccionada: `F · COMER`;
- vida máxima: `VIDA AL MÁXIMO`;
- slot vacío: no se muestra indicación.

La interfaz no anuncia cuántos HP recuperará la parte.

## Pruebas y evidencia

La implementación debe demostrar:

1. una rejilla fuente y su retorno aparecen en paredes opuestas, con tamaño de
   puerta y sin compartir pared con una puerta normal;
2. la tabla de pesos contiene exactamente `40` para vacío, `40` para loot y
   `20` para combate, suma `100`, y una muestra determinista de `10 000`
   elecciones queda a menos de dos puntos porcentuales de cada peso;
3. una puerta sellada bloquea físicamente al jugador y una puerta abierta
   permite el paso;
4. una partida nueva comienza con `7 HP`;
5. comer una parte con vida incompleta cura exactamente `2 HP` y libera el
   slot, sin superar `15 HP`;
6. el panel de cuerpo no contiene `+½ CORAZÓN`, `+1 CORAZÓN` ni otra cifra de
   curación;
7. una captura 1920 × 1080 confirma escala de rejilla, colocación mural,
   iluminación y ausencia de solapes;
8. las suites de mapa, ensamblado, ciclo de partida, rejillas, consumo, UI y
   combate continúan en verde.

## Fuera de alcance

- Los pisos -2, -1 y 0.
- Cambiar el coste de abrir una rejilla.
- Cambiar el retorno gratuito durante la partida actual.
- Añadir tipos nuevos de sala o loot.
- Modificar la animación del slime o el ataque del Experimento 07.
