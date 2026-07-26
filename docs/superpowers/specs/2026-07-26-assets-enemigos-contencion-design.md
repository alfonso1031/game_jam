# Assets animados de enemigos de Contención — diseño

Fecha: 2026-07-26
Estado: aprobado
Alcance: enemigos que puede instanciar el primer piso, Contención

## Objetivo

Reemplazar las formas primitivas y el sprite estático de los enemigos del
primer piso por arte ilustrado y animado, conservando las mecánicas, tiempos,
colisiones, drops y dificultad actuales.

El generador procedural de Contención instancia:

- EXP01 — Ciempiés de Agujas;
- EXP02 — Arácnido Blindado;
- EXP03 — Saurio Escamado;
- EXP07 — Crustáceo Triturador;
- Quimera Albina — jefe del piso.

EXP07 ya tiene arte y animaciones funcionales. Se conservará como referencia
visual y no se redibujará. El trabajo nuevo cubre EXP01, EXP02, EXP03 y la
Quimera Albina.

## Fuera de alcance

- EXP04, EXP05, EXP06, EXP08, EXP09 y EXP10, porque no aparecen en Contención.
- Nuevas mecánicas, cambios de daño, vida, velocidad, alcance o probabilidad de
  aparición.
- Rediseñar la colisión de EXP07.
- La fuente de recompensa de la segunda sala. Actualmente es un prop narrativo,
  no un enemigo con máquina de estados o descripción aprobada. No se inventará
  su comportamiento dentro de este cambio.
- Animaciones de muerte. Los enemigos actuales desaparecen inmediatamente al
  morir; añadir una fase de muerte modificaría el ciclo de sala.

## Dirección visual

El arte seguirá el lenguaje de EXP07:

- ilustración 2D de formas orgánicas y planos de color suaves;
- perspectiva cenital inclinada 3/4;
- silueta legible a distancia;
- orientación fuente hacia la derecha;
- un detalle luminoso que permita reconocer el frente;
- ausencia de texto, sombras proyectadas y fondo;
- brillo normal, porque la iluminación y el oscurecimiento los aplica Godot;
- blancos por debajo de `#E0E0E0` para conservar el destello de daño.

Las poses de aviso deben ser más diferentes entre sí que las poses de
locomoción. El jugador debe reconocer el ataque antes de que termine su
temporizador sin depender de texto de interfaz.

## Estrategia de generación

Se utilizará un enfoque híbrido de poses ilustradas más transformación en
Godot.

Cada personaje nuevo partirá de una hoja de seis poses en una cuadrícula 3 × 2.
La hoja tendrá fondo plano magenta para extraer transparencia sin confundirlo
con los verdes, azules o marrones del personaje. Todas las celdas mantendrán:

- el mismo personaje y proporciones;
- el mismo punto de apoyo;
- escala uniforme;
- orientación hacia la derecha;
- espacio libre alrededor de la silueta;
- ninguna línea divisoria, etiqueta, número o texto.

Tras retirar el fondo, las poses se separarán y normalizarán a los lienzos de
runtime. `AnimatedSprite2D` reproducirá las poses importantes y Godot seguirá
aplicando giro visual, volteo, estiramiento, destello de daño y estados
alterados.

Este método evita dos extremos:

- un único dibujo por estado, que se sentiría rígido;
- una animación completamente dibujada de más de cincuenta imágenes, difícil
  de mantener coherente durante una game jam.

## Tamaños y registro

| Personaje | Lienzo runtime | Ocupación visual aproximada | Pivote |
|---|---:|---:|---|
| EXP01 | 160 × 160 px | 104 × 58 px | centro |
| EXP02 | 160 × 160 px | 92 × 92 px | centro |
| EXP03 | 160 × 160 px | 96 × 76 px | centro |
| Quimera Albina | 384 × 256 px | 350 × 205 px | centro |

Los lienzos conservan margen suficiente para que espinas, patas, cola y alas no
se recorten durante los avisos. La Quimera mantiene una silueta más ancha que
su cápsula física: las alas comunican volumen, pero el contacto continúa
resolviéndose alrededor del cuerpo central.

## EXP01 — Ciempiés de Agujas

### Lectura visual

Cuerpo largo y segmentado, placas gris azuladas, patas cortas y una fila de
espinas inclinadas hacia atrás. La cabeza y el detalle luminoso quedan al lado
derecho. Debe verse más ligero y flexible que el jefe y que EXP07.

### Seis poses fuente

