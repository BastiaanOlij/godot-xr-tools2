#-------------------------------------------------------------------------------
# xrt2_collision_finger.gd
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

class_name XRT2CollisionFinger
extends RigidBody3D

## If disabled we will not do our collision detection
@export var enabled : bool = true

## Our parent bone rigid body
@export var parent_body : RigidBody3D

## Our target transform
@export var target_transform : Transform3D

@export var enable_force : bool = false
@export var force_coef : float = 1.0

@export var enable_torque : bool = true
@export var torque_coef : float = 1.0

func _ready():
	process_physics_priority = -91
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	linear_damp = 0.0
	angular_damp = 100.0

func _physics_process(delta):
	var parent : PhysicsBody3D = get_parent()
	if not parent:
		return

	# Copy some stuff from our parent
	if collision_layer != parent.collision_layer:
		collision_layer = parent.collision_layer
	if collision_mask != parent.collision_mask:
		collision_mask = parent.collision_mask

	# Sync exceptions
	var current_exceptions : Array[PhysicsBody3D] = get_collision_exceptions()
	var needed_exceptions : Array[PhysicsBody3D] = parent.get_collision_exceptions()

	# We must have an exception with our parent
	needed_exceptions.push_back(parent)
	# Never an exception with ourselves!
	needed_exceptions.erase(self)

	# Add exceptions we need
	for exception : PhysicsBody3D in needed_exceptions:
		if current_exceptions.has(exception):
			# We have it!
			current_exceptions.erase(exception)
		elif is_instance_valid(exception):
			exception.add_collision_exception_with(self)
			self.add_collision_exception_with(exception)

	# Remove exceptions we no longer want
	for exception : PhysicsBody3D in current_exceptions:
		exception.remove_collision_exception_with(self)
		self.remove_collision_exception_with(exception)

	# If our parent is frozen, we are frozen
	freeze = not enabled or parent.freeze

	var target : Transform3D = parent.global_transform * target_transform

	if freeze:
		global_transform = target
	else:
		if enable_force:
			var linear_movement : Vector3 = target.origin - global_position
			var force : Vector3 = linear_movement * force_coef
			apply_central_force(force)
			parent_body.apply_force(-force, global_position - parent_body.global_position)

		if enable_torque:
			# For now, we just care about rotation
			var angular_movement : Vector3 = (target.basis * global_basis.inverse()).get_euler()
			var torque : Vector3 = angular_movement * torque_coef

			apply_torque(torque)
