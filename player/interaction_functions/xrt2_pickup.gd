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
	var original_materials: Dictionary[MeshInstance3D, Material]
	var pickups: Array[XRT2Pickup]

# Class for storing object info for grabbing
class GrabObject extends RefCounted:
	var body: PhysicsBody3D
	var grab_point: XRT2GrabPoint
	var collision_point: Vector3
	var collision_normal: Vector3

# Array of all current pickup handlers
static var _pickup_handlers: Array[XRT2Pickup]

# We only want one hand to highlight
static var _highlighted_bodies: Dictionary[Node3D, HighlightedBody]

#region Export variables
## If ticked we monitor for things we can pick up
@export var enabled: bool = true:
	set(value):
		enabled = value

## We only pick up items present in these physics layers
@export_flags_3d_physics var collision_mask: int = 1:
	set(value):
		collision_mask = value

## How far from our pickup function we check if there are items to pick up.
@export var detection_radius: float = 0.3:
	set(value):
		detection_radius = value
		if is_inside_tree():
			_update_detection_radius()

## Offset our detection area
@export var detection_offset: Vector3 = Vector3(0.0, 0.0, -0.06):
	set(value):
		detection_offset = value

		if _editor_mesh_instance:
			_editor_mesh_instance.position = detection_offset

## The action we check when grabbing things
@export var grab_action: String = "grab"

## If false we need to continously hold our grab button, if true we toggle
## Note: with keyboard entry toggle is enforced
@export var grab_toggle: bool = false

## When the second hand lets go of an object, how long do we delay our "snap"
@export_range(0.0, 2.0, 0.01) var two_hand_delay = 0.5

## When an object is let go by one hand, but still held by another
## this factor is applied to soften our let go action.
@export_range(0.01, 1.00, 0.01) var let_go_factor = 0.3
#endregion


#region Private variables
# Node helpers
var _xr_origin: XROrigin3D
var _xr_controller: XRController3D
var _xr_collision_hand: XRT2CollisionHand
var _xr_player_object: CollisionObject3D
var _was_player_basis: Basis

# Object detection
var _detection_shape: SphereShape3D
var _detection_query: PhysicsShapeQueryParameters3D
var _detection_exclude : Array[RID]

# Visualisation in the editor
var _editor_sphere: SphereMesh
var _editor_mesh_instance: MeshInstance3D

# Tracks if our input is currently in grab mode (even if we're not holding anything)
var _is_grab: bool = false

# Remember if our XR action was pressed last frame
var _was_xr_pressed: bool = false

# True if we're updating our transform
var _updating_transform: bool = false

# What is currently our closest object
var _closest_object: GrabObject

# What are we holding and by which grab point
var _picked_up: PhysicsBody3D
var _picked_up_to_org_target: Transform3D
var _grab_point: XRT2GrabPoint
var _grab_offset: Transform3D
var _pivot_on_primary: bool = false
var _grab_as_static_body: bool = false
var _two_hand_delay: float = 0.0

