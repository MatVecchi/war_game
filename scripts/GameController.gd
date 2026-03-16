extends Node

class_name GameController

var provinces: Array[Province] = []
var hud_scene: Resource = preload("res://scenes/hud.tscn")
var view: Agent = null
@export var time_multiplier: float = 1.0

func _ready() -> void:
	Engine.time_scale = time_multiplier
	var polys = get_tree().get_nodes_in_group("provinces")
	var nodes: Array[Path2D]
	
	for el in polys:
		if el is not Province: return
		provinces.append(el)
	
	for el in get_children():
		if el is Path2D:
			nodes.append(el)
	
	create_hud()

func _on_army_became_known(army: Army, player: Agent) -> void:
	if player != view: return
	army.soldier_number_visible = false
	army.show() 
	army.queue_redraw()
	
func _on_army_became_perfectly_known(army: Army, player: Agent) -> void:
	if player != view: return
	army.soldier_number_visible = true
	army.show()
	army.queue_redraw()
	
func _on_army_became_unknown(army: Army, player: Agent) -> void:
	if player != view: return
	army.hide()
	army.queue_redraw()
	
func _on_view_changed(player: Agent) -> void:
	view = player
	var players = get_tree().get_nodes_in_group("players")
	for el: Agent in players:
		if el == player:
			for army: Army in el.armies:
				army.show()
				army.queue_redraw()
		else:
			for army: Army in el.armies:
				if player == null:
					army.soldier_number_visible = true
					army.show()
				elif army in player.known_armies:
					army.soldier_number_visible = false
					army.show()
				elif army in player.perfectly_known_armies:
					army.soldier_number_visible = true
					army.show()
				else:
					army.hide()
				army.queue_redraw()

func add_army_to_province(province: Province, army: Army) -> void:
	var agent: Agent = province.get_parent()
	if army == null:
		var army_scene = preload("res://scenes/army.tscn")
		army = army_scene.instantiate()
		army.army_id = len(agent.armies)
		army.soldier_number = 10
		army.life_points = army.LIFE_PER_UNIT * 10 * (float(province.province_morale)/100)
		agent.armies.append(army)
		agent.add_child(army)
	army.position = province.get_node("Node2D").global_position
	army.became_known.connect(_on_army_became_known)
	army.became_perfectly_known.connect(_on_army_became_perfectly_known)
	army.became_unknown.connect(_on_army_became_unknown)
	
	if agent != view and view != null:
		army.hide()

func create_hud():
	var canvas_layer = CanvasLayer.new()
	var hud: Hud = hud_scene.instantiate()
	canvas_layer.add_child(hud)
	hud.view_changed.connect(_on_view_changed)
	get_tree().current_scene.add_child(canvas_layer)
	
func conquer_province(province: Province, agent: Agent) -> void:
	province.reparent(agent)
	province.fill.color = agent.color
	province.province_morale = 12
	province.conquered = true
