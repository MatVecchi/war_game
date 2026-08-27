extends Node2D

class_name Army

signal army_destroyed(army: Army)
signal became_known(army: Army, player: Agent)
signal became_perfectly_known(army: Army, player: Agent)
signal became_unknown(army: Army, player: Agent)
signal movement_updated(next_pos: Vector2)

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
var target_province: Province = null
var day_battle: bool = false
var destroyed: bool = false
var active_battles: Dictionary = {}
var soldier_number_visible: bool = true
var death_count: int = 0
var current_speed: float = SPEED
const VISION_RANGE: int = 90
const OBFUSCATED_VISION_MULTIPLIER: float = 1.5
const SPEED: float = 1.0
const ATTACK_TIME: float = 60.0
const LIFE_PER_UNIT: float = 20.0
const ATTACK_PER_UNIT: float = 4.0
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
const ALLY_LABEL_BACKGROUND = Color(0.149, 0.403, 0.922, 1.0)
const ALLY_LABEL_FONT_COLOR = Color(1.0, 1.0, 1.0, 1.0)
const ALLY_PROGRESS_BAR_COLOR = Color(0.506, 0.718, 0.365, 1.0)
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
@onready var label_army_id: Label = %ArmyId

func _ready() -> void:
	add_to_group("armies")
	var camera = get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		control.scale = Vector2(1, 1)/camera.zoom
		if camera is Camera:
			control.visible = camera.zoom.x >= camera.SHOW_ARMY_COUNT_ZOOM
		else:
			control.visible = camera.zoom.x >= 2.0
	else:
		control.scale = Vector2.ONE
		control.visible = false
	$PerfectVision/CollisionShape2D.shape.radius = VISION_RANGE
	$ObfuscatedVision/CollisionShape2D.shape.radius = VISION_RANGE * OBFUSCATED_VISION_MULTIPLIER
	$ObfuscatedVision.area_entered.connect(_on_obfuscated_vision_entered)
	$ObfuscatedVision.area_exited.connect(_on_obfuscated_vision_exited)
	$PerfectVision.area_entered.connect(_on_perfect_vision_entered)
	$PerfectVision.area_exited.connect(_on_perfect_vision_exited)
	$Area2D.area_entered.connect(_on_area_entered)
	timer = get_node("/root/Game/GlobalTimer")
	timer.timeout.connect(_on_global_timer_timeout)
	day_timer = get_node("/root/Game/GlobalDayTimer")
	day_timer.timeout.connect(_on_global_day_timer_timeout)
	
	direction_line.top_level = true
	direction_line_partial.top_level = true
	
	var game: GameController = get_tree().current_scene
	if is_instance_valid(game):
		if is_instance_valid(game.hud) and not game.hud.view_changed.is_connected(_on_view_changed):
			game.hud.view_changed.connect(_on_view_changed)
		_on_view_changed(game.view)
	
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
	
	label_army_id.text = str(army_id)
		
	var game: GameController = get_tree().current_scene
	if game.view != null and player in game.view.player_in_war:
		label_panel_style_box.bg_color = ENEMY_LABEL_BACKGROUND
		label_panel.remove_theme_stylebox_override("panel")
		label_panel.add_theme_stylebox_override("panel", label_panel_style_box)
		label.remove_theme_color_override("font_color")
		label.add_theme_color_override("font_color", ENEMY_LABEL_FONT_COLOR)
		label.remove_theme_color_override("font_outline_color")
		label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
		progress_bar_style_box.bg_color = ENEMY_PROGRESS_BAR_COLOR
		progress_bar.remove_theme_stylebox_override("fill")
		progress_bar.add_theme_stylebox_override("fill", progress_bar_style_box)
	elif game.view != null and player in game.view.player_in_alliance:
		label_panel_style_box.bg_color = ALLY_LABEL_BACKGROUND
		label_panel.remove_theme_stylebox_override("panel")
		label_panel.add_theme_stylebox_override("panel", label_panel_style_box)
		label.remove_theme_color_override("font_color")
		label.add_theme_color_override("font_color", ALLY_LABEL_FONT_COLOR)
		progress_bar_style_box.bg_color = ALLY_PROGRESS_BAR_COLOR
		progress_bar.remove_theme_stylebox_override("fill")
		progress_bar.add_theme_stylebox_override("fill", progress_bar_style_box)
	else:
		label_panel_style_box.bg_color = NEUTRAL_LABEL_BACKGROUND
		label_panel.remove_theme_stylebox_override("panel")
		label_panel.add_theme_stylebox_override("panel", label_panel_style_box)
		label.remove_theme_color_override("font_color")
		progress_bar_style_box.bg_color = NEUTRAL_PROGRESS_BAR_COLOR
		progress_bar.remove_theme_stylebox_override("fill")
		progress_bar.add_theme_stylebox_override("fill", progress_bar_style_box)

