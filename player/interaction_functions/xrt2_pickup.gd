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

#region Signals

## Inform that this hand has picked up this object (also if this is the second hand).
signal picked_up(by : XRT2Pickup, what : PhysicsBody3D)

## Inform that this hand has dropped this object (also if this object is still held by the other hand).
signal dropped(by : XRT2Pickup, what : PhysicsBody3D)

#endregion

enum PickedUpByMode {
	ANY,
	PRIMARY,
	SECONDARY
}

# Class for storing our highlight overrule data
class HighlightedBody extends RefCounted:
	var original_materials : Dictionary[MeshInstance3D, Material]
	var pickups : Array[XRT2Pickup]

# Class for storing closest info
class ClosestObject extends RefCounted:
	var body : PhysicsBody3D
	var grab_point : XRT2GrabPoint

# Array of all current pickup handlers
static var _pickup_handlers : Array[XRT2Pickup]

# We only want one hand to highlight
static var _highlighted_bodies : Dictionary[Node3D, HighlightedBody]

#region Export variables
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
#endregion


#region Private variables
# Node helpers
var _xr_origin: XROrigin3D
var _xr_controller: XRController3D
var _xr_collision_hand: XRT2CollisionHand
var _xr_player_object: CollisionObject3D
var _was_player_basis: Basis

var _detection_area: Area3D
var _collision_shape: CollisionShape3D
var _collision_sphere: SphereShape3D

# When picked up by controller
var _remote_transform: RemoteTransform3D

# Visualisation in the editor
var _editor_sphere: SphereMesh
var _editor_mesh_instance: MeshInstance3D

# Tween for animations
var _tween: Tween

# Tracks if our input is currently in grab mode (even if we're not holding anything)
var _is_grab: bool = false

# Remember if our XR action was pressed last frame
var _was_xr_pressed: bool = false

# What is currently our closest object
var _closest_object: ClosestObject

# What are we holding and by which grab point
var _picked_up: PhysicsBody3D
var _grab_point: XRT2GrabPoint
var _grab_offset: Transform3D

# Original state of picked up object
var _original_freeze_mode: RigidBody3D.FreezeMode
var _original_collision_layer: int
var _original_collision_mask: int

# If true, we are the primary hand holding this object (for 2 handed)
var _is_primary: bool = false

# Our highlight material
var _highlight_material: ShaderMaterial = \
	preload("res://addons/godot-xr-tools2/shaders/highlight_by_vertex.material")
#endregion


#region Public functions
## Find an XRT2Pickup function that is a child of the given parent
static func get_pickup(parent : Node3D) -> XRT2Pickup:
	for child in parent.get_children():
		if child is XRT2Pickup:
			return child

		var pickup = XRT2Pickup.get_pickup(child)
		if pickup:
			return pickup

	return null

## Find which pickup handler has picked up this object
static func picked_up_by(what: PhysicsBody3D, mode: PickedUpByMode = PickedUpByMode.ANY) -> XRT2Pickup:
	var by : XRT2Pickup
	for pickup : XRT2Pickup in _pickup_handlers:
		if pickup._picked_up == what:
			by = pickup

			# If this is our primary, return that
			if pickup._is_primary and mode != PickedUpByMode.SECONDARY:
				return by
			elif not pickup._is_primary and mode == PickedUpByMode.SECONDARY:
				return by

	if mode == PickedUpByMode.ANY:
		# If we found one, it will be our secondary hand
		return by
	else:
		return null


## How many hands have picked up this object?
static func picked_up_count(what : PhysicsBody3D) -> int:
	var count: int = 0
	for pickup : XRT2Pickup in _pickup_handlers:
		if pickup._picked_up == what:
			count += 1

	return count


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


## Returns the grab point on the object we've picked up
func get_picked_up_grab_point() -> XRT2GrabPoint:
	if is_instance_valid(_grab_point):
		return _grab_point
	return null


## Returns true if we're the primary hand holding this object
func is_primary() -> bool:
	return _is_primary


