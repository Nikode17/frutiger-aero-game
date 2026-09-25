@tool
class_name RoomWindow
extends Resource
## Ventana ovalada en la pared de la habitación, definida por su ángulo alrededor
## de la sala (0° = +X, 90° = +Z, 180° = -X, 270° = -Z) y la altura de su centro.

@export var enabled: bool = true
@export_range(0.0, 360.0, 0.5) var angle_deg: float = 270.0
@export var center_height: float = 1.7
## Semiejes del óvalo: x a lo largo de la pared, y en vertical (metros)
@export var radius: Vector2 = Vector2(0.7, 1.0)
@export var frame_radius: float = 0.22
