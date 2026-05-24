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
@onready var agent_info_panel: PanelContainer = $PanelContainer2
@onready var agent_info: HBoxContainer = %ResourceContainer
@onready var player_name_label: Label = $PanelContainer2/HBoxContainer/PlayerName
@onready var position_label: Label = $PanelContainer2/HBoxContainer/VBoxContainer/HBoxContainer/Position
@onready var points_count_label: Label = $PanelContainer2/HBoxContainer/VBoxContainer/HBoxContainer2/PointsCount
@onready var day_cycle_label: Label = $VBoxContainer/PanelContainer3/HBoxContainer/DayCycle
@onready var time_scale_modifier: HScrollBar = $VBoxContainer/VBoxContainer/HScrollBar
@onready var time_scale_label: Label = $VBoxContainer/VBoxContainer/HBoxContainer/TimeScale
@onready var leaderboard_container: PanelContainer = $Leaderboard
@onready var match_over_text_label: Label = $Leaderboard/VBoxContainer/MatchOverText
@onready var player_list_container: VBoxContainer = $Leaderboard/VBoxContainer/PlayerList

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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
		label_name.text = "%d° - %s:" % [i + 1, player_name.capitalize()]
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
	
func _draw() -> void:
	var cam: Camera = get_viewport().get_camera_2d()
	if leaderboard_container.visible:
		cam.input_enabled = false
	else:
		cam.input_enabled = true
	
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
		label_name.text = "%d° - %s:" % [i + 1, player_name.capitalize()]
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

	queue_redraw()
	
func _on_day_timer_timeout():
	var game: GameController = get_tree().current_scene
	day_cycle_label.text = str(game.day_cycle)
	queue_redraw()

func _on_match_over() -> void:
	match_over_text_label.show()
	leaderboard_container.show()
	queue_redraw()

func _on_button_pressed() -> void:
	leaderboard_container.visible = not leaderboard_container.visible
	queue_redraw()


func _on_h_scroll_bar_scrolling() -> void:
	Engine.time_scale = time_scale_modifier.value
	time_scale_label.text = str(int(Engine.time_scale)) + "x"
