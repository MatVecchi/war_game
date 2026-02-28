extends Camera2D

var dragging := false
var drag_start_mouse_pos := Vector2.ZERO
var drag_start_camera_pos := Vector2.ZERO

const MIN_ZOOM := 0.3
const MAX_ZOOM := 3.0
const ZOOM_SPEED := 0.1

func handleZoom(s: float):
	zoom = (zoom * (1.0 + ZOOM_SPEED * s)).clamp(Vector2(MIN_ZOOM, MIN_ZOOM), Vector2(MAX_ZOOM, MAX_ZOOM))
	
func handlePan(s: bool):
	if not dragging and s:
		drag_start_mouse_pos = get_viewport().get_mouse_position()
		drag_start_camera_pos = position
		dragging = true
	
	if dragging and not s:
		dragging = false

func _process(_delta):
	if dragging:
		var moveVector = get_viewport().get_mouse_position() - drag_start_mouse_pos
		position = drag_start_camera_pos - moveVector * 1/zoom.x

func _input(_event):
	if Input.is_action_just_pressed("camera_pan"):
		handlePan(true)
	if Input.is_action_just_released("camera_pan"):
		handlePan(false)
	handleZoom(Input.get_axis("camera_zoom_out","camera_zoom_in"))

func _ready() -> void:
	pass
