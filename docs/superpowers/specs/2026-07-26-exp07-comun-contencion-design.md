# EXP07 común en Contención — diseño

Fecha: 2026-07-26  
Estado: aprobado  
Alcance: generación de enemigos del primer piso

## Objetivo

Hacer que el Crustáceo Escudo aparezca con frecuencia en las salas de combate
de Contención y garantizar que el jugador encuentre al menos uno durante cada
partida.

## Combates normales

El pool de enemigos de las salas procedurales normales será:

```gdscript
["exp01", "exp02", "exp03", "exp07"]
```

Cada entrada tendrá el mismo peso. La selección determinista existente, basada
en el ID de sala y el índice del enemigo, dará a EXP07 aproximadamente un
`25 %` de las apariciones normales.

El cambio no altera la cantidad de enemigos de cada contenido:

- `easy`: un enemigo;
- `hard`: entre dos y tres;
- destino de rejilla con combate: entre uno y dos.

## Garantía preboss

La sala con rol `preboss` conservará tres enemigos cuando no declare una
cantidad explícita.

- Los enemigos secundarios se seleccionarán únicamente entre `exp01`, `exp02`
  y `exp03`.
- El último enemigo será siempre `exp07`.
- El último enemigo seguirá marcado como líder de sala.

Esto garantiza exactamente un Crustáceo Escudo en el encuentro preboss y evita
que la garantía produzca varios EXP07 juntos por accidente.

Como la escena de EXP07 tiene `drop_parts = ["crusher_claw"]` y `EnemyBase`
garantiza el drop de los líderes, derrotarlo entregará Tenaza Trituradora.

## Determinismo y responsabilidades

`MapGenerator` continúa decidiendo topología, contenido y cantidad de enemigos.
`procedural_room.gd` continúa resolviendo qué escena corresponde a cada
aparición. No se fijará un ID de sala ni una dirección cardinal.

Una misma seed conservará el mismo mapa y los mismos tipos de enemigos. La
entrada/tutorial y la sala del cuerpo seguirán sin enemigos.

## Verificación

La implementación se acepta cuando:

1. cuatro salas normales con IDs que cubren los cuatro residuos del selector
   generan una aparición de cada tipo, incluido EXP07;
2. la rotación normal asigna a EXP07 una de cada cuatro posiciones;
3. una sala preboss con tres enemigos contiene exactamente un EXP07;
4. el EXP07 preboss es el líder de sala;
5. los dos enemigos secundarios del preboss no son EXP07;
6. el líder conserva como único drop `crusher_claw`;
7. el modelo procedural sigue validando 1.000 seeds;
8. el smoke test de combate termina sin fallos;
9. la partida inicia sin errores y permite encontrar al enemigo en el primer
   piso.

La frecuencia percibida y la dificultad del encuentro requieren una prueba
jugable humana.
