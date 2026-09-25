extends Node2D

class_name Agent

signal war_declared(from: Agent, to: Agent)
signal peace_requested
signal alliance_requested
signal peace_established(from: Agent, to: Agent)
signal alliance_established(from: Agent, to: Agent)

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
var points: int:
	get:
		var total_points: float = 0.0
		for child in get_children():
			if child is Province:
				var m = float(child.province_morale)
				if m >= 20.0:
					total_points += min((m - 20.0) / 8.0, 10.0)
		return int(round(total_points))
var perfectly_known_armies: Dictionary[Army, int] = {}
var known_armies: Dictionary[Army, int] = {}
var _last_watched_army_destinations: Dictionary[Army, Vector2] = {}
var player_in_war: Array[Agent] = []
var player_in_alliance: Array[Agent] = []
var armies: Array[Army] = []
var next_army_id: int = 0
var tcp_server := TCPServer.new()
var ws := WebSocketPeer.new()
var end_communication: bool = true
var _last_ws_state = WebSocketPeer.STATE_CLOSED
var _message_queue: Array[Dictionary] = []
var _cached_province_distances: Dictionary = {}

const MAX_ALLIANCES: int = 1

@export var PORT : int

@onready var player_name_control: Control = $Control
@onready var player_name_label: Label = $Control/PlayerName


func _ready() -> void:
	ws.outbound_buffer_size = 2097152
	ws.inbound_buffer_size = 2097152
	ws.max_queued_packets = 4096
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
	
	hour_timer = get_node("/root/Game/GlobalHourTimer")
	hour_timer.timeout.connect(_on_global_hour_timer_timeout)
	day_timer = get_node("/root/Game/GlobalDayTimer")
	day_timer.timeout.connect(_on_global_day_timer_timeout)
	game.match_over.connect(_on_match_over)
	
	player_name_label.text = name
	update_name_position()
	
	if tcp_server.listen( PORT ) != OK:
		push_error( "Unable to start the server" )
		set_process( false )
		
func _process(_delta: float) -> void:
	while tcp_server.is_connection_available():
		var conn : StreamPeerTCP = tcp_server.take_connection()
		assert( conn != null )
		ws.outbound_buffer_size = 2097152
		ws.inbound_buffer_size = 2097152
		ws.max_queued_packets = 4096
		ws.accept_stream( conn )
		
	ws.poll()
	var current_state = ws.get_ready_state()
	if current_state == WebSocketPeer.STATE_OPEN:
		if _last_ws_state != WebSocketPeer.STATE_OPEN:
			_flush_message_queue()
			send_initial_state()
		while ws.get_available_packet_count():
			var msg : String = ws.get_packet().get_string_from_ascii()
			var intention : Dictionary = JSON.parse_string( msg )
			manage( intention )
	_last_ws_state = current_state
			
