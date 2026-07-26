# Iluminación tenue y modo de prueba

## Objetivo

Hacer visible la habitación completa bajo una penumbra azulada, conservando la
lectura local de las lámparas, y permitir que el equipo pruebe una partida sin
morir mediante un interruptor de vida infinita dentro de TAB.

## Iluminación

- `game/main.tscn::Darkness` sigue siendo la única luz ambiental global.
- Su color sube desde el negro actual a un gris azulado tenue. El objetivo visual
  es distinguir suelo, paredes, puertas, enemigos y props en toda la sala sin
  convertir la escena en luz diurna.
- Las lámparas conservan energía `1.6`, radio `1.85`, color cálido, parpadeo y
  estado fundido. El cambio ambiental no modifica `lamp.gd` ni `lamp.tscn`.
- La aceptación visual se revisa en una sala con zonas alejadas de focos: toda la
  geometría debe ser legible y las manchas cálidas de las lámparas todavía deben
  destacar.

## Modo de prueba en TAB

### Interfaz

- `BodyPanel` añade un interruptor visible:
  `MODO PRUEBA · VIDA INFINITA: NO/SÍ`.
- Se puede alternar con clic o con `V` mientras el overlay de TAB está abierto.
- El estado activo usa el color cálido de selección y el inactivo conserva el
  estilo normal del panel.
- La navegación con flechas sigue dedicada a seleccionar partes; `F` sigue
  comiendo la parte seleccionada.

### Estado y duración

- `GameState` es la autoridad de `infinite_health`.
- Activarlo persiste al cambiar de sala durante la partida actual.
- `GameState.reset_run()` lo vuelve a `false`; por tanto, nueva partida, reinicio
  o regreso al título no conservan el modo de prueba.
- Un cambio emite una señal para que TAB actualice texto y estilo sin sondeo.

### Contrato de daño

- Con `infinite_health == false`, el daño mantiene el comportamiento existente.
- Con `infinite_health == true`, `damage_halves()` no reduce
  `health_halves`, no consume salvavidas y no emite muerte.
- El golpe sigue llegando a `slime.take_damage()`, por lo que conserva sonido,
  destello, invulnerabilidad temporal y retroceso. Solo se bloquea la mutación de
  HP en `GameState`.
- Las curaciones y los cambios de vida máxima continúan funcionando.

## Límites

- Es una herramienta local de prueba, no una opción del menú principal.
- No concede daño infinito, habilidades sin recarga ni invulnerabilidad física.
- No se guarda en disco ni entre partidas.
- No altera la lógica de rejillas que permite pagar vida.

## Verificación

- Prueba de estado: activar evita pérdida de HP y muerte; desactivar restaura el
  daño; `reset_run()` lo apaga.
- Prueba de UI: clic y `V` alternan el estado, actualizan el texto y no consumen
  partes.
- Prueba visual a 1920 × 1080: sala completa legible, lámparas aún visibles y
  diferenciadas.
- La regresión completa se mantiene aplazada hasta terminar el conjunto de
  cambios solicitado por el equipo.
