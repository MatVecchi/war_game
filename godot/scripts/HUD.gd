extends Control

class_name Hud

var agent_list: Array[Agent] = []

signal view_changed

var resources_count: Dictionary[Enums.Resources, Label] = {}
const MATERIAL_TEXTURES: Dictionary[Enums.Resources, Resource] = {
	Enums.Resources.WOOD: preload("res://assets/sprites/resources/wood.png"),
	Enums.Resources.IRON: preload("res://assets/sprites/resources/iron.png"),
	Enums.Resources.OIL: preload("res://assets/sprites/resources/oil.png"),
	Enums.Resources.GAS: preload("res://assets/sprites/resources/gas.png"),
	Enums.Resources.COAL: preload("res://assets/sprites/resources/coal.png"),
	Enums.Resources.GRAIN: preload("res://assets/sprites/resources/grain.png"),
	Enums.Resources.FISH: preload("res://assets/sprites/resources/fish.png"),
	Enums.Resources.GOLD: preload("res://assets/sprites/resources/gold.png")
}
@onready var agent_selector: OptionButton = $PanelContainer/VBoxContainer/AgentSelector
@onready var agent_info_panel: PanelContainer = %AgentInfoPanel
@onready var agent_info: HBoxContainer = %ResourceContainer
@onready var player_name_label: Label = $AgentInfoPanel/HBoxContainer/PlayerName
@onready var position_label: Label = $AgentInfoPanel/HBoxContainer/VBoxContainer/HBoxContainer/Position
@onready var points_count_label: Label = $AgentInfoPanel/HBoxContainer/VBoxContainer/HBoxContainer2/PointsCount
@onready var day_cycle_label: Label = $VBoxContainer/PanelContainer3/HBoxContainer/DayCycle
@onready var time_scale_modifier: HScrollBar = $VBoxContainer/VBoxContainer/HScrollBar
@onready var time_scale_label: Label = $VBoxContainer/VBoxContainer/HBoxContainer/TimeScale
@onready var leaderboard_container: PanelContainer = $Leaderboard
@onready var journal_container: PanelContainer = $Journal
@onready var match_over_text_label: Label = $Leaderboard/MarginContainer/VBoxContainer/MatchOverText
@onready var player_list_container: VBoxContainer = $Leaderboard/MarginContainer/VBoxContainer/PlayerList
@onready var most_powerful_armies_list: VBoxContainer = %MostPowerfulArmies
@onready var best_economies_list: VBoxContainer = %BestEconomies
@onready var most_popular_nations_list: VBoxContainer = %MostPopularNations

const ARROW_UP_TEXTURE = preload("res://assets/textures/arrow-up.png")
const ARROW_DOWN_TEXTURE = preload("res://assets/textures/arrow-down.png")

const BUILDING_TEXTURES: Dictionary[Enums.Buildings, Resource] = {
	Enums.Buildings.CAPITAL: preload("res://assets/sprites/buildings/capitol_s1.png"),
	Enums.Buildings.RECRUIT_CENTER: preload("res://assets/sprites/buildings/recruiting_office_s1.png")
}

@onready var province_details_panel: PanelContainer = $HBoxContainer/ProvinceDetails
@onready var province_name_label: Label = %ProvinceName
@onready var province_morale_count: Label = %MoraleCount
@onready var province_resource_production: HBoxContainer = %ProvinceResourceProduction
@onready var province_building_list: HBoxContainer = %ProvinceBuildingList
@onready var province_troop_recruitment_timer: Label = %TroopRecruitmentTimer
@onready var morale_modifier_container: PanelContainer = %MoraleModifierContainer
@onready var morale_modifier_list: VBoxContainer = %MoraleModifierList
@onready var show_modifier_list_btn: Button = %ShowModifierList

