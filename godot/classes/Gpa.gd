extends Object

class_name GPA2D

var graph: Array[GPANode] = []

func add_point(id: int, position: Vector2, weight_scale: float) -> void:
	graph.insert(id, GPANode.new(id, position, weight_scale))
	
func connect_points(id: int, to_id: int, weight: float = 1.0, bidirectional: bool = true) -> void:
	graph[id].add_connection(to_id, weight * (graph[id].position - graph[to_id].position).length())
	if bidirectional:
		graph[to_id].add_connection(id, weight * (graph[id].position - graph[to_id].position).length())
	
func get_closest_point(to_position: Vector2, include_disabled: bool = false) -> int:
	var closest_point = null
	for el in graph:
		if closest_point == null and (not el.disabled or include_disabled):
			closest_point = el
			continue
		if el.position.distance_to(to_position) < closest_point.position.distance_to(to_position) and (not el.disabled or include_disabled):
			closest_point = el
	if closest_point == null:
		return -1
	return closest_point.id
	
func get_id_path(from_id: int, to_id: int, allow_partial_path: bool = false) -> PackedInt64Array:
	# Controlli di sicurezza iniziali
	if from_id < 0 or from_id >= graph.size() or to_id < 0 or to_id >= graph.size():
		return PackedInt64Array()
	if graph[from_id] == null or graph[to_id] == null:
		return PackedInt64Array()
	if graph[from_id].disabled:
		return PackedInt64Array()

	var open_set: Array[int] = [from_id]
	var came_from: Dictionary = {}
	
	var g_score: Dictionary = {}
	g_score[from_id] = 0.0
	
	var f_score: Dictionary = {}
	f_score[from_id] = _heuristic(from_id, to_id)
	
	# Variabili per tracciare il percorso parziale
	var closest_node: int = from_id
	var min_h_score: float = f_score[from_id]

	while open_set.size() > 0:
		# Trova il nodo in open_set con l'f_score più basso
		var current_index: int = 0
		var current: int = open_set[0]
		var lowest_f: float = f_score.get(current, INF)
		
		for i in range(1, open_set.size()):
			var node_id = open_set[i]
			var f = f_score.get(node_id, INF)
			if f < lowest_f:
				lowest_f = f
				current = node_id
				current_index = i
				
		# Se abbiamo raggiunto la destinazione, ricostruiamo il percorso
		if current == to_id:
			return _reconstruct_path(came_from, current)
			
		open_set.remove_at(current_index)
		var current_node: GPANode = graph[current]
		
		# Analizza i vicini
		for edge in current_node.connections:
			var neighbor_id: int = edge.get_to_id()
			var neighbor_node: GPANode = graph[neighbor_id]
			
			if neighbor_node.disabled:
				continue
				
			# Calcola il costo (g_score) verso questo vicino, moltiplicato per il suo weight_scale
			var tentative_g: float = g_score[current] + (edge.get_weight() * neighbor_node.weight_scale)
			
			# Se abbiamo trovato un percorso migliore per arrivare a neighbor_id
			if tentative_g < g_score.get(neighbor_id, INF):
				came_from[neighbor_id] = current
				g_score[neighbor_id] = tentative_g
				
				var h: float = _heuristic(neighbor_id, to_id)
				f_score[neighbor_id] = tentative_g + h
				
				# Aggiorna il nodo più vicino per il calcolo del partial path
				if h < min_h_score:
					min_h_score = h
					closest_node = neighbor_id
					
				if not open_set.has(neighbor_id):
					open_set.append(neighbor_id)
					
	# Se il ciclo finisce e non abbiamo trovato target_id, controlliamo allow_partial_path
	if allow_partial_path and closest_node != from_id:
		return _reconstruct_path(came_from, closest_node)
		
	# Nessun percorso trovato
	return PackedInt64Array()

# --- FUNZIONI DI SUPPORTO ---

# Calcola la distanza in linea d'aria tra due nodi (Euristica A*)
func _heuristic(from_id: int, to_id: int) -> float:
	return graph[from_id].position.distance_to(graph[to_id].position)

