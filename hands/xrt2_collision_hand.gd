#-------------------------------------------------------------------------------
# xrt2_collision_hand.gd
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
class_name XRT2CollisionHand
extends RigidBody3D

## XRTools2 Collision Hand Container Script
##
## This script implements logic for collision hands.
## It encompasses all logic for showing an articulated hand mesh,
## handles its animations, and most importantly, collisions.

#region Signals
## Emitted when a new hand mesh was loaded
signal hand_mesh_changed

## Emitted when the skeleton is updated
signal skeleton_updated

## Emitted when a button on this tracker is pressed. Note that many XR runtimes allow other inputs to be mapped to buttons.
signal button_pressed(action_name: String)

## Emitted when a button on this tracker is released.
signal button_released(action_name: String)

## Emitted when a trigger or similar input on this tracker changes value.
signal input_float_changed(action_name: String, value: float)

## Emitted when a thumbstick or thumbpad on this tracker moves.
signal input_vector2_changed(action_name: String, vector: Vector2)
#endregion

## Modes for collision hand
enum CollisionHandMode {
	## Hand is disabled and must be moved externally
	DISABLED,

	## Hand teleports to target
	TELEPORT,

	## Hand collides with world (based on mask)
	COLLIDE
}


# How much displacement is required for the hand to start orienting to a surface
const ORIENT_DISPLACEMENT := 0.05

#region Export variables
## Properties related to tracking
@export_group("Tracking")

## Which hand are we tracking?
@export_enum("Left","Right") var hand : int = 0:
	set(value):
		hand = value
		if is_inside_tree():
			_update_hand_meshes()

			if not Engine.is_editor_hint():
				_update_trackers()
				_update_hand_motion_range()

## Set the tracked hand motion range (if supported).
## Note, this is a global setting per hand.
## Having multiple collision hand nodes for the same hand
## will result in the latest hand being configured defining
## this behavior.
@export_enum("Full", "Controller") var hand_motion_range = 0:
	set(value):
		hand_motion_range = value
		if is_inside_tree() and not Engine.is_editor_hint():
			_update_hand_motion_range()

## Fallback settings used if hand tracking isn't available.
@export_subgroup("Fallback", "fallback")

## The fallback pose actions to use, in order of checking.
@export var fallback_pose_actions : Array[String] = [ "palm_pose", "grip" ]

## The fallback offset position to apply.
@export var fallback_offset_position : Vector3

## The fallback offset rotation to apply.
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,or_less,or_greater,radians_as_degrees") \
	var fallback_offset_rotation : Vector3

## Trigger action for our fallback
@export var trigger_action : String = "trigger"

## Degrees to which to curl our index finger.
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var trigger_curl : float = deg_to_rad(45.0)

## Grip action for our fallback
@export var grip_action : String = "grip"

## Degrees to which to curl our bottom 3 fingers.
@export_range(0.0, 90.0, 1.0, "radians_as_degrees") var grip_curl : float = deg_to_rad(70.0)

## Properties related to physics
@export_group("Physics")

## Controls the hand collision mode
@export var mode : CollisionHandMode = CollisionHandMode.COLLIDE:
	set(value):
		mode = value
		notify_property_list_changed()

## Distance to teleport hands
@export var teleport_distance : float = 1.0

## Drop held object if teleport distance is reached?
@export var drop_on_teleport : bool = true

## Weight of our hand
@export_range(0.1, 1.0, 0.01, "suffix:kg") var hand_mass : float = 0.4:
	set(value):
		hand_mass = value
		if is_inside_tree():
			mass = value

## Max linear force
@export_range(1.0, 1000.0, 1.0, "suffix:N") var max_force : float = 500.0

## Factor to apply to required force above maximum
@export_range(0.0, 1.0, 0.01) var force_falloff_factor : float = 0.5

## Angular torgue coef
# @export_range(0.1, 100.0, 0.1) var torque_coef : float = 30.0

## Properties related to physical appearance
@export_group("Appearance")

## Specify an alternative hand scene to use instead of our built-in hand.
## Must be a proper Godot humanoid hand with Skeleton3D but without physics.
@export var alternative_hand_scene : PackedScene:
	set(value):
		alternative_hand_scene = value
		if is_inside_tree():
			_update_hand_meshes()

			if not Engine.is_editor_hint():
				_update_trackers()

