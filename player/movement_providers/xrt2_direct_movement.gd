#-------------------------------------------------------------------------------
# xrt2_direct_movement.gd
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
class_name XRT2DirectMovement
extends XRT2MovementProvider

## XRT2DirectMovement is a movement provider that implements virtual movement
## using controller input.
##
## It can be used for turning and strafing.
##
## When added as a child to a controller or collision hand node,
## input will be taken from that node. 
##
## If added directly to the character body, any controller input is used.

#region Export variables
## The action in the OpenXR action map or Godot input map that controls movement
## (for input map add entries with -x/+x/-y/+y suffixes)
@export var movement_action : String = "primary"

## Rotation speed based on X input (zero if no rotation wanted)
@export_range(0.0, 180.0, 0.1, "radians_as_degrees", "suffix:°/s") var rotation_speed : float = deg_to_rad(90)

## Step degrees for step turning (zero out for smooth turning)
@export_range(0.0, 180.0, 0.1, "radians_as_degrees") var rotation_step_angle : float = 0.0

## Forward movement speed based on Y input (zero out if no movement wanted)
@export_range(0.0, 100.0, 0.1, "suffix:m/s") var forward_movement_speed : float = 5.0

## Strafe movement speed based on X input (zero out if no movement wanted)
@export_range(0.0, 100.0, 1.0, "suffix:m/s") var strafe_movement_speed : float = 0.0

## Movement acceleration
@export var movement_acceleration : float = 15.0
#endregion

#region Private variables
# If we're a child of a controller, we limit our inputs to that controller
var _xr_collision_hand : XRT2CollisionHand
var _xr_controller : XRController3D

# Accumulated rotation for step turn
var _accumulated_rotation : float = 0.0
#endregion

#region Private functions
# Verifies if we have a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()

	if rotation_speed > 0.0 and strafe_movement_speed > 0.0:
		warnings.push_back("Both rotation speed and strafe speed is specified!")

	# Return warnings
	return warnings


# Validate our properties
func _validate_property(property: Dictionary):
	if property.name == "rotation_step_angle" and rotation_speed == 0.0:
		property.usage = PROPERTY_USAGE_NONE


# Node was added to our scene tree
func _enter_tree():
	super._enter_tree()

	_xr_collision_hand = XRT2CollisionHand.get_xr_collision_hand(self)
	if not _xr_collision_hand:
		_xr_controller = XRT2Helper.get_xr_controller(self)


# Node was removed from our scene tree
func _exit_tree():
	super._exit_tree()

	_xr_collision_hand = null
	_xr_controller = null


## Called by our locomotion handler.
func _process_locomotion(delta : float) -> void:
	# If not enabled, ignore it.
	if not enabled or not _character_body or not _locomotion_handler:
		return

	var movement_input : Vector2 = Vector2()
	if _xr_collision_hand:
		# If we're a child of a collision hand, get the input from there
		var input : Variant = _xr_collision_hand.get_input(movement_action)
		if input:
			movement_input = input as Vector2
	elif _xr_controller:
		# If we're a child of a specific controller, get the input from there
		movement_input = _xr_controller.get_vector2(movement_action)
	else:
		# If we're not, check all controllers
		# TODO this should change to using proper (Open)XR API for this!
		var controller_count = 0
		var controllers = XRServer.get_trackers(XRServer.TRACKER_CONTROLLER)
		for controller_path in controllers:
			var controller : XRControllerTracker = controllers[controller_path]
			var input = controller.get_input(movement_action)
			if input and input is Vector2:
				movement_input += input
				controller_count += 1

		if controller_count > 0:
			movement_input /= controller_count

		# We also check our input map for traditional input in this case
		if InputMap.has_action(movement_action + "-x") and InputMap.has_action(movement_action + "+x"):
			movement_input.x += Input.get_axis(movement_action + "-x", movement_action + "+x")

		if InputMap.has_action(movement_action + "-y") and InputMap.has_action(movement_action + "+y"):
			movement_input.y += Input.get_axis(movement_action + "-y", movement_action + "+y")

	# Handle rotation
	if movement_input.x != 0.0 and rotation_speed > 0.0:
		_accumulated_rotation += -movement_input.x * delta * rotation_speed
		if abs(_accumulated_rotation) > rotation_step_angle:
			var player_basis : Basis = _character_body.global_basis
			_character_body.global_basis = player_basis.rotated( \
				player_basis.y, \
				_accumulated_rotation)

			_accumulated_rotation = 0.0
	else:
		# Reset this.
		_accumulated_rotation = 0.0

	# Handle movement
	if _locomotion_handler.is_on_floor() and (strafe_movement_speed > 0.0 or forward_movement_speed > 0.0):
		# This updates the velocity of our player according to our input
		# the actual movement is applied in XRT2LocomotionHandler

		# Make sure we apply our velocity in the local orientation of our character body.
		var local_velocity : Vector3 = _character_body.global_basis.inverse() * _character_body.velocity

		# Handle forward/backwards/left/right movement.
		var direction = Vector3(movement_input.x * strafe_movement_speed, 0.0, \
				-movement_input.y * forward_movement_speed)

		local_velocity.x = move_toward(local_velocity.x, direction.x, delta * movement_acceleration)
		local_velocity.z = move_toward(local_velocity.z, direction.z, delta * movement_acceleration)

		# Now apply velocity in global orientation.
		_character_body.velocity = _character_body.global_basis * local_velocity
#endregion
