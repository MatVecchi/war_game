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
var current_army_timer: float = 0
var neighbors: Array[Area2D] = []
var borders: Array[Line2D] = []
var buildings: Dictionary[Enums.Buildings, Building] = {}
var daily_cost: Dictionary[Enums.Resources, int] = {}
var all_bonuses: Dictionary = {
}
var all_maluses: Dictionary = {
	Enums.ProvinceMoraleMaluses.CAPITAL_DISTANCE: CapitalDistanceModifier.new(),
	Enums.ProvinceMoraleMaluses.EXPANSION: ExpansionModifier.new(),
	Enums.ProvinceMoraleMaluses.ENEMY_NEIGHBORS: EnemyNeighborsModifier.new(),
	Enums.ProvinceMoraleMaluses.ENEMY_ARMIES: EnemyArmiesModifier.new(),
}
var morale_bonuses: Dictionary = {}
var morale_maluses: Dictionary = {}
var trend_texture_rect_capital: TextureRect

const ARROW_UP_TEXTURE = preload("res://assets/textures/arrow-up.png")
const ARROW_DOWN_TEXTURE = preload("res://assets/textures/arrow-down.png")
const DEFAULT_ARMY_GENERATION_WAIT: float = 720.0
const DEFAULT_START_PROVINCE_MORALE: int = 70
const DEFAULT_START_TARGET_MORALE: int = 100
const CAPITAL_COLOR_BACKGROUND: Color = Color(0.0, 0.0, 0.0, 0.5)
const RIOT_THRESHOLD: int = 33
const RIOT_BREAKPOINT: int = 30
const RIOT_BASE_DEFENSE: float = 5.0
const RIOT_PENALTY_MULTIPLIER: float = 6.0
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
const DEFAULT_DAILY_COST: Dictionary[Enums.Resources, int] = {
	Enums.Resources.WOOD: 400,
	Enums.Resources.IRON: 400,
	Enums.Resources.OIL: 267,
	Enums.Resources.GAS: 267,
	Enums.Resources.COAL: 267,
	Enums.Resources.GRAIN: 400,
	Enums.Resources.FISH: 400
}

@export var province_material: Enums.Resources
@export var double_material: bool
@export var startup_buildings: Array[Enums.Buildings]

@onready var fill: Polygon2D = $Polygon2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var province_border: Line2D = $ProvinceBorder

@onready var city_node: Node2D = $City if has_node("City") else $Node2D
@onready var control: Control = city_node.get_node("Control")
@onready var resource_texture: TextureRect = city_node.get_node("Control/ResourceTexture")
@onready var province_name_capital_container: PanelContainer = city_node.get_node("Control/SubViewportContainer/SubViewport/CapitalLabelContainer")
@onready var province_name_capital_label: Label = city_node.get_node("Control/SubViewportContainer/SubViewport/CapitalLabelContainer/MarginContainer/ProvinceName")
@onready var province_name_label: Label = city_node.get_node("Control/SubViewportContainer/SubViewport/ProvinceNameLabel")

