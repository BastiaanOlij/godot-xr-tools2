@tool
extends StaticBody3D

@export var size : Vector3 = Vector3(0.1, 2.0, 2.0):
	set(value):
		size = value
		if is_inside_tree():
			_update_size()

@export var color : Color = Color("b39aee"):
	set(value):
		color = value
		if is_inside_tree():
			_update_color()

func _update_size():
	$CollisionShape3D.shape.size = size
	$CollisionShape3D.transform.origin = Vector3(0.0, size.y * 0.5, 0.0)
	$MeshInstance3D.mesh.size = size
	$MeshInstance3D.transform.origin = Vector3(0.0, size.y * 0.5, 0.0)
	var material : ShaderMaterial = $MeshInstance3D.material_override
	if material:
		var uv1_scale : Vector2 = Vector2(max(size.x, size.z), size.y)
		material.set_shader_parameter("uv1_scale", uv1_scale)


func _update_color():
	var material : ShaderMaterial = $MeshInstance3D.material_override
	if material:
		material.set_shader_parameter("albedo", color)


func _ready():
	_update_size()
	_update_color()
