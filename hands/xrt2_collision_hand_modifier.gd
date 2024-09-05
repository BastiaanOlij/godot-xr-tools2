# xrt2_collision_hand_modifier.gd
#
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

@tool
extends Node3D
class_name XRT2CollisionHandModifier

## XRTools2 Collision Hand Modifier Script
##
## This script copies the bone positions to the relevant collision shapes
## in our [XR2CollisionHandLeft] or [XR2CollisionHandRight] subscene.
## It does NOT constrain movement.

@export var collision_hand_node : XRT2CollisionHand


var _parent_xr_node : XRNode3D
var _collision_hand_parent : Node3D
var _skeleton_3d : Skeleton3D

# Verifies if we have a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not collision_hand_node:
		warnings.push_back("No collision hand node has been specified.")

	if not XRT2Helper.get_xr_node(self):
		warnings.push_back("This node requires an XRNode3D as an anchestor.")

	if not get_parent() is Skeleton3D:
		warnings.push_back("This node must be a child of a Skeleton3D node.")

	# Return warnings
	return warnings

# Called when the node enters the scene tree for the first time.
func _ready():
	if Engine.is_editor_hint():
		return

	_parent_xr_node = XRT2Helper.get_xr_node(self)
	if collision_hand_node:
		_collision_hand_parent = collision_hand_node.get_parent()

	var parent = get_parent()
	if parent is Skeleton3D:
		_skeleton_3d = parent
		_skeleton_3d.skeleton_updated.connect(_on_skeleton_updated)


func _on_skeleton_updated():
	if Engine.is_editor_hint():
		return

	if not _skeleton_3d:
		return

	if not collision_hand_node:
		return

	if not _collision_hand_parent:
		return

	var bone_count = _skeleton_3d.get_bone_count()
	for i in bone_count:
		var offset : Transform3D
		offset.origin = Vector3(0.0, 0.015, 0.0)

		var bone_name = _skeleton_3d.get_bone_name(i)
		if bone_name == "RightHand" or bone_name == "LeftHand":
			# We make an exception for our hands root nodes
			bone_name = "Palm"
			offset.origin = Vector3(0.0, 0.025, 0.0)

		var collision_node = collision_hand_node.find_child(bone_name, false)
		if collision_node and collision_node is CollisionShape3D:
			# We need to ignore our applied offsets in XRT2CollisionHandOffset or  nodes,
			# We assume for a moment that there are no scales applied on our hand models

			var t : Transform3D = _parent_xr_node.global_transform * _skeleton_3d.get_bone_global_pose(i)

			# We can ignore our XRT2CollisionHand* offset simply by taking its parents global transform :P
			collision_node.transform = _collision_hand_parent.global_transform.inverse() * t * offset
