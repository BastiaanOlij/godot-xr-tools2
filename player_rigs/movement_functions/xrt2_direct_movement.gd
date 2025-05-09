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

## The action in the OpenXR action map or Godot input map that controls movement
## (for input map add entries with -x/+x/-y/+y suffixes)
@export var movement_action : String = "primary"

## Rotation speed based on X input (zero if no rotation wanted)
# TODO add stepped rotation option!
@export var rotation_speed : float = 1.0

## Forward movement speed based on Y input (zero out if no movement wanted)
@export var forward_movement_speed : float = 5.0

## Strafe movement speed based on X input (zero out if no movement wanted)
@export var strafe_movement_speed : float = 0.0

## Movement acceleration
@export var movement_acceleration : float = 15.0

# If we're a child of a controller, we limit our inputs to that controller
@onready var xr_controller : XRController3D = XRT2Helper.get_xr_controller(self)


# Verifies if we have a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if rotation_speed > 0.0 and strafe_movement_speed > 0.0:
		warnings.push_back("Both rotation speed and strafe speed is specified!")

	# Return warnings
	return warnings


## Called by player characters physics process.
func handle_movement(character_body : CharacterBody3D, delta : float):
	# If not enabled, ignore it (shouldn't be called)
	if !enabled:
		return

	var movement_input : Vector2 = Vector2()
	if xr_controller:
		# If we're a child of a specific controller, get the input from there
		movement_input = xr_controller.get_vector2(movement_action)
	else:
		# If we're not, check all controllers
		# TODO this should change to using proper (Open)XR API for this!
		var controllers = XRServer.get_trackers(XRServer.TRACKER_CONTROLLER)
		for controller_path in controllers:
			var controller : XRControllerTracker = controllers[controller_path]
			var input = controller.get_input(movement_action)
			if input and input is Vector2:
				movement_input += input

		# We also check our input map for traditional input in this case
		if InputMap.has_action(movement_action + "-x") and InputMap.has_action(movement_action + "+x"):
			movement_input.x += Input.get_axis(movement_action + "-x", movement_action + "+x")

		if InputMap.has_action(movement_action + "-y") and InputMap.has_action(movement_action + "+y"):
			movement_input.y += Input.get_axis(movement_action + "-y", movement_action + "+y")

	if movement_input.x != 0.0 and rotation_speed > 0.0:
		# Handle rotation
		var player_basis : Basis = character_body.global_basis
		character_body.global_basis = player_basis.rotated( \
			player_basis.y, \
			-movement_input.x * delta * rotation_speed)

	if character_body.is_on_floor() and (strafe_movement_speed > 0.0 or forward_movement_speed > 0.0):
		# This updates the velocity of our player according to our input
		# the actual movement is applied in xr_player_character

		var velocity : Vector3 = character_body.velocity

		# Now handle forward/backwards/left/right movement.
		var direction = character_body.global_transform.basis * Vector3(movement_input.x \
			* strafe_movement_speed, 0.0, -movement_input.y * forward_movement_speed)

		# TODO the code below needs to change in case the player is not standing upright

		# Add our current downwards movement to our movement direction
		direction.y += velocity.y

		velocity.x = move_toward(velocity.x, direction.x, delta * movement_acceleration)
		velocity.y = move_toward(velocity.y, direction.y, delta * movement_acceleration)
		velocity.z = move_toward(velocity.z, direction.z, delta * movement_acceleration)

		character_body.velocity = velocity