## Return the grab offset for this pickup object
func get_grab_offset() -> Transform3D:
	return _grab_offset


## Return our controller target for this hand.
func get_controller_target() -> Transform3D:
	var target: Transform3D
	if _xr_collision_hand:
		target = _xr_collision_hand.get_tracked_transform()
	elif _xr_controller:
		target = _xr_controller.global_transform
	else:
		return Transform3D()

	return target


## Pick up this object
func pickup_object(which : PhysicsBody3D):
	# No longer show highlighted
	_remove_highlight(which)

	if picked_up_by(which):
		_is_primary = false
	else :
		_is_primary = true

	# In case we need it, initialise our was player basis at pickup.
	if _xr_player_object:
		_was_player_basis = _xr_player_object.basis

	# Make sure our body doesn't collide with things we've picked up
	if _is_primary and _xr_player_object:
		# TODO should create a collision exception manager to ensure we don't undo this too quickly
		which.add_collision_exception_with(_xr_player_object)
		_xr_player_object.add_collision_exception_with(which)

	# Remember state
	_picked_up = which
	_original_collision_layer = _picked_up.collision_layer
	_original_collision_mask = _picked_up.collision_mask

	# TODO: the way we now make this work for xr_collision_hand can also
	# be applied for a xr_controller.
	# We just don't have the target override logic, but we can send a signal
	# that the user can implement.

	if _xr_collision_hand:
		# Make a collision exception between hand and picked up object
		_picked_up.add_collision_exception_with(_xr_collision_hand)
		_xr_collision_hand.add_collision_exception_with(_picked_up)

		# Remember our current hand transform.
		var hand_transform : Transform3D = _xr_collision_hand.global_transform

		# Get the offset between our hand root bone and our hand transform
		var hand_offset = get_parent().global_transform.inverse() * hand_transform

		# Find our grab point (if any).
		# Note, we're already handled our exclusive logic, can ignore that here.
		_grab_point = _get_closest_grabpoint(_picked_up, global_position)

		# Figure out our grab position
		var dest_transform : Transform3D 
		if _grab_point:
			dest_transform = _grab_point.get_hand_transform(global_position)
		else:
			dest_transform = _get_default_hand_transform(_picked_up, global_position)

		# Adjust destination by our hand offset
		dest_transform = dest_transform * hand_offset

		# Apply target override
		_grab_offset = _picked_up.global_transform.inverse() * dest_transform
		_xr_collision_hand.add_target_override(_picked_up, 1, _grab_offset)

		# TODO: We should add a nicer solution in xr collision hand for this!
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
	elif _xr_controller:
		# Old fashioned pickup, we use remote transform to pickup the object
		# TODO replace this with similar solution as collision hands node.
		if _is_primary:
			if _picked_up is RigidBody3D:
				_original_freeze_mode = _picked_up.freeze_mode

				# Don't control with physics engine, we're in control.
				_picked_up.freeze = true
				_picked_up.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				_picked_up.collision_layer = 0
				_picked_up.collision_mask = 0

				# Setup our remote transform and sync location to
				# our current picked up object position.
				_remote_transform.global_transform = _picked_up.global_transform
				_remote_transform.remote_path = _picked_up.get_path()
	
				# Find our grab point (if any).
				# Note, we're already handled our exclusive logic, can ignore that here.
				_grab_point = _get_closest_grabpoint(_picked_up, global_position)

				# Figure out our grab position.
				var dest_transform : Transform3D 
				if _grab_point:
					dest_transform = _grab_point.get_hand_transform(global_position)
				else:
					dest_transform = _get_default_hand_transform(_picked_up, global_position)

				# Make our transform local to our picked up object, we'll tween to fetch.
				dest_transform = dest_transform.inverse() * _picked_up.global_transform

				# Adjust our dest_transform to account for any offset in our pickup function
				dest_transform = transform.inverse() * dest_transform

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

	# Send out a signal to let those wanting to know that we picked something up
	picked_up.emit(self, _picked_up)

	# Let object know that we picked it up
	if _is_primary and _picked_up.has_method("picked_up"):
		_picked_up.picked_up(self)


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
		_grab_point = null
		_grab_offset = Transform3D()
		_is_primary = false
		return

	var was_picked_up = _picked_up

	# Process letting go
	if _xr_collision_hand:
		# TODO: Delay this until we're not colliding!
		_picked_up.remove_collision_exception_with(_xr_collision_hand)
		_xr_collision_hand.remove_collision_exception_with(_picked_up)

		_xr_collision_hand.remove_target_override(_picked_up)

		# TODO: should be something on our collision hand
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
	_grab_point = null
	_grab_offset = Transform3D()
	_is_primary = false

	var other = picked_up_by(was_picked_up)
	if other:
		# If it isn't already primary, this is now our primary
		other._is_primary = true
	elif _xr_player_object:
		# TODO: Delay this until we're not colliding!
		was_picked_up.remove_collision_exception_with(_xr_player_object)
		_xr_player_object.remove_collision_exception_with(was_picked_up)

		if was_picked_up.has_method("dropped"):
			was_picked_up.dropped(self)

	# Send out a signal to let those wanting to know that we dropped something
	dropped.emit(self, was_picked_up)

