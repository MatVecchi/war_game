extends Control

class_name Hud

var agent_list: Array[Agent] = []

signal view_changed

@onready var agent_selector: OptionButton = $PanelContainer/VBoxContainer/AgentSelector

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var agents = get_tree().get_nodes_in_group("players")
	
	for el in agents:
		if el is not Agent: continue
		var player = el as Agent
		agent_list.append(el)
		agent_selector.add_item(player.player_name)
		agent_selector.set_item_metadata(agent_selector.item_count - 1, player)
	queue_redraw()

func _on_agent_selector_item_selected(index: int) -> void:
	var game: GameController = get_tree().current_scene
	game.view = agent_selector.get_item_metadata(index)
	emit_signal("view_changed", agent_selector.get_item_metadata(index))
	print(index, agent_selector.get_item_metadata(index))
