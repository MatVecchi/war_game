extends Area2D

class_name Province

var timer: Timer
var hour_timer: Timer
var day_timer: Timer
var army_timer: Timer = Timer.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var conquered: bool = false
var selected: bool = false
var province_morale: int = DEFAULT_START_PROVINCE_MORALE
var target_morale: int = DEFAULT_START_TARGET_MORALE
var current_army_timer: float = DEFAULT_ARMY_GENERATION_WAIT
var neighbors: Array[Area2D] = []
var borders: Array[Line2D] = []
var buildings: Dictionary[Enums.Buildings, Building] = {}
const DEFAULT_ARMY_GENERATION_WAIT: float = 720.0
const DEFAULT_START_PROVINCE_MORALE: int = 70
const DEFAULT_START_TARGET_MORALE: int = 100
const CAPITAL_COLOR_BACKGROUND: Color = Color(0.0, 0.0, 0.0, 0.5)
const MATERIAL_TEXTURES: Dictionary[Enums.ResourcesSprites, Resource] = {
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
@export var startup_buildings: Array[Enums.Buildings]

@onready var fill := $Polygon2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var province_border: Line2D = $ProvinceBorder

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
	
	$Control/VBoxContainer/HBoxContainer/TextureRect.texture = MATERIAL_TEXTURES[_get_sprite_key()]
	
	for el in collision_polygon.polygon:
		province_border.add_point(el)

	var game: GameController = get_tree().current_scene
	game.match_over.connect(_on_match_over)
	
	neighbors = await _get_neighbors(1.1)
	set_borders()
	
	if Enums.Buildings.CAPITAL in startup_buildings:
		buildings.get_or_add(Enums.Buildings.CAPITAL, Capital.new())
	if Enums.Buildings.RECRUIT_CENTER in startup_buildings:
		buildings.get_or_add(Enums.Buildings.RECRUIT_CENTER, RecruitCenter.new())
		
	for child in get_children():
		if child is not Path2D: continue
		child = child as Path2D
		var curve: Curve2D = child.curve
		var path_line: Line2D = Line2D.new()
		path_line.width = 1.0
		path_line.default_color = Color(0.0, 0.0, 0.0, 0.2)
		for i in range(curve.point_count):
			var pos: Vector2 = curve.get_point_position(i)
			path_line.add_point(pos)
		add_child(path_line)
		
	queue_redraw()
	
	print(neighbors)
	
func set_borders() -> void:
	borders.clear()
	for i in get_children():
		if i is not Line2D or i.name == "ProvinceBorder": continue
		remove_child(i)

	for j in neighbors:
		if j.get_parent() == get_parent(): continue
		var poly1 := PackedVector2Array()
		for p in j.get_node("CollisionPolygon2D").polygon:
			poly1.append(to_local(j.get_node("CollisionPolygon2D").to_global(p)))

		var poly2 := PackedVector2Array()
		for p in collision_polygon.polygon:
			poly2.append(p)

		var inter = get_shared_edges(poly1, poly2)
		
		var poly_global := PackedVector2Array()
		for p in collision_polygon.polygon:
			poly_global.append(collision_polygon.to_global(p))

		var l = Line2D.new()
		l.width = 5.0
		l.default_color = Color(1.0, 1.0, 1.0, 0.784)
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		for polygon_ in inter:
			for p in polygon_:
				l.add_point(p)
		add_child(l)
		borders.append(l)
		
func has_building(building: Enums.Buildings):
	return building in buildings

func _get_neighbors(scale_factor: float) -> Array[Area2D]:
	var polygon: PackedVector2Array = collision_polygon.polygon
	
	var center = Vector2.ZERO
	for point in polygon:
		center += point
	center /= polygon.size()
	
	var scaled_polygon = PackedVector2Array()
	for point in polygon:
		var direction = point - center
		scaled_polygon.append(center + direction * scale_factor)
	
	collision_polygon.polygon = scaled_polygon
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var res: Array[Area2D] = []
	for collision in get_overlapping_areas():
		res.append(collision)

	collision_polygon.polygon = polygon
	collision_polygon.queue_redraw()
	await get_tree().process_frame
	
	return res
	
func get_shared_edges(poly1: PackedVector2Array, poly2: PackedVector2Array, epsilon := 0.1) -> Array:
	var shared := []

	for i in range(poly1.size()):
		var a1 = poly1[i]
		var a2 = poly1[(i + 1) % poly1.size()]

		for j in range(poly2.size()):
			var b1 = poly2[j]
			var b2 = poly2[(j + 1) % poly2.size()]

			# Controllo se i segmenti coincidono (inversi o diretti)
			if a1.distance_to(b1) < epsilon and a2.distance_to(b2) < epsilon:
				shared.append([a1, a2])
			elif a1.distance_to(b2) < epsilon and a2.distance_to(b1) < epsilon:
				shared.append([a1, a2])

	return shared

func _draw():
	$Control/VBoxContainer/HBoxContainer/ResourceCount.text = str(_get_daily_resource_count())
	$Control/VBoxContainer/PanelContainer/ProvinceName.text = province_name + ": " + str(province_morale) + "%"
	var style := StyleBoxFlat.new()
	if Enums.Buildings.CAPITAL in buildings:
		style.bg_color = CAPITAL_COLOR_BACKGROUND
	else:
		style.bg_color = Color(Color.TRANSPARENT)
	$Control/VBoxContainer/PanelContainer.add_theme_stylebox_override("panel", style)
	
	
	
func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("camera_zoom_in") or Input.is_action_just_pressed("camera_zoom_out"):
		$Control.scale = Vector2(1,1)/get_viewport().get_camera_2d().zoom
		
func _on_global_timer_timeout() -> void:
	target_morale = 100 - _get_total_morale_penalties() + _get_total_morale_bonuses()

	if not has_building(Enums.Buildings.RECRUIT_CENTER) and not army_timer.paused:
		army_timer.stop()
	elif has_building(Enums.Buildings.RECRUIT_CENTER) and army_timer.paused:
		army_timer.start()
	
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
	
func _on_match_over() -> void:
	army_timer.stop()
	
func _update_army_timer(val: float):
	if army_timer == null: return
	
	var time_left = army_timer.time_left
	var percentage = snapped((army_timer.wait_time - time_left)/army_timer.wait_time*100, 0.001)
	if percentage == 100:
		army_timer.wait_time = val
	else:
		army_timer.wait_time = val * ((100 - percentage)/100)
		current_army_timer = val
	
func _on_army_timer_timeout() -> void:
	_update_army_timer(current_army_timer)
	for el: Army in get_parent().armies:
		if el.global_position != to_global(get_city_position()): continue
		el.soldier_number += 1
		el.life_points += el.LIFE_PER_UNIT * (float(province_morale)/100)
		el.queue_redraw()
		return
	
	var game: GameController = get_tree().current_scene
	game.add_army_to_province(self, null, 1)
	
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
	return $Node2D.position
	
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
