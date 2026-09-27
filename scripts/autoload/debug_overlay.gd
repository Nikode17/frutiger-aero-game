extends CanvasLayer
## Autoload DebugOverlay: contador de FPS discreto en la esquina superior derecha.
## Se muestra u oculta con la acción "toggle_fps" (F3).

@export var update_interval: float = 0.25
@export var start_visible: bool = false

var _panel: PanelContainer
var _label: Label
var _elapsed: float = 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.15, 0.45)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -140.0
	_panel.offset_right = -10.0
	_panel.offset_top = 10.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = start_visible
	add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fps"):
		_panel.visible = not _panel.visible
		_refresh()


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_elapsed += delta
	if _elapsed >= update_interval:
		_elapsed = 0.0
		_refresh()


func _refresh() -> void:
	var fps := Engine.get_frames_per_second()
	_label.text = "%d FPS  %.1f ms" % [fps, 1000.0 / maxf(fps, 1.0)]