func _ready():
	add_to_group("provinces")
	timer = get_node("/root/Game/GlobalTimer")
	timer.timeout.connect(_on_global_timer_timeout)
	hour_timer = get_node("/root/Game/GlobalHourTimer")
	hour_timer.timeout.connect(_on_global_hour_timer_timeout)
	day_timer = get_node("/root/Game/GlobalDayTimer")
	day_timer.timeout.connect(_on_global_day_timer_timeout)
	army_timer.timeout.connect(_on_army_timer_timeout)
	add_child(army_timer)
	
	fill.polygon = collision_polygon.polygon
	daily_cost = DEFAULT_DAILY_COST
	
	province_border.hide()
	control.hide()
	_set_mouse_filter_ignore_recursive(city_node)
	resource_texture.texture = MATERIAL_TEXTURES[_get_sprite_key()]
	
	for el in collision_polygon.polygon:
		province_border.add_point(el)

	var game: GameController = get_tree().current_scene
	game.match_over.connect(_on_match_over)
	
	neighbors = await _get_neighbors(1.1)
	set_borders()
	
	target_morale = min(100, 100 - _get_total_morale_penalties() + _get_total_morale_bonuses())	

	if Enums.Buildings.CAPITAL in startup_buildings:
		var capital = Capital.new()
		capital.state = Enums.BuildingStates.FUNCTIONING
		buildings.get_or_add(Enums.Buildings.CAPITAL, capital)
	if Enums.Buildings.RECRUIT_CENTER in startup_buildings:
		var recruit_center = RecruitCenter.new()
		recruit_center.state = Enums.BuildingStates.FUNCTIONING
		buildings.get_or_add(Enums.Buildings.RECRUIT_CENTER, recruit_center)
		
	update_capital_ui()
	current_army_timer = _calculate_army_generation_wait()
	_update_army_timer(current_army_timer)

	if current_army_timer > 0:
		army_timer.start()

	for child in get_children():
		if child is not Path2D: continue
		child = child as Path2D
		var curve: Curve2D = child.curve
		var path_line: Line2D = Line2D.new()
		path_line.name = "PathLine_" + child.name
		path_line.width = 0.7
		path_line.default_color = Color(0.0, 0.0, 0.0, 0.1)
		for i in range(curve.point_count):
			var pos: Vector2 = curve.get_point_position(i)
			path_line.add_point(pos)
		add_child(path_line)
		
	queue_redraw()
	
func set_borders() -> void:
	borders.clear()
	for i in get_children():
		if i is not Line2D or i.name == "ProvinceBorder" or i.name.begins_with("PathLine"): continue
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

		var l = Line2D.new()
		l.width = 1.3
		l.default_color = Color(1.0, 1.0, 1.0, 0.784)
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		for polygon_ in inter:
			for p in polygon_:
				l.add_point(p)
		add_child(l)
		borders.append(l)
		
func has_building(building: Enums.Buildings):
	return building in buildings

func get_total_troop_recruit_percentage() -> int:
	var total_recruit_percentage = 0
	for building in buildings:
		if buildings[building].state == Enums.BuildingStates.FUNCTIONING:
			total_recruit_percentage += buildings[building].recruit_increase_percentage
	return total_recruit_percentage

func has_functioning_building(building: Enums.Buildings) -> bool:
	return building in buildings and buildings[building].state == Enums.BuildingStates.FUNCTIONING

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
	
func get_shared_edges(poly1: PackedVector2Array, poly2: PackedVector2Array, epsilon: float = 0.1) -> Array:
	var shared := []

	for i in range(poly1.size()):
		var a1 = poly1[i]
		var a2 = poly1[(i + 1) % poly1.size()]

		for j in range(poly2.size()):
			var b1 = poly2[j]
			var b2 = poly2[(j + 1) % poly2.size()]

			if a1.distance_to(b1) < epsilon and a2.distance_to(b2) < epsilon:
				shared.append([a1, a2])
			elif a1.distance_to(b2) < epsilon and a2.distance_to(b1) < epsilon:
				shared.append([a1, a2])

	return shared

func update_capital_ui() -> void:
	if province_name_capital_label:
		province_name_capital_label.text = name
	if province_name_label:
		province_name_label.text = name
		
	if Enums.Buildings.CAPITAL in buildings:
		if province_name_capital_container:
			province_name_capital_container.show()
		if province_name_label:
			province_name_label.hide()
	else:
		if province_name_capital_container:
			province_name_capital_container.hide()
		if province_name_label:
			var game: GameController = get_tree().current_scene
			if is_instance_valid(game) and game.selected_province == self:
				province_name_label.show()
			else:
				province_name_label.hide()

func _draw():
	update_capital_ui()
		
func _on_global_timer_timeout() -> void:
	target_morale = min(100, 100 - _get_total_morale_penalties() + _get_total_morale_bonuses())

	var recruit_percentage = get_total_troop_recruit_percentage()
	if recruit_percentage == 0 and not army_timer.is_stopped():
		army_timer.stop()
	elif recruit_percentage > 0 and army_timer.is_stopped():
		army_timer.start()
	
