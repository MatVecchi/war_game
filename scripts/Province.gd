extends Area2D

@export var province_id: int
@export var province_name: String
@export var province_material: String
@export var double_material: bool

@onready var fill := $Polygon2D
var selected: bool

signal province_clicked(id)

func _ready():
	add_to_group("provinces")
	connect("input_event", Callable(self, "_on_input_event"))

func _on_input_event(_viewport, _event, _shape_idx):
	if Input.is_action_just_pressed("select_province"):
		emit_signal("province_clicked", province_id)
		get_viewport().set_input_as_handled()
		
func toggle_selection():
	selected = not selected
	if selected:
		fill.modulate = Color(0.0, 0.0, 0.0, 0.463)
	else:
		fill.modulate = Color(1.0, 1.0, 1.0, 1.0)
	return selected
