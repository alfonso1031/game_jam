# Boss de Contención, rejillas, audio y presentación

## Objetivo

Completar la primera zona jugable sin alterar los contratos ya aprobados: integrar una
Quimera como boss final de Contención, volver utilizables las rejillas, añadir música de
menú y partida, y llevar la arena y la interfaz a una presentación coherente en
1920×1080.

## Precedencia de reglas

El texto recibido conserva la intención estructural, pero contiene valores sustituidos
por decisiones posteriores. Para no deshacer trabajo aprobado, mandan los contratos de
`AGENTS.md` y `docs/ARQUITECTURA.md`:

- vida inicial `7 HP`, máxima `15 HP` y curación `+2 HP`;
- salas normales `40 %` fácil, `30 %` difícil, `20 %` vacía y `10 %` cierre;
- destinos de rejilla `40 %` vacío, `40 %` loot y `20 %` combate;
- máximo una rejilla por sala, costo de parte o `1 HP`, retorno gratuito durante la run;
- preboss con tres enemigos y EXP07 como líder;
- solo se muestran salas visitadas y no se introduce persistencia entre partidas.

Se conservan del texto recibido los hitos posicionales S1, S2, preboss y boss, el camino
principal de 6–8 salas, el máximo de 12, la exclusividad de destinos, la validación
anti-softlock y la restricción de rejillas a combates.

## Boss de Contención

Se mantiene `actors/boss/boss_core.tscn` para conservar las referencias legacy, la capa
de boss y el pickup de DASH. Su presentación pasa de polígonos provisionales a la Quimera
del ZIP, procesada como PNG transparente y acompañada por un decal de arena.

El ciclo es:

1. **Ráfaga a esquina:** el boss elige una esquina distinta dentro del rectángulo jugable
   y se desplaza rápidamente hasta ella.
2. **Acecho:** se detiene durante `0,8 s`, mira al jugador y muestra la trayectoria.
3. **Lanzamiento:** fija una instantánea de la posición del jugador y se lanza hacia ella;
   no corrige la dirección durante la embestida.
4. **Recuperación:** frena durante `0,55 s` y vuelve a buscar otra esquina.

La Quimera tiene `12 HP`, recibe daño de las habilidades existentes, hace `1 HP` de daño
por contacto durante el lanzamiento y usa tres fases: al perder vida reduce la pausa y
aumenta velocidad. Sus puertas se sellan al entrar y se liberan al morir. La derrota:

- marca la sala y el boss como completados;
- otorga el pickup de DASH existente;
- suelta `silent_claws` como parte de boss;
- completa Contención una sola vez para disparar la curación y la ruta de ascenso.

La última sala procedural (`role = boss_choice`) instancia este boss en el centro y no
genera enemigos normales.

## Rejillas

La pared sigue siendo sólida: la rejilla representa una transición por interacción, no
un hueco caminable. El fallo actual es geométrico: el `Area2D` está centrado dentro de la
pared y su sensor no alcanza la posición máxima a la que puede llegar el jugador.

El sprite permanece en `DOOR_POSITIONS[direction]`, mientras el
`CollisionShape2D` del sensor se desplaza `105 px` hacia el interior. Esto permite mostrar
`E · USAR REJILLA` sin abrir un agujero por el que el jugador pueda salir del escenario.
Las pruebas instancian jugador, sala fuente y destino, comprueban detección real, costo y
`GrateSpawn`.

## Música

Los dos `.opus` recibidos se copian a `assets/audio/music/` con nombres sin espacios:

- `main_menu.opus`: portada;
- `containment_ambience.opus`: partida.

Godot los importa como recursos de audio; si el importador rechaza Opus, se convierten a
Ogg Vorbis sin modificar el contenido musical. Cada escena posee su propio
`AudioStreamPlayer` en bucle, con volumen moderado, de modo que el cambio de escena
detiene una pista antes de iniciar la otra. No se mezcla esta música con
`slime_audio.gd`, que conserva exclusivamente efectos del jugador.

## Escenario e interfaz

Se generan dos assets runtime:

- Quimera limpia con transparencia, fiel al diseño recibido;
- decal cenital de arena de Contención con anillo técnico, marcas de esquina y señales de
  peligro, sin texto y con centro libre.

La arena se instancia solo en la sala de boss y queda por debajo de actores. El resto de
salas conserva sus fondos, utilería, sangre, cuerpo, mural e iluminación.

La UI adopta un tema compartido IcyWitch:

- botones con estados normal, hover, focus y pressed claramente distintos;
- paneles oscuros translúcidos, bordes turquesa y foco cálido;
- portada con panel de acciones legible sobre la ilustración;
- HUD con marco de salud y minimapa más claros;
- mapa de TAB con encabezado local y separación visual entre cuerpo y mapa;
- pausa, costo de rejilla, ruta y resumen con el mismo lenguaje visual.

No se reintroducen textos explicativos eliminados ni controles en la portada. Los cambios
se validan en 1920×1080 y 1280×720.

## Verificación

- test de boss: ciclo de esquina, instantánea del objetivo, daño, recompensas y aparición
  procedural;
- test de rejillas: sensor accesible, prompt, transición y retorno;
- importación y carga real de ambos audios;
- `run_map_tests.gd` sobre 1.000 seeds;
- `run_lifecycle_tests.tscn`, `combat_smoke.tscn` y suites de UI;
- capturas de portada, HUD, mapa, rejilla y arena;
- arranque jugable limpio mediante Godot MCP.

El balance fino de velocidades, volumen y dificultad requiere validación humana aunque
las pruebas automáticas pasen.