## If [code]true[/code], we show our hand mesh.
## This has no effect on collisions or tracking.
@export var show_hand_mesh : bool = true:
	set(value):
		show_hand_mesh = value

		if _hand_mesh:
			_hand_mesh.visible = show_hand_mesh

## If [code]true[/code], we show a ghost hand if hand placement doesn't match.
@export var enable_ghost_hand : bool = true

## Override the material of the hand
@export var material_override : Material:
	set(value):
		material_override = value

		if _hand_mesh:
			_update_hand_material(_hand_mesh, material_override, true)

@export var debug_color : Color = Color(Color.RED, 0.9):
	set(value):
		debug_color = value
		if _palm_collision_shape:
			_palm_collision_shape.debug_color = debug_color

		for bone in _digit_collision_shapes:
			if _digit_collision_shapes[bone]:
				_digit_collision_shapes[bone].debug_color = debug_color
#endregion

## Target-override class
class TargetOverride:
	## Target of the override
	var target : Node3D

	## Target priority
	var priority : int

	## Target offset
	var offset : Transform3D

	## Target-override constructor
	func _init(t : Node3D, p : int, o : Transform3D = Transform3D()):
		target = t
		priority = p
		offset = o

#region Private Variables
# Trackers used
var _hand_tracker : XRHandTracker
var _hand_skeleton : Skeleton3D
var _ghost_skeleton : Skeleton3D
var _controller_tracker : XRControllerTracker
var _pickup : XRT2Pickup
var _parent_body : CollisionObject3D

# Sorted stack of TargetOverride
var _target_overrides : Array[TargetOverride]

# Current target override
var _target_override : Node3D

# Current target offset
var _target_offset : Transform3D

# Hand meshes
var _hand_mesh : Node3D
var _ghost_mesh : Node3D

# Skeleton collisions
var _hand_tracking_parent : XRNode3D
var _palm_collision_shape : CollisionShape3D
var _digit_collision_shapes : Dictionary[String, CollisionShape3D]
#endregion


#region Public API
## Return a XR collision hand ancestor
static func get_xr_collision_hand(p_node : Node3D) -> XRT2CollisionHand:
	var parent = p_node.get_parent()
	while parent:
		if parent is XRT2CollisionHand:
			return parent

		parent = parent.get_parent()

	# Not found
	return null


## Returns the collision parent object for this collision hand.
## Assumed to be the players body.
func get_collision_parent() -> CollisionObject3D:
	var parent = get_parent()
	while parent:
		if parent is CollisionObject3D:
			return parent
		parent = parent.get_parent()

	return null
#endregion


#region Public Action API
## Returns true if hand tracking API is used
func get_is_hand_tracking() -> bool:
	if _hand_tracker and _hand_tracker.has_tracking_data:
		return true

	return false

## Returns the pose object that handles our tracking.
func get_pose() -> XRPose:
	if _hand_tracker:
		var pose : XRPose = _hand_tracker.get_pose("default")
		if pose:
			return pose

	if _controller_tracker:
		for fallback_pose_action in fallback_pose_actions:
			var pose : XRPose = _controller_tracker.get_pose(fallback_pose_action)
			if pose:
				return pose

	return null


## Returns [code]true[/code] if we have tracking data for this hand
func get_has_tracking_data() -> bool:
	var pose = get_pose()
	if pose:
		return pose.has_tracking_data

	return false


## Get the transform for the given pose action of the normal tracker
func get_pose_transform(pose_action : String) -> Transform3D:
	if _controller_tracker and _hand_tracker:
		var controller_pose : XRPose = _controller_tracker.get_pose(pose_action)
		if controller_pose:
			var hand_pose : XRPose = get_pose()
			if hand_pose:
				# Use our hand controller pose
				var hand_transform : Transform3D = hand_pose.get_adjusted_transform()
				if !get_is_hand_tracking():
					var offset : Transform3D
					offset.basis = Basis.from_euler(fallback_offset_rotation)
					offset.origin = fallback_offset_position
					hand_transform = hand_transform * offset

				return hand_transform.inverse() * controller_pose.get_adjusted_transform()

	return Transform3D()


