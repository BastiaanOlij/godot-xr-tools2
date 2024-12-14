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
class HighlightedBody extends RefCounted:
	var original_materials : Dictionary[MeshInstance3D, Material]
	var pickups : Array[XRT2Pickup]

# Array of all current pickup handlers
static var _pickup_handlers : Array[XRT2Pickup]

# We only want one hand to highlight
static var _highlighted_bodies : Dictionary[Node3D, HighlightedBody]

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
var _xr_collision_hand : XRT2CollisionHand
var _xr_player_object : CollisionObject3D

var _detection_area : Area3D
var _collision_shape : CollisionShape3D
var _collision_sphere : SphereShape3D

# When picked up by collision hand
var _joint : Generic6DOFJoint3D

# When picked up by controller
var _remote_transform : RemoteTransform3D

# Visualisation in the editor
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

# Our highlight material
var _highlight_material : ShaderMaterial = \
	preload("res://addons/godot-xr-tools2/shaders/highlight_by_vertex.material")

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


## Pick up this object
func pickup_object(which : PhysicsBody3D):
	if not which is RigidBody3D:
		push_warning("Picking up objects other than Rigidbody is currently disabled.")
		return

	# No longer show highlighted
	_remove_highlight(which)

	if picked_up_by(which):
		_is_primary = false
	else :
		_is_primary = true

	# Make sure our body doesn't collide with things we've picked up
	if _is_primary and _xr_player_object:
		# TODO should create a collision exception manager to ensure we don't undo this too quickly
		which.add_collision_exception_with(_xr_player_object)
		_xr_player_object.add_collision_exception_with(which)

	# Remember state
	_picked_up = which
	_original_collision_layer = _picked_up.collision_layer
	_original_collision_mask = _picked_up.collision_mask

	if _xr_collision_hand:
		if _picked_up is RigidBody3D:
			# Remember our current hand transform
			var hand_transform : Transform3D = _xr_collision_hand.global_transform

			# Figure out our grab position
			var dest_transform : Transform3D = _get_closest_transform(_picked_up, global_position)
			var offset = get_parent().global_transform.inverse() * hand_transform

			# Now move our hand in the correct grab position
			_xr_collision_hand.global_transform = dest_transform * offset
			_xr_collision_hand.force_update_transform()

			# Now join our hand and the object we're picking up together
			_joint = Generic6DOFJoint3D.new()
			add_child(_joint, false, Node.INTERNAL_MODE_BACK)
			_joint.node_a = _xr_collision_hand.get_path()
			_joint.node_b = _picked_up.get_path()

			if _xr_collision_hand._hand_mesh:
				# Now position our hand mesh where our hand was
				_xr_collision_hand._hand_mesh.global_transform = hand_transform

				# And tween our hand mesh,
				# this should animate our hand moving to where we've grabbed it
				# while at the same time we pull our grabbed object to where our
				# hand is tracking 
				if _tween:
					_tween.kill()

				_tween = _xr_collision_hand._hand_mesh.create_tween()

				# Now tween
				_tween.tween_property(_xr_collision_hand._hand_mesh, "transform", Transform3D(), 0.1)

		else:
			# TODO implement other types of grab
			pass
	elif _xr_controller:
		# Old fashioned pickup, we use remote transform to pickup the object
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
				# TODO fix this transform now that we use our root node (see above)
				var dest_transform : Transform3D = _get_closest_transform(_picked_up, global_position)
				dest_transform = dest_transform.inverse() * _picked_up.global_transform

				# TODO should adjust our dest_transform to account for any offset in our hand mesh

				if _tween:
					_tween.kill()

				_tween = _remote_transform.create_tween()

				# Now tween
				_tween.tween_property(_remote_transform, "transform", dest_transform, 0.1)

			# TODO implement logic for other type of physics bodies
		else:
			# TODO implement secondary pickup
			pass

	# TODO set pose overrule based on what we've picked up (if applicable)

