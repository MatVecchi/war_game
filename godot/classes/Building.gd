extends Object
class_name Building

var state: Enums.BuildingStates
var max_lp: float
var lp: float
var morale_increase_percentage: int
var damage_absorbtion_percentage: int
var recruit_increase_percentage: int
var troop_production_increase_percentage: int
var resource_production_increase_percentage: int
var troop_speed_increase_percentage: int
var onboarding_time_reduce_percentage: int
var build_cost: Dictionary[Enums.Resources, int]
var build_time: float
var daily_cost: Dictionary[Enums.Resources, int]

func _init():
	pass

func has_enough_resources(player: Agent) -> bool:
	for k in build_cost:
		if player.resources[k] < build_cost[k]:
			return false 
	return true

func set_state(new_state: Enums.BuildingStates) -> void:
	state = new_state
	
func add_lp(adding: float) -> void:
	lp = clampf(lp + adding, 0.0, max_lp)
	
func set_lp(new_lp: float) -> void:
	lp = clampf(new_lp, 0.0, max_lp)
	
func set_max_lp() -> void:
	set_lp(max_lp)