#endregion


#region Private export variable update functions
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
#endregion


#region Private Godot functions
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

	process_physics_priority = -91

	_xr_origin = XRT2Helper.get_xr_origin(self)
	_xr_collision_hand = XRT2CollisionHand.get_xr_collision_hand(self)
	if _xr_collision_hand:
		_xr_player_object = _xr_collision_hand.get_collision_parent()
	else:
		_xr_controller = XRT2Helper.get_xr_controller(self)
		if _xr_controller:
			_xr_player_object = XRT2Helper.get_collision_object(_xr_controller)

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
	if _closest_object and is_instance_valid(_closest_object.body):
		_remove_highlight(_closest_object.body)

	drop_held_object()

	# Remove us from the pickup handlers
	if _pickup_handlers.has(self):
		_pickup_handlers.erase(self)


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
	elif not was_grab and _is_grab and _closest_object and is_instance_valid(_closest_object.body):
		pickup_object(_closest_object.body)
		return

	# Update closest object
	var was_closest_object : ClosestObject = _closest_object
	_closest_object = _get_closest()

	if was_closest_object and _closest_object and was_closest_object.body == _closest_object.body:
		# We're done
		return

	if was_closest_object and is_instance_valid(was_closest_object.body):
		# Remove highlight
		_remove_highlight(was_closest_object.body)

	if _closest_object and is_instance_valid(_closest_object.body):
		# Add highlight
		if _closest_object.grab_point and _closest_object.grab_point.highlight_mode == 2:
			# Highlight is disabled
			return

		if _closest_object.grab_point and _closest_object.grab_point.highlight_mode == 1 and picked_up_by(_closest_object.body):
			# Don't highlight for two handed pickup
			return

		_add_highlight(_closest_object.body)


