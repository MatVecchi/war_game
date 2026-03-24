extends Camera2D

class_name Camera

var dragging: bool = false
var dragged: bool = false
var input_enabled: bool = true
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_start_camera_pos: Vector2 = Vector2.ZERO
var border_shown: bool = true
var army_shown: bool = true

const MIN_ZOOM: float = 1.0
const MAX_ZOOM: float = 8.0
const ZOOM_SPEED: float = 0.1
const SHOW_BORDERS_ZOOM: float = 1.5
const SHOW_ARMY_COUNT_ZOOM: float = 2.0

func _handleZoom(s: float):	
	if s != 1.0 and s != -1.0: return
	
	var mouse_world_before = get_global_mouse_position()
	zoom = (zoom * (1.0 + (ZOOM_SPEED * s))).clamp(Vector2(MIN_ZOOM, MIN_ZOOM), Vector2(MAX_ZOOM, MAX_ZOOM))
	var mouse_world_after = get_global_mouse_position()
	global_position += mouse_world_before - mouse_world_after

	if zoom.x > SHOW_BORDERS_ZOOM and not border_shown:
		var provinces: Array[Node] = get_tree().get_nodes_in_group("provinces")
		for province in provinces:
			if province is not Province: continue
			province = province as Province
			province.province_border.show()
			province.control.show()
		border_shown = true
	elif zoom.x < SHOW_BORDERS_ZOOM and border_shown:
		var provinces: Array[Node] = get_tree().get_nodes_in_group("provinces")
		for province in provinces:
			if province is not Province: continue
			province = province as Province
			province.province_border.hide()
			province.control.hide()
		border_shown = false
		
	if zoom.x > SHOW_ARMY_COUNT_ZOOM and not army_shown:
		var armies: Array[Node] = get_tree().get_nodes_in_group("armies")
		for army in armies:
			if army is not Army: continue
			(army as Army).control.show()
			army_shown = true
	elif zoom.x < SHOW_ARMY_COUNT_ZOOM and army_shown:
		var armies: Array[Node] = get_tree().get_nodes_in_group("armies")
		for army in armies:
			if army is not Army: continue
			(army as Army).control.hide()
			army_shown = false
	
func _handlePan(s: bool):
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

func _input(_event: InputEvent) -> void:
	if input_enabled:
		if Input.is_action_just_pressed("camera_pan"):
			_handlePan(true)
			dragged = false
		_handleZoom(Input.get_axis("camera_zoom_out","camera_zoom_in"))
	if Input.is_action_just_released("camera_pan"):
		_handlePan(false)

func _ready() -> void:
	pass