func manage(message: Dictionary) -> void:
	var sender : String = message['sender']
	var receiver : String = message['receiver']
	var type : String = message[ 'type' ]
	var data : Dictionary = message[ 'data' ]
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
		elif action_type == "request_peace":
			var target_name = data.get("target")
			var players = get_tree().get_nodes_in_group("players")
			for p in players:
				if p.name == target_name:
					request_peace(p)
					break
		elif action_type == "accept_peace":
			var target_name = data.get("target")
			var players = get_tree().get_nodes_in_group("players")
			for p in players:
				if p.name == target_name:
					var game: GameController = get_tree().current_scene
					if game:
						game.register_peace_vote(self, p)
					else:
						make_peace(p)
					break
		elif action_type == "decline_peace":
			var target_name = data.get("target")
			var players = get_tree().get_nodes_in_group("players")
			for p in players:
				if p.name == target_name:
					var game: GameController = get_tree().current_scene
					if game:
						game.register_peace_decline(self, p)
					else:
						decline_peace(p)
					break
		elif action_type == "request_alliance":
			var target_name = data.get("target")
			var players = get_tree().get_nodes_in_group("players")
			for p in players:
				if p.name == target_name:
					request_alliance(p)
					break
		elif action_type == "accept_alliance":
			var target_name = data.get("target")
			var players = get_tree().get_nodes_in_group("players")
			for p in players:
				if p.name == target_name:
					make_alliance(p)
					break
		elif action_type == "decline_alliance":
			var target_name = data.get("target")
			var players = get_tree().get_nodes_in_group("players")
			for p in players:
				if p.name == target_name:
					decline_alliance(p)
					break
		elif action_type == "split_army":
			var army_id = data.get("army_id")
			var soldiers = data.get("soldiers")
			var target_prov_name = data.get("target_province")
			var army_to_split = null
			for army in armies:
				if army.army_id == army_id:
					army_to_split = army
					break
			if army_to_split != null and (soldiers is int or soldiers is float):
				var new_army = army_to_split.split(int(soldiers))
				if new_army != null and target_prov_name != null:
					var all_provinces = get_tree().get_nodes_in_group("provinces")
					for prov in all_provinces:
						if prov.name == target_prov_name:
							new_army.order(prov)
							break
	
func send_vesna_message(msg: Dictionary) -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(msg))
	else:
		_message_queue.append(msg)

func _flush_message_queue() -> void:
	while not _message_queue.is_empty():
		var msg = _message_queue.pop_front()
		ws.send_text(JSON.stringify(msg))

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
		
func dispatch_my_army_update(army: Army) -> void:
	if not is_instance_valid(army): return
	
	var loc_name = ""
	if army.province_location != null and army.province_location is Province:
		loc_name = army.province_location.name

	var attack_value = (army.soldier_number * army.ATTACK_PER_UNIT) * army.life_points / (army.soldier_number * army.LIFE_PER_UNIT) if army.soldier_number > 0 else 0.0

	var msg: Dictionary = {
		"type": "sight",
		"sender": "body",
		"receiver": self.name,
		"data": {
			"type": "my_army_update",
			"id": army.army_id,
			"x": army.global_position.x,
			"y": army.global_position.y,
			"life": army.life_points,
			"attack_value": attack_value,
			"location": loc_name,
			"travelling": army.travelling,
			"target_province": army.target_province.name if army.target_province != null else ""
		}
	}
	send_vesna_message(msg)

func _on_watched_army_movement(next_pos: Vector2, army: Army) -> void:
	if not is_instance_valid(army): return
	if army.player in player_in_alliance: return
	
	if not _last_watched_army_destinations.has(army) or _last_watched_army_destinations[army] != next_pos:
		_last_watched_army_destinations[army] = next_pos
		
		var heading_province_name = ""
		if next_pos != Vector2.ZERO:
			for prov in get_children():
				if prov is Province:
					var local_pos = prov.to_local(next_pos)
					if Geometry2D.is_point_in_polygon(local_pos, prov.collision_polygon.polygon):
						heading_province_name = prov.name
						break
		
		var attack_value = (army.soldier_number * army.ATTACK_PER_UNIT) * army.life_points / (army.soldier_number * army.LIFE_PER_UNIT) if army.soldier_number > 0 else 0.0
		
		var msg: Dictionary = {
			"type": "sight",
			"sender": "body",
			"receiver": self.name,
			"data": {
				"type": "foreign_army_moving",
				"id": army.army_id,
				"owner": army.player.name,
				"x": army.global_position.x,
				"y": army.global_position.y,
				"next_x": next_pos.x,
				"next_y": next_pos.y,
				"target_province": heading_province_name,
				"attack_value": attack_value
			}
		}
		send_vesna_message(msg)

