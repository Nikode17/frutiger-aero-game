extends Node3D
## Escena de arranque: coloca al jugador en el punto de aparición del área
## y arranca la música ambiental si existe la pista.

## Pista de música ambiental. Si el archivo no existe, no pasa nada.
@export_file("*.ogg", "*.mp3", "*.wav") var music_path: String = "res://assets/audio/music/ambient_01.ogg"
## Marker3D del área donde aparece el jugador.
@export var spawn_point_path: NodePath = ^"Area01/SpawnPoint"

@onready var player: Player = $Player


func _ready() -> void:
	var spawn := get_node_or_null(spawn_point_path) as Node3D
	if spawn:
		player.global_transform = spawn.global_transform
	else:
		push_warning("Main: no se encontró el punto de aparición '%s'." % spawn_point_path)
	MusicManager.play_track(music_path)