func _input(_event):
	if Input.is_action_just_pressed("camera_zoom_in") or Input.is_action_just_pressed("camera_zoom_out"):
		control.scale = Vector2(1,1)/get_viewport().get_camera_2d().zoom

func _on_friendly_collision(other: Army) -> void:
	if other.player in player.player_in_alliance: return
	if not travelling or other.travelling: return
	if nodes_travelled < len(path) - 1: return
	
	var path_points = get_parent().curve
	if direction == 1 and path_points.get_point_position(path_points.point_count - 1) == other.position or direction == -1 and path_points.get_point_position(0) == other.position:
		other.merge_armies(self)

func _on_enemy_collision(other: Army) -> void:
	if not is_instance_valid(other): return
	travelling = false
	other.travelling = false
	if not active_battles.has(other) and not other.active_battles.has(self):
		begin_attack(other)
		
func _on_global_timer_timeout() -> void:
	if travelling:
		if (self.progress_ratio != 1.0 and direction == 1) or (self.progress_ratio != 0.0 and direction == -1):
			self.progress += current_speed * direction
			_update_direction_lines()
		else:
			nodes_travelled += 1
			
			var next_pos = _get_next_path_position()
			if next_pos != Vector2.ZERO:
				emit_signal("movement_updated", next_pos)
				
			if nodes_travelled == len(path):
				travelling = false
				path = null
				emit_signal("movement_updated", Vector2.ZERO)
				_on_destination_reached()
				return
			
			if province_location != null and not player.get_province_owner(province_location) and province_location.get_city_position() == position:
				var owner = province_location.get_parent()
				if owner is Agent:
					if owner not in player.player_in_alliance and owner not in player.player_in_war:
						player.declare_war(owner)
					if owner in player.player_in_war:
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
			_update_direction_lines()
			if is_instance_valid(player):
				player.dispatch_my_army_update(self)
			
func _on_destination_reached() -> void:
	if target_province != null:
		province_location = target_province
	target_province = null
	_update_direction_lines()
	if province_location == null:
		var all_provinces = get_tree().get_nodes_in_group("provinces")
		for prov in all_provinces:
			if prov is Province and prov.to_global(prov.get_city_position()).distance_to(global_position) < 10.0:
				province_location = prov
				break
	if province_location == null: return
	
	for el in player.armies:
		if el != self and is_instance_valid(el) and not el.travelling:
			if el.province_location == province_location or el.global_position.distance_to(global_position) < 10.0:
				el.province_location = province_location
				el.merge_armies(self)
				return
			
	if not player.get_province_owner(province_location):
		var owner = province_location.get_parent()
		if owner is Agent:
			if owner not in player.player_in_alliance and owner not in player.player_in_war:
				player.declare_war(owner)
			if owner in player.player_in_war:
				var game: GameController = get_tree().current_scene
				game.conquer_province(province_location, player)
			
	if is_instance_valid(player):
		player.dispatch_my_army_update(self)
	var game: GameController = get_tree().current_scene
	if game != null and province_location != null and province_location is Province:
		game.notify_province_defense_change(province_location)

func check_and_merge_stationary() -> bool:
	if travelling or not is_instance_valid(player) or province_location == null: return false
	for el in player.armies:
		if el != self and is_instance_valid(el) and not el.travelling:
			if el.province_location == province_location or el.global_position.distance_to(global_position) < 10.0:
				if el.army_id < self.army_id:
					el.province_location = province_location
					el.merge_armies(self)
					return true
	return false