func _calculate_nation_strengths() -> Dictionary:
	var strengths = {}
	var players = get_tree().get_nodes_in_group("players")
	var global_soldiers = 0
	var player_soldiers = {}
	
	for p in players:
		if p is not Agent: continue
		var strength = 0
		for a in p.armies:
			if not is_instance_valid(a): continue
			strength += a.soldier_number
		player_soldiers[p.name] = strength
		global_soldiers += strength
		
	for p in players:
		if p is not Agent: continue
		var power = 0.0
		if global_soldiers > 0:
			power = (float(player_soldiers[p.name]) / global_soldiers) * 100.0
		strengths[p.name] = int(round(power))
	return strengths

func _on_global_day_timer_timeout() -> void:
	var game: GameController = get_tree().current_scene
	var msg: Dictionary = {
		"type": "sight",
		"sender": "body",
		"receiver": self.name,
		"data": {
			"type": "day_update",
			"day": game.day_cycle,
			"nation_strengths": _calculate_nation_strengths()
		}
	}
	send_vesna_message(msg)

func _on_match_over() -> void:
	var msg: Dictionary = {
		"type": "sight",
		"sender": "body",
		"receiver": self.name,
		"data": {
			"type": "match_over"
		}
	}
	send_vesna_message(msg)

func _on_army_destroyed(army: Army) -> void:
	var was_foreign = (army.player != self and army.player not in player_in_alliance)
	perfectly_known_armies.erase(army)
	known_armies.erase(army)
	_last_watched_army_destinations.erase(army)
	if army.movement_updated.is_connected(_on_watched_army_movement.bind(army)):
		army.movement_updated.disconnect(_on_watched_army_movement.bind(army))
		
	if was_foreign:
		var msg: Dictionary = {
			"type": "sight",
			"sender": "body",
			"receiver": self.name,
			"data": {
				"type": "foreign_army_destroyed",
				"id": army.army_id,
				"owner": army.player.name
			}
		}
		send_vesna_message(msg)
	
func _get_nation_orientation() -> float:
	var vertices: Array[Vector2] = []
	for province in get_children():
		if province is not Province: continue
		var poly: PackedVector2Array = (province as Province).collision_polygon.polygon
		for pt in poly:
			vertices.append(province.to_global(pt))
			
	var N = vertices.size()
	if N < 3:
		return 0.0
		
	var mean = Vector2.ZERO
	for v in vertices:
		mean += v
	mean /= float(N)
	
	var cov_xx = 0.0
	var cov_yy = 0.0
	var cov_xy = 0.0
	
	for v in vertices:
		var dx = v.x - mean.x
		var dy = v.y - mean.y
		cov_xx += dx * dx
		cov_yy += dy * dy
		cov_xy += dx * dy
		
	cov_xx /= float(N)
	cov_yy /= float(N)
	cov_xy /= float(N)
	
	var theta = 0.5 * atan2(2.0 * cov_xy, cov_xx - cov_yy)
	return theta

func _is_point_in_nation(point: Vector2) -> bool:
	for province in get_children():
		if province is not Province: continue
		var local_pos = province.to_local(point)
		if Geometry2D.is_point_in_polygon(local_pos, province.collision_polygon.polygon):
			return true
	return false

func _get_label_global_corners(center: Vector2, scale_fac: float) -> Array[Vector2]:
	var size = player_name_label.size
	var scaled_size = size * scale_fac
	var label_offset = scaled_size / 2.0
	var top_left = Vector2(center.x - label_offset.x, center.y + label_offset.y)
	var rotation = player_name_control.rotation
	
	var local_points = [
		Vector2.ZERO, # Top-Left
		Vector2(size.x / 2.0, 0), # Top-Mid
		Vector2(size.x, 0), # Top-Right
		Vector2(size.x, size.y / 2.0), # Right-Mid
		size, # Bottom-Right
		Vector2(size.x / 2.0, size.y), # Bottom-Mid
		Vector2(0, size.y), # Bottom-Left
		Vector2(0, size.y / 2.0) # Left-Mid
	]
	
	var global_corners: Array[Vector2] = []
	for lp in local_points:
		var rotated_offset = (lp * scale_fac).rotated(rotation)
		global_corners.append(top_left + rotated_offset)
		
	return global_corners