## Returns value for an associated action
func get_input(action_name) -> Variant:
	if _controller_tracker:
		return _controller_tracker.get_input(action_name)

	return null


## Trigger a haptic pulse on this controller
## Specific to OpenXR:
## - Frequence of 0.0 choses an optimal frequency for a short pulse
## - Duration of -1 choses an optimal duration for a short pulse
func trigger_haptic_pulse(action_name: String, frequency: float = 0.0, amplitude: float = 1.0, duration_sec: float = -1, delay_sec: float = 0):
	var xr_interface = XRServer.primary_interface
	if xr_interface and _controller_tracker:
		xr_interface.trigger_haptic_pulse(action_name, _controller_tracker.name, frequency, amplitude, duration_sec, delay_sec)
#endregion


#region Public Target Override API
## This function adds a target override. The collision hand will attempt to
## move to the highest priority target, or the [XRController3D] if no override
## is specified.
func add_target_override(target : Node3D, priority : int, offset : Transform3D = Transform3D()) \
	-> void:
	# Remove any existing target override from this source
	var modified := _remove_target_override(target)

	# Insert the target override
	_insert_target_override(target, priority, offset)
	modified = true

	# Update the target
	if modified:
		_update_target()


## This function remove a target override.
func remove_target_override(target : Node3D) -> void:
	# Remove the target override
	var modified := _remove_target_override(target)

	# Update the pose
	if modified:
		_update_target()
#endregion


#region Public Skeleton API
## Return a string of bone names for our collision hand
func get_concatenated_bone_names() -> String:
	if not _hand_mesh:
		return ""

	var skeleton : Skeleton3D = _get_skeleton_node(_hand_mesh)
	if not skeleton:
		return ""

	return skeleton.get_concatenated_bone_names()

## Get the transform of the given bone local to our collision hand
func get_bone_transform(bone_name : String) -> Transform3D:
	if not _hand_mesh:
		return Transform3D()

	var skeleton : Skeleton3D = _get_skeleton_node(_hand_mesh)
	if not skeleton:
		return Transform3D()

	var bone_idx = skeleton.find_bone(bone_name)
	var bone_transform : Transform3D = _hand_skeleton.get_bone_global_pose(bone_idx)

	var orient_to_godot : Basis = Basis.from_euler(Vector3(0.5 * PI, 0.5 * -PI, 0.0)) if hand==0 \
		else Basis.from_euler(Vector3(0.5 * PI, PI, 0.5 * PI))
	var bone_offset : Transform3D = Transform3D(orient_to_godot, Vector3())

	return bone_transform * bone_offset
#endregion


#region Private Property Update Functions
# Check if we need different trackers
func _update_trackers():
	var new_hand_tracker : XRHandTracker = \
		XRServer.get_tracker("/user/hand_tracker/left" if hand == 0 else "/user/hand_tracker/right")
	if _hand_tracker != new_hand_tracker:
		# Just assign it
		_hand_tracker = new_hand_tracker

	var new_controller_tracker : XRControllerTracker = \
		XRServer.get_tracker("left_hand" if hand == 0 else "right_hand")
	if _controller_tracker != new_controller_tracker:
		if _controller_tracker:
			_controller_tracker.button_pressed.disconnect(_on_button_pressed)
			_controller_tracker.button_released.disconnect(_on_button_released)
			_controller_tracker.input_float_changed.disconnect(_on_input_float_changed)
			_controller_tracker.input_vector2_changed.disconnect(_on_input_vector2_changed)

		_controller_tracker = new_controller_tracker
		if _controller_tracker:
			_controller_tracker.button_pressed.connect(_on_button_pressed)
			_controller_tracker.button_released.connect(_on_button_released)
			_controller_tracker.input_float_changed.connect(_on_input_float_changed)
			_controller_tracker.input_vector2_changed.connect(_on_input_vector2_changed)


