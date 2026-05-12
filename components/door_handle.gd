extends AnimatableBody3D

@export var force_strength: float = 600.0

@onready var start_transform = transform
var is_picked_up: bool = false


func picked_up(by: XRT2Pickup):
	is_picked_up = true
	set_process(true)

	var xr_col_hand = by.get_xr_collision_hand()
	var parent: RigidBody3D = get_parent()
	if xr_col_hand and parent:
		# Add the door as a collision exception as well
		XRT2.add_collision_exception(xr_col_hand, parent)


func dropped(by: XRT2Pickup):
	is_picked_up = false

	var xr_col_hand = by.get_xr_collision_hand()
	var parent: RigidBody3D = get_parent()
	if xr_col_hand and parent:
		# Remove the door as a collision exception
		XRT2.remove_collision_exception(xr_col_hand, parent)


func _xr_custom_pickup_handler(pickup: XRT2Pickup, delta: float, controller_target: Transform3D, _global_target: Transform3D) -> bool:
	var parent: RigidBody3D = get_parent()
	if not parent:
		return true

	var parent_t = parent.global_transform
	var v_len = parent.angular_velocity.length()
	if v_len > 0.001:
		parent_t.basis = Basis(parent.angular_velocity / v_len, v_len * delta) * parent_t.basis

	var local_position = ((parent_t * start_transform).inverse() * (controller_target * pickup.transform)).origin
	local_position.z = local_position.z - 0.065 # Z position of Left/RightGrabPoint

	var val = clamp(local_position.y, -0.05, 0.0) / -0.05
	rotation = Vector3(0.0, 0.0, val * -0.25 * PI)

	# Unlock the door
	if parent.freeze and val > 0.75:
		parent.freeze = false

		$State.material_override.albedo_color = Color(0.0, 1.0, 0.0)

	# Apply force to door
	if not parent.freeze:
		var force: Vector3 = parent.global_basis.z * ((clamp(local_position.z, -0.05, 0.05) / 0.05) * delta * force_strength)
		var pos: Vector3 = parent.global_basis * (position * Vector3(1.0, 0.0, 0.0))

		parent.apply_force(force, pos)

	return true


func _process(delta):
	var parent: RigidBody3D = get_parent()
	if not is_picked_up:
		if rotation.z < -0.05:
			rotation.z = lerp(rotation.z, 0.0, clamp(delta * 20.0, 0.0, 1.0))
		elif rotation.z < 0.0:
			rotation.z = 0.0

	if parent and rotation.z == 0.0 and parent.rotation.length() <= 0.01:
		parent.rotation = Vector3(0.0, 0.0, 0.0)

		# Lock the door again
		if not parent.freeze:
			parent.freeze = true
			# TODO: Play fall in lock sound

		$State.material_override.albedo_color = Color(1.0, 0.0 if parent.freeze else 1.0, 0.0)

		if not is_picked_up:
			set_process(false)
