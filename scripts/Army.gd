extends Node2D

class_name Army


var travelling: bool = false
var path
var nodes_travelled: int
var direction: int
var timer: Timer
var day_timer: Timer
var death_count: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var day_battle: bool = false
var province_location: Province
const SPEED: float = 1.0
const ATTACK_TIME: float = 60.0
const LIFE_PER_UNIT: float = 20.0
const ATTACK_PER_UNIT: float = 4.0
const DEFENSE_PER_UNIT: float = 5.0 

@export var soldier_number: int
@export var life_points: float
@export var army_id: int
@export var player: Agent

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Control.scale = Vector2(1, 1)/get_viewport().get_camera_2d().zoom	
	$Area2D.area_entered.connect(_on_area_entered)
	timer = get_node("/root/Game/GlobalTimer")
	timer.timeout.connect(_on_global_timer_timeout)
	day_timer = get_node("/root/Game/GlobalDayTimer")
	day_timer.timeout.connect(_on_global_day_timer_timeout)
	
	var provinces = get_tree().get_nodes_in_group("provinces")
	for el in provinces:
		if el is not Province: continue
		el.area_entered.connect(_on_province_entered)
	
func _draw() -> void:
	$Control/Label.text = str(soldier_number)
	$Control/ProgressBar.value = life_points*100/((soldier_number+death_count)*LIFE_PER_UNIT)
	
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
	if not travelling: return
	travelling = false
	if not other.travelling:
		begin_attack(other)
	else:
		begin_attack(other)
		other.begin_attack(self)
		
func _on_global_timer_timeout():
	if travelling:
		if (self.progress_ratio != 1.0 and direction == 1) or (self.progress_ratio != 0.0 and direction == -1):
			self.progress += SPEED * direction
		else:
			nodes_travelled += 1
			if nodes_travelled == len(path):
				travelling = false
				return
			var new_path = player.graph_to_path[path[nodes_travelled]][0]
			var point = player.graph_to_path[path[nodes_travelled]][1]
			var dir = new_path.get_point_direction(point)
			if get_parent() != new_path:
				reparent(new_path)
			direction = dir
			
func _on_global_day_timer_timeout():
	if day_battle: 
		day_battle = false
		return
	
	life_points += 10
func _process(_delta):
	pass
	
func _on_area_entered(area):
	var other = area.get_parent()
	if other is Army:
		if player == other.player:
			_on_friendly_collision(other)
		else:
			_on_enemy_collision(other)
			
func _on_province_entered(el: Province):
	print("new province ", el)
	province_location = el
			
func _on_battle_timer_timeout(other: Army, battle_timer: Timer):
	var casual_attacker_multiplier: float = rng.randf_range(0.5, 1.5)
	var casual_defender_multiplier: float = rng.randf_range(0.5, 1.5)
	var attacker_strength: float = (soldier_number*ATTACK_PER_UNIT)*life_points/(soldier_number*LIFE_PER_UNIT)
	var defener_strength: float = (other.soldier_number*other.DEFENSE_PER_UNIT)*other.life_points/(other.soldier_number*other.LIFE_PER_UNIT)
	var final_attack: float = attacker_strength * casual_attacker_multiplier
	var final_defense: float = defener_strength * casual_defender_multiplier
	
	print("DEFENSE: ", final_defense, " ATTACK: ", final_attack)
	
	
	life_points -= final_defense
	other.life_points -= final_attack
	
	soldier_number -= int(final_defense / LIFE_PER_UNIT)
	other.soldier_number -= int(final_attack / other.LIFE_PER_UNIT)
	
	death_count += int(final_defense / LIFE_PER_UNIT)
	other.death_count += int(final_attack / other.LIFE_PER_UNIT)

	var battle_finished: bool = false
	if other.soldier_number <= 0 or other.life_points <= 0:
		other.queue_free()
		battle_finished = true
	else:
		other.queue_redraw()
	
	if (soldier_number <= 0 or life_points <= 0) and not battle_finished:
		queue_free()
		battle_finished = true
	else:
		queue_redraw()
	
	if battle_finished:
		battle_timer.stop()
		travelling = true
	else:
		battle_timer.start()
		
func _get_morale_percentage():
	return life_points/((soldier_number+death_count)*LIFE_PER_UNIT)*100

func begin_attack(other: Army):
	var battle_timer := Timer.new()
	battle_timer.wait_time = ATTACK_TIME
	battle_timer.one_shot = true
	battle_timer.timeout.connect(_on_battle_timer_timeout.bind(other, battle_timer))
	add_child(battle_timer)
	_on_battle_timer_timeout(other, battle_timer)
	battle_timer.start()
	day_battle = true
	other.day_battle = true

	
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
	var new_path = player.graph_to_path[points[0]][0]
	var point = player.graph_to_path[points[0]][1]
	var dir = new_path.get_point_direction(point)
	if get_parent() != path:
		reparent(new_path)
	print("pg ", self.progress_ratio)
	self.progress_ratio = 1.0
	direction = dir
	travelling = true
	path = points
	nodes_travelled = 0
