extends Node

class_name GameController

signal match_over

var provinces: Array[Province] = []
var hud_scene: Resource = preload("res://scenes/hud.tscn")
var view: Agent = null
var leaderboard: Array[Variant] = []
var day_cycle: int = 1
var fog_circles: Dictionary[Army, Variant] = {}
var fog_image: Image
var vision_images: Array[Variant]
var hud: Hud
const FOG_OF_WAR_BACKGROUND_COLOR: Color = Color(0.0, 0.0, 0.0, 0.3)
const FOG_OF_WAR_OUTER_CIRCLE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.1)
const FOG_OF_WAR_INNER_CIRCLE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const FOG_OF_WAR_OUTER_CIRCLE_RADIUS_MULTIPLIER: float = 1.5
const VIEW_AGENT_COLOR: Color = Color("b4ceaf")
const VIEW_ALLY_COLOR: Color = Color("81919b")
const VIEW_ENEMY_COLOR: Color = Color("c18d8c")
const VIEW_NEUTRAL_COLOR: Color = Color("bdbaa6")
@export var time_multiplier: float = 1.0
@export var game_length: int = 90
@onready var global_timer: Timer = $GlobalTimer
@onready var global_hour_timer: Timer = $GlobalHourTimer
@onready var global_day_timer: Timer = $GlobalDayTimer
@onready var fog_sprite: Sprite2D = %FogSprite
@onready var fog_material: ShaderMaterial = %FogSprite.material as ShaderMaterial
@onready var background: Polygon2D = $Background/Polygon2D

func _create_fog() -> void:
	var world_dimensions: Vector2 = get_collision_rect_size(background)
		
	fog_image = Image.create(int(world_dimensions.x), int(world_dimensions.y), false, Image.FORMAT_RGBA8)
	fog_image.fill(Color(0, 0, 0, 0.5))
	var fog_texture: ImageTexture = ImageTexture.create_from_image(fog_image)
	fog_sprite.texture = fog_texture
	
	fog_material.set_shader_parameter("color_background", FOG_OF_WAR_BACKGROUND_COLOR)
	fog_material.set_shader_parameter("color_big", FOG_OF_WAR_OUTER_CIRCLE_COLOR)
	fog_material.set_shader_parameter("color_small", FOG_OF_WAR_INNER_CIRCLE_COLOR)
	fog_material.set_shader_parameter("big_radius_multiplier", FOG_OF_WAR_OUTER_CIRCLE_RADIUS_MULTIPLIER)

func _fog_add_circle(army: Army, pos: Vector2, radius: float) -> void:
	fog_circles[army] = {
		"position": pos + Vector2(fog_image.get_size()) / 2 + (fog_sprite.global_position * Vector2(-1.0, -1.0)),
		"radius": radius,
		"id": len(fog_circles)
	}
	
	var circles_position: Array[Vector2] = []
	var circles_radius: Array[float] = []
	
	for el in fog_circles:
		circles_position.insert(fog_circles[el]["id"], fog_circles[el]["position"])
		circles_radius.insert(fog_circles[el]["id"], fog_circles[el]["radius"])
	
	fog_material.set_shader_parameter("circle_count", len(fog_circles))
	fog_material.set_shader_parameter("pos", circles_position)
	fog_material.set_shader_parameter("small_radius", circles_radius)
	
func _fog_clear_circles() -> void:
	fog_circles.clear()
	fog_material.set_shader_parameter("circle_count", 0)
	fog_material.set_shader_parameter("pos", [])
	fog_material.set_shader_parameter("small_radius", [])
	
func _fog_del_circle(army: Army) -> void:
	fog_circles.erase(army)
	
	var circles_position: Array[Vector2] = []
	var circles_radius: Array[float] = []
	var c: int = 0
	
	for el in fog_circles:
		circles_position.append(fog_circles[el]["position"])
		circles_radius.append(fog_circles[el]["radius"])
		
		fog_circles[el]["id"] = c
		c += 1
	
	fog_material.set_shader_parameter("circle_count", len(fog_circles))
	fog_material.set_shader_parameter("pos", circles_position)
	fog_material.set_shader_parameter("small_radius", circles_radius)
	
