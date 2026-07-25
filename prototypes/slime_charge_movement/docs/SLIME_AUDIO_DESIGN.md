# Diseño de audio del slime

## Objetivo

Crear un paquete original de efectos viscosos y biológicos para comunicar el
estado del cuerpo del slime durante su movimiento. Los sonidos deben reforzar la
lectura de la mecánica sin convertirla en una criatura cómica ni en una
representación explícitamente sangrienta.

El paquete se probará primero en `prototypes/slime_charge_movement/` y después se
portará a `prueba_2/`, que ya contiene el impulso cargado como movimiento base.

## Contexto revisado

Los commits `8422285` y `b14a08d` introdujeron reglas que afectan directamente al
diseño sonoro:

- Existe una carga mínima de `0.18 s`. Soltar antes produce un fallo y una
  recuperación de `0.28 s`.
- Chocar contra una pared termina el movimiento y aplica `0.45 s` de
  recuperación.
- El impulso y el DASH usan una curva de velocidad. El sonido debe seguir el
  progreso real del estado, no asumir velocidad constante.
- El DASH continúa siendo una habilidad diferente: es más potente, concede
  invulnerabilidad y cruza huecos.

No existe todavía infraestructura de audio ni archivos de sonido en ninguno de
los dos proyectos.

## Dirección sonora

La identidad combina tres capas sintetizadas:

1. **Masa húmeda:** ruido filtrado y modulaciones lentas que sugieren líquido
   espeso.
2. **Presión interna:** tonos graves inestables y burbujas que aumentan durante
   la carga.
3. **Membrana elástica:** transitorios con cambios rápidos de tono para el
   lanzamiento, el impacto y la recuperación.

No se utilizarán grabaciones ni muestras de terceros. Todos los WAV se generarán
matemáticamente desde cero mediante un script reproducible, por lo que no
requieren atribución externa.

## Archivos

Formato común: WAV mono, PCM de 16 bits, `48 kHz`, con fades cortos y pico por
debajo de `-1 dBFS`.

| Archivo | Duración aproximada | Función |
|---|---:|---|
| `slime_charge_loop.wav` | `1.0 s` | Bucle continuo de presión húmeda |
| `slime_charge_full.wav` | `0.18 s` | Confirmación de carga completa |
| `slime_fizzle.wav` | `0.28 s` | Carga liberada antes del mínimo |
| `slime_launch_01.wav` | `0.24 s` | Liberación elástica del impulso |
| `slime_launch_02.wav` | `0.26 s` | Variante del lanzamiento |
| `slime_dash.wav` | `0.30 s` | Liberación más agresiva para el DASH |
| `slime_impact_01.wav` | `0.34 s` | Golpe húmedo contra pared |
| `slime_impact_02.wav` | `0.38 s` | Variante del impacto |
| `slime_recover_01.wav` | `0.22 s` | Reconstitución tras recorrido limpio |
| `slime_recover_02.wav` | `0.25 s` | Variante de recuperación |
| `slime_idle.wav` | `1.6 s` | Actividad orgánica opcional y muy tenue |

El sonido de reposo quedará desactivado por defecto durante la primera prueba
para evitar fatiga auditiva.

## Componente de integración

La reproducción no se mezclará directamente con la máquina de estados. Un
componente hijo `SlimeAudio` encapsulará los reproductores y expondrá esta API:

```gdscript
func begin_charge() -> void
func update_charge(power: float) -> void
func charge_full() -> void
func fizzle() -> void
func launch() -> void
func dash() -> void
func impact() -> void
func recover() -> void
func stop_charge() -> void
```

El controlador del jugador seguirá siendo la autoridad sobre los estados. Solo
notificará al componente cuando ocurra una transición.

### Comportamiento de la carga

- `begin_charge()` inicia el bucle.
- `update_charge(power)` interpola el volumen y el tono según la barra:
  `pitch_scale` de `0.85` a `1.18` y volumen de `-20 dB` a `-8 dB`.
- `charge_full()` se reproduce una sola vez por carga aunque la dirección
  continúe presionada.
- Al lanzar, fallar, recibir knockback o iniciar el DASH se detiene el bucle.

### Variaciones

Lanzamiento, impacto y recuperación alternarán dos muestras. Cada reproducción
aplicará una variación pequeña de tono, entre `0.96` y `1.04`, para reducir la
repetición sin cambiar la identidad del efecto.

## Ubicación y portabilidad

El generador será único para evitar divergencias:

```text
tools/audio/generate_slime_audio.py
```

Producirá copias idénticas dentro de cada proyecto Godot:

```text
prototypes/slime_charge_movement/audio/slime/
prueba_2/audio/slime/
```

Cada proyecto tendrá su propia versión del componente porque Godot no puede
cargar recursos situados fuera de la raíz de su proyecto.

## Integración por estado

| Transición | Sonido |
|---|---|
| `IDLE → CHARGING` | Iniciar `slime_charge_loop.wav` |
| La carga llega a `1.0` | `slime_charge_full.wav`, una vez |
| `CHARGING → LAUNCHING` | Detener bucle y reproducir un lanzamiento |
| Carga menor a `MIN_CHARGE_TIME` | Detener bucle y reproducir `slime_fizzle.wav` |
| Impulso termina sin colisión | Reproducir recuperación suave |
| Impulso o DASH choca | Reproducir impacto; no añadir recuperación suave encima |
| Inicio del DASH | Detener carga y reproducir `slime_dash.wav` |
| Knockback durante carga | Detener bucle; el golpe conserva su propia lectura |

El audio no alterará distancias, tiempos, invulnerabilidad, cooldown ni capas de
colisión.

## Verificación

La implementación se considerará técnicamente válida cuando:

1. El generador produzca siempre los once archivos con el formato y la frecuencia
   definidos.
2. Ningún archivo recorte muestras ni supere el límite de pico.
3. El bucle de carga no tenga un salto audible evidente en sus extremos.
4. Godot importe y cargue todos los WAV.
5. El prototipo arranque sin errores y sus pruebas headless sigan pasando.
6. `prueba_2` arranque sin errores ni `Debugger Break`.
7. Una prueba manual confirme que cada transición dispara un solo evento y que
   la carga responde de forma audible a la potencia.

La calidad estética final y el balance de volumen requieren escucha humana; no
pueden darse por aprobados únicamente con pruebas automatizadas.
