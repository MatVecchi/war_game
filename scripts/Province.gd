extends Area2D

class_name Province

var timer: Timer
var hour_timer: Timer
var day_timer: Timer
var army_timer: Timer = Timer.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var conquered: bool = false
const DEFAULT_ARMY_GENERATION_WAIT: float = 720.0
const DEFAULT_START_PROVINCE_MORALE: int = 70
const DEFAULT_START_TARGET_MORALE: int = 100
const MATERIAL_TEXTURES := {
	Enums.ResourcesSprites.WOOD: preload("res://assets/sprites/resources/wood.png"),
	Enums.ResourcesSprites.WOOD_DOUBLE: preload("res://assets/sprites/resources/wood_double.png"),
	Enums.ResourcesSprites.IRON: preload("res://assets/sprites/resources/iron.png"),
	Enums.ResourcesSprites.IRON_DOUBLE: preload("res://assets/sprites/resources/iron_double.png"),
	Enums.ResourcesSprites.OIL: preload("res://assets/sprites/resources/oil.png"),
	Enums.ResourcesSprites.OIL_DOUBLE: preload("res://assets/sprites/resources/oil_double.png"),
	Enums.ResourcesSprites.GAS: preload("res://assets/sprites/resources/gas.png"),
	Enums.ResourcesSprites.GAS_DOUBLE: preload("res://assets/sprites/resources/gas_double.png"),
	Enums.ResourcesSprites.COAL: preload("res://assets/sprites/resources/coal.png"),
	Enums.ResourcesSprites.COAL_DOUBLE: preload("res://assets/sprites/resources/coal_double.png"),
	Enums.ResourcesSprites.GRAIN: preload("res://assets/sprites/resources/grain.png"),
	Enums.ResourcesSprites.GRAIN_DOUBLE: preload("res://assets/sprites/resources/grain_double.png"),
	Enums.ResourcesSprites.FISH: preload("res://assets/sprites/resources/fish.png"),
	Enums.ResourcesSprites.FISH_DOUBLE: preload("res://assets/sprites/resources/fish_double.png"),
}
@export var province_id: int
@export var province_name: String
@export var province_material: Enums.Resources
@export var double_material: bool
@export var is_capital: bool

@onready var fill := $Polygon2D
var selected: bool = false
var province_morale: int = DEFAULT_START_PROVINCE_MORALE
var target_morale: int = DEFAULT_START_TARGET_MORALE
var current_army_timer: float = DEFAULT_ARMY_GENERATION_WAIT

signal province_clicked(id)

func _ready():
	add_to_group("provinces")
	timer = get_node("/root/Game/GlobalTimer")
	timer.timeout.connect(_on_global_timer_timeout)
	hour_timer = get_node("/root/Game/GlobalHourTimer")
	hour_timer.timeout.connect(_on_global_hour_timer_timeout)
	day_timer = get_node("/root/Game/GlobalDayTimer")
	day_timer.timeout.connect(_on_global_day_timer_timeout)
	current_army_timer = DEFAULT_ARMY_GENERATION_WAIT + DEFAULT_ARMY_GENERATION_WAIT*(float(province_morale)/100)
	_update_army_timer(current_army_timer)
	army_timer.timeout.connect(_on_army_timer_timeout)
	add_child(army_timer)
	army_timer.start()
	fill.color = get_parent().color
	$Control/VBoxContainer/HBoxContainer/TextureRect.texture = MATERIAL_TEXTURES[_get_sprite_key()]
	await get_tree().process_frame
	print("neighbors: ", _update_neighbors())
	
func _update_neighbors():
	var neighbors := []
	var space_state = get_world_2d().direct_space_state

	# 1. Ricostruisci la shape come ConcavePolygonShape2D
	var poly := $CollisionPolygon2D.polygon
	var segments := _polygon_to_segments(poly)

	var my_shape := ConcavePolygonShape2D.new()
	my_shape.set_segments(segments)

	# 2. Trasformazione globale
	var my_transform := $CollisionPolygon2D.global_transform

	# 3. Parametri della query
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = my_shape
	params.transform = my_transform
	params.collide_with_areas = true
	params.collide_with_bodies = false

	# 4. Query
	var results := space_state.intersect_shape(params)

	for r in results:
		var area := r.collider
		if area is Provincia and area != self:
			neighbors.append(area)





func _draw():
	$Control/VBoxContainer/HBoxContainer/ResourceCount.text = str(_get_daily_resource_count())
	$Control/VBoxContainer/ProvinceName.text = province_name + ": " + str(province_morale) + "%"
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: return
	if Input.is_action_just_released("select_province") and not get_viewport().get_camera_2d().dragged:
		emit_signal("province_clicked", province_id)
		get_viewport().set_input_as_handled()
		
	if Input.is_action_just_pressed("camera_zoom_in") or Input.is_action_just_pressed("camera_zoom_out"):
		$Control.scale = Vector2(1,1)/get_viewport().get_camera_2d().zoom
		
func _on_global_timer_timeout() -> void:
	target_morale = 100 - _get_total_morale_penalties() + _get_total_morale_bonuses()
	
func _on_global_hour_timer_timeout() -> void:
	var agent = get_parent()
	agent.resources[province_material] += float(_get_daily_resource_count()) / 24
	agent.resources[Enums.Resources.GOLD] += float(_get_daily_gold_count()) / 24
	agent.queue_redraw()
	