func _update_hand_motion_range():
	var openxr_interface : OpenXRInterface = XRServer.find_interface("OpenXR")
	if openxr_interface and openxr_interface.is_initialized():
		var openxr_hand = OpenXRInterface.HAND_LEFT if hand == 0 else OpenXRInterface.HAND_RIGHT
		var openxr_motion_range : OpenXRInterface.HandMotionRange
		match hand_motion_range:
			0: openxr_motion_range = OpenXRInterface.HAND_MOTION_RANGE_UNOBSTRUCTED
			1: openxr_motion_range = OpenXRInterface.HAND_MOTION_RANGE_CONFORM_TO_CONTROLLER
			_: openxr_motion_range = OpenXRInterface.HAND_MOTION_RANGE_UNOBSTRUCTED

		openxr_interface.set_motion_range(openxr_hand, openxr_motion_range)
#endregion


#region Private Godot Node Functions
# Validate our properties
func _validate_property(property: Dictionary):
	# Always hide these built in properties as we control them
	if property.name in [ \
		"process_physics_priority", \
		"gravity_scale", \
		"mass", \
		"continuous_cd", \
		"custom_integrator", \
		"freeze", \
		"linear_damp", \
		"linear_damp_mode", \
		"angular_damp", \
		"angular_damp_mode" \
	]:
		property.usage = PROPERTY_USAGE_NONE

	if mode != CollisionHandMode.COLLIDE and property.name in [\
		"teleport_distance", \
		"drop_on_teleport", \
		"hand_mass", \
		"force_coef", \
		"torque_coef", \
	]:
		property.usage = PROPERTY_USAGE_NONE

# Called when the node enters the scene tree for the first time.
func _ready():
	_palm_collision_shape = CollisionShape3D.new()
	_palm_collision_shape.name = "PalmCol"
	_palm_collision_shape.shape = preload("res://addons/godot-xr-tools2/hands/xrt2_hand_palm.shape")
	# This probably needs to be set based on left or right hand
	_palm_collision_shape.rotation_degrees = Vector3(0.0, 90, 90)
	_palm_collision_shape.debug_color = debug_color
	add_child(_palm_collision_shape, false, Node.INTERNAL_MODE_BACK)

	# Hardcode these values
	gravity_scale = 0.0
	continuous_cd = true
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 500.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 500.0
	mass = hand_mass

	# Init our hand meshes
	_update_hand_meshes()

	if Engine.is_editor_hint():
		return

	# Disconnect from parent transform as we move to it in the physics step,
	# and boost the physics priority above any grab-drivers or hands.
	top_level = true
	process_physics_priority = -90

	_parent_body = get_collision_parent()
	if _parent_body:
		# Hands shouldn't collide with a parent collision object
		add_collision_exception_with(_parent_body)
		_parent_body.add_collision_exception_with(self)

	var dynamic_rig : XRT2DynamicPlayerRig = XRT2DynamicPlayerRig.get_xr_dynamic_player_rig(self)
	if dynamic_rig:
		# Connect to any signals we need
		dynamic_rig.player_moved.connect(_on_player_moved)

	# If we have a pickup function, get it
	_pickup = XRT2Pickup.get_pickup(self)

	# Make sure our trackers are and stay correct
	_update_trackers()
	XRServer.tracker_added.connect(_on_tracker_signal)
	XRServer.tracker_removed.connect(_on_tracker_signal)
	XRServer.tracker_updated.connect(_on_tracker_signal)

	# Update our hand motion range
	_update_hand_motion_range()

	# Update the target
	_update_target()


