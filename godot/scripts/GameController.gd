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
var selected_province: Province = null
const FOG_OF_WAR_BACKGROUND_COLOR: Color = Color(0.0, 0.0, 0.0, 0.3)
const FOG_OF_WAR_OUTER_CIRCLE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.1)
const FOG_OF_WAR_INNER_CIRCLE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const FOG_OF_WAR_OUTER_CIRCLE_RADIUS_MULTIPLIER: float = 1.5
const VIEW_AGENT_COLOR: Color = Color("b4ceaf")
const VIEW_ALLY_COLOR: Color = Color("81919b")
const VIEW_ENEMY_COLOR: Color = Color("c18d8c")
const VIEW_NEUTRAL_COLOR: Color = Color("bdbaa6")
const PROVINCE_SELECTED_MODULATION: Color = Color(0.771, 0.771, 0.771, 1.0)
const CONQUERED_PROVINCE_MORALE: int = 25
const MAX_POINTS: int = 200
@export var time_multiplier: float = 1.0
@export var game_length: int = 30
@export var hud_enabled: bool = true
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

func _fog_flush_shader() -> void:
	var circles_position: Array[Vector2] = []
	var circles_radius: Array[float] = []
	
	for el in fog_circles:
		circles_position.append(fog_circles[el]["position"])
		circles_radius.append(fog_circles[el]["radius"])
	
	fog_material.set_shader_parameter("circle_count", len(fog_circles))
	fog_material.set_shader_parameter("pos", circles_position)
	fog_material.set_shader_parameter("small_radius", circles_radius)

func _fog_add_circle(army: Army, pos: Vector2, radius: float, update_shader: bool = true) -> void:
	fog_circles[army] = {
		"position": pos + Vector2(fog_image.get_size()) / 2 + (fog_sprite.global_position * Vector2(-1.0, -1.0)),
		"radius": radius
	}
	if update_shader:
		_fog_flush_shader()
	
func _fog_clear_circles() -> void:
	fog_circles.clear()
	fog_material.set_shader_parameter("circle_count", 0)
	fog_material.set_shader_parameter("pos", [])
	fog_material.set_shader_parameter("small_radius", [])
	
func _fog_del_circle(army: Army) -> void:
	if fog_circles.erase(army):
		_fog_flush_shader()
	
func _fog_map_circles() -> void:
	var armies: Array[Variant]
	if view == null:
		armies = get_tree().get_nodes_in_group("armies")
	else:
		armies = view.armies
	_fog_clear_circles()
	for army: Army in armies:
		_fog_add_circle(army, army.global_position, army.VISION_RANGE, false)
	_fog_flush_shader()
	
func _fog_update_circle_position(army: Army, new_pos: Vector2) -> void:
	if not fog_circles.has(army): return
	fog_circles[army]["position"] = new_pos + Vector2(fog_image.get_size()) / 2 + (fog_sprite.global_position * Vector2(-1.0, -1.0))

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
		player.war_declared.connect(_on_relations_changed)
		player.peace_established.connect(_on_relations_changed)
		player.alliance_established.connect(_on_relations_changed)
		
		var capital: Province = null
		for province in player.get_children():
			if province is not Province: continue
			province = province as Province
			if Enums.Buildings.CAPITAL in province.buildings and capital == null:
				capital = province
			elif Enums.Buildings.CAPITAL in province.buildings:
				province.buildings.erase(Enums.Buildings.CAPITAL)
				province.update_capital_ui()
	leaderboard.sort_custom(_sort_leaderboard)
	
	_create_hud()
	var bg = get_tree().get_first_node_in_group("background")
	if bg:
		bg.clear_province.connect(on_clear_province)
	_create_fog()
	_fog_map_circles()
	_set_provinces_color()

