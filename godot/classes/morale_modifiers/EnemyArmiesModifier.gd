extends MoraleModifier
class_name EnemyArmiesModifier

func _init() -> void:
	MAX_CAP = 30

func apply_modifier(province: Province) -> int:
	var parent = province.get_parent()
	if not parent is Agent:
		return 0
		
	var enemy_soldiers = 0
	var players = province.get_tree().get_nodes_in_group("players")
	for p in players:
		if p is Agent and p in parent.player_in_war:
			for army in p.armies:
				if is_instance_valid(army) and army.province_location == province:
					enemy_soldiers += army.soldier_number
					
	return -min(MAX_CAP, enemy_soldiers)

func is_modifier_applied(province: Province) -> bool:
	return apply_modifier(province) != 0


