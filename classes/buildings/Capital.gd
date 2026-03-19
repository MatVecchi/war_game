class_name Capital extends Building

func _init():
	state = Enums.BuildingStates.NOT_BUILT
	max_lp = 40.0
	morale_increase_percentage = 10
	build_cost = {
		Enums.Resources.GOLD: 2_000,
		Enums.Resources.IRON: 5_000,
		Enums.Resources.WOOD: 5_000
	}
	build_time = 720.0
