extends Area2D

class_name Background

signal clear_province()

func _ready() -> void:
	add_to_group("background")
	
func _process(_delta: float) -> void:
	pass
