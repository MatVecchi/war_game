extends Node2D

class_name Army

signal army_destroyed
signal became_known
signal became_perfectly_known
signal became_unknown

var path
var province_location
var nodes_travelled: int
var direction: int
var timer: Timer
var hour_timer: Timer
var day_timer: Timer
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var soldier_number: int
var life_points: float
var army_id: int
var player: Agent
var travelling: bool = false
var day_battle: bool = false
var destroyed: bool = false
var soldier_number_visible: bool = true
var death_count: int = 0
var current_speed: float = SPEED
const VISION_RANGE: int = 90
const OBFUSCATED_VISION_MULTIPLIER: float = 1.5
const SPEED: float = 1.0
const ATTACK_TIME: float = 60.0
const LIFE_PER_UNIT: float = 20.0
const ATTACK_PER_UNIT: float = 10.0
const DEFENSE_PER_UNIT: float = 5.0 
const ALLY_TERRITORY_SPEED_MULTIPLIER: float = 0.7
const ENEMY_TERRITORY_SPEED_MULTIPLIER: float = 0.35
const SEA_SPEED_MULTIPLIER: float = 0.1
const ARMY_DAILY_COST_PER_UNIT = {
	Enums.Resources.GRAIN: 20,
	Enums.Resources.OIL: 5
}
const MOVE_LINE_COLOR: Color = Color(0.0, 0.711, 0.0, 1.0)
const ATTACK_LINE_COLOR: Color = Color(0.699, 0.0, 0.0, 1.0)
const NEUTRAL_LABEL_BACKGROUND = Color(0.871, 0.871, 0.871, 1.0)
const NEUTRAL_LABEL_FONT_COLOR = Color(0.22, 0.22, 0.22, 1.0)
const NEUTRAL_PROGRESS_BAR_COLOR = Color(0.506, 0.718, 0.365, 1.0)
const ENEMY_LABEL_BACKGROUND = Color(0.894, 0.028, 0.089, 1.0)
const ENEMY_LABEL_FONT_COLOR = Color(1.0, 1.0, 1.0, 1.0)
const ENEMY_PROGRESS_BAR_COLOR = Color(1.0, 0.298, 0.263, 1.0)

@onready var direction_line: Line2D = $DirectionLine
@onready var direction_line_partial: Line2D = $DirectionLinePartial
@onready var control: Control = $Control
@onready var label: Label = %Label
@onready var label_style_box: StyleBoxFlat = StyleBoxFlat.new()
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var progress_bar_style_box: StyleBoxFlat = StyleBoxFlat.new()
@onready var label_panel: PanelContainer = $Control/VBoxContainer/PanelContainer
@onready var label_panel_style_box: StyleBoxFlat = StyleBoxFlat.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("armies")
	control.scale = Vector2(1, 1)/get_viewport().get_camera_2d().zoom	
	$PerfectVision/CollisionShape2D.shape.radius = VISION_RANGE
	$ObfuscatedVision/CollisionShape2D.shape.radius = VISION_RANGE * OBFUSCATED_VISION_MULTIPLIER
	$ObfuscatedVision.area_entered.connect(_on_obfuscated_vision_entered)
	$ObfuscatedVision.area_exited.connect(_on_obfuscated_vision_exited)
	$PerfectVision.area_entered.connect(_on_perfect_vision_entered)
	$PerfectVision.area_exited.connect(_on_perfect_vision_exited)
	$Area2D.area_entered.connect(_on_area_entered)
	timer = get_node("/root/Game/GlobalTimer")
	timer.timeout.connect(_on_global_timer_timeout)
	hour_timer = get_node("/root/Game/GlobalHourTimer")
	hour_timer.timeout.connect(_on_global_hour_timer_timeout)
	day_timer = get_node("/root/Game/GlobalDayTimer")
	day_timer.timeout.connect(_on_global_day_timer_timeout)
	
	var game: GameController = get_tree().current_scene
	game.hud.view_changed.connect(_on_view_changed)
	
func _create_texture(size: Vector2i, gradient_colors: PackedColorArray) -> GradientTexture2D:
	var gradient: GradientTexture2D = GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.width = size.x
	gradient.height = size.y
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(0.0, 0.5)
	gradient.gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.gradient.colors = gradient_colors
	return gradient
	
func _draw() -> void:
	if soldier_number_visible:
		label.text = str(soldier_number)
		progress_bar.value = life_points*100/((soldier_number+death_count)*LIFE_PER_UNIT)
	else:
		label.text = "?"
		progress_bar.value = 100
		
	var game: GameController = get_tree().current_scene
	if game.view != null and player in game.view.player_in_war:
		label_panel_style_box.bg_color = ENEMY_LABEL_BACKGROUND
		label_panel.add_theme_stylebox_override("panel", label_panel_style_box)
		label.add_theme_color_override("font_color", ENEMY_LABEL_FONT_COLOR)
		label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
		progress_bar_style_box.bg_color = ENEMY_PROGRESS_BAR_COLOR
		progress_bar.add_theme_stylebox_override("fill", progress_bar_style_box)
	else:
		label_panel_style_box.bg_color = NEUTRAL_LABEL_BACKGROUND
		label_panel.add_theme_stylebox_override("panel", label_panel_style_box)
		label.remove_theme_color_override("font_color")
		progress_bar_style_box.bg_color = NEUTRAL_PROGRESS_BAR_COLOR
		progress_bar.add_theme_stylebox_override("fill", progress_bar_style_box)

