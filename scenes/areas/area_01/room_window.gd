@tool
class_name RoomWindow
extends Resource
## Ventana ovalada en la pared de la habitación, definida por su ángulo alrededor
## de la sala (0° = +X, 90° = +Z, 180° = -X, 270° = -Z) y la altura de su centro.
## El marco es un bisel tipo ventana de acuario: aro de cromo estrecho y plano que monta
## sobre el borde del hueco (frame_material de RoomShell) y, por dentro, una banda plana
## de color (frame_accent_material).

@export var enabled: bool = true
@export_range(0.0, 360.0, 0.5) var angle_deg: float = 270.0
@export var center_height: float = 1.7
## Semiejes del óvalo: x a lo largo de la pared, y en vertical (metros)
@export var radius: Vector2 = Vector2(0.7, 1.0)
## Ancho del aro de cromo (m)
@export var frame_width: float = 0.085
## Cuánto sale el aro de la pared hacia la sala (m)
@export var frame_height: float = 0.028
## Parte del aro que queda sobre la pared, fuera del hueco (m); el resto tapa el hueco
@export var frame_overlap: float = 0.03
## Ancho de la banda plana interior; 0 = sin banda
@export var accent_width: float = 0.045
## Altura de la banda sobre la pared (m)
@export var accent_height: float = 0.007
