extends Node3D

@export var offset_node : Node3D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if offset_node:
		visible = offset_node.position.length() > 0.01
