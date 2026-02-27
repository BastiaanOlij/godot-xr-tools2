#-------------------------------------------------------------------------------
# xrt2_helper.gd
#-------------------------------------------------------------------------------
# MIT License
#
# Copyright (c) 2024-present Bastiaan Olij, Malcolm A Nixon and contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#-------------------------------------------------------------------------------


@tool
class_name XRT2Helper
extends Node

################################################################################
# Helper functions to access key nodes

## Find the ancestor XRController3D node for a given node.
static func get_xr_controller(p_node : Node3D) -> XRController3D:
	var parent = p_node.get_parent()
	while parent:
		if parent is XRController3D:
			return parent

		parent = parent.get_parent()

	# Not found
	return null


## Find the ancestor XRNode3D node for a given node.
static func get_xr_node(p_node : Node3D) -> XRNode3D:
	var parent = p_node.get_parent()
	while parent:
		if parent is XRNode3D:
			return parent

		parent = parent.get_parent()

	# Not found
	return null


## Find the ancestor XROrigin3D node for a given node.
static func get_xr_origin(p_node : Node3D) -> XROrigin3D:
	var parent = p_node.get_parent()
	while parent:
		if parent is XROrigin3D:
			return parent

		parent = parent.get_parent()

	# Not found
	return null


## Find the ancestor CharacterBody3D node for a given node.
static func get_character_body(p_node : Node3D) -> CharacterBody3D:
	var parent = p_node.get_parent()
	while parent:
		if parent is CharacterBody3D:
			return parent

		parent = parent.get_parent()

	# Not found
	return null


## Find the ancestor CollisionObject3D node for a given node.
static func get_collision_object(p_node : Node3D) -> CollisionObject3D:
	var parent = p_node.get_parent()
	while parent:
		if parent is CollisionObject3D:
			return parent

		parent = parent.get_parent()

	# Not found
	return null


################################################################################
# Helper functions for our physics

## Calculate the angle between two vector within the plane of another vector
static func angle_in_plane(p_plane_vector: Vector3, p_a: Vector3, p_b: Vector3) -> float:
	# Take the cross product with our plane vector
	var a: Vector3 = p_plane_vector.cross(p_a).normalized()
	var b: Vector3 = p_plane_vector.cross(p_b).normalized()

	# Now calculate the angle
	var angle = acos(a.dot(b))

	# Check alignment with plane vector
	var cross: Vector3 = a.cross(b).normalized()
	if cross.dot(p_plane_vector) < 0.0:
		angle = -angle

	return angle

## Calculate the axis-angle rotation between two orientations.
static func rotation_to_axis_angle(start_orientation : Basis, end_orientation : Basis) -> Vector3:
	var delta_basis : Basis = end_orientation * start_orientation.inverse()
	var delta_quad : Quaternion = delta_basis.get_rotation_quaternion()
	var delta_axis : Vector3 = delta_quad.get_axis().normalized()
	var delta_angle : float = delta_quad.get_angle()

	return delta_axis * delta_angle


## Calculate and apply force needed to move rigid body to target.
static func apply_force_to_target(
		delta: float,
		apply_to: RigidBody3D,
		global_target_position: Vector3,
		proportion: float = 1.0,
		parent_linear_velocity: Vector3 = Vector3(),
		parent_angular_velocity: Vector3 = Vector3(),
		parent_global_position: Vector3 = Vector3()
	):
	# Apply force to move hand to tracked location:
	# acceleration = (distance - current_velocity * t) / (0.5 * t²)
	var half_t2 = 0.5 * delta * delta

	# Grab our rigid body state.
	var state : PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(apply_to.get_rid())

	# Calculate the distance we need to travel
	var distance: Vector3 = global_target_position - apply_to.global_position

	# Add in required movement based on parent movement
	distance += parent_linear_velocity * delta

	# And add in required movement based on parent rotation.
	var angle : float = parent_angular_velocity.length()
	if angle > 0.0:
		var q : Quaternion = Quaternion(parent_angular_velocity / angle, angle * delta)
		var was_position = apply_to.global_position - parent_global_position
		var new_position = q * was_position
		distance += (new_position - was_position)

	# Now calculate our velocity
	var current_velocity = state.linear_velocity * clamp(1.0 - (state.total_linear_damp * delta), 0.0, 1.0)

	# Add our gravity.
	if state:
		current_velocity += state.total_gravity * delta

	# And calculate the required force and apply it
	var needed_acceleration : Vector3 = (distance - (current_velocity * delta)) / half_t2
	var linear_force : Vector3 = (0.5 / state.inverse_mass) * needed_acceleration # No idea why * 0.5???

	# Apply proportional
	linear_force = proportion * linear_force

	apply_to.apply_central_force(linear_force)