## Drop object we're currently holding
func drop_held_object( \
	apply_linear_velocity : Vector3 = Vector3(), apply_angular_velocity : Vector3 = Vector3() \
	) -> void:
	# Make sure we clear some initial state
	if _remote_transform:
		_remote_transform.remote_path = NodePath()

	if _tween:
		_tween.kill()
		_tween = null

	if not is_instance_valid(_picked_up):
		# Just in case
		_picked_up = null
		_is_primary = false
		return

	var was_picked_up = _picked_up

	# Process letting go
	if _xr_collision_hand:
		if _picked_up is RigidBody3D:
			if _joint:
				remove_child(_joint)
				_joint.queue_free()
				_joint = null

			if _tween:
				_tween.kill()

			if _xr_collision_hand._hand_mesh:
				_xr_collision_hand._hand_mesh.transform = Transform3D()

	elif _xr_controller:
		_picked_up.collision_layer = _original_collision_layer
		_picked_up.collision_mask = _original_collision_mask

		if _picked_up is RigidBody3D:
			_picked_up.freeze_mode = _original_freeze_mode
			_picked_up.freeze = false
			_picked_up.linear_velocity = apply_linear_velocity
			_picked_up.angular_velocity = apply_angular_velocity

	# And we're no longer holding something
	_picked_up = null
	_is_primary = false

	var other = picked_up_by(was_picked_up)
	if other:
		# If it isn't already primary, this is now our primary
		other._is_primary = true
	elif _xr_player_object:
		was_picked_up.add_collision_exception_with(_xr_player_object)
		_xr_player_object.add_collision_exception_with(was_picked_up)


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

	var xr_controller = XRT2Helper.get_xr_controller(self)
	var xr_collision_hand = XRT2CollisionHand.get_xr_collision_hand(self)

	if not xr_controller and not xr_collision_hand:
		warnings.push_back("This node requires an XRController3D or XRT2CollisionHand as an anchestor.")

	if xr_collision_hand:
		var bone_name = "LeftHand" if xr_collision_hand.hand == 0 else "RightHand"
		var parent = get_parent()
		if not parent is XRT2HandAttachment:
			warnings.push_back("This node's parent should be an XRT2HandAttachment when used with XRT2CollisionHand.")
		elif parent.bone_name != bone_name:
			warnings.push_back("The bone associated with XRT2HandAttachment should be set to %s." % [ bone_name ])

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

	_xr_origin = XRT2Helper.get_xr_origin(self)
	_xr_collision_hand = XRT2CollisionHand.get_xr_collision_hand(self)
	if _xr_collision_hand:
		_xr_player_object = _xr_collision_hand.get_collision_parent()
	else:
		_xr_controller = XRT2Helper.get_xr_controller(self)

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

	if _xr_collision_hand:
		pass
	elif _xr_controller:
		# Create remote transform
		_remote_transform = RemoteTransform3D.new()
		add_child(_remote_transform, false, Node.INTERNAL_MODE_BACK)

	_update_enabled()
	_update_collision_mask()
	_update_detection_radius()



func _exit_tree():
	_remove_highlight(_closest_object)
	drop_held_object()

	# Remove us from the pickup handlers
	if _pickup_handlers.has(self):
		_pickup_handlers.erase(self)


# Returns true if our pickup feature is attached to the left hand.
func _is_left_hand() -> bool:
	if _xr_collision_hand:
		return _xr_collision_hand.hand == 0
	elif _xr_controller:
		return _xr_controller.get_tracker_hand() == XRPositionalTracker.TRACKER_HAND_LEFT
	else:
		return false


# Returns a global transform for either our closest applicable grab point
# or point on collision shape we can grab the object (doesn't work yet)
func _get_closest_transform(body : PhysicsBody3D, to_point : Vector3) -> Transform3D:
	# Check any applicable grab point on the body first
	var is_left_hand : bool = _is_left_hand()
	var closest_grab_point : XRT2GrabPoint
	var closest_dist : float = 9999.99
	var closest_transform : Transform3D
	for child in body.get_children():
		if child is XRT2GrabPoint:
			# TODO Move this logic into the grab point, so we can create more complex
			# grab point, like implementing a grab rail or something along those lines

			var grab_point : XRT2GrabPoint = child
			if not grab_point.left_hand and is_left_hand:
				continue
			elif not grab_point.right_hand and not is_left_hand:
				continue

			var dist = (grab_point.global_position - to_point).length_squared()
			if dist < closest_dist:
				closest_grab_point = grab_point
				closest_transform = grab_point.global_transform
				closest_dist = dist

	if closest_grab_point:
		return closest_transform

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
		elif body is RigidBody3D and not body.freeze:
			# Always include rigidbodies unless frozen
			pass
		elif picked_up_by(body):
			# Already picked up, we're excluding rigidbodies from this.
			continue
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