func _on_global_day_timer_timeout() -> void:
	if check_and_merge_stationary():
		return
	if day_battle or not player.get_province_owner(province_location): 
		day_battle = false
		return
	
	var old_life = life_points
	if province_location.province_morale > 80:
		life_points += life_points * 0.05
	elif province_location.province_morale < 20:
		life_points += life_points * 0.01
	else:
		life_points += life_points * 0.02
		
	if life_points != old_life and is_instance_valid(player):
		player.dispatch_my_army_update(self)
		
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
	
func _on_area_entered(area: Area2D) -> void:
	var other: Node = area.get_parent()
	if other is Army:
		if travelling and not other.travelling:
			if player != other.player and other.player not in player.player_in_alliance and other.player not in player.player_in_war:
				var prov = other.province_location
				if prov != null and prov is Province:
					var prov_owner = prov.get_parent()
					if prov_owner is Agent and prov_owner != player and prov_owner not in player.player_in_alliance:
						player.declare_war(other.player)
		
		if player == other.player or other.player not in player.player_in_war:
			_on_friendly_collision(other)
		else:
			_on_enemy_collision(other)
	
func _notification(what: int) -> void:
	if what != NOTIFICATION_PARENTED and what != NOTIFICATION_PREDELETE: return

	if what == NOTIFICATION_PARENTED:
		province_location = get_parent().get_parent()
		if player.get_province_owner(province_location) or (province_location.get_parent() is Agent and province_location.get_parent() in player.player_in_alliance):
			current_speed = SPEED * ALLY_TERRITORY_SPEED_MULTIPLIER
		elif province_location is Background:
			current_speed = SPEED * SEA_SPEED_MULTIPLIER
		else:
			current_speed = SPEED * ENEMY_TERRITORY_SPEED_MULTIPLIER
	elif what == NOTIFICATION_PREDELETE:
		destroyed = true
		emit_signal("army_destroyed", self)
		if is_instance_valid(player):
			var msg: Dictionary = {
				"type": "sight",
				"sender": "body",
				"receiver": player.name,
				"data": {
					"type": "my_army_destroyed",
					"id": army_id
				}
			}
			player.send_vesna_message(msg)
		var game: GameController = get_tree().current_scene
		if game != null and province_location != null and province_location is Province:
			game.notify_province_defense_change(province_location)
		
func _on_battle_timer_timeout(other: Army, battle_timer: Timer) -> void:
	var random_attacker_multiplier: float = rng.randf_range(0.5, 1.5)
	var random_defender_multiplier: float = rng.randf_range(0.5, 1.5)
	var attacker_strength: float = 0.0
	if soldier_number > 0:
		attacker_strength = (soldier_number * ATTACK_PER_UNIT) * life_points / (soldier_number * LIFE_PER_UNIT)
	var defener_strength: float = 0.0
	if is_instance_valid(other) and other.soldier_number > 0:
		defener_strength = (other.soldier_number * other.DEFENSE_PER_UNIT) * other.life_points / (other.soldier_number * other.LIFE_PER_UNIT)
	var final_attack: float = attacker_strength * random_attacker_multiplier
	var final_defense: float = defener_strength * random_defender_multiplier
	
	life_points -= final_defense
	soldier_number -= int(final_defense / LIFE_PER_UNIT)
	death_count += int(final_defense / LIFE_PER_UNIT)
	
	if is_instance_valid(other):
		other.life_points -= final_attack
		other.soldier_number -= int(final_attack / other.LIFE_PER_UNIT)
		other.death_count += int(final_attack / other.LIFE_PER_UNIT)

	var battle_finished: bool = false
	if not is_instance_valid(other) or other.soldier_number <= 0 or other.life_points <= 0:
		if is_instance_valid(other):
			other.destroy_self()
		battle_finished = true
	else:
		other.queue_redraw()
		if is_instance_valid(other.player):
			other.player.dispatch_my_army_update(other)
	
	if (soldier_number <= 0 or life_points <= 0) and not battle_finished:
		destroy_self()
		battle_finished = true
	else:
		queue_redraw()
		if is_instance_valid(player):
			player.dispatch_my_army_update(self)
	
	if battle_finished or not is_instance_valid(other):
		_end_battle_with(other, battle_timer)
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
	destroyed = true
	for enemy in active_battles.keys():
		var b_timer = active_battles[enemy]
		if is_instance_valid(b_timer):
			b_timer.stop()
			b_timer.queue_free()
	active_battles.clear()
	day_battle = false
	for i in range(len(player.armies)):
		if player.armies[i] != self: continue
		player.armies.remove_at(i)
		break
	queue_free()
		