## Calculate and apply torque needed to orientate rigid body to target.
static func apply_torque_to_target(
		delta : float,
		apply_to: RigidBody3D,
		global_target_orientation : Basis,
		proportion : float = 1.0,
		parent_angular_velocity : Vector3 = Vector3(),
		parent_global_orientation : Basis = Basis()
	):
	# Apply torque to rotate hand to tracked orientation:
	var half_t2 = 0.5 * delta * delta

	# Grab our rigid body state.
	var state : PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(apply_to.get_rid())
	var moment_of_inertia: Vector3 = Vector3(1.0, 1.0, 1.0) / state.inverse_inertia

	var delta_axis_angle : Vector3 = XRT2Helper.rotation_to_axis_angle(apply_to.global_basis, global_target_orientation)
	var velocity : Vector3 = -apply_to.angular_velocity
	if parent_angular_velocity.length() > 0.0:
		# Localise and add our parents angular velocity
		velocity += apply_to.global_basis.inverse() * parent_global_orientation * parent_angular_velocity

	# Q: Shouldn't we subtract the current velocity?!?
	var needed_angular_acceleration : Vector3 = (delta_axis_angle + (velocity * delta)) / half_t2
	var torque : Vector3 = moment_of_inertia * needed_angular_acceleration * 0.5 # Why 0.5?

	# Apply as our torque
	apply_to.apply_torque(proportion * torque)


################################################################################
## Note, older PD related code below is unused but kept for reference

## Apply a linear force to a RigidBody based on a target location
static func apply_linear_force(
		delta : float,
		apply_to: RigidBody3D,
		global_target_position : Vector3,
		proportional_gain : float,
		derivative_gain : float,
		target_offset : Vector3 = Vector3(),
		parent_linear_velocity : Vector3 = Vector3(),
		parent_angular_velocity : Vector3 = Vector3(),
		parent_global_position : Vector3 = Vector3()
	):
	var target_global_offset = apply_to.global_basis * target_offset
	var original_position = apply_to.global_position + target_global_offset
	var delta_movement = global_target_position - original_position
	var velocity = -apply_to.linear_velocity

	# Add parent linear velocity
	velocity += parent_linear_velocity

	# And hand velocity resulting from rotation.
	# TODO: If stepped rotation is used, we overpower the system, possibly skip!
	var angle : float = parent_angular_velocity.length()
	if angle > 0.0:
		var q : Quaternion = Quaternion(parent_angular_velocity / angle, angle * delta)
		var was_position = original_position - parent_global_position
		var new_position = q * was_position
		velocity += (new_position - was_position) / delta

	if delta_movement.length() > 0.0 or velocity.length() > 0.0:
		# Calculate proportional term
		var p : Vector3 = delta_movement * proportional_gain

		# Calculate derivative term
		var d : Vector3 = velocity * derivative_gain

		var force = p + d

		# Apply mass!
		# force *= apply_to.mass

		# TODO: Restrict maximum force!

		# Apply force logic.
		# apply_to.apply_central_force(force)
		apply_to.apply_force(force, target_global_offset)


## Apply a torque force to a RigidBody based on a target orientation
static func apply_torque(
		delta : float,
		apply_to: RigidBody3D,
		global_target_orientation : Basis,
		proportional_gain : float,
		derivative_gain : float,
		target_offset : Basis = Basis(),
		parent_angular_velocity : Vector3 = Vector3(),
		parent_global_orientation : Basis = Basis()
	):
	var adjusted_target_orientation : Basis = global_target_orientation * target_offset.inverse()
	var delta_axis_angle : Vector3 = XRT2Helper.rotation_to_axis_angle(apply_to.global_basis, adjusted_target_orientation)
	var velocity : Vector3 = -apply_to.angular_velocity
	if parent_angular_velocity.length() > 0.0:
		# Localise and add our parents angular velocity
		velocity += apply_to.global_basis.inverse() * parent_global_orientation * parent_angular_velocity

	if delta_axis_angle.length() > 0.0 or velocity.length() > 0.0:
		# Calculate proportional term
		var p : Vector3 = delta_axis_angle * proportional_gain

		# Calculate derivative term
		var d : Vector3 = velocity * derivative_gain

		# Add together to get our input
		var pd = p + d

		# TODO: possibly apply inertia? Especially if we apply forces to held object

		# TODO: restrict maximum torque

		# Apply as our torque
		apply_to.apply_torque(pd)