func _set_provinces_color() -> void:
	if view == null:
		for province: Province in provinces:
			province.fill.color = VIEW_NEUTRAL_COLOR
	else:
		for province: Province in provinces:
			if province.get_parent() == view:
				province.fill.color = VIEW_AGENT_COLOR
			elif (province.get_parent() as Agent)in view.player_in_alliance:
				province.fill.color = VIEW_ALLY_COLOR
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
	_fog_flush_shader()
		
	var players = get_tree().get_nodes_in_group("players")
	for player: Agent in players:
		for el in leaderboard:
			if el["player"] == player:
				el["points"] = player.points
	leaderboard.sort_custom(_sort_leaderboard)
	check_victory_conditions()
	
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
				elif army in player.perfectly_known_armies:
					army.soldier_number_visible = true
					army.show()
				elif army in player.known_armies:
					army.soldier_number_visible = false
					army.show()
				else:
					army.hide()
				army.queue_redraw()
	_fog_map_circles()
	_set_provinces_color()
	
func _on_relations_changed(_from_player: Agent, _to_player: Agent) -> void:
	_set_provinces_color()
	for army in get_tree().get_nodes_in_group("armies"):
		if army is Army:
			army.queue_redraw()
	
func _sort_leaderboard(a, b):
	return a["points"] > b["points"]
	
func notify_province_defense_change(province: Province) -> void:
	if not is_instance_valid(province): return
	var agents = get_tree().get_nodes_in_group("players")
	for agent in agents:
		if agent is Agent:
			agent.dispatch_province_defense_update(province)

func register_army(army: Army) -> void:
	if not is_instance_valid(army): return
	if not army.army_destroyed.is_connected(_on_army_destroyed):
		army.army_destroyed.connect(_on_army_destroyed)
	if not army.became_known.is_connected(_on_army_became_known):
		army.became_known.connect(_on_army_became_known)
	if not army.became_perfectly_known.is_connected(_on_army_became_perfectly_known):
		army.became_perfectly_known.connect(_on_army_became_perfectly_known)
	if not army.became_unknown.is_connected(_on_army_became_unknown):
		army.became_unknown.connect(_on_army_became_unknown)
	
	if army.player == view or view == null:
		_fog_add_circle(army, army.global_position, army.VISION_RANGE)
	
	if army.player != view and view != null:
		army.hide()
	army.queue_redraw()

func add_army_to_province(province: Province, army: Army = null, sn: int = 10, force_new: bool = false) -> Army:
	var agent: Agent = province.get_parent()
	if army == null:
		if not force_new and is_instance_valid(agent):
			for existing in agent.armies:
				if is_instance_valid(existing) and not existing.travelling:
					if existing.province_location == province or (existing.province_location == null and existing.global_position.distance_to(province.to_global(province.get_city_position())) < 10.0):
						existing.province_location = province
						existing.soldier_number += sn
						existing.life_points += existing.LIFE_PER_UNIT * sn * (float(province.province_morale)/100)
						existing.queue_redraw()
						agent.dispatch_my_army_update(existing)
						notify_province_defense_change(province)
						return existing
		
		var paths: Array[Node] = get_tree().get_nodes_in_group("paths")
		var army_scene = preload("res://scenes/army.tscn")
		army = army_scene.instantiate()
		army.army_id = agent.next_army_id
		agent.next_army_id += 1
		army.soldier_number = sn
		army.life_points = army.LIFE_PER_UNIT * sn * (float(province.province_morale)/100)
		army.player = agent
		army.province_location = province
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
		if is_instance_valid(agent):
			agent.dispatch_my_army_update(army)
	register_army(army)
	notify_province_defense_change(province)
	return army

var hud_canvas_layer: CanvasLayer = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_hud"):
		toggle_hud()

func toggle_hud() -> void:
	if hud:
		hud_enabled = not hud.visible
		hud.visible = hud_enabled
		if hud_canvas_layer:
			hud_canvas_layer.visible = hud_enabled
	elif hud_scene:
		hud_enabled = true
		_create_hud()

func _create_hud():
	if hud_scene:
		hud_canvas_layer = CanvasLayer.new()
		hud = hud_scene.instantiate()
		hud_canvas_layer.add_child(hud)
		hud.view_changed.connect(_on_view_changed)
		get_tree().current_scene.add_child(hud_canvas_layer)
		hud_canvas_layer.visible = hud_enabled
		hud.visible = hud_enabled
	
