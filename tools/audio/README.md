# Generador de audio del slime

Ejecuta `python tools/audio/generate_slime_audio.py` desde la raíz del repositorio.

El generador usa únicamente la biblioteca estándar de Python. Cada forma de onda se
sintetiza matemáticamente; no incorpora muestras de terceros. Los archivos generados
se copian a ambos proyectos Godot porque `res://` no puede atravesar una raíz de
proyecto. Aun así, hace falta una escucha humana para aprobar su resultado estético.
