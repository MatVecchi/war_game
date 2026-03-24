extends Building
class_name RecruitCenter

func _init():
	state = Enums.BuildingStates.NOT_BUILT
	max_lp = 5.0
	recruit_increase_percentage = 100
	build_cost = {
		Enums.Resources.GOLD: 1_000,
		Enums.Resources.IRON: 250,
		Enums.Resources.WOOD: 250
	}
	build_time = 1.0
	
	super()