func _input(_event):
	if Input.is_action_just_pressed("camera_zoom_in") or Input.is_action_just_pressed("camera_zoom_out"):
		control.scale = Vector2(1,1)/get_viewport().get_camera_2d().zoom

func _on_friendly_collision(other: Army) -> void:
	if not travelling or other.travelling: return
	if nodes_travelled < len(path) - 1: return
	
	var path_points = get_parent().curve
	if direction == 1 and path_points.get_point_position(path_points.point_count - 1) == other.position or direction == -1 and path_points.get_point_position(0) == other.position:
		other.merge_armies(self)

func _on_enemy_collision(other: Army) -> void:
	if not travelling: return
	travelling = false
	if not other.travelling:
		begin_attack(other)
	else:
		begin_attack(other)
		other.begin_attack(self)
		
func _on_global_timer_timeout() -> void:
	if travelling:
		if (self.progress_ratio != 1.0 and direction == 1) or (self.progress_ratio != 0.0 and direction == -1):
			self.progress += current_speed * direction
			
			for i in range(nodes_travelled, len(path)):
				var point_path: Path2D = player.graph_to_path[path[i]][0]
				var path_point: int = player.graph_to_path[path[i]][1]
				
				
				direction_line.set_point_position(i, to_local(point_path.to_global(point_path.curve.get_point_position(path_point))))
			
			var next_point_path_partial: Path2D = player.graph_to_path[path[nodes_travelled]][0]
			var next_path_point_partial: int = player.graph_to_path[path[nodes_travelled]][1]			
			direction_line_partial.set_point_position(1, to_local(next_point_path_partial.to_global(next_point_path_partial.curve.get_point_position(next_path_point_partial))))
		else:
			nodes_travelled += 1
			if nodes_travelled == len(path):
				travelling = false
				path = null
				_on_destination_reached()
				return
			
			if province_location != null and not player.get_province_owner(province_location) and province_location.get_city_position() == position:
				var game: GameController = get_tree().current_scene
				game.conquer_province(province_location, player)
			
			var new_path = player.graph_to_path[path[nodes_travelled]][0]
			var point = player.graph_to_path[path[nodes_travelled]][1]
			var dir = new_path.get_point_direction(point)
			if get_parent() != new_path:
				reparent(new_path)
			var distance = new_path.curve.get_point_position(point).distance_to(position)
			if dir == -1:
				self.progress = distance
			else:
				self.progress = new_path.curve.get_point_position(point).distance_to(new_path.curve.get_point_position(0)) - distance
			
			direction = dir
			
func _on_global_hour_timer_timeout() -> void:
	if player == null: return	
	for i in ARMY_DAILY_COST_PER_UNIT:
		player.add_resource(i, -ARMY_DAILY_COST_PER_UNIT[i] / 24)
			
func _on_destination_reached() -> void:
	direction_line.points.clear()
	if province_location == null: return
	if not player.get_province_owner(province_location):
		var game: GameController = get_tree().current_scene
		game.conquer_province(province_location, player)

func _on_global_day_timer_timeout() -> void:
	if day_battle or not player.get_province_owner(province_location): 
		day_battle = false
		return
	
	if province_location.province_morale > 80:
		life_points += life_points * 0.05
	elif province_location.province_morale < 20:
		life_points += life_points * 0.01
	else:
		life_points += life_points * 0.02
		
func _on_obfuscated_vision_entered(area: Area2D) -> void:
	if area.name != "Area2D": return
	var other: Node = area.get_parent()
	if other is Army and player != other.player:
		player.add_known_army(other)

func _on_obfuscated_vision_exited(area: Area2D) -> void:
	if area.name != "Area2D": return
	var other: Node = area.get_parent()
	if other is Army and player != other.player:
		player.remove_know_army_reference(other)
	
func _on_perfect_vision_entered(area: Area2D) -> void:
	if area.name != "Area2D": return
	var other: Node = area.get_parent()
	if other is Army and player != other.player:
		player.add_perfectly_known_army(other)
	
func _on_perfect_vision_exited(area: Area2D) -> void:
	if area.name != "Area2D": return
	var other: Node = area.get_parent()
	if other is Army and player != other.player:
		player.remove_perfectly_know_army_reference(other)
		if not destroyed:
			player.add_known_army(other)
	
func _on_area_entered(area: Area2D) -> void:
	var other: Node = area.get_parent()
	if other is Army:
		if player == other.player or other.player not in player.player_in_war:
			_on_friendly_collision(other)
		else:
			_on_enemy_collision(other)
	
