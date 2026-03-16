extends Camera2D

class_name Camera

var dragging := false
var dragged := false
var drag_start_mouse_pos := Vector2.ZERO
var drag_start_camera_pos := Vector2.ZERO

const MIN_ZOOM := 0.0
const MAX_ZOOM := 8.0
const ZOOM_SPEED := 0.1

func handleZoom(s: float):	
	if s != 1.0 and s != -1.0: return
	
	var mouse_world_before = get_global_mouse_position()
	zoom = (zoom * (1.0 + (ZOOM_SPEED * s))).clamp(Vector2(MIN_ZOOM, MIN_ZOOM), Vector2(MAX_ZOOM, MAX_ZOOM))
	var mouse_world_after = get_global_mouse_position()
	global_position += mouse_world_before - mouse_world_after

	
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
		if moveVector == Vector2.ZERO: return
		dragged = true
		position = drag_start_camera_pos - moveVector * 1/zoom.x

func _input(_event):
	if Input.is_action_just_pressed("camera_pan"):
		handlePan(true)
		dragged = false
	if Input.is_action_just_released("camera_pan"):
		handlePan(false)
	handleZoom(Input.get_axis("camera_zoom_out","camera_zoom_in"))

func _ready() -> void:
	pass