# Static object lerp duration, time in second that it will take to rotate move the players body into position.
# Should make this setable at some point
var _static_velocity_lerp_duration: float = 0.1 

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
static func picked_up_by(what: PhysicsBody3D = null, mode: PickedUpByMode = PickedUpByMode.ANY, exclude: Array[XRT2Pickup] = []) -> XRT2Pickup:
	var by : XRT2Pickup
	for pickup : XRT2Pickup in _pickup_handlers:
		if pickup in exclude:
			# In our exclude list? Skip.
			continue
		elif what and pickup._picked_up != what:
			# Hasn't picked up this object? Skip.
			continue
		elif not what and not pickup.has_picked_up():
			# Any object but we haven't picked anything up? Skip.
			continue

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
func pickup_object(object : GrabObject):
	var inv_picked_up_global_transform: Transform3D = object.body.global_transform.inverse()

	# Get our current tracker position
	var target: Transform3D
	if _xr_collision_hand:
		target = _xr_collision_hand.get_tracked_transform()
	elif _xr_controller:
		target = _xr_controller.global_transform
	else:
		push_error("Controller not found!")
		return

	# Remember our offset between our target and picked up object
	_picked_up_to_org_target = inv_picked_up_global_transform * target

	# No longer show highlighted
	_remove_highlight(object.body)

	var other: XRT2Pickup = picked_up_by(object.body)
	if other:
		# We are secondary
		_is_primary = false

		# Reset some things on our other hand
		other._two_hand_delay = 0.0
		other._picked_up_to_org_target = inv_picked_up_global_transform * other.get_controller_target()
	else :
		_is_primary = true
		_two_hand_delay = 0.0

	# In case we need it, initialise our was player basis at pickup.
	if _xr_player_object:
		_was_player_basis = _xr_player_object.basis

	# Remember state
	_picked_up = object.body

	if object.body is RigidBody3D or object.body is PhysicalBone3D:
		# Make sure our body doesn't collide with things we've picked up
		XRT2Helper.add_collision_exception(_xr_player_object, object.body)

		# Get some behaviour characteristics
		var rigid_body_behaviour: XRT2RigidBodyBehaviour = XRT2RigidBodyBehaviour.get_behaviour_node(object.body)
		if rigid_body_behaviour:
			_pivot_on_primary = rigid_body_behaviour.pivot_on_primary
			_grab_as_static_body = rigid_body_behaviour.grab_as_static_body
		else:
			_pivot_on_primary = false
			_grab_as_static_body = false

		# If object is frozen, always treat like a static body.
		if object.body.freeze:
			_grab_as_static_body = true
	elif object.body is StaticBody3D:
		_pivot_on_primary = false
		_grab_as_static_body = true

	if _xr_collision_hand:
		# Make a collision exception between hand and picked up object
		XRT2Helper.add_collision_exception(_xr_collision_hand, _picked_up)

	# Find our grab point (if any).
	# Note, we're already handled our exclusive logic, can ignore that here.
	_grab_point = _get_closest_grabpoint(_picked_up, global_position)

	# Figure out our grab position and finger poses
	var grab_transform: Transform3D 
	var finger_poses: XRT2FingerPoses
	var open_finger_poses: XRT2FingerPoses
	if _grab_point:
		grab_transform = _grab_point.get_hand_transform(global_position)
		finger_poses = _grab_point.finger_poses
		open_finger_poses = _grab_point.open_finger_poses
	else:
		grab_transform = _get_hand_transform_from_surface(object.collision_point, object.collision_normal)
	var local_grab_transform: Transform3D = inv_picked_up_global_transform * grab_transform

	# Calculate the offset between our controller position, and the object we picked up.
	var target_offset: Transform3D = global_transform.inverse() * target

	_grab_offset = local_grab_transform * target_offset

	if _xr_collision_hand:
		# Apply target override
		_xr_collision_hand.add_target_override(_picked_up, 1, _grab_offset)

		# Set finger poses based on what we've picked up (if applicable)
		_xr_collision_hand.finger_poses = finger_poses
		_xr_collision_hand.open_finger_poses = open_finger_poses

		# Now animate our hand from our current location to our new location
		_xr_collision_hand.tween_hand_from_location(target)
	elif _xr_controller and _xr_controller.has_method("picked_up_object"):
		# Sent signal to controller we've now picked up this object.
		_xr_controller.picked_up_object(_picked_up, _is_primary, finger_poses, open_finger_poses)

	# Send out a signal to let those wanting to know that we picked something up
	picked_up.emit(self, _picked_up)

	# Let object know that we picked it up
	if _is_primary and _picked_up.has_method("picked_up"):
		_picked_up.picked_up(self)


## Drop object we're currently holding
func drop_held_object( \
	apply_linear_velocity : Vector3 = Vector3(), apply_angular_velocity : Vector3 = Vector3() \
	) -> void:
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
		XRT2Helper.remove_collision_exception(_xr_collision_hand, _picked_up)

		_xr_collision_hand.remove_target_override(_picked_up)
		_xr_collision_hand.finger_poses = null
		_xr_collision_hand.open_finger_poses = null

		# Reset our tween
		_xr_collision_hand.reset_tween()
	elif _xr_controller and _xr_controller.has_method("dropped_object"):
		# Tell controller we are no longer holding this.
		_xr_controller.dropped_object(_picked_up)

	# And we're no longer holding something
	_picked_up = null
	_grab_point = null
	_grab_offset = Transform3D()
	_is_primary = false
	_pivot_on_primary = false
	_grab_as_static_body = false

	if _xr_player_object and (was_picked_up is RigidBody3D or was_picked_up is PhysicalBone3D):
		XRT2Helper.remove_collision_exception(_xr_player_object, was_picked_up)

	var other = picked_up_by(was_picked_up)
	if other:
		# If it isn't already primary, this is now our primary
		other._is_primary = true
		other._two_hand_delay = two_hand_delay
		other._picked_up_to_org_target = was_picked_up.global_transform.inverse() * other.get_controller_target()
	elif _xr_player_object and was_picked_up.has_method("dropped"):
		was_picked_up.dropped(self)

	# Send out a signal to let those wanting to know that we dropped something
	dropped.emit(self, was_picked_up)
