@tool
extends RigidBody3D

@export var size : Vector3 = Vector3(0.1, 0.1, 0.1):
	set(value):
		size = value
		if is_inside_tree():
			_update_size()

@export var color : Color = Color("e800ed"):
	set(value):
		color = value
		if is_inside_tree():
			_update_color()

func _update_size():
	$CollisionShape3D.shape.size = size
	$MeshInstance3D.mesh.size = size
	$Label3D.position.z = size.z * 0.5 + 0.002
	$RightGrabPoint.position.x = size.x * 0.5 + 0.025
	$LeftGrabPoint.position.x = -(size.x * 0.5 + 0.025)


func _update_color():
	var material : ShaderMaterial = $MeshInstance3D.material_override
	if material:
		material.set_shader_parameter("albedo", color)


func _ready():
	_update_size()
	_update_color()


func _process(_delta):
	$Label3D.text = "%0.1f Kg" % [ mass ]
