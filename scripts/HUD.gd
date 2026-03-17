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
@onready var agent_info: HBoxContainer = $PanelContainer2/HBoxContainer
@onready var player_name_label: Label = $PanelContainer2/HBoxContainer/PlayerName
@onready var position_label: Label = $PanelContainer2/HBoxContainer/VBoxContainer/HBoxContainer/Position
@onready var points_count_label: Label = $PanelContainer2/HBoxContainer/VBoxContainer/HBoxContainer2/PointsCount
@onready var leaderboard: MenuButton = $Leaderboard

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var agents = get_tree().get_nodes_in_group("players")
	
	for el in agents:
		if el is not Agent: continue
		var player = el as Agent
		agent_list.append(el)
		agent_selector.add_item(player.player_name)
		agent_selector.set_item_metadata(agent_selector.item_count - 1, player)
		
	for k in MATERIAL_TEXTURES:
			var resource_container: HBoxContainer = HBoxContainer.new()
			var resource_image: TextureRect = TextureRect.new()
			var resource_count: Label = Label.new()
			
			resource_image.texture = MATERIAL_TEXTURES[k]
			
			resource_container.add_child(resource_image)
			resource_container.add_child(resource_count)
			agent_info.add_child(resource_container)
			resources_count[k] = resource_count
	
	var game: GameController = get_tree().current_scene 
	var popup: PopupMenu = leaderboard.get_popup()
	popup.clear()  # pulisce eventuali voci precedenti

	for entry in game.leaderboard:
		var player_name = entry["player"].player_name
		var points = entry["points"]
		popup.add_item("%s: %d pts" % [player_name, points])
	queue_redraw()
	
	var timer: Timer = get_tree().get_nodes_in_group("timer")[0]
	timer.timeout.connect(_on_timer_timeout)

func _on_agent_selector_item_selected(index: int) -> void:
	var game: GameController = get_tree().current_scene
	var player: Agent = agent_selector.get_item_metadata(index)
	game.view = player
	emit_signal("view_changed", player)
	if player == null:
		agent_info_panel.hide()
	else:
		agent_info_panel.show()
		player_name_label.text = player.player_name
		
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
	var player: Agent = (get_tree().current_scene as GameController).view
	if player == null: return

	var game: GameController = get_tree().current_scene
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
	
	var popup: PopupMenu = leaderboard.get_popup()
	popup.clear()  # pulisce eventuali voci precedenti

	for entry in game.leaderboard:
		var player_name = entry["player"].player_name
		var points = entry["points"]
		popup.add_item("%s: %d pts" % [player_name, points])

	queue_redraw()
	
