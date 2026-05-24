extends Node2D

class_name Agent

signal war_declared
signal peace_requested
signal alliance_requested

var routes: GPA2D = GPA2D.new()
var hour_timer: Timer
var day_timer: Timer
var graph_to_path = []
var path_to_graph = {}
var resources: Dictionary[Enums.Resources, int] = {
	Enums.Resources.WOOD: 15_000,
	Enums.Resources.IRON: 15_000,
	Enums.Resources.OIL: 10_000,
	Enums.Resources.GAS: 10_000,
	Enums.Resources.COAL: 10_000,
	Enums.Resources.GRAIN: 10_000,
	Enums.Resources.FISH: 10_000,
	Enums.Resources.GOLD: 200_000,
}
var points: int = 54
var perfectly_known_armies: Dictionary[Army, int] = {}
var known_armies: Dictionary[Army, int] = {}
var player_in_war: Array[Agent] = []
var armies: Array[Army] = []
var next_army_id: int = 0
var tcp_server := TCPServer.new()
var ws := WebSocketPeer.new()
var end_communication: bool = true

@export var PORT : int

@onready var player_name_control: Control = $Control
@onready var player_name_label: Label = $Control/PlayerName


func _ready() -> void:
	add_to_group("players")
	await get_tree().process_frame
	var paths: Array[Node] = get_tree().get_nodes_in_group("paths")
	var c: int = 0
	for el in paths:
		if el is not Path2D: continue
		var start_point_position = el.to_global(el.curve.get_point_position(0))
		var end_point_position = el.to_global(el.curve.get_point_position(el.curve.point_count - 1))
		var weight: float
		if el.get_parent().get_parent() == self:
			weight = 1.0
		else:
			weight = 2.0
		routes.add_point(c, start_point_position, 1.0)
		routes.add_point(c + 1, end_point_position, 1.0)
		routes.connect_points(c, c + 1, weight)
		graph_to_path.insert(c, [el, 0])
		graph_to_path.insert(c + 1, [el, el.curve.point_count - 1])
		path_to_graph[el] = [c, c + 1]
		c += 2
		
	for el in paths:
		if el is not Path2D: continue
		var connected_points_start: Array[Variant] = el.get_paths_points(0)
		var connected_points_end: Array[Variant] = el.get_paths_points(el.curve.point_count - 1)
		var weight: float
		
		if el.get_parent().get_parent() == self:
			weight = 1.0
		else:
			weight = 1.5
		
		for s in connected_points_start:
			var i: int
			if s[1] == 0:
				i = 0
			else:
				i = 1
			routes.connect_points(path_to_graph[el][0], path_to_graph[s[0]][i], weight)
		
		for s in connected_points_end:
			var i: int
			if s[1] == 0:
				i = 0
			else:
				i = 1
			routes.connect_points(path_to_graph[el][1], path_to_graph[s[0]][i], weight)
	
	var provinces = get_tree().get_nodes_in_group("provinces")
	for el in provinces:
		if el is not Province: continue
		
		if el not in get_children():
			for path in el.get_province_paths():
				var graph_node_key = 0
				if path[1] != Vector2.ZERO:
					graph_node_key = 1
				routes.set_point_weight_scale(path_to_graph[path[0]][graph_node_key], 1.5)
	
	var game: GameController = get_tree().current_scene
	var children = get_children()
	for i in range(len(children)):
		if children[i] is not Province: continue	
		game.add_army_to_province(children[i])
	
	if len(armies) > 0 and name == "ukraine":
		armies[0].order(game.provinces[2])
		declare_war(get_tree().current_scene.get_node("russia"))
		pass
	
	hour_timer = get_node("/root/Game/GlobalHourTimer")
	hour_timer.timeout.connect(_on_global_hour_timer_timeout)
	day_timer = get_node("/root/Game/GlobalDayTimer")
	day_timer.timeout.connect(_on_global_day_timer_timeout)
	
	player_name_label.text = name
	update_name_position()
	
	if tcp_server.listen( PORT ) != OK:
		push_error( "Unable to start the server" )
		set_process( false )
		
func _process(_delta: float) -> void:
	while tcp_server.is_connection_available():
		var conn : StreamPeerTCP = tcp_server.take_connection()
		assert( conn != null )
		ws.accept_stream( conn )
		
	ws.poll()
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count():
			var msg : String = ws.get_packet().get_string_from_ascii()
			var intention : Dictionary = JSON.parse_string( msg )
			#print(intention)
			manage( intention )
			