# Handle physics processing
func _physics_process(delta):
	if Engine.is_editor_hint():
		return

	# Handle DISABLED or no target.
	if mode == CollisionHandMode.DISABLED:
		freeze = true
		return

	var target : Transform3D

	if _target_override:
		target = _target_override.global_transform * _target_offset
	else:
		var found_tracking_data = false

		# Give priority to our hand tracker.
		if _hand_tracker:
			var pose : XRPose = _hand_tracker.get_pose("default")
			if pose and pose.has_tracking_data:
				target = pose.get_adjusted_transform()
				found_tracking_data = true

		# Check our controller tracker.
		if not found_tracking_data and _controller_tracker:
			for fallback_pose_action in fallback_pose_actions:
				var pose : XRPose = _controller_tracker.get_pose(fallback_pose_action)
				if pose and pose.has_tracking_data:
					target.basis = Basis.from_euler(fallback_offset_rotation)
					target.origin = fallback_offset_position
					target = pose.get_adjusted_transform() * target
					found_tracking_data = true
					break

		# Ignore when controller is not tracking.
		if not found_tracking_data:
			freeze = true
			return

		# Seeing we're working in global space,
		# we need to take our parent into account
		var parent_transform : Transform3D = get_parent().global_transform 
		target = parent_transform * target

	# Always place our ghost mesh at our tracked location.
	if _ghost_mesh:
		_ghost_mesh.global_transform = target

	# Handle TELEPORT
	if mode == CollisionHandMode.TELEPORT:
		freeze = true
		global_transform = target
		return

	# Handle too far from target.
	if global_position.distance_to(target.origin) > teleport_distance:
		if drop_on_teleport and _pickup:
			# If we're holding something, drop it!
			_pickup.drop_held_object()

		freeze = true
		global_transform = target
		return

	# We got this far, make sure we're unfrozen and let Godot position our hand.
	if freeze:
		freeze = false
		linear_velocity = Vector3()
		angular_velocity = Vector3()

	# Implementation below inspired by Dedm0zaj's physics hand implementation.
	# We're attempting to calculate actual force/torque needed however.

	# TODO adjust this correctly if we are holding an object.

	# Grab our rigid body state.
	var state : PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(get_rid())

	# Apply force to move hand to tracked location:
	# acceleration = (distance - current_velocity * t) / (0.5 * t²)

	var factor = 0.5 * delta * delta
	var current_linear_velocity = linear_velocity  * clamp(1.0 - (linear_damp * delta), 0.0, 1.0)

	# Add our gravity.
	if state:
		current_linear_velocity += state.total_gravity * delta

	# Calculate the required force based on our desired movement.
	var linear_movement : Vector3 = target.origin - global_position
	var needed_acceleration : Vector3 = (linear_movement - current_linear_velocity * delta) / factor
	var linear_force : Vector3 = needed_acceleration * mass * 0.5 # No idea why * 0.5???

	# Limit our force.
	var required_force = linear_force.length()
	if required_force > max_force:
		var overflow_force = required_force - max_force
		linear_force *= (max_force + overflow_force * force_falloff_factor) / required_force

	# Apply force logic.
	apply_central_force(linear_force)

	# Apply torque to rotate hand to tracked rotation:
	# Torque = moment_of_inertia * angular_acceleration

	# Get our moment of inertial from our rigidbody state.
	var moment_of_inertia : Vector3 = Vector3()
	if state:
		if state.inverse_inertia != Vector3():
			moment_of_inertia = Vector3(mass, mass, mass) / state.inverse_inertia

	# Apply our damp so we know our current velocity.
	var current_angular_velocity : Vector3 = angular_velocity * clamp(1.0 - (angular_damp * delta), 0.0, 1.0)

	# Calculate the needed torque.
	var angular_movement : Vector3 = (target.basis * global_basis.inverse()).get_euler()
	var needed_angular_acceleration : Vector3 = (angular_movement - current_angular_velocity * delta) / factor
	var torque : Vector3 = moment_of_inertia * needed_angular_acceleration * 0.5 # Why 0.5?

	apply_torque(torque)


func _process(_delta):
	if Engine.is_editor_hint():
		return

	# Our hand should now be positioned so we can do our ghost logic.
	if _ghost_mesh:
		_ghost_mesh.visible = false
		if enable_ghost_hand:
			if (_ghost_mesh.global_position - _hand_mesh.global_position).length() > 0.005:
				_ghost_mesh.visible = true
			else:
				if (_ghost_mesh.global_basis * _hand_mesh.global_basis.inverse()) \
					.get_rotation_quaternion().get_angle() > deg_to_rad(15.0):
					_ghost_mesh.visible = true
#endregion


#region Private Target Override Functions
# This function inserts a target override into the overrides list by priority
# order.
func _insert_target_override( \
	target : Node3D, priority : int, offset : Transform3D = Transform3D() \
	) -> void:
	# Construct the target override
	var override := TargetOverride.new(target, priority, offset)

	# Iterate over all target overrides in the list
	for pos in _target_overrides.size():
		# Get the target override
		var o : TargetOverride = _target_overrides[pos]

		# Insert as early as possible to not invalidate sorting
		if o.priority <= priority:
			_target_overrides.insert(pos, override)
			return

	# Insert at the end
	_target_overrides.push_back(override)


