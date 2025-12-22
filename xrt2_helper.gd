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

################################################################################
# Helper functions for our physics

## Calculate the axis-angle rotation between two orientations.
static func rotation_to_axis_angle(start_orientation : Basis, end_orientation : Basis) -> Vector3:
	var delta_basis : Basis = end_orientation * start_orientation.inverse()
	var delta_quad : Quaternion = delta_basis.get_rotation_quaternion()
	var delta_axis : Vector3 = delta_quad.get_axis().normalized()
	var delta_angle : float = delta_quad.get_angle()

	return delta_axis * delta_angle


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
	var delta_axis_angle : Vector3 = XRT2Helper.rotation_to_axis_angle(apply_to.global_basis, global_target_orientation)
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