func manage(message: Dictionary) -> void:
	var sender : String = message['sender']
	var receiver : String = message['receiver']
	var type : String = message[ 'type' ]
	var data : Dictionary = message[ 'data' ]
	print(sender, " ", receiver, " ", type, " ", data)
	if type == "action":
		var action_type = data.get("action_type")
		if action_type == "move_army":
			var army_id = data.get("army_id")
			var target_prov_name = data.get("target_province")
			var army_to_move = null
			for army in armies:
				if army.army_id == army_id:
					army_to_move = army
					break
			if army_to_move != null:
				var all_provinces = get_tree().get_nodes_in_group("provinces")
				for prov in all_provinces:
					if prov.name == target_prov_name:
						army_to_move.order(prov)
						break
		elif action_type == "declare_war":
			var target_name = data.get("target")
			var players = get_tree().get_nodes_in_group("players")
			for p in players:
				if p.name == target_name:
					declare_war(p)
					break
	
func _exit_tree() -> void:
	ws.close()
	tcp_server.stop()
	
func _on_global_hour_timer_timeout() -> void:
	var total_army_daily_cost: Dictionary[Enums.Resources, int] = {
		Enums.Resources.WOOD: 0,
		Enums.Resources.IRON: 0,
		Enums.Resources.OIL: 0,
		Enums.Resources.GAS: 0,
		Enums.Resources.COAL: 0,
		Enums.Resources.GRAIN: 0,
		Enums.Resources.FISH: 0,
		Enums.Resources.GOLD: 0,
	}
	
	for el in armies:
		if not is_instance_valid(el): continue
		for i in el.ARMY_DAILY_COST_PER_UNIT:
			total_army_daily_cost[i] += el.ARMY_DAILY_COST_PER_UNIT[i]*el.soldier_number
	
	for i in total_army_daily_cost:
		add_resource(i, -ceil(float(total_army_daily_cost[i])/24))
		
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var state: Dictionary = {
			"type": "sight",
			"sender": self.name,
			"receiver": "vesna",
			"data": {
				"type": "state_update",
				"resources": {},
				"my_armies": [],
				"allied_provinces": [],
				"enemy_provinces": [],
				"nation_strengths": {},
				"active_wars": len(player_in_war),
				"neighbor_nations": {}
			}
		}
		
		# fill resources
		for res in resources:
			var res_name = Enums.Resources.keys()[res].to_lower()
			state["data"]["resources"][res_name] = resources[res]
			
		# fill my_armies
		var all_provinces = get_tree().get_nodes_in_group("provinces")
		for army in armies:
			if not is_instance_valid(army): continue
			var loc_name = ""
			if army.province_location != null and army.province_location is Province:
				loc_name = army.province_location.name
				
			var distances = {}
			for allied_prov in all_provinces:
				if allied_prov.get_parent() == self:
					var start: int = routes.get_closest_point(army.global_position)
					var target: int = routes.get_closest_point(allied_prov.to_global(allied_prov.get_city_position()))
					var path_points = routes.get_id_path(start, target, false)
					var dist = 0.0
					if len(path_points) > 0:
						for j in range(len(path_points) - 1):
							var p1 = routes.get_point_position(path_points[j])
							var p2 = routes.get_point_position(path_points[j+1])
							dist += p1.distance_to(p2)
					else:
						dist = 999999.0 # Unreachable
					distances[allied_prov.name] = dist

			state["data"]["my_armies"].append({
				"id": army.army_id,
				"x": army.global_position.x,
				"y": army.global_position.y,
				"life": army.life_points,
				"attack_value": (army.soldier_number * army.ATTACK_PER_UNIT) * army.life_points / (army.soldier_number * army.LIFE_PER_UNIT) if army.soldier_number > 0 else 0.0,
				"location": loc_name,
				"distances": distances
			})
			
		# fill allied and enemy provinces
		for prov in all_provinces:
			if prov.get_parent() == self:
				state["data"]["allied_provinces"].append({
					"id": prov.name,
					"morale": prov.province_morale,
					"x": prov.global_position.x,
					"y": prov.global_position.y
				})
			elif prov.get_parent() in player_in_war:
				var has_army = false
				var defense_value = 0.0
				for army in prov.get_parent().armies:
					if not is_instance_valid(army): continue
					if army.province_location == prov:
						has_army = true
						defense_value += (army.soldier_number * army.DEFENSE_PER_UNIT) * army.life_points / (army.soldier_number * army.LIFE_PER_UNIT)
				var bordering_allies = []
				for neighbor in prov.neighbors:
					if neighbor.get_parent() == self:
						bordering_allies.append(neighbor.name)
				state["data"]["enemy_provinces"].append({
					"id": prov.name,
					"owner": prov.get_parent().name,
					"has_army": has_army,
					"defense_value": defense_value,
					"x": prov.global_position.x,
					"y": prov.global_position.y,
					"bordering_allies": bordering_allies
				})
		
		# fill nation_strengths
		var players = get_tree().get_nodes_in_group("players")
		for p in players:
			if p == self: continue
			var strength = 0
			for a in p.armies:
				if not is_instance_valid(a): continue
				strength += a.soldier_number
			state["data"]["nation_strengths"][p.name] = strength
			
		# fill neighbor_nations
		var neighbor_nations_dict = {}
		for prov in get_children():
			if prov is Province:
				for neighbor_prov in prov.neighbors:
					if neighbor_prov is Province and neighbor_prov.get_parent() != self:
						var neighbor_agent = neighbor_prov.get_parent()
						if neighbor_agent is Agent:
							neighbor_nations_dict[neighbor_agent] = true

		var neighbors_data = {}
		for neighbor_agent in neighbor_nations_dict:
			var res_production = {}
			for n_prov in neighbor_agent.get_children():
				if n_prov is Province:
					var res_name = Enums.Resources.keys()[n_prov.province_material].to_lower()
					var count = n_prov._get_daily_resource_count()
					if res_production.has(res_name):
						res_production[res_name] += count
					else:
						res_production[res_name] = count
			neighbors_data[neighbor_agent.name] = res_production
			
		state["data"]["neighbor_nations"] = neighbors_data
			
		ws.send_text(JSON.stringify(state))
		
