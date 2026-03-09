extends Node

class_name Agent

var routes: AStar2D = AStar2D.new()
var graph_to_path = []
var path_to_graph = {}
var resources: Dictionary[Enums.Resources, int] = {
	Enums.Resources.WOOD: 0,
	Enums.Resources.IRON: 0
}

@export var player_name: String
@export var color: Color
@export var armies: Array[Army]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("players")
	await get_tree().process_frame
	var paths = get_tree().get_nodes_in_group("paths")
	var c := 0
	for el in paths:
		if el is not Path2D: continue
		routes.add_point(c, el.curve.get_point_position(0), 1.0)
		routes.add_point(c + 1, el.curve.get_point_position(el.curve.point_count - 1), 1.0)
		routes.connect_points(c, c + 1, true)
		graph_to_path.insert(c, [el, 0])
		graph_to_path.insert(c + 1, [el, el.curve.point_count - 1])
		path_to_graph[el] = [c, c + 1]
		c += 2
		
	for el in paths:
		if el is not Path2D: continue
		var connected_points_start = el.get_paths_points(0)
		var connected_points_end = el.get_paths_points(el.curve.point_count - 1)
		
		for s in connected_points_start:
			var i
			if s[1] == 0:
				i = 0
			else:
				i = 1
			routes.connect_points(path_to_graph[el][0], path_to_graph[s[0]][i], true)
		
		for s in connected_points_end:
			var i
			if s[1] == 0:
				i = 0
			else:
				i = 1
			routes.connect_points(path_to_graph[el][1], path_to_graph[s[0]][i], true)
	
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
	var childrens = get_children()
	var army_scene := preload("res://scenes/army.tscn")
	for i in range(len(childrens)):		
		var army: Army = army_scene.instantiate()
		army.army_id = i
		army.soldier_number = 10
		army.life_points = army.LIFE_PER_UNIT * 10 * (float(childrens[i].province_morale)/100)
		army.player = self
		
		armies.append(army)
		if childrens[i] is Province:
			for el in paths:
				if el is Path2D:
					var count = el.curve.point_count
					for j in range(count):
						if el.curve.get_point_position(j) == childrens[i].get_city_position():
							el.add_child(army)
			game.state.add_army_to_province(childrens[i], army)
	
	if len(armies) > 0 and player_name == "Libia Orientale":
		for x in armies:
			#print(x.position)
			pass
		armies[0].order(game.state.provinces[2])
		
func get_province_owner(province: Province) -> bool:
	if province == null: return false
	return province.get_parent() == self

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