func _physics_process(delta):
	# Don't run in editor
	if Engine.is_editor_hint():
		return

	if not _picked_up:
		return

	var controller_target: Transform3D = get_controller_target()
	if controller_target == Transform3D():
		return

	var global_target: Transform3D = controller_target * _grab_offset.inverse()
	if _picked_up.has_method("_xr_custom_pickup_handler"):
		_picked_up._xr_custom_pickup_handler(self, global_target)
	elif _picked_up is RigidBody3D or _picked_up is PhysicalBone3D:
		# TODO: obtain this somehow from our picked up object (decoration?)
		var pivot_on_primary: bool = true

		var parent_linear_velocity: Vector3 = Vector3()
		var parent_angular_velocity: Vector3 = Vector3()
		var parent_global_position: Vector3 = Vector3()
		var parent_global_basis: Basis = Basis()
		if _xr_player_object:
			parent_global_position = _xr_player_object.global_position
			parent_global_basis = _xr_player_object.global_basis
			if _xr_player_object is RigidBody3D:
				parent_linear_velocity = _xr_player_object.linear_velocity
				parent_angular_velocity = _xr_player_object.angular_velocity
			elif _xr_player_object is CharacterBody3D:
				parent_linear_velocity = _xr_player_object.velocity

				# Calculate our parents angular velocity.
				# Our characterbody also includes our physical movement and we would double account for this.
				parent_angular_velocity = XRT2Helper.rotation_to_axis_angle(_was_player_basis, _xr_player_object.basis) / delta
				_was_player_basis = _xr_player_object.basis

		if _is_primary:
			# Find the other hand with which we are holding this object (if any).
			# Note: If we're somehow holding an object with more than 2 hands,
			# we're not taking that into account.
			# Yes we're sadly discriminating towards extraterrestrial
			var other: XRT2Pickup = picked_up_by(_picked_up, PickedUpByMode.SECONDARY)
			if other:
				# If we have a second hand, we want the relative position between
				# the two hands to define orientation.
				# Lets get info from our second hand
				var other_grab_offset: Transform3D = other.get_grab_offset()
				var other_controller_target: Transform3D = other.get_controller_target()

				# Calculate the vector between the two hands in local space,
				# and in global space, and that gives us our orientation data.
				var start_vector: Vector3 = (other_grab_offset.origin - _grab_offset.origin).normalized()
				var dest_vector: Vector3 = (other_controller_target.origin - controller_target.origin).normalized()
				var cross: Vector3 = start_vector.cross(dest_vector).normalized()
				var angle: float = acos(start_vector.dot(dest_vector))

				global_target.basis = Basis(cross, angle)
				if pivot_on_primary:
					# If we're pivoting on primary, adjust our target position accordingly.
					global_target.origin = controller_target.origin - (global_target.basis * _grab_offset.origin)

			# Apply angular motion to picked up object.
			# We always do this on primary only!
			XRT2Helper.apply_torque_to_target(
				delta, _picked_up, global_target.basis, 1.0,
				parent_angular_velocity, parent_global_basis
			)

		if not pivot_on_primary:
			# If we're holding this with multiple hands, we apply proportionally.
			var proportion: float = 1.0 / picked_up_count(_picked_up)

			# Apply linear motion to picked up object.
			XRT2Helper.apply_force_to_target(delta, _picked_up, global_target.origin, proportion,
				parent_linear_velocity, parent_angular_velocity, parent_global_position
			)
		elif _is_primary:
			# Apply linear motion to picked up object.
			XRT2Helper.apply_force_to_target(delta, _picked_up, global_target.origin, 1.0,
				parent_linear_velocity, parent_angular_velocity, parent_global_position
			)
	elif _picked_up is StaticBody3D:
		# TODO: If static body, apply forces to player!
		pass

#endregion


#region Private functions
# Returns true if our pickup feature is attached to the left hand.
func _is_left_hand() -> bool:
	if _xr_collision_hand:
		return _xr_collision_hand.hand == 0
	elif _xr_controller:
		return _xr_controller.get_tracker_hand() == XRPositionalTracker.TRACKER_HAND_LEFT
	else:
		return false


# Get collision rids for our hand
func _get_hand_collision_rids() -> Array[RID]:
	var ret : Array[RID]
	if _xr_collision_hand:
		ret.push_back(_xr_collision_hand.get_rid())

	return ret


func _get_closest_grabpoint(body : PhysicsBody3D, hand_position : Vector3) -> XRT2GrabPoint:
	# Check any applicable grab point on the body first
	var is_left_hand : bool = _is_left_hand()
	var closest_grab_point : XRT2GrabPoint
	var closest_dist : float = 9999.99
	for child in body.get_children():
		if child is XRT2GrabPoint and child.enabled:
			var grab_point : XRT2GrabPoint = child
			if not grab_point.left_hand and is_left_hand:
				continue
			elif not grab_point.right_hand and not is_left_hand:
				continue

			var dist = (grab_point.get_hand_transform(hand_position).origin - hand_position).length_squared()
			if dist < closest_dist:
				closest_grab_point = grab_point
				closest_dist = dist

	return closest_grab_point


