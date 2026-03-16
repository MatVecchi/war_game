extends Node

class_name GameController

var provinces: Array[Province] = []
var hud_scene: Resource = preload("res://scenes/hud.tscn")
var view: Agent = null
var fog_image: Image
var vision_images: Array[Image]
@export var time_multiplier: float = 1.0
@onready var global_timer: Timer = $GlobalTimer
@onready var fog_sprite: Sprite2D = %FogSprite
@onready var background: Polygon2D = $Background/Polygon2D


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
	global_timer.timeout.connect(_on_global_timer_timeout)

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
	
func _on_global_timer_timeout() -> void:
	update_fog()
	
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
	army.army_destroyed.connect(update_vision_images)
	army.became_known.connect(_on_army_became_known)
	army.became_perfectly_known.connect(_on_army_became_perfectly_known)
	army.became_unknown.connect(_on_army_became_unknown)
	update_vision_images()
	
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
	
func get_collision_rect_size(poly: Polygon2D) -> Vector2:
	var pts = poly.polygon
	if pts.size() != 4:
		return Vector2.ZERO

	var min_x = pts[0].x
	var max_x = pts[0].x
	var min_y = pts[0].y
	var max_y = pts[0].y

	for p in pts:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	return Vector2(max_x - min_x, max_y - min_y)
	
func update_fog() -> void:
	var world_dimensions: Vector2 = get_collision_rect_size(background)
		
	fog_image = Image.create(int(world_dimensions.x), int(world_dimensions.y), false, Image.FORMAT_RGBA8)
	fog_image.fill(Color(0, 0, 0, 0.5))
	var armies: Array[Variant]
	if view == null:
		armies = get_tree().get_nodes_in_group("armies")
	else:
		armies = view.armies
		
	for i in range(len(armies)):
		var army = armies[i] as Army
		var vision_dimensions: Vector2i = Vector2i(army.VISION_RANGE * 2, army.VISION_RANGE * 2)
		var vision_rect: Rect2i = Rect2i(Vector2.ZERO, vision_dimensions)
		print(army.global_position)
		fog_image.blend_rect(vision_images[i], vision_rect, army.position + Vector2(fog_image.get_size()) / 2) 
	var fog_texture: ImageTexture = ImageTexture.create_from_image(fog_image)
	fog_sprite.texture = fog_texture
	
func update_vision_images() -> void:
	var armies: Array[Node] = get_tree().get_nodes_in_group("armies")
	vision_images.clear()
	for army: Army in armies:
		vision_images.append(army.vision_sprite.texture.get_image())
		vision_images[len(vision_images) - 1].convert(Image.FORMAT_RGBA8)