func conquer_province(province: Province, agent: Agent, is_riot: bool=false) -> void:
	var previous_player: Agent = province.get_parent()
	province.reparent(agent)

	if province.get_parent() == view:
		province.fill.color = VIEW_AGENT_COLOR
	elif view and (province.get_parent() as Agent) in view.player_in_alliance:
		province.fill.color = VIEW_ALLY_COLOR
	elif view and (province.get_parent() as Agent) in view.player_in_war:
		province.fill.color = VIEW_ENEMY_COLOR
	else:
		province.fill.color = VIEW_NEUTRAL_COLOR
	
	province.set_borders()
	for el in province.neighbors:
		if el is not Province: continue
		el.set_borders()
	previous_player.update_name_position()
	agent.update_name_position()

	var prov_owner = province.get_parent()

	if Enums.Buildings.CAPITAL in province.buildings:
		province.buildings.erase(Enums.Buildings.CAPITAL)
		province.update_capital_ui()
		province.queue_redraw()

	if not is_riot:
		province.province_morale = CONQUERED_PROVINCE_MORALE
		province.conquered = true
	else:
		for army in previous_player.armies:
			if army.province_location == province or (army.province_location == null and army.global_position.distance_to(province.get_city_global_position()) < 10.0):
				army.player = prov_owner
				previous_player.armies.erase(army)
		print("province riot")

	if hud and selected_province == province:
		hud.show_province_details(province)

	_send_province_update_to_all(province)
	for neighbor in province.neighbors:
		if neighbor is Province:
			_send_province_update_to_all(neighbor)
	for p in get_tree().get_nodes_in_group("players"):
		if p is Agent:
			p.dispatch_neighbor_nations_update()
	check_victory_conditions()

func _send_province_update_to_all(target_prov: Province) -> void:
	if not is_instance_valid(target_prov): return
	var target_owner = target_prov.get_parent()
	var players = get_tree().get_nodes_in_group("players")
	var city_pos = target_prov.to_global(target_prov.get_city_position())
	
	for player in players:
		if player is Agent:
			var bordering_allies = []
			for neighbor in target_prov.neighbors:
				if neighbor is Province:
					var np = neighbor.get_parent()
					if np is Agent and (np == player or np in player.player_in_alliance):
						bordering_allies.append(neighbor.name)
					
			var has_army = false
			var defense_value = 0.0 
			for army in get_tree().get_nodes_in_group("armies"):
				if not is_instance_valid(army): continue
				if army.player is Agent and army.player != player and (army.player not in player.player_in_alliance):
					if army.province_location == target_prov or (not army.travelling and army.province_location == null and army.global_position.distance_to(city_pos) < 10.0):
						has_army = true
						if army.soldier_number > 0:
							defense_value += (army.soldier_number * army.DEFENSE_PER_UNIT) * army.life_points / (army.soldier_number * army.LIFE_PER_UNIT)

			var msg: Dictionary = {
				"type": "sight",
				"sender": "body",
				"receiver": player.name,
				"data": {
					"type": "province_owner_update",
					"id": target_prov.name,
					"owner": target_owner.name if is_instance_valid(target_owner) else "",
					"morale": target_prov.province_morale,
					"x": city_pos.x,
					"y": city_pos.y,
					"has_army": has_army,
					"defense_value": defense_value,
					"bordering_allies": bordering_allies,
					"is_capital": Enums.Buildings.CAPITAL in target_prov.buildings,
					"is_double": target_prov.double_material,
					"resource": Enums.Resources.keys()[target_prov.province_material].to_lower()
				}
			}
			player.send_vesna_message(msg)
	
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


func end_match() -> void:
	if not global_timer.is_stopped():
		global_timer.stop()
		global_hour_timer.stop()
		global_day_timer.stop()
		emit_signal("match_over")