func _get_nation_center() -> Vector2:
	var total_area: float = 0.0
	var weighted_centroid: Vector2 = Vector2.ZERO
	var provinces: Array[Node] = get_children()
	
	var province_centroids = {}
	
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
		else:
			centroid = province.to_global(province.get_city_position())
			
		var abs_area: float = abs(area)
		weighted_centroid += centroid * abs_area
		total_area += abs_area
		province_centroids[province] = centroid
		
	if total_area == 0.0:
		return Vector2.ZERO
		
	var nation_centroid = weighted_centroid / total_area
	
	if _is_point_in_nation(nation_centroid):
		return nation_centroid

	var closest_province: Province = null
	var min_distance: float = INF
	
	for province in province_centroids:
		var dist = nation_centroid.distance_to(province_centroids[province])
		if dist < min_distance:
			min_distance = dist
			closest_province = province
			
	if closest_province != null:
		return province_centroids[closest_province]
		
	return nation_centroid
	
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
	if not is_instance_valid(player_name_control) or not is_instance_valid(player_name_label):
		return
		
	var new_position = _get_nation_center()
	var nation_rect = _get_nation_bounds()
	
	if new_position == Vector2.ZERO or nation_rect.size == Vector2.ZERO:
		player_name_control.hide()
		return
		
	player_name_control.show()
	
	var theta = _get_nation_orientation()
	player_name_control.rotation = clamp(theta, -1.2, 1.2)
	
	var margin_factor = 0.4
	var max_size = nation_rect.size * margin_factor
	
	player_name_label.scale = Vector2.ONE
	
	var scale_factor = 1.0
	var scale_x = max_size.x / player_name_label.size.x
	var scale_y = max_size.y / player_name_label.size.y
	scale_factor = min(scale_x, scale_y)
	
	var max_iterations = 10
	var fits = false
	var min_scale = min(0.15, scale_factor)
	
	while not fits and max_iterations > 0 and scale_factor > min_scale:
		var corners = _get_label_global_corners(new_position, scale_factor)
		var all_inside = true
		for p in corners:
			if not _is_point_in_nation(p):
				all_inside = false
				break
		if all_inside:
			fits = true
		else:
			scale_factor *= 0.85
			max_iterations -= 1
			
	if scale_factor < min_scale:
		scale_factor = min_scale
		
	player_name_label.scale = Vector2(scale_factor, scale_factor)
	
	var scaled_size = player_name_label.size * scale_factor
	var label_offset = scaled_size / 2.0
	player_name_label.global_position = Vector2(new_position.x - label_offset.x, new_position.y + label_offset.y)
	
	player_name_control.queue_redraw()
	
func declare_war(player: Agent) -> void:
	if player in player_in_war: return
	if player in player_in_alliance: return

	player_in_war.append(player)
	
	if player in player_in_alliance:
		player_in_alliance.erase(player)
		player.player_in_alliance.erase(self)
		for p in get_tree().get_nodes_in_group("players"):
			if p is Agent:
				var break_msg: Dictionary = {
					"type": "sight",
					"sender": "body",
					"receiver": p.name,
					"data": {
						"type": "alliance_broken",
						"nation1": self.name,
						"nation2": player.name
					}
				}
				p.send_vesna_message(break_msg)
		dispatch_neighbor_nations_update()
		player.dispatch_neighbor_nations_update()
		
	# Implicitly declare war on target's allies
	var target_allies = []
	for ally in player.player_in_alliance:
		if ally != self and not (ally in player_in_war):
			target_allies.append(ally)

	player.declare_war(self)
	emit_signal("war_declared", self, player)
	
	var msg: Dictionary = {
		"type": "sight",
		"sender": "body",
		"receiver": self.name,
		"data": {
			"type": "war_declared",
			"nation": player.name
		}
	}
	send_vesna_message(msg)
	
	for ally in target_allies:
		declare_war(ally)
	
