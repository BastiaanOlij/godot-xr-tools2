#-------------------------------------------------------------------------------
# xrt2_force_body.gd
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
class_name XRT2ForceBody
extends AnimatableBody3D

## XRTools2 Force Body script
##
## This script enhances AnimatableBody3D with move_and_slide and the ability
## to push bodies by emparting forces on them.

## Force Body Collision
class ForceBodyCollision extends RefCounted:
	## Collider object
	var collider : Node3D

	## Collision point
	var position : Vector3

	## Collision normal
	var normal : Vector3

## Ignore collisions with first ancestor
@export var ignore_first_ancestor : bool = true

## Enables or disables pushing bodies
@export var push_bodies : bool = true

## Control the stiffness of the body
@export var stiffness : float = 10.0

## Control the maximum push force
@export var maximum_force : float = 0.5

## Maximum slides
@export var max_slides : int = 4


func _ready():
	if Engine.is_editor_hint():
		return

	# Make sure this is off or weird shit happens...
	sync_to_physics = false

	if ignore_first_ancestor:
		var parent = get_parent()
		while parent:
			if parent is PhysicsBody3D:
				add_collision_exception_with(parent)
				return

			parent = parent.get_parent()

## This function moves and slides along the [param move] vector. It returns
## information about the last collision, or null if no collision
func move_and_slide(move : Vector3) -> ForceBodyCollision:
	# Loop performing the movement steps
	var step_move := move
	var ret : ForceBodyCollision = null
	var last_body : RigidBody3D
	for step in max_slides:
		# Take the next step
		var collision := move_and_collide(step_move)

		# If we didn't collide with anything then we have finished the entire
		# move_and_slide operation
		if not collision:
			break

		# Save relevant collision information
		var collider := collision.get_collider()
		var postion := collision.get_position()
		var normal := collision.get_normal()

		# Save the collision information
		if not ret:
			ret = ForceBodyCollision.new()

		ret.collider = collider
		ret.position = postion
		ret.normal = normal

		# Calculate the next move
		var next_move := collision.get_remainder().slide(normal)

		# Handle pushing bodies
		if push_bodies:
			var body := collider as RigidBody3D
			if body and body == last_body:
				# Don't repeatedly hit the same body
				return ret

			if body:
				# Calculate the momentum lost by the collision
				var lost_momentum := step_move - next_move

				# TODO: We should consider the velocity of the body such that
				# we never push it away faster than our own velocity.

				# Apply the lost momentum as an impulse to the body we hit
				body.apply_impulse(
					(lost_momentum * stiffness).limit_length(maximum_force),
					position - body.global_position)

				# Remember we already collided with this
				last_body = body

		# Update the remaining movement
		step_move = next_move

		# Prevent bouncing back along movement path
		if next_move.dot(move) <= 0:
			break

	# Return the last collision data
	return ret
