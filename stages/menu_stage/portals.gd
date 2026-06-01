@tool
extends Node3D

@export var distance: float = 25.0:
	set(value):
		distance = value
		if is_inside_tree():
			_update_positioning()

func _ready():
	if Engine.is_editor_hint():
		_update_positioning()

func _update_positioning():
	var count: int = get_child_count()
	var angle_step: float = TAU / float(count)
	var angle: float = 0.0

	for child in get_children():
		child.transform = Transform3D(Basis(), Vector3(0.0, 0.0, distance)).rotated(Vector3.UP, angle).looking_at(Vector3(), Vector3.UP, true)
		angle += angle_step

func _on_child_entered_tree(_node):
	_update_positioning()


func _on_child_exiting_tree(_node):
	_update_positioning()


func _on_child_order_changed():
	_update_positioning()