#endregion


#region Private export variable update functions
# Update our detection radius
func _update_detection_radius():
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

	# Return warnings
	return warnings


# Validate properties, or change their properties
func _validate_property(property: Dictionary) -> void:
	# We control these
	if _xr_collision_hand and property.name in [ "position", "rotation", "scale", "rotation_edit_mode", "rotation_order", "top_level" ]:
		property.usage = PROPERTY_USAGE_NONE


# Exclude any collision children related to this node
func _exclude_collision_children(parent: Node3D):
	for child in parent.get_children():
		if child is CollisionObject3D:
			_detection_exclude.push_back(child.get_rid())

		_exclude_collision_children(child)


# Called when node enters the scene tree
func _enter_tree():
	_detection_exclude.clear()

	# Exclude any collision parents of our node
	var parent = get_parent()
	while parent:
		if parent is CollisionObject3D:
			_detection_exclude.push_back(parent.get_rid())
		parent = parent.get_parent()

	_xr_origin = XRT2Helper.get_xr_origin(self)
	_exclude_collision_children(_xr_origin)

	_xr_collision_hand = XRT2CollisionHand.get_xr_collision_hand(self)
	if _xr_collision_hand:
		_xr_player_object = _xr_collision_hand.get_collision_parent()

		_xr_collision_hand.hand_mesh_changed.connect(_on_hand_mesh_changed)
		_xr_collision_hand.skeleton_updated.connect(_on_skeleton_updated)
		_on_skeleton_updated()

	else:
		_xr_controller = XRT2Helper.get_xr_controller(self)
		if _xr_controller:
			_xr_player_object = XRT2Helper.get_collision_object(_xr_controller)

	notify_property_list_changed()


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
		_editor_mesh_instance.position = detection_offset
		add_child(_editor_mesh_instance, false, Node.INTERNAL_MODE_BACK)

		# For now visualize our center, but this should be replaced by a gizmo!!
		var center_mesh_instance = MeshInstance3D.new()
		center_mesh_instance.mesh = _editor_sphere
		_editor_mesh_instance.add_child(center_mesh_instance)
		center_mesh_instance.scale = Vector3(0.1, 0.1, 0.1)

		_update_detection_radius()
		return

	process_physics_priority = -91

	# Add this to our list of active pickup handlers
	_pickup_handlers.push_back(self)

	# Create our detection shape
	_detection_shape = SphereShape3D.new()

	# Create our detection query
	_detection_query = PhysicsShapeQueryParameters3D.new()
	_detection_query.shape = _detection_shape

	_update_detection_radius()


# Called when node exits the scene tree
func _exit_tree():
	_detection_exclude.clear()

	if not Engine.is_editor_hint():
		if _closest_object and is_instance_valid(_closest_object.body):
			_remove_highlight(_closest_object.body)

		drop_held_object()

		# Remove us from the pickup handlers
		if _pickup_handlers.has(self):
			_pickup_handlers.erase(self)

	_xr_origin = null
	if _xr_collision_hand:
		_xr_collision_hand.hand_mesh_changed.disconnect(_on_hand_mesh_changed)
		_xr_collision_hand.skeleton_updated.disconnect(_on_skeleton_updated)
		_xr_collision_hand = null
	_xr_controller = null
	_xr_player_object = null


# Runs every frame
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
		pickup_object(_closest_object)
		return

	# Update closest object
	var was_closest_object : GrabObject = _closest_object
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


# Runs every physics frame
func _physics_process(delta):
	# Don't run in editor
	if Engine.is_editor_hint():
		return

	# Nothing picked up, no need to run this
	if not _picked_up:
		return

	var controller_target: Transform3D = get_controller_target()
	if controller_target == Transform3D():
		return

	var global_target: Transform3D = controller_target * _grab_offset.inverse()
	if _picked_up.has_method("_xr_custom_pickup_handler"):
		if _picked_up._xr_custom_pickup_handler(self, delta, controller_target, global_target):
			# Handled, don't run our default logic
			return

	if not _grab_as_static_body and (_picked_up is RigidBody3D or _picked_up is PhysicalBone3D):
		_handle_picked_up_dynamic(delta, controller_target, global_target)
	elif _grab_as_static_body and _xr_player_object:
		if not XRT2LocomotionHandler.get_locomotion_handler(_xr_player_object):
			_handle_picked_up_static(delta, controller_target, global_target)


