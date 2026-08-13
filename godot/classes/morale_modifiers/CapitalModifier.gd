extends MoraleModifier
class_name CapitalModifier

func _init() -> void:
	DEFAULT_MODIFIER = 10

func apply_modifier(province: Province) -> int:
	if Enums.Buildings.CAPITAL in province.buildings:
		return DEFAULT_MODIFIER
	return 0

func is_modifier_applied(province: Province) -> bool:
	return apply_modifier(province) != 0


