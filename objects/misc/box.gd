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
	$Weight.position.z = size.z * 0.5 + 0.002
	$Weight.pixel_size = size.x * 0.01

func _ready():
	$Weight.text = "%d Kg" % [ mass ]
	_update_size()