func _on_global_hour_timer_timeout() -> void:
	var agent: Agent = get_parent()
	agent.add_resource(province_material, int(get_daily_resource_count() / 24.0))
	agent.add_resource(Enums.Resources.GOLD, int(get_daily_gold_count() / 24.0))
	for res in daily_cost:
		agent.add_resource(res, -int(daily_cost[res] / 24.0))
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
	province_morale = min(100, province_morale)
	current_army_timer = _calculate_army_generation_wait()
	_update_army_timer(current_army_timer)
	queue_redraw()

	var agent = get_parent()
	if agent is Agent:
		var msg: Dictionary = {
			"type": "sight",
			"sender": "body",
			"receiver": agent.name,
			"data": {
				"type": "province_morale_update",
				"id": name,
				"morale": province_morale
			}
		}
		agent.send_vesna_message(msg)

	if province_morale < RIOT_THRESHOLD:
		var stationary_defense = 0.0
		var player = get_parent()
		if player is Agent:
			for army in player.armies:
				if is_instance_valid(army) and not army.travelling and army.province_location == self:
					if army.soldier_number > 0:
						stationary_defense += (army.soldier_number * army.DEFENSE_PER_UNIT) * army.life_points / (army.soldier_number * army.LIFE_PER_UNIT)

		var required_defense = 0.0
		if province_morale >= RIOT_BREAKPOINT:
			required_defense = RIOT_BASE_DEFENSE
		else:
			required_defense = RIOT_BASE_DEFENSE + (float(RIOT_BREAKPOINT) - province_morale) * RIOT_PENALTY_MULTIPLIER

		if stationary_defense < required_defense:
			var riot_chance = 1.0 - (float(province_morale) / float(RIOT_THRESHOLD))
			if rng.randf() < riot_chance:
				_trigger_riot()

func _trigger_riot() -> void:
	var player = get_parent()
	if player is not Agent: return

	var possible_nations: Array[Agent] = []
	for neighbor in neighbors:
		if neighbor is Province:
			var neighbor_owner = neighbor.get_parent()
			if neighbor_owner is Agent and neighbor_owner != player and neighbor_owner not in possible_nations:
				possible_nations.append(neighbor_owner)

	if possible_nations.is_empty():
		var players = get_tree().get_nodes_in_group("players")
		for p in players:
			if p is Agent and p != player:
				possible_nations.append(p)

	if possible_nations.is_empty():
		return

	var new_owner = possible_nations[rng.randi_range(0, possible_nations.size() - 1)]
	var game: GameController = get_tree().current_scene
	game.conquer_province(self, new_owner)
	
func _on_match_over() -> void:
	army_timer.stop()
	
func _calculate_army_generation_wait() -> float:
	var total_recruit_percentage = get_total_troop_recruit_percentage()
	return (DEFAULT_ARMY_GENERATION_WAIT * float(total_recruit_percentage / 100.0)) + DEFAULT_ARMY_GENERATION_WAIT * (1.0 - (float(province_morale) / 100.0))
	
func _update_army_timer(val: float) -> void:
	if army_timer == null: return
	current_army_timer = val
	
	if army_timer.is_stopped():
		army_timer.wait_time = val
	else:
		var progress_ratio: float = 0.0
		if army_timer.wait_time > 0:
			progress_ratio = 1.0 - (army_timer.time_left / army_timer.wait_time)
		army_timer.wait_time = val
		var remaining_time: float = max(0.1, val * (1.0 - progress_ratio))
		army_timer.start(remaining_time)
	
