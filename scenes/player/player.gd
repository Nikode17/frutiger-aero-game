class_name Player
extends CharacterBody3D
## Controlador en primera persona: movimiento suave, mirada con ratón, salto y sprint.

@export_group("Movimiento")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var acceleration: float = 12.0   # Qué tan rápido alcanza la velocidad objetivo
@export var deceleration: float = 16.0   # Qué tan rápido frena al soltar las teclas
@export var air_control: float = 0.35    # Fracción de la aceleración disponible en el aire
@export var jump_velocity: float = 4.5

@export_group("Cámara")
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.15
@export var max_pitch_degrees: float = 89.0
@export var capture_mouse_on_start: bool = true

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	if capture_mouse_on_start:
		_capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	# Mirada con ratón solo mientras está capturado
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-deg_to_rad(motion.relative.x * mouse_sensitivity))
		head.rotate_x(-deg_to_rad(motion.relative.y * mouse_sensitivity))
		var limit := deg_to_rad(max_pitch_degrees)
		head.rotation.x = clampf(head.rotation.x, -limit, limit)
		return

	# Esc libera el ratón; clic lo vuelve a capturar
	if event.is_action_pressed("release_mouse"):
		_release_mouse()
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture_mouse()


func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Dirección deseada en el plano horizontal, relativa a la orientación del cuerpo
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity := direction * target_speed

	# Aceleración o frenado según haya input, reducidos en el aire
	var rate := acceleration if direction != Vector3.ZERO else deceleration
	if not is_on_floor():
		rate *= air_control

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.lerp(target_velocity, clampf(rate * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