# This function removes a target from the overrides list
func _remove_target_override(target : Node) -> bool:
	var pos := 0
	var length := _target_overrides.size()
	var modified := false

	# Iterate over all pose overrides in the list
	while pos < length:
		# Get the target override
		var o : TargetOverride = _target_overrides[pos]

		# Check for a match
		if o.target == target:
			# Remove the override
			_target_overrides.remove_at(pos)
			modified = true
			length -= 1
		else:
			# Advance down the list
			pos += 1

	# Return the modified indicator
	return modified


# This function updates the target for hand movement.
func _update_target() -> void:
	# Assume no current override.
	_target_override = null
	_target_offset = Transform3D()

	# Use first target override if specified
	if _target_overrides.size():
		_target_override = _target_overrides[0].target
		_target_offset = _target_overrides[0].offset
#endregion


#region Private Hand Mesh Functions
# Find the skeleton node child
func _get_skeleton_node(p_node : Node) -> Skeleton3D:
	for child in p_node.get_children():
		if child is Skeleton3D:
			return child

		var ret : Skeleton3D = _get_skeleton_node(child)
		if ret:
			return ret

	return null


# Add modifier nodes to our hand meshes
func _add_hand_modifiers(p_hand_mesh : Node3D) -> void:
	var skeleton_node = _get_skeleton_node(p_hand_mesh)
	if not skeleton_node:
		push_error("Couldn't locate skeleton node for " + name)
		return

	# Add hand tracking modifier
	var hand_tracking_modifier : XRHandModifier3D = XRHandModifier3D.new()
	hand_tracking_modifier.hand_tracker = "/user/hand_tracker/left" if hand == 0 \
		else "/user/hand_tracker/right"
	skeleton_node.add_child(hand_tracking_modifier)

	# Add fallback modifier
	var hand_fallback_modifier : XRT2HandFallbackModifier3D= XRT2HandFallbackModifier3D.new()
	hand_fallback_modifier.trigger_action = trigger_action
	hand_fallback_modifier.trigger_curl = trigger_curl
	hand_fallback_modifier.grip_action = grip_action
	hand_fallback_modifier.grip_curl = grip_curl
	skeleton_node.add_child(hand_fallback_modifier)

	# TODO add pose override modifier

# Find the mesh_instance node child
func _get_mesh_instance_node(p_node : Node) -> MeshInstance3D:
	for child in p_node.get_children():
		if child is MeshInstance3D:
			return child

		var ret : MeshInstance3D = _get_mesh_instance_node(child)
		if ret:
			return ret

	return null


# Set the material on the given hand mesh
func _update_hand_material(p_node : Node, p_material : Material, p_cast_shadows : bool) -> void:
	var mesh_instance = _get_mesh_instance_node(p_node)
	if mesh_instance:
		mesh_instance.material_override = p_material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if p_cast_shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _update_hand_meshes():
	# Clean up old hand meshes
	_clear_digit_collisions()

	if _hand_skeleton:
		_hand_skeleton = null

	if _hand_mesh:
		remove_child(_hand_mesh)
		_hand_mesh.queue_free()
		_hand_mesh = null

	if _ghost_skeleton:
		_ghost_skeleton.skeleton_updated.disconnect(_on_skeleton_updated)
		_ghost_skeleton = null

	if _ghost_mesh:
		remove_child(_ghost_mesh)
		_ghost_mesh.queue_free()
		_ghost_mesh = null

	# Load new ones
	var hand_scene : PackedScene
	if alternative_hand_scene:
		hand_scene = alternative_hand_scene
	elif hand == 0:
		hand_scene = preload("res://addons/godot-xr-tools2/hands/gltf/LeftHandHumanoid.gltf")
	else:
		hand_scene = preload("res://addons/godot-xr-tools2/hands/gltf/RightHandHumanoid.gltf")

	if hand_scene:
		_hand_mesh = hand_scene.instantiate()
		if _hand_mesh:
			_hand_mesh.visible = show_hand_mesh
			add_child(_hand_mesh)
			_update_hand_material(_hand_mesh, material_override, true)

			_hand_skeleton = _get_skeleton_node(_hand_mesh)

		_ghost_mesh = hand_scene.instantiate()
		if _ghost_mesh:
			_ghost_mesh.visible = false
			_ghost_mesh.top_level = true
			add_child(_ghost_mesh)
			_add_hand_modifiers(_ghost_mesh)
			_update_hand_material(_ghost_mesh, \
				preload("res://addons/godot-xr-tools2/hands/gltf/ghost_material.tres"), false)

			# We apply our modifiers to our ghost skeleton,
			# and then copy them to our hand skeleton.
			# Eventually this will allow us to restrict the movement
			# on the hand based on collisions.
			_ghost_skeleton = _get_skeleton_node(_ghost_mesh)
			if _ghost_skeleton:
				_ghost_skeleton.skeleton_updated.connect(_on_skeleton_updated)
				_on_skeleton_updated()

	hand_mesh_changed.emit()
