extends Path2D

class_name Path

func _ready() -> void:
	add_to_group("paths")
	
func get_paths_points(idx: int) -> Array[Variant]:
	var paths = get_tree().get_nodes_in_group("paths")
	var point_position = to_global(self.curve.get_point_position(idx))
	var paths_points = []
	for el in paths:
		if el is not Path2D: continue
		var path_point_count: int =  el.curve.point_count
		if el.to_global(el.curve.get_point_position(0)).is_equal_approx(point_position):
			paths_points.append([el, 0])
		elif el.to_global(el.curve.get_point_position(path_point_count - 1)).is_equal_approx(point_position):
			paths_points.append([el, path_point_count - 1])
	return paths_points
	
func get_point_direction(point: int) -> int:
	if point == 0:
		return -1
	elif point == curve.point_count - 1:
		return 1
	return 0
