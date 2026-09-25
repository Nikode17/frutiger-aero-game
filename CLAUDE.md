# Frutiger Aero Game

Juego de exploración en primera persona (walking sim) con estética Frutiger Aero: cielos azules, agua cristalina, burbujas, materiales glossy y de cristal, vegetación verde brillante, luz suave y optimista. El jugador pasea por distintas áreas con música ambiental de fondo y puede moverse entre ellas. El alcance crecerá sobre la marcha.

## Roles
- **Tommy (usuario)** es el director creativo: decide áreas, mood, referencias, música y prioridades.
- **Claude** es quien implementa y aconseja. Propone, pero no toma decisiones creativas por su cuenta.

## Stack
- Godot 4.x, versión estándar (GDScript, no C#/.NET).
- Blender (+ blender-mcp más adelante) para assets; se exportan a `.glb`.
- Assets externos solo con licencia CC0 o CC-BY (Poly Haven, ambientCG, Kenney, OpenGameArt, Freesound).

## Estructura de carpetas
```
scenes/
  main.tscn            # escena de arranque
  player/              # controlador en primera persona
  areas/<nombre>/      # una carpeta por área (escena + scripts propios)
scripts/
  autoload/            # singletons (música, transiciones, estado global)
assets/
  audio/music/
  audio/sfx/
  models/
  textures/
  hdri/
  shaders/
CREDITS.md             # autor, fuente y licencia de cada asset externo
```

## Convenciones de código
- GDScript con tipado estático (`var speed: float = 5.0`, `func _ready() -> void:`).
- Nombres de archivos y carpetas en `snake_case`; clases en `PascalCase`.
- Parámetros ajustables expuestos con `@export` para poder tocarlos desde el inspector.
- Comentarios breves en español.
- Nada de rutas absolutas: siempre `res://`.
- Controles definidos en el Input Map de `project.godot`, nunca teclas hardcodeadas.

## Forma de trabajar
- Trabajo por fases. Al terminar cada fase: resumen de lo hecho, cómo probarlo y **esperar confirmación de Tommy** antes de seguir.
- Cambios pequeños y verificables. Si algo implica rehacer estructura o una decisión creativa, preguntar antes.
- Tras cada cambio, verificar que el proyecto carga sin errores:
  ```
  godot --headless --path . --import
  godot --headless --path . --quit-after 120
  ```
  Revisar la salida en busca de errores de script o recursos faltantes.
- Commits pequeños con mensajes claros en español (`feat: controlador en primera persona`).
- No editar ni subir la carpeta `.godot/` (caché).
- Si falta un asset (música, textura), dejar un placeholder y avisar de qué archivo hay que poner y dónde.
- Cada asset externo que se añada se registra en `CREDITS.md`.

## Rendimiento
Objetivo: 60 FPS estables en un portátil gaming. Preferir iluminación sencilla, texturas de 2K como máximo y postprocesado con moderación (bloom sí, pero ajustado).
