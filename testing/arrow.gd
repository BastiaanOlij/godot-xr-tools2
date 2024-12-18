@tool
extends Node3D

@export var color : Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		color = value
		
		if _material:
			_material.set_shader_parameter("albedo", color)

var _material : ShaderMaterial

func _ready():
	_material = $Staff.material_override
	if _material:
		_material.set_shader_parameter("albedo", color)
