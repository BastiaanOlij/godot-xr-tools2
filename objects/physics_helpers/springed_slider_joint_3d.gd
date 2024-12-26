class_name SpringedSliderJoint3D
extends SliderJoint3D

@export var lower_distance : float = 0.0
@export_range(0.0, 20.0, 0.01, "suffix:N") var lower_force : float = 0
@export var upper_distance : float = 0.0
@export_range(0.0, 20.0, 0.01, "suffix:N") var upper_force : float = 0

var _rigid_body_b : RigidBody3D
var _start_pos : Vector3

func _ready():
	_rigid_body_b = get_node(node_b)
	if _rigid_body_b:
		_start_pos = global_transform.inverse() * _rigid_body_b.global_position

func _physics_process(_delta):
	if _rigid_body_b:
		var new_pos : Vector3 = global_transform.inverse() * _rigid_body_b.global_position
		var movement : Vector3 = new_pos - _start_pos

		var force : Vector3 = Vector3()
		if movement.x < lower_distance and lower_force > 0.0:
			force.x = -lower_force
		elif movement.x > upper_distance and upper_force > 0.0:
			force.x = upper_force

		if force.x != 0.0:
			force = global_basis * force
			_rigid_body_b.apply_force(force)