#endregion


#region Private Collision Functions
# Remove all our digit collisions
func _clear_digit_collisions() -> void:
	for digit : String in _digit_collision_shapes:
		var collision_node = _digit_collision_shapes[digit]
		remove_child(collision_node)
		collision_node.queue_free()
	_digit_collision_shapes.clear()
#endregion


#region Signal handling
# React to add/remove/change tracker signal
func _on_tracker_signal(_tracker_name: StringName, _type: int):
	_update_trackers()

# Update our skeleton including creating missing digit collisions
func _on_skeleton_updated() -> void:
	var bone_count = _ghost_skeleton.get_bone_count()
	for i in bone_count:
		var bone_transform : Transform3D = _ghost_skeleton.get_bone_global_pose(i)
		var collision_node : CollisionShape3D
		var offset : Transform3D
		offset.origin = Vector3(0.0, 0.015, 0.0) # move to side of object

		var bone_name = _ghost_skeleton.get_bone_name(i)
		if bone_name == ("LeftHand" if hand == 0 else "RightHand"):
			offset.origin = Vector3(0.0, 0.025, 0.0) # move to side of object
			collision_node = _palm_collision_shape
		elif bone_name.contains("Proximal") or bone_name.contains("Intermediate") or \
			bone_name.contains("Distal"):
			if _digit_collision_shapes.has(bone_name):
				collision_node = _digit_collision_shapes[bone_name]
			else:
				collision_node = CollisionShape3D.new()
				collision_node.name = bone_name + "Col"
				collision_node.shape = \
					preload("res://addons/godot-xr-tools2/hands/xrt2_hand_digit.shape")
				collision_node.debug_color = debug_color
				add_child(collision_node, false, Node.INTERNAL_MODE_BACK)
				_digit_collision_shapes[bone_name] = collision_node

		if collision_node:
			# TODO it would require a far more complex approach,
			# but being able to check if our collision shapes
			# can move to their new locations would be interesting.

			# For now just copy our transform to our collision shape
			collision_node.transform = bone_transform * offset

		# And copy our bone transform to our hand skeleton.
		var bone_pose : Transform3D = _ghost_skeleton.get_bone_pose(i)
		_hand_skeleton.set_bone_pose(i, bone_pose)

	skeleton_updated.emit()


func _on_player_moved(from_transform : Transform3D, to_transform : Transform3D, is_teleport : bool):
	if is_teleport:
		# TODO this needs to be implemented
		pass
	else:
		# Old logic, no longer applied
		# var current_local_transform : Transform3D = from_transform.inverse() * global_transform
		# var target_transform : Transform3D = to_transform * current_local_transform
		# var delta_movement : Vector3 = target_transform.origin - global_transform.origin
		pass


func _on_button_pressed(action_name: String):
	# Just chain this.
	button_pressed.emit(action_name)


func _on_button_released(action_name: String):
	# Just chain this.
	button_released.emit(action_name)


func _on_input_float_changed(action_name: String, value: float):
	# Just chain this.
	input_float_changed.emit(action_name, value)


func _on_input_vector2_changed(action_name: String, vector: Vector2):
	# Just chain this.
	input_vector2_changed.emit(action_name, vector)
#endregion
