#-------------------------------------------------------------------------------
# xrt2_snap_zone.gd
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

class_name XRT2SnapZone
extends Node3D

## XRTools2 Snap Zone Script
##
## Snap magnets are objects that will attempt to snap an object
## close to it by pulling on it like a magnet.
## The pulling force gets stronger the closer it gets.
## The assumption is that the pulled object will be pulled against
## another physics body related to the magnet.


#region Signals
signal captured(body)
signal released(body)
#endregion

#region Export variables
# Is our snap zone enabled?
@export var enabled: bool = true:
	set(value):
		enabled = value

		if Engine.is_editor_hint():
			return

		set_physics_process(enabled)
		set_process(enabled and _captured_body)
		if not enabled:
			_clear_closest_body()
			release_captured_body()

## Radius within which we snap objects
@export var radius: float = 0.05

## Optional, object to snap must be part of this group
@export var require_group: String

## Optional, object to snap must not belong to this group
@export var exclude_group: String

## We only snap objects belonging to these physics layers
@export_flags_3d_physics var detection_mask: int = 1
#endregion


#region Private variables
static var _snap_zones: Array[XRT2SnapZone]

# Object detection
var _detection_shape: SphereShape3D
var _detection_query: PhysicsShapeQueryParameters3D
var _detection_exclude : Array[RID]

# Track which object is currently closest and can potentially be snapped
var _closest_body: PhysicsBody3D
var _closest_offset: Transform3D
static var _closest_lookup: Dictionary[PhysicsBody3D, XRT2SnapZone]

# Track object currently attached to our snap point
var _captured_body: PhysicsBody3D
var _captured_offset: Transform3D
var _captured_was_frozen: bool = false
var _joint: Generic6DOFJoint3D
static var _captured_lookup: Dictionary[PhysicsBody3D, XRT2SnapZone]
#endregion


#region Public functions
## Find our XRT2SnapZone that has currently captured this object (if any)
static func captured_by(body: PhysicsBody3D) -> XRT2SnapZone:
	if _captured_lookup.has(body):
		return _captured_lookup[body]

	return null


static func closest_snap_zone(to: Vector3) -> XRT2SnapZone:
	var closest: XRT2SnapZone
	var dist_squared: float = 9999.9

	for snap_zone in _snap_zones:
		var new_dist_squared = (snap_zone.global_position - to).length_squared()
		if new_dist_squared < dist_squared:
			dist_squared = new_dist_squared
			closest = snap_zone

	return closest


## Find our XRT2SnapZone that has currently closest to and in snapping range of this object (if any)
static func closest_to(body: PhysicsBody3D) -> XRT2SnapZone:
	if _closest_lookup.has(body):
		return _closest_lookup[body]

	return null


## Return the closest offset (if applicable)
func get_closest_offset(global: bool = true):
	if global:
		return global_transform * _closest_offset
	else:
		return _closest_offset


## Capture this node
func capture_node(body: PhysicsBody3D, offset: Transform3D = Transform3D()):
	if not enabled:
		return

	if _captured_body:
		if _captured_body == body:
			return
		release_captured_body()

	_clear_closest_body()

	_captured_body = body
	_captured_offset = offset
	_captured_was_frozen = _captured_body.freeze

	# Position
	_captured_body.global_transform = global_transform.orthonormalized() * _captured_offset

	# Add to our lookup cache
	_captured_lookup[_captured_body] = self

	var parent: Node = get_parent()

	if parent is PhysicsBody3D:
		_joint = Generic6DOFJoint3D.new()
		_joint.node_a = parent.get_path()
		_joint.node_b = _captured_body.get_path()
		add_child(_joint, false, Node.INTERNAL_MODE_BACK)
	else:
		_captured_body.freeze = true

	while parent:
		if parent is RigidBody3D:
			XRT2.add_collision_exception(parent, _captured_body)
		parent = parent.get_parent()

	set_process(true)

	captured.emit(_captured_body)

## Release our current captured node
func release_captured_body():
	if _joint:
		remove_child(_joint)
		_joint.queue_free()
		_joint = null

	if not _captured_body:
		return

	_captured_lookup.erase(_captured_body)

	if not is_instance_valid(_captured_body):
		_captured_body = null
		return

	var parent: Node = get_parent()
	while parent:
		if parent is RigidBody3D:
			XRT2.remove_collision_exception(parent, _captured_body)
		parent = parent.get_parent()

	_captured_body.freeze = _captured_was_frozen
	var was_captured = _captured_body
	_captured_body = null

	set_process(false)

	released.emit(was_captured)
#endregion


#region Private functions
func _clear_closest_body():
	if not _closest_body:
		return

	_closest_lookup.erase(_closest_body)
	_closest_body = null
	_closest_offset = Transform3D()

	# print(self.name, "._clear_closest_body: ", _closest_lookup)