func _get_morale_percentage() -> float:
	return life_points/((soldier_number+death_count)*LIFE_PER_UNIT)*100

func begin_attack(other: Army) -> void:
	if not is_instance_valid(other) or other == self: return
	if active_battles.has(other) or other.active_battles.has(self): return
	
	var battle_timer := Timer.new()
	battle_timer.wait_time = ATTACK_TIME
	battle_timer.one_shot = true
	battle_timer.timeout.connect(_on_battle_timer_timeout.bind(other, battle_timer))
	add_child(battle_timer)
	active_battles[other] = battle_timer
	day_battle = true
	other.day_battle = true
	
	if not other.army_destroyed.is_connected(_on_enemy_destroyed.bind(battle_timer)):
		other.army_destroyed.connect(_on_enemy_destroyed.bind(battle_timer))
		
	_on_battle_timer_timeout(other, battle_timer)

func _end_battle_with(other: Army, battle_timer: Timer) -> void:
	if is_instance_valid(battle_timer):
		battle_timer.stop()
		battle_timer.queue_free()
	if other != null and active_battles.has(other):
		active_battles.erase(other)
	day_battle = (active_battles.size() > 0)
	if is_instance_valid(other):
		if other.active_battles.has(self):
			other.active_battles.erase(self)
		other.day_battle = (other.active_battles.size() > 0)
	if active_battles.is_empty() and not destroyed:
		if path != null and len(path) > 0 and not travelling:
			travelling = true
			_update_direction_lines()
			if is_instance_valid(player):
				player.dispatch_my_army_update(self)

func _on_enemy_destroyed(destroyed_army: Army, battle_timer: Timer) -> void:
	_end_battle_with(destroyed_army, battle_timer)
	
func merge_armies(other: Army) -> void:
	soldier_number += other.soldier_number
	life_points += other.life_points
	other.destroy_self()
	queue_redraw()
	if is_instance_valid(player):
		player.dispatch_my_army_update(self)
	var game: GameController = get_tree().current_scene
	if game != null and province_location != null and province_location is Province:
		game.notify_province_defense_change(province_location)

func split(soldiers_to_split: int) -> Army:
	if soldiers_to_split <= 0 or soldiers_to_split >= soldier_number:
		return null
		
	var ratio = float(soldiers_to_split) / float(soldier_number)
	var split_life_points = life_points * ratio
	
	soldier_number -= soldiers_to_split
	life_points -= split_life_points
	queue_redraw()
	if is_instance_valid(player):
		player.dispatch_my_army_update(self)
	
	var game: GameController = get_tree().current_scene
	var new_army: Army = null

	if not travelling and province_location != null and province_location is Province and game != null:
		new_army = game.add_army_to_province(province_location, null, soldiers_to_split, true)
		new_army.life_points = split_life_points
		if is_instance_valid(player):
			player.dispatch_my_army_update(new_army)
		return new_army

	var army_scene = load("res://scenes/army.tscn")
	new_army = army_scene.instantiate()
	new_army.army_id = player.next_army_id
	player.next_army_id += 1
	new_army.soldier_number = soldiers_to_split
	new_army.life_points = split_life_points
	new_army.player = player
	new_army.province_location = province_location
	player.armies.append(new_army)
	
	get_parent().add_child(new_army)
	new_army.position = position
	new_army.progress = self.progress
	new_army.progress_ratio = self.progress_ratio
	
	if travelling:
		new_army.path = path
		new_army.nodes_travelled = nodes_travelled
		new_army.direction = direction
		new_army.travelling = true
		new_army.direction_line.default_color = MOVE_LINE_COLOR
		new_army.direction_line_partial.default_color = ATTACK_LINE_COLOR
		new_army._update_direction_lines()
	
	if game != null:
		game.register_army(new_army)
		
	if is_instance_valid(new_army.player):
		new_army.player.dispatch_my_army_update(new_army)
	if game != null and province_location != null and province_location is Province:
		game.notify_province_defense_change(province_location)
	return new_army
	
