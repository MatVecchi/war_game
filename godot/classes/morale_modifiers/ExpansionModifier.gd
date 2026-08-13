extends MoraleModifier
class_name ExpansionModifier

const MIN_EXPANSION = 0.06
const MAX_EXPANSION = 0.5

func _init() -> void:
	MAX_CAP = 35

func apply_modifier(province: Province) -> int:
	var parent = province.get_parent()
	if not parent is Agent:
		return 0
		
	var all_provinces = province.get_tree().get_nodes_in_group("provinces")
	var total_count = all_provinces.size()
	if total_count == 0:
		return 0
		
	var owned_count = 0
	for child in parent.get_children():
		if child is Province:
			owned_count += 1
			
	var ratio = float(owned_count) / float(total_count)
	
	if ratio <= MIN_EXPANSION:
		return 0
	elif ratio >= MAX_EXPANSION:
		return -MAX_CAP
	else:
		var penalty = int(float(MAX_CAP) * (ratio - MIN_EXPANSION) / (MAX_EXPANSION - MIN_EXPANSION))
		return -penalty

func is_modifier_applied(province: Province) -> bool:
	return apply_modifier(province) != 0


