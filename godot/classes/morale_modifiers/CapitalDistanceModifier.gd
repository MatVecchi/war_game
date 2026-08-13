extends MoraleModifier
class_name CapitalDistanceModifier

const NO_CAPITAL_PENALTY = 40
const MAX_DISTANCE = 2000.0

func _init() -> void:
	MAX_CAP = 35

func apply_modifier(province: Province) -> int:
	var parent = province.get_parent()
	if not parent is Agent:
		return 0
	
	var capital: Province = null
	for child in parent.get_children():
		if child is Province and Enums.Buildings.CAPITAL in child.buildings:
			capital = child
			break
			
	if capital == null:
		return -NO_CAPITAL_PENALTY
		
	var dist = province.to_global(province.get_city_position()).distance_to(capital.to_global(capital.get_city_position()))
	
	var penalty = int((dist / MAX_DISTANCE) * MAX_CAP)
	return -min(penalty, MAX_CAP)

func is_modifier_applied(province: Province) -> bool:
	return apply_modifier(province) != 0
