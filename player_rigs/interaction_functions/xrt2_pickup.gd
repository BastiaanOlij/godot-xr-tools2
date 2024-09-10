#-------------------------------------------------------------------------------
# xrt2_pickup.gd
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
class_name XRT2Pickup
extends Node3D


## XRTools2 Pickup Script
##
## This script implements logic for picking up physics objects.
## This script works best when childed to an [XRT2CollisionHand] object.

# TODO:
# - Right now we just pick up RigidBodies which then move with our hand.
#   The idea is to also be able to grab marked StaticBodies but we then keep
#   our hand attached to the static body and work with a movement provider
#   to allow allow body movement.
# - We need to communicate the weight of the [RigidBody3D] we pick up to
#   our collision hands so we can react to holding weighted objects
# - We need to deal with two handed pickup
# - We no longer have logic on our [RigidBody3D] so we need a static
#   interface to easily find out by what the [RigidBody3D] is held
# - We need to come up with a way to override finger positions that work
#   in combination with hand tracking, possibly turning off hand tracking
#   when we are holding an object. Ideally we should have an option to
#   automatically pose the hand correctly if no grab point is specified.
# - Need to re-introduce grab points with optional finger poses

# Class for storing our highlight overrule data
class HighlightOverrule extends RefCounted:
	var mesh_instance : MeshInstance3D
	var original_material : Material

# Class for storing copied collision data
class CopiedCollision extends RefCounted:
	var collision_shape : CollisionShape3D
	var org_transform : Transform3D

## If ticked we monitor for things we can pick up
@export var enabled : bool = true:
	set(value):
		enabled = value
		if is_inside_tree():
			_update_enabled()

## We only pick up items present in these physics layers
@export_flags_3d_physics var collision_mask = 1:
	set(value):
		collision_mask = value
		if is_inside_tree():
			_update_collision_mask()

## How far from our pickup function we check if there are items to pick up.
@export var detection_radius : float = 0.3:
	set(value):
		detection_radius = value
		if is_inside_tree():
			_update_detection_radius()

## The action we check when grabbing things
@export var grab_action : String = "grab"

## If false we need to continously hold our grab button, if true we toggle
## Note: with keyboard entry toggle is enforced
@export var grab_toggle : bool = false

# Node helpers
var _xr_origin : XROrigin3D
var _xr_controller : XRController3D
var _collision_hand : XRT2CollisionHand
var _detection_area : Area3D
var _collision_shape : CollisionShape3D
var _collision_sphere : SphereShape3D
var _remote_transform : RemoteTransform3D

var _editor_sphere : SphereMesh
var _editor_mesh_instance : MeshInstance3D

# Tween for animations
var _tween : Tween

# Tracks if our input is currently in grab mode (even if we're not holding anything)
var _is_grab : bool = false

# Remember if our XR action was pressed last frame
var _was_xr_pressed : bool = false

# What is currently our closest object
var _closest_object : PhysicsBody3D

# What are we holding
var _picked_up : PhysicsBody3D

# Original state of picked up object
var _original_freeze_mode : RigidBody3D.FreezeMode
var _original_collision_layer : int
var _original_collision_mask : int

# If true, we are the primary hand holding this object (for 2 handed)
var _is_primary : bool = false

# Active highlights
var _active_highlights : Array[HighlightOverrule]

# Our highlight material
var _highlight_material : ShaderMaterial = \
	preload("res://addons/godot-xr-tools2/shaders/highlight_by_vertex.material")

# Active copied collisions
var _active_copied_collisions : Array[CopiedCollision]

# Array of all current pickup handlers
static var _pickup_handlers : Array[XRT2Pickup]

# We only want one hand to highlight
static var _highlighted_bodies : Array[Node3D]


## Find which pickup handler has picked up this object
static func picked_up_by(what : PhysicsBody3D) -> XRT2Pickup:
	var by : XRT2Pickup
	for pickup : XRT2Pickup in _pickup_handlers:
		if pickup._picked_up == what:
			by = pickup

			# If this is our primary, return that
			if pickup._is_primary:
				return by

	# If we found one, it will be our secondary hand
	return by

