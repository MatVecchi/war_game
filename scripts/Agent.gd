extends Node

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

@export var player_name: String
@export var color: Color
@export var armies: Array[Army]

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
		if provinces is not Province: continue
		
		if el not in get_children():
			for path in el.get_province_paths():
				var graph_node_key = 0
				if path[1] > 0:
					graph_node_key = 1
				routes.set_point_weight_scale(graph_to_path[path[0]][graph_node_key], 1.5)
	
	var game: GameController = get_tree().current_scene
	var children = get_children()
	var army_scene := preload("res://scenes/army.tscn")
	for i in range(len(children)):
		if children[i] is not Province: continue	
			
		var army: Army = army_scene.instantiate()
		army.army_id = len(armies)
		army.soldier_number = 10
		army.life_points = army.LIFE_PER_UNIT * 10 * (float(children[i].province_morale)/100)
		army.player = self
		
		armies.append(army)
		for el in paths:
			if el is Path2D:
				var count = el.curve.point_count
				for j in range(count):
					if el.curve.get_point_position(j) == children[i].get_city_position():
						el.add_child(army)
						break
		game.add_army_to_province(children[i], army)
	
	if len(armies) > 0 and player_name == "Libia Orientale":
		armies[0].order(game.provinces[2])
		declare_war(get_tree().current_scene.get_node("Libia Occidentale"))
		pass
	
	hour_timer = get_node("/root/Game/GlobalHourTimer")
	hour_timer.timeout.connect(_on_global_hour_timer_timeout)
	day_timer = get_node("/root/Game/GlobalDayTimer")
	day_timer.timeout.connect(_on_global_day_timer_timeout)
	
	player_name_label.text = player_name
	player_name_control.queue_redraw()
	
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
		for i in el.ARMY_DAILY_COST_PER_UNIT:
			total_army_daily_cost[i] += el.ARMY_DAILY_COST_PER_UNIT[i]*el.soldier_number
	
	for i in total_army_daily_cost:
		add_resource(i, -ceil(float(total_army_daily_cost[i])/24))

func _on_global_day_timer_timeout() -> void:
	pass
	
func _on_army_destroyed(army: Army):
	perfectly_known_armies.erase(army)
	known_armies.erase(army)
	
func add_known_army(army: Army):
	if army in perfectly_known_armies: return
	known_armies.get_or_add(army, 0)
	known_armies[army] += 1
	army.army_destroyed.connect(_on_army_destroyed)
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
		army.emit_signal("became_unknown", army, self)
	
func add_perfectly_known_army(army: Army):
	if army in known_armies:
		known_armies.erase(army)
	perfectly_known_armies.get_or_add(army, 0)
	perfectly_known_armies[army] += 1
	army.army_destroyed.connect(_on_army_destroyed)
	army.emit_signal("became_perfectly_known", army, self)
	
func remove_perfectly_know_army_reference(army: Army):
	if army not in perfectly_known_armies: return
	perfectly_known_armies[army] -= 1
	if perfectly_known_armies[army] == 0:
		perfectly_known_armies.erase(army)
		army.emit_signal("became_unknown", army, self)
		
func get_province_owner(province: Province) -> bool:
	if province == null: return false
	return province.get_parent() == self
	
func add_resource(resource: Enums.Resources, qnt: int):
	resources[resource] += qnt
