extends Node

class_name GameController

var state: GameState
@export var time_multiplier: float = 1.0

func _ready() -> void:
	Engine.time_scale = time_multiplier
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
		province.fill.color = agent.color
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
			army.life_points = army.LIFE_PER_UNIT * 10 * (float(province.province_morale)/100)
			agent.armies.append(army)
			agent.add_child(army)
		army.position = province.get_node("Node2D").global_position

func _on_global_timer_timeout() -> void:
	pass
