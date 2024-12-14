@tool
extends RigidBody3D

@export var size : Vector3 = Vector3(0.1, 0.1, 0.1):
	set(value):
		size = value
		if is_inside_tree():
			_update_size()

func _update_size():
	$CollisionShape3D.shape.size = size
	$MeshInstance3D.mesh.size = size
	$LeftGrabPoint.position.x = -(size.x * 0.5 + 0.025)
	$RightGrabPoint.position.x = size.x * 0.5 + 0.025

func _ready():
	_update_size()
