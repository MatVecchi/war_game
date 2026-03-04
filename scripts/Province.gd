extends Area2D

class_name Province

var timer: Timer
@export var province_id: int
@export var province_name: String
@export var province_material: Enums.Resources
@export var province_morale: int
@export var double_material: bool

@onready var fill := $Polygon2D
var selected: bool

signal province_clicked(id)

func _ready():
	add_to_group("provinces")
	timer = get_node("/root/Game/GlobalTimer")
	timer.timeout.connect(_on_global_timer_timeout)
	connect("input_event", Callable(self, "_on_input_event"))
	fill.modulate = get_parent().color

'	fill.outline_color = Color.WHITE
	fill.outline_width = 3'
	

func _on_input_event(_viewport, _event, _shape_idx):
	if _event is InputEventMouseMotion: return
	if Input.is_action_just_released("select_province") and not get_viewport().get_camera_2d().dragged:
		emit_signal("province_clicked", province_id)
		get_viewport().set_input_as_handled()
		
func _on_global_timer_timeout():
	pass
		
func get_city_position():
	return $Node2D.global_position
		
func toggle_selection():
	selected = not selected
	if selected:
		fill.modulate = blend(get_parent().color, Color(0.0, 0.0, 0.0, 0.114))
	else:
		fill.modulate = get_parent().color
	return selected
	
func blend_under(bottom: Color, top: Color) -> Color:
	var a = top.a
	return bottom * (1.0 - a) + top * a

func blend(bottom: Color, top: Color) -> Color:
	var out = blend_under(bottom, top)
	out.a = bottom.a + top.a * (1.0 - bottom.a)
	return out