func request_peace(player: Agent) -> void:
	var game: GameController = get_tree().current_scene
	var target_coalition: Array[Agent] = game.get_war_coalition(player, self) if game else [player]
	if game:
		game.register_peace_request(self, player)
	emit_signal("peace_requested", self, player)
	for target in target_coalition:
		var msg: Dictionary = {
			"type": "sight",
			"sender": "body",
			"receiver": target.name,
			"data": {
				"type": "peace_request_received",
				"sender": self.name
			}
		}
		target.send_vesna_message(msg)

func decline_peace(player: Agent) -> void:
	var msg: Dictionary = {
		"type": "sight",
		"sender": "body",
		"receiver": player.name,
		"data": {
			"type": "peace_request_declined",
			"sender": self.name
		}
	}
	player.send_vesna_message(msg)

func make_peace(player: Agent) -> void:
	if player not in player_in_war: return

	player_in_war.erase(player)
	player.make_peace(self)

	emit_signal("peace_established", self, player)

	var msg: Dictionary = {
		"type": "sight",
		"sender": "body",
		"receiver": self.name,
		"data": {
			"type": "peace_established",
			"nation": player.name
		}
	}
	send_vesna_message(msg)

	# Retreat armies that are travelling to attack player's provinces
	for army in armies:
		if is_instance_valid(army) and army.travelling and army.target_province != null:
			if army.target_province.get_parent() == player:
				var nearest_ally = find_nearest_allied_province(army.global_position)
				if nearest_ally != null:
					army.order(nearest_ally)

func find_nearest_allied_province(from_position: Vector2) -> Province:
	var allied_provinces: Array[Province] = []
	for node in get_tree().get_nodes_in_group("provinces"):
		if node is Province and node.get_parent() == self:
			allied_provinces.append(node)
	
	var nearest_prov = null
	var min_dist = 999999.0
	for prov in allied_provinces:
		var dist = from_position.distance_to(prov.to_global(prov.get_city_position()))
		if dist < min_dist:
			min_dist = dist
			nearest_prov = prov
	return nearest_prov
	
func request_alliance(player: Agent) -> void:
	if len(player_in_alliance) >= MAX_ALLIANCES or len(player.player_in_alliance) >= MAX_ALLIANCES:
		var msg: Dictionary = {
			"type": "sight",
			"sender": "body",
			"receiver": self.name,
			"data": {
				"type": "alliance_request_declined",
				"sender": player.name
			}
		}
		send_vesna_message(msg)
		return
	emit_signal("alliance_requested", self, player)
	var msg: Dictionary = {
		"type": "sight",
		"sender": "body",
		"receiver": player.name,
		"data": {
			"type": "alliance_request_received",
			"sender": self.name
		}
	}
	player.send_vesna_message(msg)

func decline_alliance(player: Agent) -> void:
	var msg: Dictionary = {
		"type": "sight",
		"sender": "body",
		"receiver": player.name,
		"data": {
			"type": "alliance_request_declined",
			"sender": self.name
		}
	}
	player.send_vesna_message(msg)

func make_alliance(player: Agent, is_symmetric_call: bool = false) -> void:
	if player in player_in_alliance: return
	
	if not is_symmetric_call:
		if len(player_in_alliance) >= MAX_ALLIANCES or len(player.player_in_alliance) >= MAX_ALLIANCES:
			var msg: Dictionary = {
				"type": "sight",
				"sender": "body",
				"receiver": self.name,
				"data": {
					"type": "alliance_request_declined",
					"sender": player.name
				}
			}
			send_vesna_message(msg)
			return

	player_in_alliance.append(player)
	if not is_symmetric_call:
		player.make_alliance(self, true)
		emit_signal("alliance_established", self, player)
		for p in get_tree().get_nodes_in_group("players"):
			if p is Agent:
				var msg: Dictionary = {
					"type": "sight",
					"sender": "body",
					"receiver": p.name,
					"data": {
						"type": "alliance_established",
						"nation1": self.name,
						"nation2": player.name
					}
				}
				p.send_vesna_message(msg)
		dispatch_neighbor_nations_update()
		player.dispatch_neighbor_nations_update()

		var game: GameController = get_tree().current_scene
		if game != null:
			for prov in get_tree().get_nodes_in_group("provinces"):
				if prov is Province:
					game._send_province_update_to_all(prov)