func _fog_map_circles() -> void:
	var armies: Array[Variant]
	if view == null:
		armies = get_tree().get_nodes_in_group("armies")
	else:
		armies = view.armies
	_fog_clear_circles()
	for army: Army in armies:
		_fog_add_circle(army, army.global_position, army.VISION_RANGE)
	
func _fog_update_circle_position(army: Army, new_pos: Vector2) -> void:
	fog_circles[army]["position"] = new_pos + Vector2(fog_image.get_size()) / 2 + (fog_sprite.global_position * Vector2(-1.0, -1.0))
	
	var circles_position: Array[Vector2] = []
	var circles_radius: Array[float] = []
	
	for el in fog_circles:
		circles_position.insert(fog_circles[el]["id"], fog_circles[el]["position"])
		circles_radius.insert(fog_circles[el]["id"], fog_circles[el]["radius"])
	
	fog_material.set_shader_parameter("pos", circles_position)
	fog_material.set_shader_parameter("small_radius", circles_radius)

func _ready() -> void:
	Engine.time_scale = time_multiplier
	var polys = get_tree().get_nodes_in_group("provinces")
	var nodes: Array[Path2D]
	var players: Array[Node] = get_tree().get_nodes_in_group("players")
	
	for el in polys:
		if el is not Province: continue
		provinces.append(el)
	
	for el in get_children():
		if el is Path2D:
			nodes.append(el)
			
	for player: Agent in players:
		leaderboard.append({"player": player, "points": player.points})
		player.war_declared.connect(_on_war_declared)
		
		var capital: Province = null
		for province in player.get_children():
			if province is not Province: continue
			province = province as Province
			if Enums.Buildings.CAPITAL in province.buildings and capital == null:
				capital = province
			elif Enums.Buildings.CAPITAL in province.buildings:
				province.buildings.remove_at(province.buildings.find(Enums.Buildings.CAPITAL))
	leaderboard.sort_custom(_sort_leaderboard)
	
	_create_hud()
	_create_fog()
	_fog_map_circles()
	_set_provinces_color()
	global_timer.timeout.connect(_on_global_timer_timeout)

func _set_provinces_color() -> void:
	if view == null:
		for province: Province in provinces:
			province.fill.color = VIEW_NEUTRAL_COLOR
	else:
		for province: Province in provinces:
			if province.get_parent() == view:
				province.fill.color = VIEW_AGENT_COLOR
			elif (province.get_parent() as Agent) in view.player_in_war:
				province.fill.color = VIEW_ENEMY_COLOR
			else:
				province.fill.color = VIEW_NEUTRAL_COLOR

func _on_army_became_known(army: Army, player: Agent) -> void:
	if player != view: return
	army.soldier_number_visible = false
	army.show() 
	army.queue_redraw()
	
func _on_army_became_perfectly_known(army: Army, player: Agent) -> void:
	if player != view: return
	army.soldier_number_visible = true
	army.show()
	army.queue_redraw()
	
func _on_army_became_unknown(army: Army, player: Agent) -> void:
	if player != view: return
	army.hide()
	army.queue_redraw()
	
func _on_army_destroyed(army: Army) -> void:
	var armies: Array[Army] = army.player.armies
	for i in range(len(armies)):
		if armies[i] != army: continue
		armies.remove_at(i)
		break
	_fog_del_circle(army)
	
func _on_global_timer_timeout() -> void:
	var armies: Array[Variant]
	if view == null:
		armies = get_tree().get_nodes_in_group("armies")
	else:
		armies = view.armies
	for el: Army in armies:
		_fog_update_circle_position(el, el.global_position)
		
	var players = get_tree().get_nodes_in_group("players")
	for player: Agent in players:
		for el in leaderboard:
			if el["player"] == player:
				el["points"] = player.points
	leaderboard.sort_custom(_sort_leaderboard)
	
