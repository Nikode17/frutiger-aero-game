extends Node3D
## Escena de arranque: arranca la música ambiental si existe la pista.

## Pista de música ambiental. Si el archivo no existe, no pasa nada.
@export_file("*.ogg", "*.mp3", "*.wav") var music_path: String = "res://assets/audio/music/ambient_01.ogg"


func _ready() -> void:
	MusicManager.play_track(music_path)
