extends Node2D

class_name Army

var travelling
var nodes_travelled: int
var direction: int
const SPEED: float = 0.1

@export var soldier_number: int
@export var army_id: int
@export var player: Agent

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Control.scale = Vector2(1, 1)/get_viewport().get_camera_2d().zoom
	
func _draw() -> void:
	$Control/Label.text = str(soldier_number)
	
func _input(_event):
	if Input.is_action_just_pressed("camera_zoom_in") or Input.is_action_just_pressed("camera_zoom_out"):
		$Control.scale = Vector2(1,1)/get_viewport().get_camera_2d().zoom

func _process(delta):
	if travelling != null:
		if (self.progress_ratio != 1.0 and direction == 1) or (self.progress_ratio != 0.0 and direction == -1):
			self.progress += SPEED * direction
		else:
			nodes_travelled += 1
			if nodes_travelled == len(travelling):
				travelling = null
				return
			var path = player.graph_to_path[travelling[nodes_travelled]][0]
			var point = player.graph_to_path[travelling[nodes_travelled]][1]
			var dir = path.get_point_direction(point)
			if get_parent() != path:
				reparent(path)
			direction = dir
	
func order(city: Province):
	var start = player.routes.get_closest_point(position)
	var target = player.routes.get_closest_point(city.get_city_position())
	var points = player.routes.get_id_path(start, target, false)
	var path = player.graph_to_path[points[0]][0]
	var point = player.graph_to_path[points[0]][1]
	var dir = path.get_point_direction(point)
	if get_parent() != path:
		reparent(path)
	direction = dir
	travelling = points
	nodes_travelled = 0