## Returns true if we've picked up something (/are holding onto something)
func has_picked_up() -> bool:
	if is_instance_valid(_picked_up):
		return true
	return false


## Returns the object we're currently holding
func get_picked_up() -> PhysicsBody3D:
	if is_instance_valid(_picked_up):
		return _picked_up
	return null


## Returns true if we're the primary hand holding this object
func is_primary() -> bool:
	return _is_primary


# Update our enabled status
func _update_enabled():
	if _collision_sphere:
		_collision_shape.disabled = !enabled
	if _detection_area:
		_detection_area.monitoring = enabled

	# Q: Do we drop anything we're holding when disabled?


# Update our collision mask
func _update_collision_mask():
	if _detection_area:
		_detection_area.collision_mask = collision_mask


# Update our detection radius
func _update_detection_radius():
	if _collision_sphere:
		_collision_sphere.radius = detection_radius
	if _editor_mesh_instance:
		# Just scale it, prevents having to recreate mesh
		_editor_mesh_instance.scale = Vector3(detection_radius, detection_radius, detection_radius)


# Verifies if we have a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not XRT2Helper.get_xr_controller(self):
		warnings.push_back("This node requires an XRController3D as an anchestor.")

	# Collision hand is optional, no warning needed

	# Return warnings
	return warnings


# Called when the node enters the scene tree for the first time.
func _ready():
	# In editor, just create visual aid
	if Engine.is_editor_hint():
		var material : ShaderMaterial = ShaderMaterial.new()
		material.shader = preload("res://addons/godot-xr-tools2/shaders/unshaded_with_alpha.gdshader")
		material.set_shader_parameter("albedo", Color("#00b6b71b"))

		_editor_sphere = SphereMesh.new()
		_editor_sphere.radius = 1.0
		_editor_sphere.height = 2.0
		_editor_sphere.radial_segments = 32
		_editor_sphere.rings = 16
		_editor_sphere.material = material

		_editor_mesh_instance = MeshInstance3D.new()
		_editor_mesh_instance.mesh = _editor_sphere
		add_child(_editor_mesh_instance, false, Node.INTERNAL_MODE_BACK)

		_update_detection_radius()
		return

	# Add this to our list of active pickup handlers
	_pickup_handlers.push_back(self)

	# Create our collision shape
	_collision_sphere = SphereShape3D.new()

	# Create our collision object
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = _collision_sphere

	# Create our area detection node
	_detection_area = Area3D.new()
	_detection_area.add_child(_collision_shape, false, Node.INTERNAL_MODE_FRONT)
	add_child(_detection_area, false, Node.INTERNAL_MODE_BACK)

	# Create remote transform
	_remote_transform = RemoteTransform3D.new()
	add_child(_remote_transform, false, Node.INTERNAL_MODE_BACK)

	_update_enabled()
	_update_collision_mask()
	_update_detection_radius()

	_xr_origin = XRT2Helper.get_xr_origin(self)
	_xr_controller = XRT2Helper.get_xr_controller(self)
	_collision_hand = XRT2CollisionHand.get_xr_collision_hand(self)


func _exit_tree():
	_remove_highlight()
	drop_held_object()

	# Remove us from the pickup handlers
	if _pickup_handlers.has(self):
		_pickup_handlers.erase(self)


# Returns a global transform for either our closest applicable grab point
# or point on collision shape we can grab the object (doesn't work yet)
func _get_closest_transform(body : PhysicsBody3D, to_point : Vector3) -> Transform3D:
	# Check any applicable grab point on the body first
	var closest_grab_point : XRT2GrabPoint
	var closest_dist : float = 9999.99
	for child in body.get_children():
		if child is XRT2GrabPoint:
			var grab_point : XRT2GrabPoint = child
			if not grab_point.left_hand and _xr_controller.get_tracker_hand() == \
				XRPositionalTracker.TRACKER_HAND_LEFT:
				continue
			elif not grab_point.right_hand and _xr_controller.get_tracker_hand() == \
				XRPositionalTracker.TRACKER_HAND_RIGHT:
				continue

			var dist = (grab_point.global_position - to_point).length_squared()
			if dist < closest_dist:
				closest_grab_point = grab_point
				closest_dist = dist

	if closest_grab_point:
		return closest_grab_point.global_transform

	# TODO If no grab points, we need to find a way to find the closest point on our collision shape

	# For now just return the bodies global transform
	return body.global_transform