1. `approach_a`: cuerpo ondulado hacia arriba;
2. `approach_b`: cuerpo ondulado hacia abajo;
3. `windup_a`: segmentos comprimiéndose;
4. `windup_b`: espinas levantadas y cabeza baja;
5. `charge`: cuerpo totalmente estirado y espinas pegadas;
6. `rest`: cuerpo doblado, espinas caídas y cabeza contra el suelo.

### Animaciones runtime

| Animación | Secuencia | Relación mecánica |
|---|---|---|
| `approach` | 1, 2, 1 en bucle | acompaña el zigzag |
| `windup` | 3, 4 sin bucle | termina dentro de `0.65 s` |
| `charge` | 5 | se mantiene durante la embestida |
| `rest` | 6 | ventana de castigo |

El último fotograma de `windup` debe quedar visible antes de que
`_enter_charge()` congele la dirección.

## EXP02 — Arácnido Blindado

### Lectura visual

Caparazón octogonal pesado, ocho patas mecánico-orgánicas y abdomen protegido.
La boca de red apunta hacia la derecha. Las patas delanteras comunican el
aplastamiento y el abdomen comunica el disparo; ambos avisos deben ser
inequívocamente distintos.

### Seis poses fuente

1. `reposition_a`: apoyo sobre patas diagonales;
2. `reposition_b`: apoyo alterno;
3. `shoot_windup`: abdomen inflado y boca de red abierta;
4. `shoot_release`: cabeza extendida en la dirección del proyectil;
5. `slam_windup`: cuerpo elevado y patas abiertas;
6. `slam_impact`: cuerpo bajo, patas clavadas y caparazón comprimido.

### Animaciones runtime

| Animación | Secuencia | Relación mecánica |
|---|---|---|
| `reposition` | 1, 2 en bucle | movimiento lateral lento |
| `shoot_windup` | 3, 4 sin bucle | concluye dentro de `0.75 s` |
| `slam_windup` | 5, 6 sin bucle | concluye dentro de `0.9 s` |
| `recover` | 6, 2 | vuelve a la postura de locomoción |

El proyectil y el área de aplastamiento siguen naciendo desde el script; la
imagen no aplica daño ni modifica su alcance.

## EXP03 — Saurio Escamado

### Lectura visual

Reptil sin ojos, cabeza en cuña, placas verdes grisáceas y cola gruesa. La
ausencia de ojos comunica que es ciego. La cabeza debe diferenciarse claramente
de la cola para que el jugador entienda que el frente es la zona segura y el
flanco activa el coletazo.

### Seis poses fuente

1. `walk_a`: apoyo delantero;
2. `walk_b`: apoyo trasero;
3. `tail_windup_a`: cola comenzando a enrollarse;
4. `tail_windup_b`: cuerpo bajo y cola completamente tensada;
5. `tail_sweep`: cola extendida lateralmente alrededor del cuerpo;
6. `recover`: cola caída y cuerpo desequilibrado.

### Animaciones runtime

| Animación | Secuencia | Relación mecánica |
|---|---|---|
| `walk` | 1, 2 en bucle | presión continua |
| `tail_windup` | 3, 4, 5 sin bucle | concluye dentro de `0.5 s` |
| `recover` | 6, 1 | vuelve a caminar dentro de `0.55 s` |

El fotograma de barrido aparece al final del aviso. `_swipe()` continúa siendo
la única autoridad del cono de daño y del retroceso.

## EXP07 — Crustáceo Triturador

Se conservan:

- `exp07_crustacean_00.png` a `exp07_crustacean_02.png`;
- `exp07_pinch_00.png` a `exp07_pinch_04.png`;
- `exp07_crustacean_frames.tres`;
- los estados `advance`, `pinch_windup` y `recover`.

No se redibuja ni se comparte su animación con el slime. Únicamente se
mantendrá el mismo contrato de nombres y reproducción que usarán los enemigos
nuevos.

## Quimera Albina — jefe

### Lectura visual

Criatura albina ancha, baja y alada, con cuerpo central claramente sólido.
Debe conservar la identidad del asset actual, pero separar visualmente la
ráfaga hacia la esquina, el apuntado y el salto. Las alas nunca deben parecer
una barrera física completa: la cápsula de contacto sigue centrada en el torso.

### Seis poses fuente

1. `seek_a`: alas alternadas hacia arriba;
2. `seek_b`: alas alternadas hacia abajo;
3. `aim_a`: cuerpo comprimido y alas cerrándose;
4. `aim_b`: cuerpo aún más bajo y detalle frontal iluminado;
5. `pounce`: cuerpo y alas estirados hacia delante;
6. `recover`: alas abiertas, cuerpo aplastado y desorientado.

