extends Node

var state: GameState

func _ready() -> void:
	var polys = get_tree().get_nodes_in_group("provinces")
	var bg = get_tree().get_nodes_in_group("background")[0]
	bg.clear_province.connect(clear_selection)
	state = GameState.new(polys)

func _process(_delta: float) -> void:
	pass
	
func clear_selection():
	var p = state.get_province_selected()
	if p != null:
		p.toggle_selection()
		state.set_province_selected(null)

class GameState:
	var provinces
	var province_selected
	func _init(polys: Array[Node]) -> void:
		provinces = polys
		for el in provinces:
			el.province_clicked.connect(self.select_province)
			
	func get_province(id: int):
		for el in self.provinces:
			if el.province_id == id:
				return el
		return null
	
	func get_province_selected():
		return province_selected
	
	func set_province_selected(new_province):
		province_selected = new_province
		
	func select_province(id: int):
		if get_province_selected() != null && get_province_selected().province_id != id:
			get_province_selected().toggle_selection()
		var el = get_province(id)
		if el.toggle_selection():
			set_province_selected(el)
		else:
			set_province_selected(null)
