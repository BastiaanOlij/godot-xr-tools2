#-------------------------------------------------------------------------------
# xrt2_locomotion_handler.gd
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

class_name XRT2LocomotionHandler
extends Node3D

## XRT2LocomotionHandler handles the players controller-based movement and
## applies this movement.
##
## Locomotion itself is handled by child nodes, for this _process_locomotion
## is called on child and sibling nodes before processing our move_and_slide.
##
## This object should be a child of a CharacterBody3D node.
## You should not implement your own physics handling on the parent.

#region Export variables
@export_group("Collisions", "collision_")

## Lets the player push rigid bodies
@export var collision_push_rigid_bodies : bool = true

## If push_rigid_bodies is enabled, provides a strength factor for the impulse
@export var collision_push_strength_factor : float = 1.0
#endregion

#region Private variables
# Character body node
var _character_body : CharacterBody3D
#endregion

#region Public functions
## Returns whether our character is on the floor.
## We may not be able to rely on CharacterBody3D.is_on_floor.
func is_on_floor() -> bool:
	if not _character_body:
		return false

	# TODO: Once we implement raycast floor check we need to change this.
	return _character_body.is_on_floor()
#endregion

#region Private functions
# Verifies our input movement handler has a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	# Check if parent is of the correct type
	var parent = get_parent()
	if not parent or not parent is CharacterBody3D:
		warnings.append("Parent node must be an CharacterBody3D node")

	# Return warnings
	return warnings


# Check if we're colliding with rigid bodies and exert a collision force on those.
func _push_rigid_bodies() -> void:
	# Check if we collided with rigid bodies and apply impulses to them to move them out of the way
	if collision_push_rigid_bodies:
		for idx in range(_character_body.get_slide_collision_count()):
			var with = _character_body.get_slide_collision(idx)
			var obj = with.get_collider()

			if obj is RigidBody3D:
				var rb : RigidBody3D = obj

				# Get our relative impact velocity
				var impact_velocity = _character_body.velocity - rb.linear_velocity

				# Determine the strength of the impulse we're about to give
				var strength = impact_velocity.dot(-with.get_normal(0)) * collision_push_strength_factor

				# Our impulse is applied in the opposite direction
				# of the normal of the surface we're hitting
				var impulse = -with.get_normal(0) * strength

				# Determine the location at which we're hitting in the object local space
				# but in global orientation
				var pos = with.get_position(0) - rb.global_transform.origin

				# And apply the impulse
				rb.apply_impulse(impulse, pos)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Get the Character body
	var parent = get_parent()
	if parent and parent is CharacterBody3D:
		_character_body = parent


# Called every physics frame
func _physics_process(delta) -> void:
	# Do not run if in the editor
	if Engine.is_editor_hint():
		set_process(false)
		return

	# Check for our character body
	if not _character_body:
		set_process(false)
		return

	# Request locomotion input
	_character_body.propagate_call(&"_process_locomotion", [delta])

	# Apply environmental gravity
	var gravity_state := PhysicsServer3D.body_get_direct_state(_character_body.get_rid())
	_character_body.velocity += gravity_state.total_gravity * delta

	_character_body.move_and_slide()

	_push_rigid_bodies()
#endregion