### Animaciones runtime

| Animación | Secuencia | Relación mecánica |
|---|---|---|
| `seek_corner` | 1, 2 en bucle | ráfaga hacia una esquina |
| `corner_aim` | 3, 4 en bucle lento | acompaña la línea de apuntado |
| `pounce` | 5 | activo durante el contacto dañino |
| `recover` | 6, 1 | ventana antes de buscar otra esquina |

La velocidad de la animación de apuntado no modifica `AIM_TIME`; debe seguir
funcionando durante las tres fases del jefe. El estiramiento existente de
`_update_visual()` se conserva como refuerzo de la pose `pounce`.

## Integración en Godot

### Enemigos normales

Para EXP01, EXP02 y EXP03:

1. crear una carpeta propia bajo `prueba_2/assets/enemies/`;
2. guardar allí las poses procesadas y su importación;
3. crear `expXX_*_frames.tres`;
4. sustituir `Body: Polygon2D` por `Sprite: AnimatedSprite2D` en la escena;
5. añadir `_visual_state()` al script para traducir el estado actual al nombre
   de animación;
6. conservar las formas físicas, propiedades exportadas, drops y grupos;
7. usar `advance` o la animación normal equivalente como `autoplay`.

`enemy_base.gd` seguirá encargándose del volteo horizontal, estados alterados,
destello de daño y fallback si faltara una animación.

### Jefe

En `boss_core.tscn`, `Sprite2D` se convertirá en `AnimatedSprite2D` y usará un
recurso `SpriteFrames` propio. `boss_core.gd` seleccionará la animación según
`SEEK_CORNER`, `CORNER_AIM`, `POUNCE` y `RECOVER`, sin reiniciarla en cada
fotograma.

La línea de apuntado, la vida, el contacto, las fases y los drops continúan
siendo autoridad de `boss_core.gd`.

## Estructura de archivos

Fuentes de generación:

```text
art_raw/enemies/containment/
  exp01_centipede/
  exp02_spider/
  exp03_saurian/
  boss_chimera/
```

Recursos cargados por Godot:

```text
prueba_2/assets/enemies/
  exp01_centipede/
  exp02_spider/
  exp03_saurian/

prueba_2/assets/bosses/containment_chimera/

prueba_2/actors/enemies/
  exp01_centipede_frames.tres
  exp02_spider_frames.tres
  exp03_saurian_frames.tres

prueba_2/actors/boss/
  boss_core_frames.tres
```

## Errores y fallback

- Ningún script usará `preload()` hacia un PNG que no esté rastreado por Git.
- Las escenas apuntarán a `SpriteFrames`; la lógica no conocerá rutas de
  fotogramas individuales.
- Si una animación solicitada no existe, los enemigos normales usarán el
  `autoplay` existente en vez de romper la escena.
- El jefe conservará una animación predeterminada válida desde el `.tscn`.
- Los originales de generación quedarán fuera de `prueba_2` para que Godot no
  los incluya en la exportación.
- Se validará que las esquinas sean transparentes y que no queden bordes
  magenta antes de integrar cada pose.

## Verificación

De acuerdo con la instrucción actual del equipo, no se ejecutarán suites
automáticas durante esta implementación. La verificación será:

1. importar el proyecto con Godot para generar la caché local;
2. comprobar que todas las escenas de enemigos cargan sin recursos faltantes;
3. abrir una partida de Contención;
4. observar EXP01, EXP02, EXP03 y EXP07 en salas normales y preboss;
5. observar la Quimera en las cuatro fases visuales;
6. confirmar manualmente que el daño coincide con el último fotograma del aviso;
7. comprobar con Git que todos los PNG, `SpriteFrames`, escenas y scripts
   necesarios están rastreados;
8. iniciar el juego en un checkout sin depender de archivos dentro de
   `.godot/`.

## Criterios de aceptación

- Ningún enemigo que aparece en Contención usa `Polygon2D` como cuerpo final.
- EXP01, EXP02 y EXP03 muestran locomoción, aviso, ataque y recuperación
  distinguibles.
- EXP07 conserva su comportamiento y animaciones actuales.
- La Quimera Albina anima desplazamiento, apuntado, salto y recuperación.
- Los avisos terminan visualmente antes de la llamada que aplica el ataque.
- No cambian vida, daño, velocidad, colisiones, drops ni probabilidades.
- Todos los recursos visibles están incluidos en Git y cargan en un clon
  limpio.