func _on_view_changed(player: Agent) -> void:
	view = player
	var players = get_tree().get_nodes_in_group("players")
	for el: Agent in players:
		if el == player:
			for army: Army in el.armies:
				army.soldier_number_visible = true
				army.show()
				army.queue_redraw()
		else:
			for army: Army in el.armies:
				if player == null:
					army.soldier_number_visible = true
					army.show()
				elif army in player.known_armies:
					army.soldier_number_visible = false
					army.show()
				elif army in player.perfectly_known_armies:
					army.soldier_number_visible = true
					army.show()
				else:
					army.hide()
				army.queue_redraw()
	_fog_map_circles()
	_set_provinces_color()
	
func _on_war_declared(_from_player: Agent, _to_player: Agent) -> void:
	_set_provinces_color()
	
func _sort_leaderboard(a, b):
	return a["points"] < b["points"]

func add_army_to_province(province: Province, army: Army = null, sn: int = 10) -> void:
	var agent: Agent = province.get_parent()
	if army == null:
		var paths: Array[Node] = get_tree().get_nodes_in_group("paths")
		var army_scene = preload("res://scenes/army.tscn")
		army = army_scene.instantiate()
		army.army_id = agent.next_army_id
		agent.next_army_id += 1
		army.soldier_number = sn
		army.life_points = army.LIFE_PER_UNIT * 10 * (float(province.province_morale)/100)
		army.player = agent
		agent.armies.append(army)

		for el in paths:
			if el is Path2D:
				var count: int = el.curve.point_count
				var found: bool = false
				for j in range(count):
					if el.curve.get_point_position(j) == province.get_city_position():
						el.add_child(army)
						if j != 0:
							army.progress_ratio = 1.0
						found = true
						break
				if found:
					break
	army.army_destroyed.connect(_on_army_destroyed)
	army.became_known.connect(_on_army_became_known)
	army.became_perfectly_known.connect(_on_army_became_perfectly_known)
	army.became_unknown.connect(_on_army_became_unknown)
	
	if army.player == view or view == null:
		_fog_add_circle(army, army.position, army.VISION_RANGE)
	
	if agent != view and view != null:
		army.hide()

func _create_hud():
	var canvas_layer = CanvasLayer.new()
	hud = hud_scene.instantiate()
	canvas_layer.add_child(hud)
	hud.view_changed.connect(_on_view_changed)
	get_tree().current_scene.add_child(canvas_layer)
	
func conquer_province(province: Province, agent: Agent) -> void:
	var previous_player: Agent = province.get_parent()
	province.reparent(agent)
	province.province_morale = 12
	province.conquered = true

	if view == null or (view != province.get_parent() and province.get_parent() not in view.player_in_war):
		province.fill.color = VIEW_NEUTRAL_COLOR
	elif view == province.get_parent():
		province.fill.color = VIEW_AGENT_COLOR
	elif view != province.get_parent() and province.get_parent() in view.player_in_war:
		province.fill.color = VIEW_ENEMY_COLOR
	
	province.set_borders()
	for el in province.neighbors:
		if el is not Province: continue
		el.set_borders()
	previous_player.update_name_position()
	agent.update_name_position()
	
func get_collision_rect_size(poly: Polygon2D) -> Vector2:
	var pts = poly.polygon
	if pts.size() != 4:
		return Vector2.ZERO
	var min_x = pts[0].x
	var max_x = pts[0].x
	var min_y = pts[0].y
	var max_y = pts[0].y

	for p in pts:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	return Vector2(max_x - min_x, max_y - min_y)


func _on_global_day_timer_timeout() -> void:
	day_cycle += 1
	if day_cycle > game_length:
		global_timer.stop()
		global_hour_timer.stop()
		global_day_timer.stop()
		day_cycle = game_length
		emit_signal("match_over")
		
