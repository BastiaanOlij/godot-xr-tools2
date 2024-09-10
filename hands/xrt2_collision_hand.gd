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
extends XRT2ForceBody

## XRTools2 Collision Hand Container Script
##
## This script implements logic for collision hands. Specifically it tracks
## its ancestor [XRController3D], and can act as a container for hand models
## and pickup functions.
##
## Note: This works best when used with the palm-pose pose.

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

# Distance to teleport hands
const TELEPORT_DISTANCE := 1.0


## Controls the hand collision mode
@export var mode : CollisionHandMode = CollisionHandMode.COLLIDE

## Links to skeleton that adds finger digits
@export var hand_skeleton : Skeleton3D:
	set(value):
		if hand_skeleton == value:
			return

		if hand_skeleton:
			_hand_tracking_parent = null
			hand_skeleton.skeleton_updated.disconnect(_on_skeleton_updated)
			for digit in _digit_collision_shapes:
				var shape : CollisionShape3D = _digit_collision_shapes[digit]
				remove_child(shape)
				shape.queue_free()
			_digit_collision_shapes.clear()

		hand_skeleton = value
		if hand_skeleton and is_inside_tree():
			_update_hand_skeleton()

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

# Controller to target (if no target overrides)
var _controller : XRController3D

# Sorted stack of TargetOverride
var _target_overrides : Array[TargetOverride]

# Current target (controller or override)
var _target : Node3D

# Current target offset
var _target_offset : Transform3D

# Skeleton collisions
var _hand_tracking_parent : XRNode3D
var _palm_collision_shape : CollisionShape3D
var _digit_collision_shapes : Dictionary

## Return a XR collision hand ancestor
static func get_xr_collision_hand(p_node : Node3D) -> XRT2CollisionHand:
	var parent = p_node.get_parent()
	while parent:
		if parent is XRT2CollisionHand:
			return parent

		parent = parent.get_parent()

	# Not found
	return null


# Called when the node enters the scene tree for the first time.
func _ready():
	_palm_collision_shape = CollisionShape3D.new()
	_palm_collision_shape.name = "Palm"
	_palm_collision_shape.shape = preload("res://addons/godot-xr-tools2/hands/xrt2_hand_palm.shape")
	# This probably needs to be set based on left or right hand
	_palm_collision_shape.rotation_degrees = Vector3(0.0, 90, 90)
	add_child(_palm_collision_shape, false, Node.INTERNAL_MODE_BACK)

	_update_hand_skeleton()

	if Engine.is_editor_hint():
		return

	super()

	# Disconnect from parent transform as we move to it in the physics step,
	# and boost the physics priority above any grab-drivers or hands.
	top_level = true
	process_physics_priority = -90

	# Populate nodes
	_controller = XRT2Helper.get_xr_controller(self)

	# Update the target
	_update_target()


# Handle physics processing
func _physics_process(_delta):
	if Engine.is_editor_hint():
		return

	# Ignore when controller is not tracking
	if not _controller.get_has_tracking_data():
		return

	# Move to the current target
	_move_to_target()


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
	# Start by assuming the controller
	_target = _controller
	_target_offset = Transform3D()

	# Use first target override if specified
	if _target_overrides.size():
		_target = _target_overrides[0].target
		_target_offset = _target_overrides[0].offset


# This function moves the collision hand to the target node.
func _move_to_target():
	# Handle DISABLED or no target
	if mode == CollisionHandMode.DISABLED or not _target:
		return

	var target : Transform3D = _target.global_transform * _target_offset

	# Handle TELEPORT
	if mode == CollisionHandMode.TELEPORT:
		global_transform = target
		return

	# Handle too far from target
	if global_position.distance_to(target.origin) > TELEPORT_DISTANCE:
		global_transform = target
		return

	# Orient the hand then move
	global_transform.basis = target.basis
	move_and_slide(target.origin - global_position)
	force_update_transform()

func _update_hand_skeleton():
	if hand_skeleton:
		_hand_tracking_parent = XRT2Helper.get_xr_node(hand_skeleton)
		hand_skeleton.skeleton_updated.connect(_on_skeleton_updated)

		# Run atleast once to init
		_on_skeleton_updated()

func _on_skeleton_updated():
	var bone_count = hand_skeleton.get_bone_count()
	for i in bone_count:
		var collision_node : CollisionShape3D
		var offset : Transform3D
		offset.origin = Vector3(0.0, 0.015, 0.0) # move to side of object

		var bone_name = hand_skeleton.get_bone_name(i)
		if bone_name == "RightHand" or bone_name == "LeftHand":
			offset.origin = Vector3(0.0, 0.025, 0.0) # move to side of object
			collision_node = _palm_collision_shape
		elif bone_name.contains("Proximal") or bone_name.contains("Intermediate") or \
			bone_name.contains("Distal"):
			if _digit_collision_shapes.has(bone_name):
				collision_node = _digit_collision_shapes[bone_name]
			else:
				print("Creating ",bone_name)
				collision_node = CollisionShape3D.new()
				collision_node.name = bone_name
				collision_node.shape = \
					preload("res://addons/godot-xr-tools2/hands/xrt2_hand_digit.shape")
				add_child(collision_node, false, Node.INTERNAL_MODE_BACK)
				_digit_collision_shapes[bone_name] = collision_node

		if collision_node:
			# TODO it would require a far more complex approach,
			# but being able to check if our collision shapes can move to their new locations
			# would be interesting.

			# We need to ignore our applied offsets in XRT2CollisionHandOffset or nodes,
			# We assume for a moment that there are no scales applied on our hand models
			var t : Transform3D = _hand_tracking_parent.global_transform * \
				hand_skeleton.get_bone_global_pose(i)

			# We can ignore our XRT2CollisionHand* offset simply by using its parents.
			collision_node.transform = get_parent().global_transform.inverse() * t * offset
