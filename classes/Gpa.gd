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
	return closest_point.id
	
func get_id_path(from_id: int, to_id: int, allow_partial_path: bool = false) -> PackedInt64Array:
		# Distanze iniziali
	var dist := {}
	var prev := {}
	var visited := {}

	for node in graph:
		dist[node.id] = INF
		prev[node.id] = null
		visited[node.id] = false

	dist[from_id] = 0.0

	# Priority queue manuale (O(n²), ma ok per grafi piccoli)
	while true:
		var current = null
		var current_dist := INF

		# Trova il nodo non visitato con distanza minore
		for id in dist.keys():
			if not visited[id] and dist[id] < current_dist:
				current = id
				current_dist = dist[id]

		if current == null:
			break  # Nessun nodo raggiungibile rimasto

		visited[current] = true

		# Se abbiamo raggiunto la destinazione, possiamo fermarci
		if current == to_id:
			break

		var node := graph[current]
		if node.disabled:
			continue

		# Esplora i vicini
		for edge in node.connections:
			var neighbor = edge.get_to_id()
			var neighbor_node := graph[neighbor]
			if neighbor_node.disabled:
				continue

			# Costo effettivo: peso arco * weight_scale del nodo di arrivo
			var cost = edge.get_weight() * neighbor_node.weight_scale
			var new_dist = dist[current] + cost

			if new_dist < dist[neighbor]:
				dist[neighbor] = new_dist
				prev[neighbor] = current

	# Ricostruzione del percorso
	var path := []
	var cur = to_id

	if prev[cur] == null and cur != from_id:
		if allow_partial_path:
			# Trova il nodo più vicino raggiungibile
			var best := from_id
			var best_dist = dist[from_id]
			for id in dist.keys():
				if dist[id] < best_dist:
					best = id
					best_dist = dist[id]
			cur = best
		else:
			return []

	while cur != null:
		path.append(cur)
		cur = prev[cur]

	path.reverse()
	return PackedInt64Array(path)

	
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
