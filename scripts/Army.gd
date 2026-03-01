extends Node2D

class_name Army

var path_follow: PathFollow2D

@export var soldier_number: int
@export var army_id: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	path_follow = PathFollow2D.new()
	add_child(path_follow)
	
	$Control.scale = Vector2(1, 1)/get_viewport().get_camera_2d().zoom
	
func _draw() -> void:
	$Control/Label.text = str(soldier_number)
	
func _input(_event):
	if Input.is_action_just_pressed("camera_zoom_in") or Input.is_action_just_pressed("camera_zoom_out"):
		$Control.scale = Vector2(1,1)/get_viewport().get_camera_2d().zoom

func _process(delta):
	if $NavigationAgent2D.is_navigation_finished():
		return
	print($NavigationAgent2D.is_target_reachable())	
	var direction = $NavigationAgent2D.get_next_path_position() - global_position
	var velocity = direction.normalized() * 100.0   # velocità in pixel/sec

	global_position += velocity * delta

	
func order(city: Province):
	var game: GameController = get_tree().current_scene
	var current_node: Path2D
	var goal: Path2D
	for el in game.get_children():
		if el is Path2D and el.position == position:
			current_node = el
		elif el is Path2D and el.position == city.position:
			goal = el
	var path = game.state.find_path(current_node, goal)
	path_follow.set_path(path)
	#agent.target_position = city.position
