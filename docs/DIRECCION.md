# DIRECCIÓN — Humano o Monstruo

Documento de diseño. Fija **de qué va el juego** y qué se recorta para llegar ahí.
Es par de [`PLAN.md`](PLAN.md): el PLAN describe el MVP que ya se construyó, este
describe hacia dónde gira. Donde se contradigan, manda este.

Estado: **propuesta cerrada, pendiente de implementar.** Las decisiones marcadas
como PENDIENTE son las únicas que faltan.

---

## 1 · La decisión

Todo el juego es una pregunta, repetida cuatro veces:

> Te arrancaron de un cuerpo humano. Puedes recuperarlo, o puedes quedarte con
> lo que te hicieron. Las dos cosas te sacan de acá. No son la misma salida.

No hay una barra de progreso ni una habilidad "buena". Hay un eje con dos polos,
y el jugador se coloca en él cuatro veces por partida.

### El eje

| | **HUMANO** | **MONSTRUO** |
|---|---|---|
| Verbo | usar el laboratorio | romper el laboratorio |
| Puerta cerrada | la abres | la revientas |
| Un escáner | te reconoce y cede | te marca y dispara |
| Fuerza | poca | mucha |
| Rutas | pasillos, ascensores, terminales | rejillas, tuberías, muros agrietados |
| Cuerpo | rígido, controlado, frágil de reflejos | deformable, violento, tosco |
| Presión | tardas más | te cazan |
| Salida | te abren la puerta | haces tu propio agujero |

**Ninguno de los dos es el camino correcto.** Cada obstáculo del juego tiene las
dos soluciones. Lo que cambia es cómo se siente llegar.

### La ficción

El slime **fue** una persona. No lo dice ningún texto: lo dicen los cadáveres del
laboratorio, que tienen las piezas que te faltan, y los experimentos, que tienen
las que te pusieron.

Sin cinemáticas. La historia es el cuerpo del jugador.

---

## 2 · Las cuatro zonas

Se acaban los seis huecos genéricos. **Cuatro zonas del cuerpo, una parte cada
una, dos opciones por zona.** Ocho partes en todo el juego.

Cuatro decisiones por partida. Dieciséis cuerpos posibles. Un solo eje.

### Catálogo completo

| Zona | HUMANO — gana / pierde | MONSTRUO — gana / pierde |
|---|---|---|
| **PIERNAS** | **Piernas Recuperadas**<br>+ caminas: movimiento continuo, preciso, puedes parar<br>− pierdes el impulso cargado y con él la embestida | **Patas Hidráulicas**<br>+ impulso más largo, DASH con invulnerabilidad, cruzas huecos<br>− no frenas: chocar aturde el doble |
| **BRAZOS** | **Manos**<br>+ `master_key`: paneles, palancas, terminales, ascensores<br>− daño cuerpo a cuerpo ×0,5, no rompes nada | **Garra**<br>+ daño cuerpo a cuerpo ×2, `break_walls`<br>− no operas nada del laboratorio; fallar te clava 0,4 s |
| **CABEZA** | **Rostro**<br>+ lees carteles y mapas, el escáner te reconoce<br>− no ves en la oscuridad ni detectas lo que está oculto | **Sentidos**<br>+ ves enemigos a través de las paredes, marcas puntos débiles<br>− no lees nada: carteles y mapa ilegibles |
| **TORSO** | **Caja Torácica**<br>+ 2 corazones, resistes empujes<br>− sólido: no cruzas rejillas, no regeneras | **Masa Gelatinosa**<br>+ cruzas rejillas y tuberías, regeneras fuera de combate<br>− 2 corazones, cualquier golpe te manda lejos |

Nota de lectura: cada par reparte lo mismo. Uno da **acceso y aguante**, el otro
da **poder y movilidad**. Ninguna casilla está vacía y ninguna es obviamente
mejor. Si al jugar una lo parece, se ajusta esa fila, no el sistema.

### Por qué estas cuatro

- **PIERNAS** es la zona que más se siente, porque cambia el movimiento base. Es
  la primera decisión que debe encontrar el jugador.
- **BRAZOS** es la que más cambia el mapa: `master_key` contra `break_walls`.
- **CABEZA** es información. Es la única que no cambia el combate, y hace falta
  que una no lo haga.
- **TORSO** es supervivencia contra rutas. Es la más dolorosa de decidir.

---

## 3 · Reglas del sistema

### Humanidad

```
humanidad = zonas humanas − zonas monstruo        rango −4 .. +4
```

Zona vacía cuenta 0. Arrancas en 0: slime desnudo, ni una cosa ni la otra.

**El mundo consulta el signo, no el número.** `humanidad > 0` el laboratorio te
trata como personal; `< 0` como fuga biológica; `= 0` no te ve.

Nunca se muestra el número. Se muestra el cuerpo (§5) y lo que el laboratorio
hace contigo (§4).

### Exclusividad e irreversibilidad

- Una zona admite **una** parte. Poner la contraria no está permitido: **la zona
  se cierra al equipar.**
- Cuatro decisiones por partida, todas definitivas.