# Ricostruisce il percorso a ritroso dal dizionario came_from
func _reconstruct_path(came_from: Dictionary, current: int) -> PackedInt64Array:
	var path: PackedInt64Array = PackedInt64Array()
	path.append(current)
	while came_from.has(current):
		current = came_from[current]
		path.append(current)
		
	# Inverti per avere il percorso dal punto di partenza alla destinazione
	path.reverse()
	return path

func get_point_position(id: int) -> Vector2:
	return graph[id].position

func set_connection_weight(from_id: int, to_id: int, weight: float) -> void:
	for el in graph[from_id].connections:
		if el.get_to_id() != to_id: continue
		el.set_weight(weight)
	
	for el in graph[to_id].connections:
		if el.get_to_id() != from_id: continue
		el.set_weight(weight)
	
func set_point_weight_scale(id: int, weight_scale: float) -> void:
	graph[id].weight_scale = weight_scale
	
func debug_graph(tree: SceneTree, time: float = -1.0) -> void:
	var graph_container: Node = Node.new()
	print("Graph:")
	for node in graph:
		var l: Line2D = Line2D.new()
		var t: Label = Label.new()
		var circle: Line2D = _debug_create_circle(node.position, 5.0, Color(1.0, 0.0, 0.0, 1.0))
		t.position = node.position
		t.text = str(node.id)
		t.scale = Vector2(0.5, 0.5)
		circle.add_child(t)
		graph_container.add_child(circle)
		
		l.width = 1.0
		l.default_color = Color(1.0, 0.0, 0.0, 1.0)
		l.add_point(node.position)
		print(node.id, " ", node.position, " ", node.weight_scale, " Connections:")
		for c in node.connections:
			l.add_point(graph[c.get_to_id()].position)
			print(graph[c.get_to_id()].id)
		graph_container.add_child(l)
		
	tree.current_scene.add_child(graph_container)
	if time != -1.0:
		await tree.create_timer(time).timeout
		tree.current_scene.remove_child(graph_container)
	
func debug_path(start: int, target: int, tree: SceneTree, time: float = -1.0) -> void:
	var path_container: Node = Node.new()
	var path = get_id_path(start, target)
	print(path, start, target)
	for point in path:
		var node = graph[point]
		var l: Line2D = Line2D.new()
		var color: Color
		
		if point == start:
			color = Color(0.0, 0.0, 1.0, 1.0)
		else:
			color = Color(0.0, 1.0, 0.0, 1.0)
			
		var circle: Line2D = _debug_create_circle(node.position, 5.0, color)
		l.width = 1.0
		l.default_color = Color(0.0, 1.0, 0.0, 1.0)
		l.add_point(node.position)
		
		path_container.add_child(l)
		path_container.add_child(circle)
	tree.current_scene.add_child(path_container)
	if time != -1.0:
		await tree.create_timer(time).timeout
		tree.current_scene.remove_child(path_container)
	
func _debug_create_circle(center: Vector2, radius: float, color: Color, points: int = 64) -> Line2D:
	var pts: Array[Vector2] = []
	var line: Line2D = Line2D.new()
	line.width = 1.0
	line.default_color = color
	line.closed = true
	for i in range(points):
		var angle = TAU * float(i) / points
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	line.points = pts
	return line

class GPANode:
	var id: int
	var position: Vector2
	var weight_scale: float
	var disabled: bool
	var connections: Array[GPAEdge]
	
	func _init(new_id: int, new_position: Vector2, new_weight_scale: float) -> void:
		id = new_id
		position = new_position
		weight_scale = new_weight_scale
		disabled = false
		connections = []
		
	func add_connection(to_id: int, weight: float) -> void:
		for el in connections:
			if el.get_to_id() == to_id: return
			
		connections.append(GPAEdge.new(to_id, weight))
	
class GPAEdge:
	var _to_id: int
	var _weight: float
	
	func _init(to_id: int, weight: float = 1.0):
		_to_id = to_id
		_weight = weight
		
	func get_to_id() -> int:
		return _to_id
	
	func get_weight() -> float:
		return _weight
		
	func set_to_id(to_id: int) -> void:
		_to_id = to_id
	
	func set_weight(weight: float) -> void:
		_weight = weight