func _get_closest() -> PhysicsBody3D:
	var overlapping_bodies = _detection_area.get_overlapping_bodies()
	var closest_body : PhysicsBody3D
	var closest_dist : float = 9999.99

	for body : Node3D in overlapping_bodies:
		if body.is_ancestor_of(self):
			# Ignore any of our parents
			continue
		elif _xr_origin.is_ancestor_of(body):
			# Ignore any children of our origin
			continue
		elif _highlighted_bodies.has(body) and not body == _closest_object:
			# Already highlighted but not by us
			continue
		elif picked_up_by(body):
			# Already picked up
			# TODO make exception for things we can pick up two handed (maybe all rigidbodies?).
			continue
		elif body is RigidBody3D and not body.freeze:
			# Always include rigidbodies unless already frozen
			pass
		elif body is StaticBody3D:
			# TODO implement a system for selectively including these
			# (or maybe switch on animatable body)
			continue
		else:
			# Skip anything else
			continue

		# See if this is our closest object
		var new_point = _get_closest_transform(body, global_position).origin
		var new_dist = (new_point - global_position).length_squared()
		if new_dist < closest_dist:
			closest_body = body
			closest_dist = new_dist

	return closest_body


func _add_highlight(node : Node3D):
	for child in node.get_children():
		if child is MeshInstance3D:
			var highlight : HighlightOverrule = HighlightOverrule.new()
			highlight.mesh_instance = child
			highlight.original_material = child.material_overlay
			_active_highlights.push_back(highlight)

			child.material_overlay = _highlight_material

		# Find mesh instances any level deep
		_add_highlight(child)


func _remove_highlight():
	# Return highlights to original materials
	for highlight : HighlightOverrule in _active_highlights:
		if is_instance_valid(highlight.mesh_instance):
			highlight.mesh_instance.material_overlay = highlight.original_material

	# And clear our array
	_active_highlights.clear()


func _copy_collisions(from : RigidBody3D):
	if not is_instance_valid(_collision_hand) or not is_instance_valid(_remote_transform):
		return

	for child in from.get_children():
		if child is CollisionShape3D:
			var copied_collision : CopiedCollision = CopiedCollision.new()
			copied_collision.collision_shape = CollisionShape3D.new()
			copied_collision.collision_shape.shape = child.shape
			copied_collision.org_transform = child.transform

			_collision_hand.add_child(copied_collision.collision_shape, false, Node.INTERNAL_MODE_BACK)
			copied_collision.collision_shape.transform = _remote_transform.transform * \
				copied_collision.org_transform

			_active_copied_collisions.push_back(copied_collision)


func _update_collision():
	if is_instance_valid(_collision_hand) and is_instance_valid(_remote_transform):
		for copied_collision : CopiedCollision in _active_copied_collisions:
			if is_instance_valid(copied_collision.collision_shape):
				copied_collision.collision_shape.transform = _remote_transform.transform * \
					copied_collision.org_transform


func _remove_collision():
	if is_instance_valid(_collision_hand):
		for copied_collision : CopiedCollision in _active_copied_collisions:
			if is_instance_valid(copied_collision.collision_shape):
				_collision_hand.remove_child(copied_collision.collision_shape)
				copied_collision.collision_shape.queue_free()

	_active_copied_collisions.clear()