> **Por qué irreversible.** Es lo que hace que la decisión pese, y es más simple
> de implementar y de entender que cualquier sistema de coste por cambiar. Si al
> probarlo resulta demasiado cruel, la variante suave es: cambiar de bando en una
> zona cuesta **un corazón de vida máxima permanente**. Se decide jugando, no
> discutiendo. → PENDIENTE-1

### Comer partes

El verbo que ya existe se queda, con una regla nueva:

- **Solo se come carne de experimento.** Da ½ corazón.
- **Las partes humanas no se comen.** No te alimentan.

Consecuencia gratis: la vía humana tiene menos curación disponible. La vía
monstruo se sostiene sola y por eso el laboratorio tiene que apretarla (§4).

Comer **no** mueve el eje. Es la válvula neutra: qué haces con la parte que no
elegiste, o con la que llega cuando la zona ya está cerrada.

### El momento de decidir

Cada sala con experimento ofrece **las dos partes de una misma zona**:

- el experimento muerto suelta la parte de monstruo;
- el laboratorio tiene la humana — en un cadáver, una prótesis, una vitrina.

Están las dos en la sala, a la vista, al mismo tiempo. Recoges una y **la otra se
queda ahí**, visible, mientras cruzas la puerta. Eso es la decisión y hay que
poder verla quedarse atrás.

---

## 4 · Contrato de las dos vías

El eje solo existe si el mundo lo consulta. Hoy no lo hace: `master_key` está
declarada en `core/parts_db.gd` y **no la lee nadie**, y `break_walls` solo
alimenta `break_shield` de un arco cuerpo a cuerpo en
`actors/player/abilities/ability_runner.gd` — no rompe ninguna pared. Ese es el
agujero central que cierra este documento.

### Banderas que el mundo pregunta

| Bandera | La da | Abre |
|---|---|---|
| `master_key` | Manos | paneles, terminales, palancas, ascensores, puertas con cerradura |
| `break_walls` | Garra | muros agrietados, barricadas, vitrinas |
| `squeeze` | Masa Gelatinosa | rejillas, tuberías, pasos angostos |
| `read` | Rostro | carteles, mapa del piso, códigos |
| `see_through` | Sentidos | enemigos y trampas tras las paredes |
| `walk` | Piernas Recuperadas | movimiento continuo (sustituye al impulso cargado) |

Todas se consultan con `Inventory.mod_flag()`, que ya existe.

### Regla dura de nivel

> **Toda sala tiene al menos una ruta para cada bando.** Ninguna combinación de
> las dieciséis puede quedar encerrada.

Las rutas **no** son equivalentes. La asimetría es el juego:

- Salas donde el monstruo pasa en cinco segundos por un muro y el humano da un
  rodeo de un minuto por el ascensor.
- Salas donde el humano abre una puerta y sigue, y el monstruo tiene que matar
  todo lo que hay dentro.

Si las dos rutas cuestan lo mismo, el eje es decorativo.

### El laboratorio reacciona

Es la presión que equilibra al monstruo, que si no es poder gratis.

| Humanidad | La instalación |
|---|---|
| `> 0` | Las puertas ceden. Los escáneres te dejan pasar. Nadie te persigue. |
| `= 0` | Indiferente. No te reconoce ni te caza. |
| `< 0` | Los escáneres te marcan. Se activan torretas y alarmas. La instalación te caza. |

Un solo umbral, en el signo. Nada de tablas de reputación.

---

## 5 · Beneficio y costo, en la animación

Requisito no negociable: **el jugador tiene que ver lo que gana y lo que pierde,
sin abrir un menú.** Con un eje binario esto se vuelve fácil, porque toda parte
da a un lado y quita al otro, siempre.

Tres capas. Ninguna necesita arte nuevo.

### Capa 1 — El momento de equipar

Beat de ~1 segundo, con el juego detenido. **La parte se acopla y algo se cae.**

- **Humana:** el miembro brota y un pedazo de gel se desprende, cae y se disuelve.
- **Monstruo:** la carne se hincha y desgarra piel humana que se queda en el suelo.

Dos iconos junto al cuerpo: `+` lo que ganas, `−` lo que pierdes. Un sonido que
sube, otro que baja. Ganancia y pérdida en el mismo gesto: imposible no
entenderlo.

### Capa 2 — El cuerpo, permanente, en cada frame

Es la capa más importante y la más barata. Las amplitudes de deformación están
fijas en `_update_visual()` de `actors/player/slime.gd`:

| Constante actual | Qué hace |
|---|---|
| `0.22` / `0.16` | compresión al cargar |
| `0.36` / `0.26` | estiramiento en vuelo |
| `0.24` / `0.20` | aplastamiento al aterrizar |
| `0.04` | respiración en reposo |

**Escalarlas por la humanidad.** Un solo valor mueve el cuerpo entero:

| Humanidad | Cuerpo |
|---|---|
| `+4` | casi no deforma. Respira. Se yergue. Silueta angulosa, color hacia piel. Núcleo apagado. |
| `0` | como está hoy. |
| `−4` | deformación exagerada, la silueta gotea, el núcleo brilla. |

