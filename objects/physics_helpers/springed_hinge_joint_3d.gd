class_name SpringedHingeJoint3D
extends HingeJoint3D

@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var lower_spring_limit = -180.0
@export_range(0.0, 10.0, 0.01, "suffix:N") var lower_torque = 2.0
@export_range(-180.0, 180.0, 1.0, "radians_as_degrees") var higher_spring_limit = 180.0
@export_range(0.0, 10.0, 0.01, "suffix:N") var higher_torque = 2.0

var _rigid_body_b : RigidBody3D
var _start_vector : Vector3

func _ready():
	_rigid_body_b = get_node(node_b)
	if _rigid_body_b:
		var body_rotation : Basis = global_basis.inverse() * _rigid_body_b.global_basis
		_start_vector = body_rotation.x

func _physics_process(_delta):
	# Assume node B is the one we move
	if not _rigid_body_b:
		return

	var body_rotation : Basis = global_basis.inverse() * _rigid_body_b.global_basis
	var angle = body_rotation.x.angle_to(_start_vector)
	var cross = body_rotation.x.cross(_start_vector)
	if cross.z < 0.0:
		angle = -angle

	var torque : Vector3 = Vector3()
	if angle < lower_spring_limit and lower_torque > 0.0:
		torque.z = lower_torque
	elif angle > higher_spring_limit and higher_torque > 0.0:
		torque.z = -higher_torque

	if torque.z != 0.0:
		torque = global_basis * torque
		_rigid_body_b.apply_torque(torque)

	# TODO, if A isn't a StaticBody, we may need to apply a counter torque