func add_known_army(army: Army) -> void:
	if not army.movement_updated.is_connected(_on_watched_army_movement.bind(army)):
		army.movement_updated.connect(_on_watched_army_movement.bind(army))
		if army.travelling:
			var next_pos = army._get_next_path_position()
			if next_pos != Vector2.ZERO:
				_on_watched_army_movement(next_pos, army)
	
	if not army.army_destroyed.is_connected(_on_army_destroyed):
		army.army_destroyed.connect(_on_army_destroyed)
		
	var was_known = known_armies.has(army) and known_armies[army] > 0
	var is_perfectly_known = perfectly_known_armies.has(army) and perfectly_known_armies[army] > 0

	known_armies.get_or_add(army, 0)
	known_armies[army] += 1

	if not was_known and not is_perfectly_known:
		army.emit_signal("became_known", army, self)
	
func remove_know_army_reference(army: Army):
	if army not in known_armies: return
	known_armies[army] -= 1
	if known_armies[army] == 0:
		known_armies.erase(army)
		var is_perfectly_known = perfectly_known_armies.has(army) and perfectly_known_armies[army] > 0
		if not is_perfectly_known:
			_last_watched_army_destinations.erase(army)
			if army.movement_updated.is_connected(_on_watched_army_movement.bind(army)):
				army.movement_updated.disconnect(_on_watched_army_movement.bind(army))
			if army.army_destroyed.is_connected(_on_army_destroyed):
				army.army_destroyed.disconnect(_on_army_destroyed)
			army.emit_signal("became_unknown", army, self)
	
func add_perfectly_known_army(army: Army):
	if not army.movement_updated.is_connected(_on_watched_army_movement.bind(army)):
		army.movement_updated.connect(_on_watched_army_movement.bind(army))
		if army.travelling:
			var next_pos = army._get_next_path_position()
			if next_pos != Vector2.ZERO:
				_on_watched_army_movement(next_pos, army)
				
	if not army.army_destroyed.is_connected(_on_army_destroyed):
		army.army_destroyed.connect(_on_army_destroyed)
		
	var was_perfectly_known = perfectly_known_armies.has(army) and perfectly_known_armies[army] > 0

	perfectly_known_armies.get_or_add(army, 0)
	perfectly_known_armies[army] += 1

	if not was_perfectly_known:
		army.emit_signal("became_perfectly_known", army, self)
	
func remove_perfectly_know_army_reference(army: Army):
	if army not in perfectly_known_armies: return
	perfectly_known_armies[army] -= 1
	if perfectly_known_armies[army] == 0:
		perfectly_known_armies.erase(army)
		var is_known = known_armies.has(army) and known_armies[army] > 0
		if is_known:
			army.emit_signal("became_known", army, self)
		else:
			_last_watched_army_destinations.erase(army)
			if army.movement_updated.is_connected(_on_watched_army_movement.bind(army)):
				army.movement_updated.disconnect(_on_watched_army_movement.bind(army))
			if army.army_destroyed.is_connected(_on_army_destroyed):
				army.army_destroyed.disconnect(_on_army_destroyed)
			army.emit_signal("became_unknown", army, self)
		
func get_province_owner(province: Node) -> bool:
	if province is not Province: return false
	return province.get_parent() == self
	