El squash-and-stretch es lo que hace que el slime se lea como gel. **Quitárselo
es la mejor animación de pérdida del proyecto y no cuesta ni un sprite.**

### Capa 3 — El tell por parte

Cada penalización necesita su gesto visible, o para el jugador no existe:

| Parte | Tell del costo |
|---|---|
| Piernas Recuperadas | la barra de carga desaparece. La pérdida de potencia se siente en el primer paso. |
| Patas Hidráulicas | choque contra pared: el aturdimiento largo, aplastado y sin control. |
| Manos | el golpe cuerpo a cuerpo es corto y blando; el arco se ve pequeño. |
| Garra | fallar deja el brazo clavado y arrastrando (`whiff_lock`, ya implementado). |
| Rostro | la oscuridad se cierra alrededor. El juego ya corre al 47 % de brillo: muerde solo. |
| Sentidos | los carteles y el mapa se ven corruptos, no en blanco. Hay texto y no puedes leerlo. |
| Caja Torácica | frente a una rejilla, el cuerpo choca y no entra. Se ve el intento. |
| Masa Gelatinosa | cualquier golpe te manda al otro lado de la sala. |

Regla general: **un costo que no tiene tell hay que borrarlo del diseño**, porque
el jugador ya está pagándolo sin saberlo.

---

## 6 · Finales

`ui/ending.gd` ya existe. Ramifica por signo:

| Humanidad | Final |
|---|---|
| `> 0` | Sales caminando por la puerta principal. La instalación te deja ir. |
| `< 0` | Abres un agujero y sales por él. |
| `= 0` | PENDIENTE-2 — dos finales bastan para el jam. El tercero (ninguno de los dos bandos te reclama) solo si sobra tiempo. |

---

## 7 · Qué se recorta

Migración desde el estado actual. Todo es borrar, salvo el punto 3.

| # | Archivo | Cambio |
|---|---|---|
| 1 | `core/parts_db.gd` | 44 partes → **8**. Se conservan `body_zone`, `mods` y los `EFFECT_*`; se borra el resto del catálogo. Cada entrada gana dos campos: `gain` y `lose`, texto corto que se muestra al recoger. |
| 2 | `autoload/inventory.gd` | `SLOT_COUNT = 6` genéricos → **4 zonas fijas**. La exclusividad por `body_zone` ya está escrita y pasa a ser la regla principal. Zona ocupada = cerrada. |
| 3 | `world/props/door.gd` y props nuevos | **Añadir** el contrato de §4: los obstáculos declaran qué bandera los abre y consultan `Inventory.mod_flag()`. Es lo único que se construye de cero. |
| 4 | `actors/player/abilities/ability_runner.gd` | `break_walls` deja de significar `break_shield`. Pasa a romper muros de verdad. |
| 5 | `autoload/game_state.gd` | Fuera el bono `+0,5 % de daño por parte de jefe consumida`: es imperceptible y no decide nada. Entra `humanity()`. |
| 6 | `ui/inventory_ui.gd` | Deja de ser una rejilla de seis huecos. Pasa a ser **el cuerpo**: cuatro zonas dibujadas sobre una silueta, cada una con su parte y su costo a la vista. |
| 7 | `actors/player/slime.gd` | Las constantes de `_update_visual()` se escalan por humanidad (§5, capa 2). |
| 8 | `prueba_2/docs/ART_SPEC.md` | Los 44 iconos de parte caen a 8. Se añade la silueta del slime por nivel de humanidad. Es el mayor ahorro de arte del proyecto. |

El movimiento continuo por piernas ya estaba anticipado como habilidad futura en
[`AGENTS.md`](../AGENTS.md) §3.12. Encaja sin pelear con nada.

---

## 8 · Riesgos

1. **Que las dos vías sean igual de buenas.** Si todo obstáculo se resuelve igual
   de bien por los dos lados, el eje es cosmético. La asimetría de §4 es
   obligatoria, no un adorno.
2. **Que ser monstruo salga gratis.** Es el bando con más poder y más curación.
   Sin la persecución de §4 nadie se humaniza.
3. **Que el jugador no note que decidió.** Por eso la parte rechazada se queda en
   el suelo a la vista, y por eso el cuerpo cambia para siempre (§5).
4. **Que la irreversibilidad frustre.** Es el riesgo aceptado a cambio de que la
   decisión pese. → PENDIENTE-1.

---

## 9 · Pendientes

| # | Decisión | Recomendación |
|---|---|---|
| PENDIENTE-1 | ¿Zona irreversible, o reversible pagando un corazón permanente? | Irreversible. Es más simple y pesa más. Revisar tras la primera partida jugada. |
| PENDIENTE-2 | ¿Tercer final para humanidad `= 0`? | No para el jam. |
| PENDIENTE-3 | ¿Cuántas salas por zona antes de forzar la decisión? | Una zona por piso, cuatro pisos. Encaja con el mapa que ya existe. |

Lo demás está cerrado. Se implementa en el orden de §7.
