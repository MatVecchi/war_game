extends Node

class_name GameController

var state: GameState

func _ready() -> void:
	var polys = get_tree().get_nodes_in_group("provinces")
	var agents = get_tree().get_nodes_in_group("players")
	var nodes: Array[Path2D]
	var bg = get_tree().get_nodes_in_group("background")[0]
	bg.clear_province.connect(clear_selection)
	
	for el in get_children():
		if el is Path2D:
			nodes.append(el)
	
			
	
	state = GameState.new(polys, agents, nodes)
	#state.conquer_province(get_node("Libia Occidentale/Tripoli"), get_node("Libia Orientale"))

func _process(_delta: float) -> void:
	pass
	
func clear_selection():
	var p = state.get_province_selected()
	if p != null:
		p.toggle_selection()
		state.set_province_selected(null)

class GameState:
	var provinces
	var province_selected
	var players
	var all_nodes
	func _init(polys: Array[Node], agents: Array[Node], nodes: Array[Path2D]) -> void:
		provinces = polys
		players = agents
		all_nodes = nodes
		for el in provinces:
			el.province_clicked.connect(self.select_province)
			
	func get_province(id: int):
		for el in self.provinces:
			if el.province_id == id:
				return el
		return null
	
	func get_province_selected():
		return province_selected
	
	func set_province_selected(new_province):
		province_selected = new_province
		
	func conquer_province(province: Province, agent: Agent):
		province.reparent(agent)
		province.fill.modulate = agent.color
		province.province_morale = 20
		
	func select_province(id: int):
		if get_province_selected() != null && get_province_selected().province_id != id:
			get_province_selected().toggle_selection()
		var el = get_province(id)
		if el.toggle_selection():
			set_province_selected(el)
		else:
			set_province_selected(null)
			
	func add_army_to_province(province: Province, army: Army):
		var agent = province.get_parent()
		if army == null:
			var army_scene = preload("res://scenes/army.tscn")
			army = army_scene.instantiate()
			army.army_id = 0
			army.soldier_number = 10
			agent.armies.append(army)
			agent.add_child(army)
		army.position = province.get_node("Node2D").global_position
		
	func find_path(start: Path2D, goal: Path2D) -> Array:
		var dist = {}
		var prev = {}
		var queue = []
	
		for node in all_nodes:
			dist[node] = INF
			prev[node] = null
			queue.append(node)

		dist[start] = 0

		while queue.size() > 0:
			queue.sort_custom(func(a, b): return dist[a] < dist[b])
			var u = queue.pop_front()
	
			if u == goal:
				break

			for v in u.neighbors:
				var alt = dist[u] + u.position.distance_to(v.position)
				if alt < dist[v]:
					dist[v] = alt
					prev[v] = u

		var path = []
		var u = goal
		while u != null:
			path.push_front(u)
			u = prev[u]

		return path
