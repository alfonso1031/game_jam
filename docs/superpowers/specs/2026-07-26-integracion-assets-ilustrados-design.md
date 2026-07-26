# Integración de assets ilustrados — diseño

Fecha: 2026-07-26  
Estado: aprobado  
Alcance: pantalla de inicio, utilería de Contención, rejilla procedural y ataque del Experimento 07

## Objetivo

Integrar los tres paquetes entregados sin tratarlos como imágenes decorativas
aisladas. Cada asset debe pertenecer a la feature que representa, conservar la
arquitectura por feature del proyecto y coincidir visualmente con la mecánica
que ya ejecuta el juego.

Paquetes fuente:

- `Title_Screen-20260726T044454Z-1-001.zip`
- `Assets-20260726T044356Z-1-001.zip`
- `Claw_Ataque-20260726T044638Z-1-001.zip`

La implementación seguirá una integración funcional. No se ampliará el cambio
a un reemplazo artístico general de fondos, personajes u otros pisos.

## 1. Pantalla de inicio

Las dos ilustraciones de 1920 × 1080 forman una introducción corta:

1. El juego inicia mostrando `Pantalla de inicio_1.png`, con el slime contenido.
2. La imagen permanece aproximadamente 0,8 segundos para que la escena sea
   legible.
3. Una sacudida corta y un destello comunican la ruptura.
4. Se hace una transición cruzada de aproximadamente 0,6 segundos hacia
   `Pantalla de inicio_2.png`, con el slime liberado.
5. Los botones del menú aparecen con un fundido suave sobre la segunda imagen.

La segunda imagen será el estado estable de la pantalla. La animación se
reproduce una vez cada vez que se entra al título desde el arranque. Una tecla,
un clic o una acción de interfaz durante la introducción la omite y muestra el
menú final; esa entrada no debe iniciar accidentalmente una partida.

El título ya forma parte de las ilustraciones. Se retirarán u ocultarán las
formas y textos procedurales que lo duplican. Los botones seguirán siendo nodos
de interfaz reales, con foco de teclado y sin texto explicativo innecesario.

Los recursos vivirán bajo `prueba_2/assets/ui/title/`, mientras que la lógica y
la escena seguirán en `prueba_2/ui/`.

## 2. Utilería ambiental de Contención

Cada ilustración se convertirá en una escena reutilizable bajo
`prueba_2/world/props/`, con su textura en
`prueba_2/assets/environment/containment/`.

### Tubo de vidrio roto

`Tubo_Vidrio_Roto.png` aparecerá en la primera sala, detrás del punto de
aparición del slime. Su función es indicar visualmente el origen del escape sin
añadir un texto tutorial.

La colisión cubrirá únicamente la base sólida. Los fragmentos y el espacio
abierto no bloquearán al jugador. La ubicación respetará el área necesaria para
leer los controles de la primera sala.

### Tubo de vidrio intacto, tubo y armario

`Tubo_Vidrio.png`, `Tubo.png` y `Armario.png` serán utilería de las salas
procedurales de Contención:

- tendrán escala y profundidad coherentes con los personajes;
- solo su base o volumen sólido tendrá colisión;
- no podrán tapar puertas, el punto de aparición ni la ruta mínima entre
  conexiones;
- su selección y posición dependerán de la semilla para que una misma seed sea
  reproducible;
- no se colocarán en pisos futuros hasta definir su dirección visual.

La generación manejará datos de colocación y el ensamblador instanciará las
escenas. No se incrustarán rutas de texturas directamente en la lógica del mapa.

## 3. Rejilla funcional

`Rejilla.png` representará físicamente las conexiones alternativas que el mapa
procedural ya modela.

- Solo se instancia si la sala tiene una salida por rejilla.
- Nunca habrá más de una rejilla en una sala.
- Dos rejillas no compartirán destino.
- Su colocación no bloqueará las puertas normales.
- Al acercarse, la interfaz indicará la acción disponible de forma breve.
- Al usarla se reutiliza el flujo existente de coste: el jugador decide
  sacrificar una parte equipada o pagar vida.
- No se crea un objeto adicional de tipo `squeeze`.
- Si el coste escogido mata al jugador, la decisión se respeta y termina la
  partida.

La transición solo ocurre después de confirmar y cobrar correctamente el
coste. Cancelar devuelve el control al jugador sin modificar vida, partes o
mapa.

## 4. Ataque ilustrado del enemigo

`Claw_Ataque` pertenece al **Experimento 07 — Crustáceo Escudo**. No es una
animación del slime ni de la parte equipable `crusher_claw`.

Los cinco fotogramas se procesarán a un tamaño de juego, eliminando el lienzo
transparente sobrante pero conservando un punto de anclaje común. Los originales
se mantendrán rastreables dentro de la carpeta del enemigo o se conservará una
receta reproducible del recorte.

La máquina de estados existente seguirá siendo la autoridad:

- al entrar en `PINCH_WINDUP`, comienza la secuencia ilustrada;
- la duración visual se ajusta a `PINCH_WINDUP = 0.8`;
- el fotograma extendido coincide con `_pinch()`;
- `_pinch()` continúa siendo el único lugar que aplica el cono de daño, alcance
  y retroceso;
- al pasar a `RECOVER`, el enemigo vuelve de manera legible a su postura normal;
- la orientación visual sigue el lado al que mira el enemigo;
- el ataque se interrumpe de forma segura si el enemigo muere o sale del árbol.

El drop `crusher_claw` no cambia. Que el enemigo pueda soltar esa parte no
significa que el slime reutilice su animación corporal.

## 5. Importación y control de versiones

Todos los PNG usados en escenas o scripts deben quedar incluidos en Git. Antes
de entregar:

1. se forzará una importación headless de Godot;
2. se verificará que no haya referencias rotas;
3. se comprobará con `git ls-files` que cada textura fuente necesaria esté
   rastreada;
4. no se dependerá del caché local `.godot/`;
5. las escenas deben cargar correctamente en un clon que todavía no tenga
   recursos importados.

Esto evita repetir el fallo previo donde una textura referenciada existía solo
en una máquina.

## 6. Verificación

La integración se considerará completa cuando:

- la introducción A → B se vea a 1920 × 1080 y pueda omitirse sin iniciar la
  partida;
- los botones aparezcan y conserven navegación por teclado y ratón;
- la primera sala muestre el tubo roto sin bloquear al slime;
- varias seeds coloquen utilería sin solapar puertas ni rutas;
- una sala con conexión por rejilla muestre exactamente una rejilla funcional;
- cancelar o pagar el coste de la rejilla produzca el estado esperado;
- el ataque del Crustáceo reproduzca los cinco fotogramas y el daño ocurra en el
  contacto visual;
- el juego, las pruebas procedurales y el smoke test de combate arranquen sin
  errores de recursos.

También se actualizarán `docs/ARQUITECTURA.md` y la referencia operativa que
corresponda para registrar las nuevas escenas, rutas y responsabilidades.
