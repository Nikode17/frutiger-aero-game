@tool
class_name RoomWave
extends Resource
## Tramo de pared con "ola": a cierta altura la pared sale hacia dentro con un saliente
## redondeado y luego vuelve a su sitio antes de subir al techo. Se define por su ángulo
## alrededor de la sala (0° = +X, 90° = +Z, 180° = -X, 270° = -Z), como las ventanas.

@export var enabled: bool = true
@export_range(0.0, 360.0, 0.5) var angle_deg: float = 90.0
## Semianchura angular del tramo (grados), incluida la transición
@export_range(2.0, 60.0, 0.5) var half_width_deg: float = 18.0
## Parte de la semianchura que se usa para entrar y salir suavemente (grados)
@export_range(0.5, 60.0, 0.5) var taper_deg: float = 9.0
## Altura de la cresta del saliente (m)
@export var crest_height: float = 3.0
## Cuánto sale la pared hacia dentro en la cresta (m)
@export var depth: float = 0.42
## Extensión vertical de la ola por debajo y por encima de la cresta (m)
@export var lower_extent: float = 1.1
@export var upper_extent: float = 0.9
## La cresta sube y baja esta cantidad a lo largo del tramo para que no sea recta (m)
@export var crest_variation: float = 0.12