func _set_closest_body(body: PhysicsBody3D, offset: Transform3D):
	if _closest_body:
		if _closest_body == body:
			return
		_clear_closest_body()

	# body was the closest to another snap zone? then they're no longer the closest!
	if _closest_lookup.has(body):
		_closest_lookup[body]._clear_closest_body()

	_closest_body = body
	_closest_offset = offset
	_closest_lookup[body] = self

	# print(self.name, "._set_closest_body: ", _closest_lookup)


func _enter_tree():
	if Engine.is_editor_hint():
		return

	_snap_zones.push_back(self)

	_detection_exclude.clear()

	# Exclude any collision parents of our node
	var parent = get_parent()
	while parent:
		if parent is CollisionObject3D:
			_detection_exclude.push_back(parent.get_rid())
		parent = parent.get_parent()


func _ready():
	if Engine.is_editor_hint():
		return

	# Create our detection shape
	_detection_shape = SphereShape3D.new()

	# Create our detection query
	_detection_query = PhysicsShapeQueryParameters3D.new()
	_detection_query.shape = _detection_shape


func _exit_tree():
	if Engine.is_editor_hint():
		return

	_detection_exclude.clear()

	release_captured_body()

	_snap_zones.erase(self)


func _physics_process(delta):
	if Engine.is_editor_hint():
		return

	if not enabled:
		_clear_closest_body()
		set_physics_process(false)
		return

	# JIC our captured object has been freed
	if _captured_body and not is_instance_valid(_captured_body):
		release_captured_body()

	# We already have a captured object
	if _captured_body:
		return

	var state : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	_detection_shape.radius = radius
	_detection_query.collision_mask = detection_mask
	_detection_query.exclude = _detection_exclude
	_detection_query.transform = global_transform

	# TODO: We may want to exclude all XRT2CollisionHand objects
	# and possibly other objects as well.
	# We may want to add a static register/unregister exclude function.

	var result: Dictionary = state.get_rest_info(_detection_query)
	if not result or result.is_empty():
		_clear_closest_body()
		return

	var closest_body: PhysicsBody3D = instance_from_id(result.collider_id)
	if not closest_body:
		_clear_closest_body()
		return

	# We can only snap rigid bodies and physical bones
	if not closest_body is RigidBody3D and not closest_body is PhysicalBone3D:
		_clear_closest_body()
		return

	# We shouldn't snap the players hands
	if closest_body is XRT2CollisionHand:
		_clear_closest_body()
		return

	# Is closest body in the required group?
	if require_group and not closest_body.is_in_group(require_group):
		_clear_closest_body()
		return

	# Is closest body not in the excluded group?
	if exclude_group and closest_body.is_in_group(exclude_group):
		_clear_closest_body()
		return

	# Already captured
	if captured_by(closest_body):
		_clear_closest_body()
		return

	# Find closest point on body to attract
	var snap_point: XRT2SnapPoint
	var snap_dist_squared: float = 999999.99
	for child: XRT2SnapPoint in closest_body.find_children("*", "XRT2SnapPoint", false):
		var new_dist: float = (child.global_position - global_position).length_squared()
		if new_dist < snap_dist_squared:
			snap_dist_squared = new_dist
			snap_point = child

	var closest_point: Vector3
	var offset_transform: Transform3D
	if snap_point:
		closest_point = snap_point.global_position
		offset_transform = snap_point.transform
	else:
		offset_transform.basis.y = -result.normal.normalized()
		offset_transform.basis.x = global_basis.z.cross(offset_transform.basis.y).normalized()
		offset_transform.basis.z = offset_transform.basis.x.cross(offset_transform.basis.y).normalized()

		closest_point = result.point
		offset_transform.origin = closest_point
		offset_transform = closest_body.global_transform.inverse() * offset_transform

	# Check if our we're the closest snap zone to our closest_body,
	# by distance (we may not have processed the others).
	if closest_snap_zone(closest_point) != self:
		_clear_closest_body()
		return

	# Currently picked up? We won't snap
	if XRT2Pickup.picked_up_by(closest_body):
		_set_closest_body(closest_body, offset_transform.inverse().orthonormalized())

		return

	capture_node(closest_body, offset_transform.inverse().orthonormalized())


func _process(_delta):
	if Engine.is_editor_hint():
		return

	if not enabled:
		set_process(false)
		return

	if not _captured_body:
		return
	if not is_instance_valid(_captured_body):
		release_captured_body()
		return

	# Handled through joint?
	if _joint:
		return

	# Just apply
	_captured_body.global_transform = global_transform.orthonormalized() * _captured_offset
#endregion