func _notification(what: int) -> void:
	if what != NOTIFICATION_PARENTED and what != NOTIFICATION_PREDELETE: return

	if what == NOTIFICATION_PARENTED:
		province_location = get_parent().get_parent()
		if player.get_province_owner(province_location):
			current_speed = SPEED * ALLY_TERRITORY_SPEED_MULTIPLIER
		elif province_location is Background:
			current_speed = SPEED * SEA_SPEED_MULTIPLIER
		else:
			current_speed = SPEED * ENEMY_TERRITORY_SPEED_MULTIPLIER
	elif what == NOTIFICATION_PREDELETE:
		destroyed = true
		emit_signal("army_destroyed", self)
func _on_battle_timer_timeout(other: Army, battle_timer: Timer) -> void:
	var random_attacker_multiplier: float = rng.randf_range(0.5, 1.5)
	var random_defender_multiplier: float = rng.randf_range(0.5, 1.5)
	var attacker_strength: float = (soldier_number*ATTACK_PER_UNIT)*life_points/(soldier_number*LIFE_PER_UNIT)
	var defener_strength: float = (other.soldier_number*other.DEFENSE_PER_UNIT)*other.life_points/(other.soldier_number*other.LIFE_PER_UNIT)
	var final_attack: float = attacker_strength * random_attacker_multiplier
	var final_defense: float = defener_strength * random_defender_multiplier
	
	#print("DEFENSE: ", final_defense, " ATTACK: ", final_attack)
	
	
	life_points -= final_defense
	other.life_points -= final_attack
	
	soldier_number -= int(final_defense / LIFE_PER_UNIT)
	other.soldier_number -= int(final_attack / other.LIFE_PER_UNIT)
	
	death_count += int(final_defense / LIFE_PER_UNIT)
	other.death_count += int(final_attack / other.LIFE_PER_UNIT)

	var battle_finished: bool = false
	if other.soldier_number <= 0 or other.life_points <= 0:
		other.destroy_self()
		battle_finished = true
	else:
		other.queue_redraw()
	
	if (soldier_number <= 0 or life_points <= 0) and not battle_finished:
		destroy_self()
		battle_finished = true
	else:
		queue_redraw()
	
	if battle_finished:
		battle_timer.stop()
		travelling = true
	else:
		battle_timer.start()
		
func _on_view_changed(view: Agent) -> void:
	if view == null or view == player:
		direction_line.show()
		direction_line_partial.hide()
	else:
		direction_line.hide()
		direction_line_partial.show()
		
func destroy_self() -> void:
	for i in range(len(player.armies)):
		if player.armies[i] != self: continue
		player.armies.remove_at(i)
		break
	queue_free()
		
func _get_morale_percentage() -> float:
	return life_points/((soldier_number+death_count)*LIFE_PER_UNIT)*100

func begin_attack(other: Army) -> void:
	var battle_timer := Timer.new()
	battle_timer.wait_time = ATTACK_TIME
	battle_timer.one_shot = true
	battle_timer.timeout.connect(_on_battle_timer_timeout.bind(other, battle_timer))
	add_child(battle_timer)
	_on_battle_timer_timeout(other, battle_timer)
	battle_timer.start()
	day_battle = true
	other.day_battle = true

	
func merge_armies(other: Army) -> void:
	soldier_number += other.soldier_number
	life_points += other.life_points
	other.queue_free()
	queue_redraw()
	
func has_reached_destination() -> bool:
	return path == null
	
func order(city: Province) -> void:
	var start: int = player.routes.get_closest_point(global_position)
	var target: int = player.routes.get_closest_point(city.to_global(city.get_city_position()))
	var points: PackedInt64Array = player.routes.get_id_path(start, target, false)
	var new_path: Path2D = player.graph_to_path[points[0]][0]
	var point: int = player.graph_to_path[points[0]][1]
	var dir = new_path.get_point_direction(point)
	if get_parent() != path:
		reparent(new_path)
		
	var distance = new_path.curve.get_point_position(point).distance_to(position)
	if dir == -1:
		self.progress = distance
	else:
		self.progress = new_path.curve.get_point_position(point).distance_to(new_path.curve.get_point_position(0)) - distance
	direction = dir
	path = points
	nodes_travelled = 0
	travelling = true
	
	direction_line.default_color = MOVE_LINE_COLOR
	direction_line.clear_points()
	
	direction_line_partial.default_color = MOVE_LINE_COLOR
	direction_line_partial.clear_points()
	for graph_point in points:
		var point_path: Path2D = player.graph_to_path[graph_point][0]
		var path_point: int = player.graph_to_path[graph_point][1]
		
		
		direction_line.add_point(to_local(point_path.to_global(point_path.curve.get_point_position(path_point))))

	var point_path_partial: Path2D = player.graph_to_path[path[0]][0]
	var path_point_partial: int = player.graph_to_path[path[0]][1]
	var next_point_path_partial: Path2D = player.graph_to_path[path[1]][0]
	var next_path_point_partial: int = player.graph_to_path[path[1]][1]
	
	direction_line_partial.add_point(to_local(point_path_partial.to_global(point_path_partial.curve.get_point_position(path_point_partial))))
	direction_line_partial.add_point(to_local(next_point_path_partial.to_global(next_point_path_partial.curve.get_point_position(next_path_point_partial))))
