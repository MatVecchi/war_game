extends Node2D

class_name Army

var travelling: Province
var direction: int
const SPEED: int = 10

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
		elif travelling.get_city_position() != position:
			var next_path = get_parent().get_next_path(self)
			reparent(next_path[0])
			if get_parent().curve.get_point_position(next_path[1]) == get_parent().curve.get_point_position(0):
				self.progress_ratio = 0.0
				direction = 1
			else:
				self.progress_ratio = 1.0
				direction = -1
	
func order(city: Province):
	var start = player.routes.get_closest_point(position)
	var target = player.routes.get_closest_point(city.get_city_position())
	var points = player.routes.get_id_path(start, target, false)
	var path = player.graph_to_path[points[0]][0]
	var point = player.graph_to_path[points[0]][1]
	var dir = path.get_point_direction(point)
	if get_parent() != path:
		reparent(path)
