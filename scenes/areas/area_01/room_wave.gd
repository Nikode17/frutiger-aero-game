@tool
class_name RoomWave
extends Resource
## Tramo de pared con "ola": a partir de cierta altura la pared se curva hacia dentro y
## sube así hasta el techo, cuyo borde queda más hacia dentro en ese tramo (como si el
## techo bajara en curva). Se define por su ángulo alrededor de la sala (0° = +X,
## 90° = +Z, 180° = -X, 270° = -Z), como las ventanas.

@export var enabled: bool = true
@export_range(0.0, 360.0, 0.5) var angle_deg: float = 90.0
## Semianchura angular del tramo (grados), incluida la transición
@export_range(2.0, 60.0, 0.5) var half_width_deg: float = 18.0
## Parte de la semianchura que se usa para entrar y salir suavemente (grados)
@export_range(0.5, 60.0, 0.5) var taper_deg: float = 9.0
## Altura a la que la pared ya ha terminado de curvarse hacia dentro (m)
@export var crest_height: float = 3.0
## Cuánto entra la pared (y el borde del techo) respecto a la pared normal (m)
@export var depth: float = 0.38
## Altura que ocupa la curva por debajo de la cresta (m): empieza en crest_height - lower_extent
@export var lower_extent: float = 1.1
## La cresta sube y baja esta cantidad a lo largo del tramo para que no sea recta (m)
@export var crest_variation: float = 0.12
## En el techo el desplazamiento se desvanece hacia el centro de la sala. Distancia
## relativa a la pared (1 = pared, 0 = centro): completo a partir de ceiling_fade_end y
## nulo por debajo de ceiling_fade_start. Mantener start por encima del tragaluz (~0,5).
@export_range(0.3, 1.0, 0.01) var ceiling_fade_start: float = 0.62
@export_range(0.3, 1.0, 0.01) var ceiling_fade_end: float = 0.92