func check_victory_conditions() -> void:
	var players = get_tree().get_nodes_in_group("players")
	for player: Agent in players:
		if player.points >= MAX_POINTS:
			end_match()
			break

func _on_global_day_timer_timeout() -> void:
	day_cycle += 1
	if day_cycle > game_length:
		day_cycle = game_length
		end_match()
		
func select_province(province: Province) -> void:
	if selected_province == province:
		if selected_province != null:
			selected_province.fill.modulate = Color.WHITE
			if Enums.Buildings.CAPITAL not in selected_province.buildings:
				selected_province.province_name_label.hide()
		selected_province = null
		if hud:
			hud.show_province_details(null)
	else:
		if selected_province != null:
			selected_province.fill.modulate = Color.WHITE
			if Enums.Buildings.CAPITAL not in selected_province.buildings:
				selected_province.province_name_label.hide()
		selected_province = province
		province.fill.modulate = PROVINCE_SELECTED_MODULATION
		if Enums.Buildings.CAPITAL not in province.buildings:
			province.province_name_label.show()
		if hud:
			hud.show_province_details(province)

func on_clear_province() -> void:
	if selected_province != null and is_instance_valid(selected_province):
		selected_province.fill.modulate = Color.WHITE
		if Enums.Buildings.CAPITAL not in selected_province.buildings:
			selected_province.province_name_label.hide()
		selected_province = null
		if hud:
			hud.show_province_details(null)

var pending_peace_votes: Dictionary = {}

func get_war_coalition(agent: Agent, enemy: Agent) -> Array[Agent]:
	var coalition: Array[Agent] = [agent]
	for ally in agent.player_in_alliance:
		if ally is Agent and ally in enemy.player_in_war and not (ally in coalition):
			coalition.append(ally)
	return coalition

func get_war_front_key(agent_a: Agent, agent_b: Agent) -> String:
	var side_a = get_war_coalition(agent_a, agent_b)
	var side_b = get_war_coalition(agent_b, agent_a)
	var names_a: Array[String] = []
	for a in side_a:
		names_a.append(a.name)
	names_a.sort()
	var names_b: Array[String] = []
	for b in side_b:
		names_b.append(b.name)
	names_b.sort()
	var str_a = ",".join(names_a)
	var str_b = ",".join(names_b)
	var sides = [str_a, str_b]
	sides.sort()
	return sides[0] + " VS " + sides[1]

func register_peace_request(requester: Agent, target: Agent) -> void:
	var key = get_war_front_key(requester, target)
	if not pending_peace_votes.has(key):
		pending_peace_votes[key] = {}
	pending_peace_votes[key][requester] = true

func register_peace_vote(voter: Agent, target: Agent) -> void:
	var side_a = get_war_coalition(voter, target)
	var side_b = get_war_coalition(target, voter)
	var key = get_war_front_key(voter, target)
	if not pending_peace_votes.has(key):
		pending_peace_votes[key] = {}
	pending_peace_votes[key][voter] = true
	
	var all_agreed = true
	for m in side_a:
		if not pending_peace_votes[key].get(m, false):
			all_agreed = false
			break
	if all_agreed:
		for m in side_b:
			if not pending_peace_votes[key].get(m, false):
				all_agreed = false
				break
				
	if all_agreed:
		pending_peace_votes.erase(key)
		for a in side_a:
			for b in side_b:
				if is_instance_valid(a) and is_instance_valid(b) and (b in a.player_in_war):
					a.make_peace(b)

func register_peace_decline(decliner: Agent, target: Agent) -> void:
	var side_a = get_war_coalition(decliner, target)
	var side_b = get_war_coalition(target, decliner)
	var key = get_war_front_key(decliner, target)
	pending_peace_votes.erase(key)
	
	for enemy in side_b:
		if is_instance_valid(enemy):
			var msg: Dictionary = {
				"type": "sight",
				"sender": "body",
				"receiver": enemy.name,
				"data": {
					"type": "peace_request_declined",
					"sender": decliner.name
				}
			}
			enemy.send_vesna_message(msg)