var selected_province: Province = null
var hud_trend_arrow: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var agents = get_tree().get_nodes_in_group("players")
	
	for el in agents:
		if el is not Agent: continue
		var player = el as Agent
		agent_list.append(el)
		agent_selector.add_item(player.name.capitalize())
		agent_selector.set_item_metadata(agent_selector.item_count - 1, player)
		
	for k in MATERIAL_TEXTURES:
			var resource_container: HBoxContainer = HBoxContainer.new()
			resource_container.size_flags_horizontal = Control.SIZE_EXPAND
			var resource_image: TextureRect = TextureRect.new()
			var resource_count: Label = Label.new()
			
			resource_image.texture = MATERIAL_TEXTURES[k]
			
			resource_container.add_child(resource_image)
			resource_container.add_child(resource_count)
			agent_info.add_child(resource_container)
			resources_count[k] = resource_count
	
	var game: GameController = get_tree().current_scene 
	for i in range(len(game.leaderboard)):
		var player_name = game.leaderboard[i]["player"].name
		var points = game.leaderboard[i]["points"]
		var container: HBoxContainer = HBoxContainer.new()
		var label_name: Label = Label.new()
		var label_points: Label = Label.new()
		label_name.text = "#%d - %s:" % [i + 1, player_name.capitalize()]
		label_points.text = "%d pts" % [points]
		label_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		container.add_child(label_name)
		container.add_child(label_points)
		player_list_container.add_child(container)
	time_scale_modifier.value = Engine.time_scale 
	time_scale_label.text = str(int(Engine.time_scale)) + "x"
	day_cycle_label.text = str(game.day_cycle)
	queue_redraw()
	
	var timer: Timer = get_tree().get_nodes_in_group("timer")[0]
	var day_timer: Timer = get_tree().get_nodes_in_group("day_timer")[0]
	
	timer.timeout.connect(_on_timer_timeout)
	day_timer.timeout.connect(_on_day_timer_timeout)
	game.match_over.connect(_on_match_over)
	
	agent_selector.mouse_filter = Control.MOUSE_FILTER_PASS
	
	hud_trend_arrow = TextureRect.new()
	hud_trend_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hud_trend_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hud_trend_arrow.custom_minimum_size = Vector2(16, 16)
	hud_trend_arrow.size_flags_horizontal = Control.SIZE_EXPAND
	province_morale_count.get_parent().add_child(hud_trend_arrow)
	province_morale_count.get_parent().move_child(hud_trend_arrow, 2)
	
	province_resource_production.add_theme_constant_override("separation", 10)
	province_building_list.add_theme_constant_override("separation", 10)
	
	if show_modifier_list_btn:
		show_modifier_list_btn.pressed.connect(_on_show_modifier_list_pressed)

	
func _draw() -> void:
	var cam: Camera = get_viewport().get_camera_2d()
	if leaderboard_container.visible:
		cam.input_enabled = false
	else:
		cam.input_enabled = true
	_update_province_details_ui()

func _on_agent_selector_item_selected(index: int) -> void:
	var game: GameController = get_tree().current_scene
	var player: Agent = agent_selector.get_item_metadata(index)
	game.view = player
	emit_signal("view_changed", player)
	if player == null:
		agent_info_panel.hide()
	else:
		agent_info_panel.show()
		player_name_label.text = player.name.capitalize()
		
		for k in MATERIAL_TEXTURES:
			if player.resources[k] > 999 and player.resources[k] < 9_999:
				resources_count[k].text = "%.1fk" % (player.resources[k] / 1000.0)
			elif player.resources[k] > 9_999:
				@warning_ignore("integer_division")
				resources_count[k].text = str(player.resources[k] / 1000) + "k"
			else:
				resources_count[k].text = str(player.resources[k])
		var leaderboard_position: int
		for i in range(len(game.leaderboard)):
			if game.leaderboard[i]["player"] == player:
				leaderboard_position = i
				break
		position_label.text = str(leaderboard_position + 1)
		points_count_label.text = str(player.points)
	queue_redraw()
	
func _on_timer_timeout():
	var game: GameController = get_tree().current_scene
	
	for entry in player_list_container.get_children():
		entry.queue_free()
	
	for i in range(len(game.leaderboard)):
		var player_name = game.leaderboard[i]["player"].name
		var points = game.leaderboard[i]["points"]
		var container: HBoxContainer = HBoxContainer.new()
		var label_name: Label = Label.new()
		var label_points: Label = Label.new()
		label_name.text = "#%d - %s:" % [i + 1, player_name.capitalize()]
		label_points.text = "%d pts" % [points]
		label_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		container.add_child(label_name)
		container.add_child(label_points)
		player_list_container.add_child(container)

	var player: Agent = game.view
	if player != null:
		for k in MATERIAL_TEXTURES:
			if player.resources[k] > 999 and player.resources[k] < 9_999:
				resources_count[k].text = "%.1fk" % (player.resources[k] / 1000.0)
			elif player.resources[k] > 9_999:
				@warning_ignore("integer_division")
				resources_count[k].text = str(player.resources[k] / 1000) + "k"
			else:
				resources_count[k].text = str(player.resources[k])

		var leaderboard_position: int
		for i in range(len(game.leaderboard)):
			if game.leaderboard[i]["player"] == player:
				leaderboard_position = i
				break
		position_label.text = str(leaderboard_position + 1)
		points_count_label.text = str(player.points)

	if selected_province != null and is_instance_valid(selected_province):
		_update_province_details_ui()

	queue_redraw()
	
func _on_day_timer_timeout():
	var game: GameController = get_tree().current_scene
	day_cycle_label.text = str(game.day_cycle)

	_update_most_powerful_armies()
	_update_best_economies()
	_update_most_popular_nations()
	queue_redraw()

