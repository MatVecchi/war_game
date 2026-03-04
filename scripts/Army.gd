extends Node2D

class_name Army


var travelling
var nodes_travelled: int
var direction: int
var timer: Timer
var death_count: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
const SPEED: float = 1.0
const ATTACK_TIME: float = 60_000.0
const LIFE_PER_UNIT: float = 10.0
const ATTACK_PER_UNIT: float = 8.0
const DEFENSE_PER_UNIT: float = 12.0 

@export var soldier_number: int
@export var life_points: float = 100.0
@export var army_id: int
@export var player: Agent

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Control.scale = Vector2(1, 1)/get_viewport().get_camera_2d().zoom	
	$Area2D.area_entered.connect(_on_area_entered)
	timer = get_node("/root/Game/GlobalTimer")
	timer.timeout.connect(_on_global_timer_timeout)
	
func _draw() -> void:
	$Control/Label.text = str(soldier_number)
	$Control/ProgressBar.value = life_points/100*(soldier_number*LIFE_PER_UNIT)
	
func _input(_event):
	if Input.is_action_just_pressed("camera_zoom_in") or Input.is_action_just_pressed("camera_zoom_out"):
		$Control.scale = Vector2(1,1)/get_viewport().get_camera_2d().zoom

func _on_friendly_collision(other: Army):
	if travelling == null or other.travelling != null: return
	if nodes_travelled < len(travelling) - 1: return
	
	var path_points = get_parent().curve
	if direction == 1 and path_points.get_point_position(path_points.point_count - 1) == other.position:
		other.merge_armies(self)

func _on_enemy_collision(other: Army):
	if travelling == null: return
	travelling = null
	if other.travelling == null:
		begin_attack(other)
	else:
		begin_attack(other)
		other.begin_attack(self)
		
func _on_global_timer_timeout():
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
			
func _process(_delta):
	pass
	
func _on_area_entered(area):
	var other = area.get_parent()
	if other is Army:
		if player == other.player:
			_on_friendly_collision(other)
		else:
			_on_enemy_collision(other)
			
func _on_battle_timer_timeout(other: Army, battle_timer: Timer):
	print("attacking...", other, battle_timer)

func begin_attack(other: Army):
	var battle_timer := Timer.new()
	battle_timer.wait_time = ATTACK_TIME
	battle_timer.one_shot = true
	battle_timer.timeout.connect(_on_battle_timer_timeout.bind(other, battle_timer))
	add_child(battle_timer)
	battle_timer.start()

	
func merge_armies(other: Army):
	soldier_number += other.soldier_number
	life_points += other.life_points
	other.queue_free()
	queue_redraw()
	
func order(city: Province):
	var start = player.routes.get_closest_point(position)
	var target = player.routes.get_closest_point(city.get_city_position())
	var points = player.routes.get_id_path(start, target, false)
	print(player.graph_to_path, "------", points, "--------", start, "----------", target, "-----------", player.routes)
	var path = player.graph_to_path[points[0]][0]
	var point = player.graph_to_path[points[0]][1]
	var dir = path.get_point_direction(point)
	if get_parent() != path:
		reparent(path)
	direction = dir
	travelling = points
	nodes_travelled = 0
