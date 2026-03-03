extends Area2D

signal clear_province()

func _ready() -> void:
	add_to_group("background")
	connect("input_event", Callable(self, "_on_input_event"))
	
func _on_input_event(_viewport, _event, _shape_idx):
	if _event is InputEventMouseMotion: return
	if Input.is_action_just_released("select_province") and not get_viewport().get_camera_2d().dragged:
		emit_signal("clear_province")

func _process(_delta: float) -> void:
	pass