func add_resource(resource: Enums.Resources, qnt: int):
	var old_qnt = resources[resource]
	if resources[resource] + qnt >= 0:
		resources[resource] += qnt
	else:
		resources[resource] = 0
		
	if resources[resource] != old_qnt:
		var res_name = Enums.Resources.keys()[resource].to_lower()
		var msg: Dictionary = {
			"type": "sight",
			"sender": "body",
			"receiver": self.name,
			"data": {
				"type": "resource_change",
				"resource": res_name,
				"amount": resources[resource]
			}
		}
		send_vesna_message(msg)

func dispatch_province_defense_update(province: Province) -> void:
	if not is_instance_valid(province): return
	var prov_owner = province.get_parent()
	if prov_owner == self: return
	
	var has_army = false
	var defense_value = 0.0
	var city_pos = province.to_global(province.get_city_position())
	for army in get_tree().get_nodes_in_group("armies"):
		if not is_instance_valid(army): continue
		if army.player != self and (army.player not in player_in_alliance):
			if army.province_location == province or (not army.travelling and army.global_position.distance_to(city_pos) < 20.0):
				has_army = true
				if army.soldier_number > 0:
					defense_value += (army.soldier_number * army.DEFENSE_PER_UNIT) * army.life_points / (army.soldier_number * army.LIFE_PER_UNIT)
					
	var msg: Dictionary = {
		"type": "sight",
		"sender": "body",
		"receiver": self.name,
		"data": {
			"type": "enemy_province_defense_update",
			"id": province.name,
			"has_army": has_army,
			"defense_value": defense_value
		}
	}
	send_vesna_message(msg)

func send_initial_state() -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	
	var all_provinces: Array[Province] = []
	for node in get_tree().get_nodes_in_group("provinces"):
		if node is Province:
			all_provinces.append(node)

	var allied_provinces_data = []
	var enemy_provinces_data = []
	
	for province in all_provinces:
		var prov_owner = province.get_parent()
		if prov_owner == self:
			allied_provinces_data.append({
				"id": province.name,
				"morale": province.province_morale,
				"x": province.to_global(province.get_city_position()).x,
				"y": province.to_global(province.get_city_position()).y,
				"is_capital": Enums.Buildings.CAPITAL in province.buildings,
				"is_double": province.double_material,
				"resource": Enums.Resources.keys()[province.province_material].to_lower()
			})
		else:
			var bordering_allies = []
			for neighbor in province.neighbors:
				if neighbor is Province:
					var np = neighbor.get_parent()
					if np is Agent and (np == self or np in player_in_alliance):
						bordering_allies.append(neighbor.name)
					
			var has_army = false
			var defense_value = 0.0
			var city_pos = province.to_global(province.get_city_position())
			for army in get_tree().get_nodes_in_group("armies"):
				if not is_instance_valid(army): continue
				if army.player is Agent and army.player != self and (army.player not in player_in_alliance):
					if army.province_location == province or (not army.travelling and army.global_position.distance_to(city_pos) < 20.0):
						has_army = true
						if army.soldier_number > 0:
							defense_value += (army.soldier_number * army.DEFENSE_PER_UNIT) * army.life_points / (army.soldier_number * army.LIFE_PER_UNIT)
			
			enemy_provinces_data.append({
				"id": province.name,
				"owner": prov_owner.name,
				"x": province.to_global(province.get_city_position()).x,
				"y": province.to_global(province.get_city_position()).y,
				"has_army": has_army,
				"defense_value": defense_value,
				"bordering_allies": bordering_allies,
				"is_capital": Enums.Buildings.CAPITAL in province.buildings,
				"is_double": province.double_material,
				"resource": Enums.Resources.keys()[province.province_material].to_lower()
			})

	var strengths = _calculate_nation_strengths()
	var neighbors_data = get_neighbor_nations_data()

	var game: GameController = get_tree().current_scene
	var game_rules_data = {
		"riot_threshold": Province.RIOT_THRESHOLD,
		"riot_breakpoint": Province.RIOT_BREAKPOINT,
		"riot_base_defense": Province.RIOT_BASE_DEFENSE,
		"riot_penalty_multiplier": Province.RIOT_PENALTY_MULTIPLIER,
		"life_per_unit": Army.LIFE_PER_UNIT,
		"attack_per_unit": Army.ATTACK_PER_UNIT,
		"defense_per_unit": Army.DEFENSE_PER_UNIT,
		"max_alliances": MAX_ALLIANCES,
		"conquered_morale": GameController.CONQUERED_PROVINCE_MORALE
	}
	var state: Dictionary = {
		"type": "sight",
		"sender": "body",
		"receiver": self.name,
		"data": {
			"type": "state_update",
			"allied_provinces": allied_provinces_data,
			"enemy_provinces": enemy_provinces_data,
			"province_distances": get_province_distances_data(),
			"nation_strengths": strengths,
			"neighbor_nations": neighbors_data,
			"day": game.day_cycle,
			"game_rules": game_rules_data
		}
	}
	send_vesna_message(state)