func _on_global_timer_timeout() -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	var armies_to_report = {}
	for army in known_armies:
		armies_to_report[army] = true
	for army in perfectly_known_armies:
		armies_to_report[army] = true
		
	for army in armies_to_report:
		if not is_instance_valid(army): continue
		if army.travelling and army.path != null and len(army.path) > army.nodes_travelled + 1:
			var point_path_next: Path2D = army.player.graph_to_path[army.path[army.nodes_travelled + 1]][0]
			var path_point_next: int = army.player.graph_to_path[army.path[army.nodes_travelled + 1]][1]
			var next_pos = point_path_next.to_global(point_path_next.curve.get_point_position(path_point_next))
			
			var msg: Dictionary = {
				"type": "sight",
				"sender": self.name,
				"receiver": "vesna",
				"data": {
					"type": "foreign_army_moving",
					"id": army.army_id,
					"owner": army.player.name,
					"x": army.global_position.x,
					"y": army.global_position.y,
					"next_x": next_pos.x,
					"next_y": next_pos.y
				}
			}
			ws.send_text(JSON.stringify(msg))

func _on_global_day_timer_timeout() -> void:
	pass
	
func _on_army_destroyed(army: Army) -> void:
	perfectly_known_armies.erase(army)
	known_armies.erase(army)
	if army.movement_updated.is_connected(_on_watched_army_movement.bind(army)):
		army.movement_updated.disconnect(_on_watched_army_movement.bind(army))
	
func _get_nation_center() -> Vector2:
	var total_area: float = 0.0
	var weighted_centroid: Vector2 = Vector2.ZERO
	var provinces: Array[Node] = get_children()
	
	for province in provinces:
		if province is not Province: continue
		var poly: PackedVector2Array = (province as Province).collision_polygon.polygon
		var count: int = poly.size()
		var area: float = 0.0
		var centroid: Vector2 = Vector2.ZERO
		
		for i in range(count):
			var p1: Vector2 = province.to_global(poly[i])
			var p2: Vector2 = province.to_global(poly[(i + 1) % count])
			
			var cross_product: float = (p1.x * p2.y) - (p2.x * p1.y)
			area += cross_product
			centroid.x += (p1.x + p2.x) * cross_product
			centroid.y += (p1.y + p2.y) * cross_product
			
		area *= 0.5
		if area != 0.0:
			centroid /= (6.0 * area)
			
		var abs_area: float = abs(area)
		weighted_centroid += centroid * abs_area
		total_area += abs_area
		
	if total_area == 0.0:
		return Vector2.ZERO
		
	return weighted_centroid / total_area
	