func _on_army_timer_timeout() -> void:
	current_army_timer = _calculate_army_generation_wait()
	army_timer.wait_time = current_army_timer
	var game: GameController = get_tree().current_scene
	for el: Army in get_parent().armies:
		if el.global_position != to_global(get_city_position()): continue
		el.soldier_number += 1
		el.life_points += el.LIFE_PER_UNIT * (float(province_morale)/100)
		el.queue_redraw()
		var agent = get_parent()
		if agent is Agent:
			agent.dispatch_my_army_update(el)
		if game != null:
			game.notify_province_defense_change(self)
		return
	
	if game != null:
		game.add_army_to_province(self, null, 1)
		game.notify_province_defense_change(self)
	
func get_daily_resource_count() -> int:
	var resource_to_add: int = (province_morale * 24) + 750
	
	if double_material:
		resource_to_add *= 2
	return resource_to_add
	
func get_daily_gold_count() -> int:
	if double_material:
		return province_morale * 29
	else:
		return province_morale * 57

func _update_active_morale_modifiers() -> void:
	morale_bonuses.clear()
	morale_maluses.clear()
	for key in all_bonuses:
		var modifier = all_bonuses[key]
		if modifier.is_modifier_applied(self):
			morale_bonuses[key] = modifier
	for building in buildings:
		if buildings[building].morale_increase_percentage != 0 and buildings[building].state == Enums.BuildingStates.FUNCTIONING:
			morale_bonuses["building_%s" % building] = buildings[building]
	for key in all_maluses:
		var modifier = all_maluses[key]
		if modifier.is_modifier_applied(self):
			morale_maluses[key] = modifier
	
func _get_total_morale_penalties() -> int:
	_update_active_morale_modifiers()
	var total_penalties = 0
	for key in morale_maluses:
		var modifier = morale_maluses[key]
		total_penalties += abs(modifier.apply_modifier(self))
	return total_penalties
	
func _get_total_morale_bonuses() -> int:
	_update_active_morale_modifiers()
	var total_bonuses = 0
	for key in morale_bonuses:
		var modifier = morale_bonuses[key]
		if key.begins_with("building_"):
			total_bonuses += modifier.morale_increase_percentage
		else:
			total_bonuses += abs(modifier.apply_modifier(self))
	return total_bonuses

	
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
	return city_node.position
	
func get_city_global_position() -> Vector2:
	return to_global(city_node.position)
	
func get_province_paths():
	if not is_inside_tree(): return []
	var global_paths = get_tree().get_nodes_in_group("paths")
	var paths = []
	for el in global_paths:
		if el is not Path: continue
		
		var start = el.curve.get_point_position(0)
		var end = el.curve.get_point_position(el.curve.point_count - 1)
		
		if start == get_city_position():
			paths.append([el, start])
		elif end == get_city_position():
			paths.append([el, end])
	return paths
	
func _notification(what: int) -> void:
	if what != NOTIFICATION_PARENTED: return
	if not is_inside_tree(): return
	var parent = get_parent()
	if parent == null or not (parent is Agent): return
	for path in get_province_paths():
		var graph_node_key = 0
		if path[1] != Vector2.ZERO:
			graph_node_key = 1
		
		if path[0] in parent.path_to_graph:
			var node_id = parent.path_to_graph[path[0]][graph_node_key]
			parent.routes.set_point_weight_scale(node_id, 1.0)
		
		var players = get_tree().get_nodes_in_group("players")
		for player in players:
			if player == parent: continue
			if player is Agent and path[0] in player.path_to_graph:
				var enemy_node_id = player.path_to_graph[path[0]][graph_node_key]
				player.routes.set_point_weight_scale(enemy_node_id, 1.5)
					
func toggle_selection() -> bool:
	selected = not selected
	if selected:
		fill.color = blend(get_parent().color, Color(0.0, 0.0, 0.0, 0.114))
	else:
		fill.color = get_parent().color
	queue_redraw()
	return selected
	
func blend_under(bottom: Color, top: Color) -> Color:
	var a = top.a
	return bottom * (1.0 - a) + top * a

func blend(bottom: Color, top: Color) -> Color:
	var out = blend_under(bottom, top)
	out.a = bottom.a + top.a * (1.0 - bottom.a)
	return out

func _set_mouse_filter_ignore_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_filter_ignore_recursive(child)