func _on_match_over() -> void:
	match_over_text_label.show()
	leaderboard_container.show()
	queue_redraw()

func _on_button_pressed() -> void:
	leaderboard_container.visible = not leaderboard_container.visible
	queue_redraw()

func _on_statistics_button_pressed() -> void:
	journal_container.visible = not journal_container.visible
	queue_redraw()


func _on_h_scroll_bar_scrolling() -> void:
	Engine.time_scale = time_scale_modifier.value
	time_scale_label.text = str(int(Engine.time_scale)) + "x"

func _update_most_powerful_armies() -> void:
	var nation_data: Array[Dictionary] = []
	var global_soldiers: int = 0
	
	for agent in agent_list:
		if not is_instance_valid(agent): continue
		var nation_soldiers: int = 0
		for army in agent.armies:
			if is_instance_valid(army):
				nation_soldiers += army.soldier_number
		global_soldiers += nation_soldiers
		nation_data.append({
			"agent": agent,
			"soldiers": nation_soldiers
		})
		
	nation_data.sort_custom(func(a, b):
		return a["soldiers"] > b["soldiers"]
	)
	
	for entry in most_powerful_armies_list.get_children():
		entry.queue_free()
		
	for i in range(len(nation_data)):
		var entry = nation_data[i]
		var agent = entry["agent"]
		var soldiers = entry["soldiers"]
		
		var power: float = 0.0
		if global_soldiers > 0:
			power = (float(soldiers) / global_soldiers) * 100.0
			
		var container: HBoxContainer = HBoxContainer.new()
		var label_name: Label = Label.new()
		var label_value: Label = Label.new()
		
		label_name.text = "#%d - %s:" % [i + 1, agent.name.capitalize()]
		label_value.text = "%.1f%%" % power
		label_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		container.add_child(label_name)
		container.add_child(label_value)
		most_powerful_armies_list.add_child(container)

func _update_best_economies() -> void:
	var nation_data: Array[Dictionary] = []
	for agent in agent_list:
		if not is_instance_valid(agent): continue
		var daily_prod: int = 0
		for child in agent.get_children():
			if child is Province:
				daily_prod += child.get_daily_resource_count()
		nation_data.append({
			"agent": agent,
			"production": daily_prod
		})
		
	nation_data.sort_custom(func(a, b):
		return a["production"] > b["production"]
	)
	
	for entry in best_economies_list.get_children():
		entry.queue_free()
		
	for i in range(len(nation_data)):
		var entry = nation_data[i]
		var agent = entry["agent"]
		var prod = entry["production"]
		
		var prod_str = ""
		if prod > 999 and prod < 9_999:
			prod_str = "%.1fk t" % (prod / 1000.0)
		elif prod > 9_999:
			@warning_ignore("integer_division")
			prod_str = str(prod / 1000) + "k t"
		else:
			prod_str = str(prod) + " t"
			
		var container: HBoxContainer = HBoxContainer.new()
		var label_name: Label = Label.new()
		var label_value: Label = Label.new()
		
		label_name.text = "#%d - %s:" % [i + 1, agent.name.capitalize()]
		label_value.text = prod_str
		label_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		container.add_child(label_name)
		container.add_child(label_value)
		best_economies_list.add_child(container)

func _update_most_popular_nations() -> void:
	var nation_data: Array[Dictionary] = []
	for agent in agent_list:
		if not is_instance_valid(agent): continue
		var total_morale: int = 0
		var province_count: int = 0
		for child in agent.get_children():
			if child is Province:
				total_morale += child.province_morale
				province_count += 1
				
		var mean_morale: float = 0.0
		if province_count > 0:
			mean_morale = float(total_morale) / province_count
			
		nation_data.append({
			"agent": agent,
			"morale": mean_morale
		})
		
	nation_data.sort_custom(func(a, b):
		return a["morale"] > b["morale"]
	)
	
	for entry in most_popular_nations_list.get_children():
		entry.queue_free()
		
	for i in range(len(nation_data)):
		var entry = nation_data[i]
		var agent = entry["agent"]
		var morale = entry["morale"]
		
		var container: HBoxContainer = HBoxContainer.new()
		var label_name: Label = Label.new()
		var label_value: Label = Label.new()
		
		label_name.text = "#%d - %s:" % [i + 1, agent.name.capitalize()]
		label_value.text = "%.1f%%" % morale
		label_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		container.add_child(label_name)
		container.add_child(label_value)
		most_popular_nations_list.add_child(container)

func show_province_details(province: Province) -> void:
	selected_province = province
	if province == null:
		province_details_panel.hide()
		if morale_modifier_container:
			morale_modifier_container.hide()
	else:
		province_details_panel.show()
		_update_province_details_ui()

