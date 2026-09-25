extends Node
## Autoload MusicManager: música ambiental en loop con crossfade entre pistas.
## Uso: MusicManager.play_track("res://assets/audio/music/pista.ogg")
## Si la ruta no existe, avisa por consola y no hace nada (sin errores).

@export var default_volume_db: float = -6.0
@export var crossfade_duration: float = 2.0
@export var bus_name: String = "Master"

# Dos reproductores para poder cruzar una pista con la siguiente
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _tween: Tween
var _current_path: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_a = _make_player("PlayerA")
	_player_b = _make_player("PlayerB")
	_active = _player_a


func _make_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus_name
	player.volume_db = -80.0
	add_child(player)
	return player


## Reproduce una pista en loop. Si ya hay otra sonando, hace crossfade.
## Devuelve true si la pista se cargó correctamente.
func play_track(path: String, fade: float = -1.0) -> bool:
	if path == _current_path and _active.playing:
		return true

	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("MusicManager: no se encontró la pista '%s'. Coloca el archivo en assets/audio/music/." % path)
		return false

	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("MusicManager: no se pudo cargar '%s' como AudioStream." % path)
		return false

	_enable_loop(stream)

	var duration := crossfade_duration if fade < 0.0 else fade
	var incoming := _player_b if _active == _player_a else _player_a
	var outgoing := _active

	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(incoming, "volume_db", default_volume_db, duration)
	if outgoing.playing:
		_tween.tween_property(outgoing, "volume_db", -80.0, duration)
		_tween.chain().tween_callback(outgoing.stop)

	_active = incoming
	_current_path = path
	return true


## Detiene la música con un fundido de salida.
func stop(fade: float = -1.0) -> void:
	var duration := crossfade_duration if fade < 0.0 else fade
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_active, "volume_db", -80.0, duration)
	_tween.tween_callback(_active.stop)
	_current_path = ""


## Ruta de la pista que suena ahora ("" si ninguna).
func get_current_track() -> String:
	return _current_path


# Activa el loop según el tipo de stream (ogg, mp3 o wav).
func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