func _highlight_meshes(node : Node3D) -> Dictionary[MeshInstance3D, Material]:
	var ret : Dictionary[MeshInstance3D, Material]

	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_instance : MeshInstance3D = child
			if mesh_instance.visible:
				ret[mesh_instance] = mesh_instance.material_overlay
				mesh_instance.material_overlay = _highlight_material

		if child is Node3D:
			# Find mesh instances any level deep
			var dic : Dictionary[MeshInstance3D, Material] = _highlight_meshes(child)
			ret.merge(dic)

	return ret


# Add highlight to this object.
# If there is already a highlight, we add ourself.
func _add_highlight(node : Node3D):
	if _highlighted_bodies.has(node):
		if not _highlighted_bodies[node].pickups.has(self):
			_highlighted_bodies[node].pickups.push_back(self)
		return

	var highlight : HighlightedBody = HighlightedBody.new()
	highlight.original_materials = _highlight_meshes(node)
	highlight.pickups.push_back(self)
	_highlighted_bodies[node] = highlight


# Remove highlight from this object.
# If other pickups are highlighting this object, we only remove ourselves.
func _remove_highlight(node : Node3D):
	if _highlighted_bodies.has(node):
		if _highlighted_bodies[node].pickups.has(self):
			_highlighted_bodies[node].pickups.erase(self)

		if _highlighted_bodies[node].pickups.is_empty():
			for mesh_instance in _highlighted_bodies[node].original_materials:
				if is_instance_valid(mesh_instance) and is_instance_valid(_highlighted_bodies[node]):
					mesh_instance.material_overlay = _highlighted_bodies[node].original_materials[mesh_instance]

			_highlighted_bodies.erase(node)


# Returns [code]true[/code] if we have tracking data for our hand
func _have_tracking_data() -> bool:
	if _xr_collision_hand:
		return _xr_collision_hand.get_has_tracking_data()
	elif _xr_controller:
		return _xr_controller.get_has_tracking_data()
	else:
		return false


# Get the pose used for tracking
func _get_pose() -> XRPose:
	if _xr_collision_hand:
		return _xr_collision_hand.get_pose()
	elif _xr_controller:
		return _xr_controller.get_pose()
	else:
		return null


# Returns our grab input
func _get_grab_value() -> float:
	if _xr_collision_hand:
		var input : Variant = _xr_collision_hand.get_input(grab_action)
		if input:
			var value : float = input
			return value
	elif _xr_controller:
		return _xr_controller.get_float(grab_action)

	return 0.0


func _process(_delta):
	# Don't run in editor
	if Engine.is_editor_hint():
		return

	# If we don't have a controller ancestor, nothing we can do
	if not _xr_controller and not _xr_collision_hand:
		return

	# if we're not tracking, do nothing
	if not _have_tracking_data():
		# We do not drop what we hold (right away)
		return

	# Get some info from our pose
	var linear_velocity : Vector3 = Vector3()
	var angular_velocity : Vector3 = Vector3()
	var pose : XRPose = _get_pose()
	if pose:
		linear_velocity = pose.linear_velocity
		angular_velocity = pose.angular_velocity

	# Object we picked up no longer exists? Drop it
	if _picked_up and not is_instance_valid(_picked_up):
		drop_held_object(linear_velocity, angular_velocity)

	# Our pickup handler is no longer enabled? Drop what we're holding
	if not enabled and _picked_up:
		drop_held_object(linear_velocity, angular_velocity)

	# Check our grab status
	var was_grab = _is_grab
	var xr_grab_float : float = _get_grab_value()
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
			return

		drop_held_object(linear_velocity, angular_velocity)
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
		_remove_highlight(was_closest_object)

	if _closest_object and is_instance_valid(_closest_object):
		# add highlight
		_add_highlight(_closest_object)
