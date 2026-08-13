extends MoraleModifier
class_name EnemyNeighborsModifier

func _init() -> void:
	DEFAULT_MODIFIER = 5

func apply_modifier(province: Province) -> int:
	var parent = province.get_parent()
	if not parent is Agent:
		return 0
		
	var enemy_neighbors_count = 0
	for neighbor in province.neighbors:
		if neighbor is Province:
			var neighbor_owner = neighbor.get_parent()
			if neighbor_owner is Agent and neighbor_owner in parent.player_in_war:
				enemy_neighbors_count += 1
				
	return -DEFAULT_MODIFIER * enemy_neighbors_count

func is_modifier_applied(province: Province) -> bool:
	return apply_modifier(province) != 0


