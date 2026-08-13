extends Object
class_name MoraleModifier

var MAX_CAP: Variant = null
var MIN_CAP: Variant = null
var DEFAULT_MODIFIER: Variant = null

func apply_modifier(province: Province) -> int:
	push_error("apply_modifier must be implemented")
	return -1

func is_modifier_applied(province: Province) -> bool:
	push_error("is_modifier_applied must be implemented")
	return false