func _update_province_details_ui() -> void:
	if selected_province == null or not is_instance_valid(selected_province):
		return
		
	province_name_label.text = selected_province.name
	
	province_morale_count.text = str(selected_province.province_morale) + "%"
	var trend = selected_province.target_morale - selected_province.province_morale
	if trend > 0:
		hud_trend_arrow.texture = ARROW_UP_TEXTURE
		hud_trend_arrow.show()
	elif trend < 0:
		hud_trend_arrow.texture = ARROW_DOWN_TEXTURE
		hud_trend_arrow.show()
	else:
		hud_trend_arrow.texture = null
		hud_trend_arrow.hide()
		
	for child in province_resource_production.get_children():
		province_resource_production.remove_child(child)
		child.queue_free()
		
	var net_change: Dictionary[Enums.Resources, int] = {}
	for res in Enums.Resources.values():
		net_change[res] = 0
		
	net_change[selected_province.province_material] += selected_province.get_daily_resource_count()
	net_change[Enums.Resources.GOLD] += selected_province.get_daily_gold_count()
	
	for res in selected_province.daily_cost:
		net_change[res] -= selected_province.daily_cost[res]
		
	for res in Enums.Resources.values():
		var net = net_change[res]
		if net <= 0: continue
		
		var container = HBoxContainer.new()
		container.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var img = TextureRect.new()
		img.texture = MATERIAL_TEXTURES[res]
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(16, 16)
		container.add_child(img)
		
		var lbl = Label.new()
		lbl.text = "+" + str(net)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		container.add_child(lbl)
		
		province_resource_production.add_child(container)
		
	for child in province_building_list.get_children():
		province_building_list.remove_child(child)
		child.queue_free()
		
	for b_enum in selected_province.buildings:
		var building = selected_province.buildings[b_enum]
		if building.state == Enums.BuildingStates.NOT_BUILT:
			continue
			
		if b_enum in BUILDING_TEXTURES:
			var img = TextureRect.new()
			img.texture = BUILDING_TEXTURES[b_enum]
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.custom_minimum_size = Vector2(32, 32)
			
			if building.state == Enums.BuildingStates.DAMAGED:
				img.modulate = Color(1, 0.5, 0.5, 1)
			province_building_list.add_child(img)
			
	var has_active_recruit_center = false
	if selected_province.has_building(Enums.Buildings.RECRUIT_CENTER):
		var rc = selected_province.buildings[Enums.Buildings.RECRUIT_CENTER]
		if rc.state != Enums.BuildingStates.NOT_BUILT:
			has_active_recruit_center = true
			
	if has_active_recruit_center:
		var time_left = selected_province.army_timer.time_left
		province_troop_recruitment_timer.text = _format_time(time_left)
	else:
		province_troop_recruitment_timer.text = "Inactive"
		
	if morale_modifier_list:
		for child in morale_modifier_list.get_children():
			morale_modifier_list.remove_child(child)
			child.queue_free()
			
		selected_province._update_active_morale_modifiers()
		
		for bonus_key in selected_province.morale_bonuses:
			var modifier = selected_province.morale_bonuses[bonus_key]
			var name_str = ""
			var val
			if bonus_key.begins_with("building_"):
				name_str = Enums.Buildings.keys()[int(bonus_key.replace("building_", ""))].replace("_", " ").capitalize()
				val = modifier.morale_increase_percentage
			else:
				name_str = Enums.ProvinceMoraleBonuses.keys()[bonus_key].replace("_", " ").capitalize()
				val = modifier.apply_modifier(selected_province)
			_add_modifier_item(name_str, val)
			
		for malus_key in selected_province.morale_maluses:
			var modifier = selected_province.morale_maluses[malus_key]
			var val = modifier.apply_modifier(selected_province)
			var name_str = Enums.ProvinceMoraleMaluses.keys()[malus_key].replace("_", " ").capitalize()
			_add_modifier_item(name_str, val)

func _format_time(seconds: float) -> String:
	var total_secs = int(ceil(seconds))
	var mins = total_secs / 60
	var secs = total_secs % 60
	return "%02d:%02d" % [mins, secs]

func _add_modifier_item(name_str: String, val: int) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var label_name = Label.new()
	label_name.text = name_str
	
	var label_val = Label.new()
	label_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	if val > 0:
		label_val.text = "+" + str(val)
		label_val.add_theme_color_override("font_color", Color("2196f3")) # Blue
	elif val < 0:
		label_val.text = str(val)
		label_val.add_theme_color_override("font_color", Color("f44336")) # Red
	else:
		label_val.text = str(val)
		
	hbox.add_child(label_name)
	hbox.add_child(label_val)
	morale_modifier_list.add_child(hbox)

func _on_show_modifier_list_pressed() -> void:
	if morale_modifier_container:
		morale_modifier_container.visible = not morale_modifier_container.visible