# Called when locomotion is handeld by a locomotion handler
func _process_locomotion(delta: float) -> void:
	if not _picked_up:
		# Not picked up, no need to run this.
		return
	elif not _xr_player_object:
		# No player object to run our logic on, no need to run this.
		return
	elif _picked_up.has_method("_xr_custom_pickup_handler"):
		# Has a custom handler, no need to run this.
		return
	elif not _grab_as_static_body:
		# Hasn't picked up a static body, no need to run this.
		return

	var controller_target: Transform3D = get_controller_target()
	if controller_target == Transform3D():
		return

	_handle_picked_up_static(delta, controller_target, controller_target * _grab_offset.inverse())
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


func _get_hand_transform_from_surface(point: Vector3, normal: Vector3) -> Transform3D:
	var t : Transform3D

	# Invert the normal if we're dealing with our left hand
	if _is_left_hand():
		normal = -normal

	t.basis.x = normal.normalized()
	t.basis.z = t.basis.x.cross(global_basis.y).normalized()
	t.basis.y = t.basis.z.cross(t.basis.x).normalized()
	t.origin = point

	# We need an offset as our collision point should be at our palm...
	t = t * Transform3D(Basis(), -detection_offset)

	return t


# Get our closest grabable object
func _get_closest() -> GrabObject:
	if not enabled:
		return null

	if not _detection_shape:
		return null

	if not _detection_query:
		return null

	var state : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	_detection_shape.radius = detection_radius
	_detection_query.collision_mask = collision_mask
	_detection_query.exclude = _detection_exclude
	_detection_query.transform = global_transform * Transform3D(Basis(), detection_offset)
	
	var result: Dictionary = state.get_rest_info(_detection_query)
	if not result or result.is_empty():
		return null

	var hand_normal = -global_basis.x if _is_left_hand() else global_basis.x
	if hand_normal.dot(result.normal) < 0.0:
		return null

	var collider: PhysicsBody3D = instance_from_id(result.collider_id)
	if not collider:
		return null

	# Check if already picked up
	var by : XRT2Pickup = picked_up_by(collider)
	if by:
		# Check if it's already been picked up by an exclusive grab
		var on_grab_point = by.get_picked_up_grab_point()
		if on_grab_point and on_grab_point.exclusive:
			# Can't pick this up
			return null

	# Get our grab point (if any)
	var grab_point = _get_closest_grabpoint(collider, global_position)
	if grab_point:
		if by and grab_point.exclusive:
			# Two handed not possible
			return null

	var closest: GrabObject = GrabObject.new()
	closest.body = collider
	closest.grab_point = grab_point
	closest.collision_point = result.point
	closest.collision_normal = result.normal

	return closest


# Handle moving a picked up dynamic object (RigidBody3D/PhysicalBone3D)
# In this scenario, we want to manipulate the held object
func _handle_picked_up_dynamic(delta: float, controller_target: Transform3D, global_target: Transform3D) -> void:
	var primary_factor: float = 1.0 if _two_hand_delay == 0.0 else let_go_factor
	_two_hand_delay = max(0.0, _two_hand_delay - delta)

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

			# Now calculate how much our tracked hands are rotated along our destination vector
			var primary_angle = XRT2Helper.angle_in_plane(dest_vector, global_target.basis * _grab_offset.basis.y, controller_target.basis.y)
			var secondary_angle = XRT2Helper.angle_in_plane(dest_vector, global_target.basis * other_grab_offset.basis.y, other_controller_target.basis.y)

			global_target.basis = Basis(dest_vector, (primary_angle + secondary_angle) * 0.5) * global_target.basis

			if _pivot_on_primary:
				# If we're pivoting on primary, adjust our target position accordingly.
				global_target.origin = controller_target.origin - (global_target.basis * _grab_offset.origin)

		# Apply angular motion to picked up object.
		# We always do this on primary only!
		XRT2Helper.apply_torque_to_target(
			delta, _picked_up, global_target.basis, primary_factor,
			parent_angular_velocity, parent_global_basis
		)

	if not _pivot_on_primary:
		# If we're holding this with multiple hands, we apply proportionally.
		var proportion: float = 1.0 / picked_up_count(_picked_up)

		# Apply linear motion to picked up object.
		XRT2Helper.apply_force_to_target(delta, _picked_up, global_target.origin, proportion,
			parent_linear_velocity, parent_angular_velocity, parent_global_position
		)
	elif _is_primary:
		# Apply linear motion to picked up object.
		XRT2Helper.apply_force_to_target(delta, _picked_up, global_target.origin, primary_factor,
			parent_linear_velocity, parent_angular_velocity, parent_global_position
		)