# Returns a transform for hand positioning using our default logic.
# Used when there are no grab points.
func _get_default_hand_transform(body : PhysicsBody3D, hand_position : Vector3) -> Transform3D:
	var state : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	# TODO: Change this to shape cast using our area collision shape

	var params : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	params.from = hand_position
	params.to = body.global_position
	params.exclude = _get_hand_collision_rids()
	
	var result : Dictionary = state.intersect_ray(params)
	if result.is_empty():
		# Huh? This shouldn't happen, missing collision shape?
		return body.global_transform
	else:
		# We're assuming no other object was inbetween
		var is_left_hand : bool = _is_left_hand()

		var t : Transform3D
		t.basis.x = result['normal']
		if is_left_hand:
			t.basis.x = -t.basis.x
		t.basis.y = t.basis.x.cross(-global_basis.z).normalized()
		t.basis.z = t.basis.x.cross(t.basis.y).normalized()
		t.origin = result['position'] + t.basis.y * 0.01
		return t


func _get_closest() -> ClosestObject:
	if not _detection_area.monitoring:
		return null

	var overlapping_bodies = _detection_area.get_overlapping_bodies()
	var closest : ClosestObject
	var closest_dist : float = 9999999.99

	for body : Node3D in overlapping_bodies:
		if body.is_ancestor_of(self):
			# Ignore any of our parents
			continue
		elif _xr_origin.is_ancestor_of(body):
			# Ignore any children of our origin
			continue
		elif body is RigidBody3D and not body.freeze:
			# Always include rigidbodies unless frozen
			# TODO see if we can treat frozen bodies like grabing a static body
			pass
		elif body is PhysicalBone3D and _xr_collision_hand:
			# We support picking up PhysicalBone3D if we're using collision hands
			pass
		elif body is StaticBody3D and _xr_collision_hand:
			# TODO implement a system for selectively including these
			# (or maybe switch on animatable body)
			pass
		else:
			# Skip anything else
			continue

		var by : XRT2Pickup = picked_up_by(body)
		if by:
			# Check if it's already been picked up by an exclusive grab
			var on_grab_point = by.get_picked_up_grab_point()
			if on_grab_point and on_grab_point.exclusive:
				# Can't pick this up
				continue

		# Do we have a grab point?
		var new_dist : float = 9999999.99
		var grab_point = _get_closest_grabpoint(body, global_position)
		if grab_point:
			if by and grab_point.exclusive:
				# Two handed not possible
				continue

			new_dist = (global_position - grab_point.get_hand_transform(global_position).origin).length_squared()
		else:
			# TODO should do our raycast to see if there is nothing between us and the object we're picking up
			
			new_dist = (global_position - body.global_position).length_squared()

		# See if this is our closest object
		if new_dist < closest_dist:
			closest = ClosestObject.new()
			closest.body = body
			closest.grab_point = grab_point
			closest_dist = new_dist

	return closest


func _highlight_meshes(node : Node3D) -> Dictionary[MeshInstance3D, Material]:
	var ret : Dictionary[MeshInstance3D, Material]

	if node.has_method("get_highlight_meshes"):
		var mesh_instances : Array[MeshInstance3D] = node.get_highlight_meshes()
		for mesh_instance : MeshInstance3D in mesh_instances:
			ret[mesh_instance] = mesh_instance.material_overlay
			mesh_instance.material_overlay = _highlight_material
	else:
		for child in node.get_children():
			if child.is_in_group("xrt2_no_highlight"):
				# Don't process this node for highlights
				continue

			if child is MeshInstance3D:
				var mesh_instance : MeshInstance3D = child
				if mesh_instance.visible:
					ret[mesh_instance] = mesh_instance.material_overlay
					mesh_instance.material_overlay = _highlight_material

			if child is Node3D and not child is PhysicsBody3D:
				# Find mesh instances any level deep, but not into a new physics body
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
#endregion