func pickup_object(which : PhysicsBody3D):
	if not which is RigidBody3D:
		push_warning("Picking up objects other than Rigidbody is currently disabled.")
		return

	# No longer show highlighted
	_remove_highlight()

	if picked_up_by(which):
		_is_primary = false
	else :
		_is_primary = true

	# Remember state
	_picked_up = which
	_original_collision_layer = _picked_up.collision_layer
	_original_collision_mask = _picked_up.collision_mask

	if _is_primary:
		if _picked_up is RigidBody3D:
			_original_freeze_mode = _picked_up.freeze_mode

			# Don't control with physics engine, we're in control
			_picked_up.freeze = true
			_picked_up.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			_picked_up.collision_layer = 0
			_picked_up.collision_mask = 0

			# Setup our remote transform and sync location to our current picked up position
			_remote_transform.global_transform = _picked_up.global_transform
			_remote_transform.remote_path = _picked_up.get_path()

			# Determine the location we should be holding our object
			var dest_transform : Transform3D = _get_closest_transform(_picked_up, global_position)
			dest_transform = dest_transform.inverse() * _picked_up.global_transform

			# TODO should adjust our dest_transform to account for any offset in our hand mesh

			if _tween:
				_tween.kill()

			_tween = _remote_transform.create_tween()

			# Now tween
			_tween.tween_property(_remote_transform, "transform", dest_transform, 0.1)

			if _collision_hand:
				_copy_collisions(_picked_up)

				# TODO Should add weight to collision hand

		# TODO implement logic for other type of physics bodies
	else:
		# TODO implement secondary pickup
		pass


func drop_held_object( \
	apply_linear_velocity : Vector3 = Vector3(), apply_angular_velocity : Vector3 = Vector3() \
	) -> void:
	# Make sure we clear some initial state
	_remote_transform.remote_path = NodePath()
	_remove_collision()

	# TODO remove weight from collision hand

	if _tween:
		_tween.kill()
		_tween = null

	if is_instance_valid(_picked_up):
		# Process letting go
		_picked_up.collision_layer = _original_collision_layer
		_picked_up.collision_mask = _original_collision_mask

		if _picked_up is RigidBody3D:
			_picked_up.freeze_mode = _original_freeze_mode
			_picked_up.freeze = false
			_picked_up.linear_velocity = apply_linear_velocity
			_picked_up.angular_velocity = apply_angular_velocity

		# TODO add temporary exception for collisions with our hand


	# And we're no longer holding something
	_picked_up = null
	_is_primary = false


func _process(_delta):
	# Don't run in editor
	if Engine.is_editor_hint():
		return

	# If we don't have a controller ancestor, nothing we can do
	if not _xr_controller:
		return

	# if we're not tracking, do nothing
	if not _xr_controller.get_has_tracking_data():
		# We do not drop what we hold (right away)
		return

	# Object we picked up no longer exists? Drop it
	if _picked_up and not is_instance_valid(_picked_up):
		drop_held_object()

	# Our pickup handler is no longer enabled? Drop what we're holding
	if not enabled and _picked_up:
		var pose : XRPose = _xr_controller.get_pose()
		drop_held_object(pose.linear_velocity, pose.angular_velocity)

	# Check our grab status
	var was_grab = _is_grab
	var xr_grab_float : float = _xr_controller.get_float(grab_action)
	var threshold : float = 0.6 if _was_xr_pressed else 0.8
	var xr_pressed : bool = xr_grab_float > threshold
	if xr_pressed != _was_xr_pressed:
		_was_xr_pressed = xr_pressed
		if grab_toggle:
			_is_grab = not _is_grab
		else:
			_is_grab = xr_pressed
	elif InputMap.has_action(grab_action) and Input.is_action_just_pressed(grab_action):
		# Toggle
		_is_grab = not _is_grab

	if _picked_up:
		if _is_grab:
			_update_collision()
			return

		drop_held_object()
	elif not was_grab and _is_grab and _closest_object and is_instance_valid(_closest_object):
		pickup_object(_closest_object)
		return

	# Update closest object
	var was_closest_object = _closest_object
	_closest_object = _get_closest()

	if was_closest_object == _closest_object:
		# We're done
		return

	if was_closest_object and is_instance_valid(was_closest_object):
		# Remove highlight
		_highlighted_bodies.erase(was_closest_object)
		_remove_highlight()

	if _closest_object and is_instance_valid(_closest_object):
		# add highlight
		_highlighted_bodies.push_back(_closest_object)
		_add_highlight(_closest_object)