# Handle moving a picked up static object (StaticBody3D/AnimatableBody3D) 
# In this scenario, we want to rotate/move our player
func _handle_picked_up_static(delta: float, controller_target: Transform3D, global_target: Transform3D) -> void:
	# Find any other pickup handler that has picked up something (should be our other hand).
	var other: XRT2Pickup = picked_up_by(null, PickedUpByMode.ANY, [ self ])
	if other and not _is_left_hand():
		# If both hands are holding something, we only process the left hand.
		return

	var target_basis: Basis = Basis()
	var lerp_factor: float = delta / _static_velocity_lerp_duration

	# Get are we moving from and to, we want this to be exact:
	var start_position: Vector3 = controller_target.origin
	var dest_position: Vector3 = _picked_up.global_transform * _grab_offset.origin

	if other:
		# Q: Should we use original orientation here too?

		var other_picked_up: PhysicsBody3D = other.get_picked_up()
		var other_grab_offset: Transform3D = other.get_grab_offset()
		var other_grab_origin: Vector3 = other_picked_up.global_transform * other_grab_offset.origin
		var other_controller_target: Transform3D = other.get_controller_target()

		# We rotate our player in reverse
		var start_vector = (other_controller_target.origin - start_position).normalized()
		var dest_vector = (other_grab_origin - dest_position).normalized()
		var cross: Vector3 = start_vector.cross(dest_vector).normalized()
		var angle: float = acos(start_vector.dot(dest_vector))

		if cross.length() > 0.0 and angle > 0.0:
			target_basis = Basis(cross, angle * lerp_factor)

		# Now calculate how much our tracked hands are rotated along our destination vector
		var primary_angle = XRT2Helper.angle_in_plane(dest_vector, controller_target.basis.y, target_basis * _picked_up.global_basis * _grab_offset.basis.y)
		var secondary_angle = XRT2Helper.angle_in_plane(dest_vector, other_controller_target.basis.y, target_basis * other_picked_up.global_basis * other_grab_offset.basis.y)

		target_basis = Basis(dest_vector, (primary_angle + secondary_angle) * 0.5 * lerp_factor) * target_basis * _xr_player_object.global_basis

		# And update for two handed linear velocity
		start_position = (start_position + other_controller_target.origin) * 0.5
		dest_position = (dest_position + other_grab_origin) * 0.5
	else:
		# Single handed, determine rotation difference based on our rotation when we grabbed the static object
		var dest_transform: Transform3D = _picked_up.global_transform * _picked_up_to_org_target
		var axis_angle: Vector3 = XRT2Helper.rotation_to_axis_angle(controller_target.basis, dest_transform.basis)

		# And apply partial rotation to our player body
		target_basis = Basis(axis_angle.normalized(), axis_angle.length() * lerp_factor) * _xr_player_object.global_basis

	# Apply our results based on our primary hand
	if _xr_player_object is RigidBody3D:
		# Apply torque to player object
		XRT2Helper.apply_torque_to_target(delta, _xr_player_object, target_basis)

		# Apply forces to player object
		XRT2Helper.apply_force_to_target(delta, _xr_player_object, _xr_player_object.global_position + (dest_position - start_position))
	elif _xr_player_object is CharacterBody3D:
		# We don't have an angular velocity here, nor collision detection so we're just going to rotate around the local y-axis
		target_basis = target_basis.looking_at(target_basis.z - target_basis.z.project(_xr_player_object.global_basis.y), _xr_player_object.global_basis.y, true)
		_xr_player_object.global_basis = target_basis

		# And adjust linear velocity of player object
		var required_linear_velocity: Vector3 = (dest_position - start_position) / delta
		_xr_player_object.velocity = lerp(_xr_player_object.velocity, required_linear_velocity, lerp_factor)


# Highlight meshes on this node
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


# Called when the hand mesh of our related XRT2CollisionHand changes
func _on_hand_mesh_changed() -> void:
	_on_skeleton_updated()


# Called when the hand skeleton of our related XRT2CollisionHand changes
func _on_skeleton_updated() -> void:
	if not _xr_collision_hand:
		return

	if _updating_transform:
		return

	_updating_transform = true

	transform = _xr_collision_hand.get_bone_transform("LeftMiddleMetacarpal" if _xr_collision_hand.hand == 0 else "RightMiddleMetacarpal")

	_updating_transform = false
#endregion