func _on_global_day_timer_timeout() -> void:
	if conquered:
		conquered = false
		return
	var delta: float = target_morale - province_morale
	if delta == 0: return
	var adding: int = ceil(delta/100 * 15)
	if adding < 3:
		province_morale += adding
	else:
		var adding2: int = rng.randi_range(-3, 3)
		province_morale += adding + adding2
	current_army_timer = DEFAULT_ARMY_GENERATION_WAIT + DEFAULT_ARMY_GENERATION_WAIT*(float(province_morale)/100)
	_update_army_timer(current_army_timer)
	queue_redraw()
	
	
func _update_army_timer(val: float):
	if army_timer == null: return
	
	var time_left = army_timer.time_left
	var percentage = snapped((army_timer.wait_time - time_left)/army_timer.wait_time*100, 0.001)
	if percentage == 100:
		army_timer.wait_time = val
	else:
		army_timer.wait_time = val * ((100 - percentage)/100)
		current_army_timer = val
	print("update timer: ", val, " ", army_timer.wait_time, " ", (100 - percentage), " ", percentage, " ", time_left)
	
func _on_army_timer_timeout() -> void:
	_update_army_timer(current_army_timer)
	for el: Army in get_parent().armies:
		if el.position != get_city_position(): continue
		el.soldier_number += 1
		el.life_points += el.LIFE_PER_UNIT * (float(province_morale)/100)
		el.queue_redraw()
		return
	
	var paths = get_tree().get_nodes_in_group("paths")
	var game: GameController = get_tree().current_scene
	var army_scene := preload("res://scenes/army.tscn")
	var army: Army = army_scene.instantiate()
	army.army_id = 1
	army.soldier_number = 1
	army.life_points = army.LIFE_PER_UNIT * (float(province_morale)/100)
	army.player = get_parent()
	get_parent().armies.append(army)
	for el in paths:
		if el is Path2D:
			var count = el.curve.point_count
			for j in range(count):
				if el.curve.get_point_position(j) == get_city_position():
					el.add_child(army)
	game.state.add_army_to_province(self, army)
	
func _get_daily_resource_count() -> int:
	var resource_to_add: int = (province_morale * 24) + 750
	
	if double_material:
		resource_to_add *= 2
	return resource_to_add
	
func _get_daily_gold_count() -> int:
	if double_material:
		return province_morale * 29
	else:
		return province_morale * 57
	
func _get_total_morale_penalties() -> int:
	return 0
	
func _get_total_morale_bonuses() -> int:
	return 0
	
func _get_sprite_key():
	match province_material:
		Enums.Resources.WOOD:
			return Enums.ResourcesSprites.WOOD_DOUBLE if double_material else Enums.ResourcesSprites.WOOD

		Enums.Resources.IRON:
			return Enums.ResourcesSprites.IRON_DOUBLE if double_material else Enums.ResourcesSprites.IRON
			
		Enums.Resources.OIL:
			return Enums.ResourcesSprites.OIL_DOUBLE if double_material else Enums.ResourcesSprites.OIL
			
		Enums.Resources.GAS:
			return Enums.ResourcesSprites.GAS_DOUBLE if double_material else Enums.ResourcesSprites.GAS
		
		Enums.Resources.COAL:
			return Enums.ResourcesSprites.COAL_DOUBLE if double_material else Enums.ResourcesSprites.COAL
		
		Enums.Resources.GRAIN:
			return Enums.ResourcesSprites.GRAIN_DOUBLE if double_material else Enums.ResourcesSprites.GRAIN
		
		Enums.Resources.FISH:
			return Enums.ResourcesSprites.FISH_DOUBLE if double_material else Enums.ResourcesSprites.FISH

		
func get_city_position() -> Vector2:
	return $Node2D.global_position
	
func get_province_paths():
	var global_paths = get_tree().get_nodes_in_group("paths")
	var paths = []
	for el in global_paths:
		if el is not Path: continue
		
		var start = el.curve.get_point_position(0)
		var end = el.curve.get_point_position(el.curve.pont_count - 1)
		
		if start == get_city_position():
			paths.append([el, start])
		elif end == get_city_position():
			paths.append([el, end])
	return paths
	
func _notification(what: int) -> void:
	if get_tree() == null: return
	if what == NOTIFICATION_PARENTED:
		for path in get_province_paths():
				var graph_node_key = 0
				if path[1] > 0:
					graph_node_key = 1
				get_parent().routes.set_point_weight_scale(get_parent().graph_to_path[path[0]][graph_node_key], 1.0)
				
				var players = get_tree().get_nodes_in_group("players")
				for player in players:
					if player == get_parent(): continue
					player.routes.set_point_weight_scale(player.graph_to_path[path[0]][graph_node_key], 1.5)
					
func toggle_selection() -> bool:
	selected = not selected
	if selected:
		fill.color = blend(get_parent().color, Color(0.0, 0.0, 0.0, 0.114))
	else:
		fill.color = get_parent().color
	return selected
	
func blend_under(bottom: Color, top: Color) -> Color:
	var a = top.a
	return bottom * (1.0 - a) + top * a

func blend(bottom: Color, top: Color) -> Color:
	var out = blend_under(bottom, top)
	out.a = bottom.a + top.a * (1.0 - bottom.a)
	return out
