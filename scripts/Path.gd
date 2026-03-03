extends Path2D


func _ready() -> void:
	add_to_group("paths")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func get_paths_points(idx: int):
	var paths = get_tree().get_nodes_in_group("paths")
	var point_position = self.curve.get_point_position(idx)
	var paths_points = []
	for el in paths:
		if el is not Path2D: continue
		var path_point_count: int =  el.curve.point_count
		if el.curve.get_point_position(0) == point_position:
			paths_points.append([el, 0])
		elif el.curve.get_point_position(path_point_count - 1) == point_position:
			paths_points.append([el, path_point_count - 1])
	return paths_points
	
func get_point_direction(point: int):
	if point == 0:
		return -1
	elif point == curve.point_count - 1:
		return 1
	return 0

	
	
func get_next_path(node: Node):
	var paths = get_tree().get_nodes_in_group("paths")
	for el in paths:
		if el is Path2D and el != self:
			var count = el.curve.point_count
			if el.curve.get_point_position(0) == self.curve.get_point_position(0) or el.curve.get_point_position(0) == self.curve.get_point_position(self.curve.point_count - 1):
				return [el, 0]
			elif el.curve.get_point_position(self.curve.point_count - 1) == self.curve.get_point_position(0) or el.curve.get_point_position(0) == self.curve.get_point_position(self.curve.point_count - 1):
				return [el, self.curve.point_count - 1]