func _get_nation_bounds() -> Rect2:
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var has_points = false
	
	for province in get_children():
		if province is not Province: continue
		
		var poly: PackedVector2Array = province.collision_polygon.polygon
		for point in poly:
			var global_point = province.to_global(point)
			min_pos.x = min(min_pos.x, global_point.x)
			min_pos.y = min(min_pos.y, global_point.y)
			max_pos.x = max(max_pos.x, global_point.x)
			max_pos.y = max(max_pos.y, global_point.y)
			has_points = true
			
	if not has_points:
		return Rect2(global_position, Vector2.ZERO)
		
	return Rect2(min_pos, max_pos - min_pos)

func update_name_position() -> void:
	var new_position = _get_nation_center()
	var nation_rect = _get_nation_bounds()
	
	if new_position == Vector2.ZERO or nation_rect.size == Vector2.ZERO:
		if is_instance_valid(player_name_control):
			player_name_control.queue_free()
		return
		
	var margin_factor = 0.4
	var max_size = nation_rect.size * margin_factor
	
	player_name_label.scale = Vector2.ONE
	
	var scale_factor = 1.0
	var scale_x = max_size.x / player_name_label.size.x
	var scale_y = max_size.y / player_name_label.size.y
	scale_factor = min(scale_x, scale_y)
	player_name_label.scale = Vector2(scale_factor, scale_factor)
	
	var scaled_size = player_name_label.size * scale_factor
	var label_offset = scaled_size / 2.0
	player_name_label.global_position = Vector2(new_position.x - label_offset.x, new_position.y + label_offset.y)
	
	player_name_control.queue_redraw()
	
func add_known_army(army: Army) -> void:
	if army in perfectly_known_armies: return
	
	if not army.movement_updated.is_connected(_on_watched_army_movement.bind(army)):
		army.movement_updated.connect(_on_watched_army_movement.bind(army))
		if army.travelling:
			var next_pos = army._get_next_path_position()
			if next_pos != Vector2.ZERO:
				_on_watched_army_movement(army, next_pos)
	
	if not army.army_destroyed.is_connected(_on_army_destroyed):
		army.army_destroyed.connect(_on_army_destroyed)
		
	known_armies.get_or_add(army, 0)
	known_armies[army] += 1
	army.emit_signal("became_known", army, self)
	
func declare_war(player: Agent) -> void:
	if player in player_in_war: return

	player_in_war.append(player)
	player.declare_war(self)
	emit_signal("war_declared", self, player)
	
func request_peace(player: Agent) -> void:
	emit_signal("peace_requested", self, player)
	
func request_alliance(player: Agent) -> void:
	emit_signal("alliance_requested", self, player)
	
func remove_know_army_reference(army: Army):
	if army not in known_armies: return
	known_armies[army] -= 1
	if known_armies[army] == 0:
		known_armies.erase(army)
		if army not in perfectly_known_armies:
			if army.movement_updated.is_connected(_on_watched_army_movement.bind(army)):
				army.movement_updated.disconnect(_on_watched_army_movement.bind(army))
			if army.army_destroyed.is_connected(_on_army_destroyed):
				army.army_destroyed.disconnect(_on_army_destroyed)
		army.emit_signal("became_unknown", army, self)
	
func add_perfectly_known_army(army: Army):
	if army in known_armies:
		known_armies.erase(army)
		
	if not army.movement_updated.is_connected(_on_watched_army_movement.bind(army)):
		army.movement_updated.connect(_on_watched_army_movement.bind(army))
		if army.travelling:
			var next_pos = army._get_next_path_position()
			if next_pos != Vector2.ZERO:
				_on_watched_army_movement(army, next_pos)
				
	if not army.army_destroyed.is_connected(_on_army_destroyed):
		army.army_destroyed.connect(_on_army_destroyed)
		
	perfectly_known_armies.get_or_add(army, 0)
	perfectly_known_armies[army] += 1
	army.emit_signal("became_perfectly_known", army, self)
	
func remove_perfectly_know_army_reference(army: Army):
	if army not in perfectly_known_armies: return
	perfectly_known_armies[army] -= 1
	if perfectly_known_armies[army] == 0:
		perfectly_known_armies.erase(army)
		if army not in known_armies:
			if army.movement_updated.is_connected(_on_watched_army_movement.bind(army)):
				army.movement_updated.disconnect(_on_watched_army_movement.bind(army))
			if army.army_destroyed.is_connected(_on_army_destroyed):
				army.army_destroyed.disconnect(_on_army_destroyed)
		army.emit_signal("became_unknown", army, self)
		
func get_province_owner(province: Province) -> bool:
	if province == null: return false
	return province.get_parent() == self
	
func add_resource(resource: Enums.Resources, qnt: int):
	if resources[resource] + qnt >= 0:
		resources[resource] += qnt
	else:
		resources[resource] = 0