func has_reached_destination() -> bool:
	return path == null
	
func _get_next_path_position() -> Vector2:
	if path != null and len(path) > nodes_travelled + 1:
		var point_path_next: Path2D = player.graph_to_path[path[nodes_travelled + 1]][0]
		var path_point_next: int = player.graph_to_path[path[nodes_travelled + 1]][1]
		return point_path_next.to_global(point_path_next.curve.get_point_position(path_point_next))
	return Vector2.ZERO
	
func order(city: Province) -> void:
	if travelling and path != null and len(path) > 0:
		var last_node = path[len(path) - 1]
		var point_path: Path2D = player.graph_to_path[last_node][0]
		var path_point: int = player.graph_to_path[last_node][1]
		var current_dest = point_path.to_global(point_path.curve.get_point_position(path_point))
		var new_dest = city.to_global(city.get_city_position())
		if current_dest.distance_to(new_dest) < 1.0:
			return

	var start: int = player.routes.get_closest_point(global_position)
	var target: int = player.routes.get_closest_point(city.to_global(city.get_city_position()))
	var points: PackedInt64Array = player.routes.get_id_path(start, target, false)
	if len(points) == 0: return
	var new_path: Path2D = player.graph_to_path[points[0]][0]
	var point: int = player.graph_to_path[points[0]][1]
	var dir = new_path.get_point_direction(point)
	if get_parent() != new_path:
		reparent(new_path)
		
	var distance = new_path.curve.get_point_position(point).distance_to(position)
	if dir == -1:
		self.progress = distance
	else:
		self.progress = new_path.curve.get_point_position(point).distance_to(new_path.curve.get_point_position(0)) - distance
	var prev_loc = province_location
	province_location = null
	direction = dir
	path = points
	nodes_travelled = 0
	travelling = true
	target_province = city
	
	direction_line.default_color = MOVE_LINE_COLOR
	direction_line_partial.default_color = ATTACK_LINE_COLOR
	_update_direction_lines()
	
	var next_pos = _get_next_path_position()
	if next_pos != Vector2.ZERO:
		emit_signal("movement_updated", next_pos)
	if is_instance_valid(player):
		player.dispatch_my_army_update(self)
	var game: GameController = get_tree().current_scene
	if game != null and prev_loc != null and prev_loc is Province:
		game.notify_province_defense_change(prev_loc)

func _update_direction_lines() -> void:
	if not travelling or path == null or len(path) == 0:
		direction_line.clear_points()
		direction_line_partial.clear_points()
		return
	
	var game: GameController = get_tree().current_scene
	if is_instance_valid(game):
		_on_view_changed(game.view)
	
	direction_line.clear_points()
	direction_line.add_point(global_position)
	for i in range(nodes_travelled, len(path)):
		var graph_point = path[i]
		var point_path: Path2D = player.graph_to_path[graph_point][0]
		var path_point: int = player.graph_to_path[graph_point][1]
		var global_pt = point_path.to_global(point_path.curve.get_point_position(path_point))
		direction_line.add_point(global_pt)
		
	direction_line_partial.clear_points()
	if nodes_travelled < len(path):
		direction_line_partial.add_point(global_position)
		var next_point = path[nodes_travelled]
		var next_point_path: Path2D = player.graph_to_path[next_point][0]
		var next_path_point: int = player.graph_to_path[next_point][1]
		var next_global_pt = next_point_path.to_global(next_point_path.curve.get_point_position(next_path_point))
		direction_line_partial.add_point(next_global_pt)
