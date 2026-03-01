extends Node

class_name Agent

@export var color: Color
@export var armies: Array[Army]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("players")
	await get_tree().process_frame
	var game: GameController = get_tree().current_scene
	var childrens = get_children()
	var army_scene := preload("res://scenes/army.tscn")
	for i in range(len(childrens)):		
		var army: Army = army_scene.instantiate()
		army.army_id = i
		army.soldier_number = 10
		
		armies.append(army)
		add_child(army)
		if childrens[i] is Province:
			game.state.add_army_to_province(childrens[i], army)
	
	'if len(armies) > 0:
		for x in armies:
			print(x.position)
		armies[0].order(game.state.provinces[1])'
	
	'for el in get_children():
		if el is Province:
			el.fill.modulate = color
			provinces.append(el)
		if el is Army:
			armies.append(el)
	for i in range(len(provinces)):
		game.state.add_army_to_province(provinces[i], armies[i])'
		


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
