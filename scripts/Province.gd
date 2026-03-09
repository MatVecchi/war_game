extends Area2D

class_name Province

var timer: Timer
var day_timer: Timer
@export var province_id: int
@export var province_name: String
@export var province_material: Enums.Resources
@export var double_material: bool
@export var is_capital: bool

@onready var fill := $Polygon2D
var selected: bool
var province_morale: int = 70
var target_morale: int = 100
var MATERIAL_TEXTURES := {
	Enums.ResourcesSprites.WOOD: preload("res://assets/sprites/resources/wood.png"),
	Enums.ResourcesSprites.WOOD_DOUBLE: preload("res://assets/sprites/resources/wood_double.png"),
	Enums.ResourcesSprites.IRON: preload("res://assets/sprites/resources/iron.png"),
	Enums.ResourcesSprites.IRON_DOUBLE: preload("res://assets/sprites/resources/iron_double.png")
}

signal province_clicked(id)

func _ready():
	add_to_group("provinces")
	timer = get_node("/root/Game/GlobalTimer")
	timer.timeout.connect(_on_global_timer_timeout)
	day_timer = get_node("/root/Game/GlobalDayTimer")
	day_timer.timeout.connect(_on_global_day_timer_timeout)
	fill.color = get_parent().color
	$Control/VBoxContainer/HBoxContainer/TextureRect.texture = MATERIAL_TEXTURES[_get_sprite_key()]

func _draw():
	$Control/VBoxContainer/HBoxContainer/ResourceCount.text = str(_get_daily_resource_count())
	$Control/VBoxContainer/ProvinceName.text = province_name + ": " + str(province_morale) + "%"
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: return
	if Input.is_action_just_released("select_province") and not get_viewport().get_camera_2d().dragged:
		emit_signal("province_clicked", province_id)
		get_viewport().set_input_as_handled()
		
	if Input.is_action_just_pressed("camera_zoom_in") or Input.is_action_just_pressed("camera_zoom_out"):
		$Control.scale = Vector2(1,1)/get_viewport().get_camera_2d().zoom
		
func _on_global_timer_timeout():
	var agent = get_parent()
	agent.resources[province_material] += _get_daily_resource_count() / 24
	agent.queue_redraw()
	
	target_morale = 100 - _get_total_morale_penalties() + _get_total_morale_bonuses()
	
func _on_global_day_timer_timeout():
	var delta: float = target_morale - province_morale
	if delta == 0: return
	
	province_morale += ceil(delta/100 * 15)
	queue_redraw()
	
func _get_daily_resource_count():
	var resource_to_add: int = (province_morale * 24) + 750
	
	if double_material:
		resource_to_add *= 2
	return resource_to_add
	
func _get_total_morale_penalties():
	return 0
	
func _get_total_morale_bonuses():
	return 0
	
func _get_sprite_key():
	match province_material:
		Enums.Resources.WOOD:
			return Enums.ResourcesSprites.WOOD_DOUBLE if double_material else Enums.ResourcesSprites.WOOD

		Enums.Resources.IRON:
			return Enums.ResourcesSprites.IRON_DOUBLE if double_material else Enums.ResourcesSprites.IRON

		
func get_city_position() -> Vector2:
	return $Node2D.global_position
	
func get_province_paths():
	var global_paths = get_tree().get_nodes_in_group("paths")
	var paths = []
	for el in global_paths:
		if el is not Path: continue
		
		var start = el.curve.get_point_position(0)
		var end = el.curve.get_point_position(el.curve.pont_count - 1)
		
		if start == get_city_position():
			paths.append([el, start])
		elif end == get_city_position():
			paths.append([el, end])
	return paths
	
func _notification(what: int) -> void:
	if get_tree() == null: return
	if what == NOTIFICATION_PARENTED:
		for path in get_province_paths():
				var graph_node_key = 0
				if path[1] > 0:
					graph_node_key = 1
				get_parent().routes.set_point_weight_scale(get_parent().graph_to_path[path[0]][graph_node_key], 1.0)
				
				var players = get_tree().get_nodes_in_group("players")
				for player in players:
					if player == get_parent(): continue
					player.routes.set_point_weight_scale(player.graph_to_path[path[0]][graph_node_key], 1.5)
					
func toggle_selection():
	selected = not selected
	if selected:
		fill.color = blend(get_parent().color, Color(0.0, 0.0, 0.0, 0.114))
	else:
		fill.color = get_parent().color
	return selected
	
func blend_under(bottom: Color, top: Color) -> Color:
	var a = top.a
	return bottom * (1.0 - a) + top * a

func blend(bottom: Color, top: Color) -> Color:
	var out = blend_under(bottom, top)
	out.a = bottom.a + top.a * (1.0 - bottom.a)
	return out