func get_province_distances_data() -> Dictionary:
	if not _cached_province_distances.is_empty():
		return _cached_province_distances

	var all_provinces: Array[Province] = []
	for node in get_tree().get_nodes_in_group("provinces"):
		if node is Province:
			all_provinces.append(node)

	for p1 in all_provinces:
		var start: int = routes.get_closest_point(p1.to_global(p1.get_city_position()))
		var p1_dict: Dictionary = {}
		for p2 in all_provinces:
			if p1 == p2:
				p1_dict[p2.name] = 0.0
			else:
				var target: int = routes.get_closest_point(p2.to_global(p2.get_city_position()))
				var path_points = routes.get_id_path(start, target, false)
				var dist: float = 0.0
				if len(path_points) > 0:
					for j in range(len(path_points) - 1):
						var pt1 = routes.get_point_position(path_points[j])
						var pt2 = routes.get_point_position(path_points[j+1])
						dist += pt1.distance_to(pt2)
				else:
					dist = 999999.0
				p1_dict[p2.name] = snappedf(dist, 0.1)
		_cached_province_distances[p1.name] = p1_dict

	return _cached_province_distances

func get_neighbor_nations_data() -> Dictionary:
	var neighbor_nations_dict = {}
	var alliance_provinces: Array[Province] = []
	for child in get_children():
		if child is Province:
			alliance_provinces.append(child)
	for ally in player_in_alliance:
		if is_instance_valid(ally) and ally is Agent:
			for child in ally.get_children():
				if child is Province:
					alliance_provinces.append(child)

	for prov in alliance_provinces:
		for neighbor_prov in prov.neighbors:
			if neighbor_prov is Province:
				var neighbor_agent = neighbor_prov.get_parent()
				if neighbor_agent is Agent and neighbor_agent != self and (neighbor_agent not in player_in_alliance):
					var has_prov = false
					for child in neighbor_agent.get_children():
						if child is Province:
							has_prov = true
							break
					if has_prov:
						neighbor_nations_dict[neighbor_agent] = true

	var neighbors_data = {}
	for neighbor_agent in neighbor_nations_dict:
		var res_production = {}
		for n_prov in neighbor_agent.get_children():
			if n_prov is Province:
				var res_name = Enums.Resources.keys()[n_prov.province_material].to_lower()
				var count = n_prov.get_daily_resource_count()
				if res_production.has(res_name):
					res_production[res_name] += count
				else:
					res_production[res_name] = count
		neighbors_data[neighbor_agent.name] = res_production
	return neighbors_data

func dispatch_neighbor_nations_update() -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	var msg: Dictionary = {
		"type": "sight",
		"sender": "body",
		"receiver": self.name,
		"data": {
			"type": "neighbor_nations_update",
			"neighbor_nations": get_neighbor_nations_data()
		}
	}
	send_vesna_message(msg)
