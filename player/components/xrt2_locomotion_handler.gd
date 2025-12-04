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

@tool
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

@export_group("Physics")

## Effects how quickly we stop if we're on a floor and have no additional input
@export_range(0.01, 0.90, 0.01) var drag_factor = 0.1
#endregion

#region Private variables
# Character body node
var _character_body : CharacterBody3D

# Callbacks for on floor checks
var _on_floor_callbacks : Array[Callable]

# Callbacks for getting floor friction
var _floor_friction_callbacks : Array[Callable]
#endregion

#region Public functions
## Register an on floor callback
func register_on_floor_callback(callback : Callable):
	if not _on_floor_callbacks.has(callback):
		_on_floor_callbacks.push_back(callback)


## Unregister an on floor callback
func unregister_on_floor_callback(callback : Callable):
	if _on_floor_callbacks.has(callback):
		_on_floor_callbacks.erase(callback)


## Register an floor friction callback
func register_floor_friction_callback(callback : Callable):
	if not _floor_friction_callbacks.has(callback):
		_floor_friction_callbacks.push_back(callback)


## Unregister an floor friction callback
func unregister_floor_friction_callback(callback : Callable):
	if _floor_friction_callbacks.has(callback):
		_floor_friction_callbacks.erase(callback)


## Returns whether our character is on the floor.
## We may not be able to rely on CharacterBody3D.is_on_floor.
func is_on_floor() -> bool:
	for callback in _on_floor_callbacks:
		if callback.call():
			return true

	if not _character_body:
		return false

	return _character_body.is_on_floor()


## Returns our floor friction
func get_floor_friction() -> float:
	var has_floor_friction : bool = false
	var total_floor_friction : float = 0.0

	# It's likely we only have one callback but...
	for callback in _floor_friction_callbacks:
		has_floor_friction = true
		total_floor_friction += callback.call()

	if has_floor_friction:
		print(total_floor_friction)
		return total_floor_friction

	# No callback, assume full friction
	return 1.0
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

	# Apply floor friction
	var floor_friction : float = get_floor_friction()
	if floor_friction > 0.0:
		var local_velocity = _character_body.global_basis.inverse() * _character_body.velocity

		# Apply drag (note 60.0 assume 60 fps reference value
		var factor : float = 1.0 - clamp(floor_friction * 60.0 * delta * drag_factor, 0.0, 1.0)
		local_velocity *= Vector3(factor, 1.0, factor)

		_character_body.velocity = _character_body.global_basis * local_velocity

	# Request locomotion input
	_character_body.propagate_call(&"_process_locomotion", [delta])

	# Apply environmental gravity
	_character_body.velocity += _character_body.get_gravity() * delta

	_character_body.move_and_slide()

	_push_rigid_bodies()
#endregion
