#-------------------------------------------------------------------------------
# xrt2_hand_attachment.gd
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
class_name XRT2HandAttachment
extends Node3D

## XRTools2 Hand Attachment Script
##
## This script exposes bone locations for collision hands.
## This has to be a child of a [XRT2CollisionHand] node.

#region Export variables
## The bone for our hand that we position this at
@export var bone_name: String:
	set(value):
		bone_name = value
		if is_inside_tree():
			_on_skeleton_updated()

## Additional position offset to apply
@export var position_offset: Vector3 = Vector3():
	set(value):
		position_offset = value
		if is_inside_tree():
			_on_skeleton_updated()

## Additional rotation offset to apply
@export var rotation_offset: Vector3 = Vector3():
	set(value):
		rotation_offset = value
		if is_inside_tree():
			_on_skeleton_updated()
#endregion

#region Private variables
var _updating : bool = false
var _xr_collision_hand: XRT2CollisionHand
#endregion

#region Public functions
## Return our collision hand (if applicable)
func get_xr_collision_hand() -> XRT2CollisionHand:
	return _xr_collision_hand
#endregion

#region Private functions
# Verifies if we have a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not _xr_collision_hand:
		warnings.push_back("This node must be a child of an XRT2CollisionHand node.")

	# Return warnings
	return warnings


# Update our properties
func _validate_property(property):
	if (property.name == "bone_name"):
		var parent = get_parent()
		if parent and parent is XRT2CollisionHand:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = parent.get_concatenated_bone_names()
		else:
			property.hint = PROPERTY_HINT_NONE
			property.hint_string = ""
	elif (property.name == "rotation_offset"):
		property.hint = PROPERTY_HINT_RANGE
		property.hint_string = "0.0,360.0,radians_as_degrees"
	elif _xr_collision_hand and property.name in [ "position", "rotation", "scale", "rotation_edit_mode", "rotation_order", "top_level" ]:
		property.usage = PROPERTY_USAGE_NONE


func _enter_tree():
	_xr_collision_hand = XRT2CollisionHand.get_xr_collision_hand(self)
	if _xr_collision_hand:
		_xr_collision_hand.hand_mesh_changed.connect(_on_hand_mesh_changed)
		_xr_collision_hand.skeleton_updated.connect(_on_skeleton_updated)

		_on_skeleton_updated()

	notify_property_list_changed()


func _exit_tree():
	if _xr_collision_hand:
		_xr_collision_hand.hand_mesh_changed.disconnect(_on_hand_mesh_changed)
		_xr_collision_hand.skeleton_updated.disconnect(_on_skeleton_updated)
		_xr_collision_hand = null


func _on_hand_mesh_changed():
	notify_property_list_changed()
	_on_skeleton_updated()


func _on_skeleton_updated():
	var transform_offset:Transform3D = Transform3D(Basis.from_euler(rotation_offset), position_offset)

	if not _xr_collision_hand:
		transform = transform_offset
		return

	if _updating:
		return
	_updating = true

	if not bone_name.is_empty():
		transform = _xr_collision_hand.get_bone_transform(bone_name) * transform_offset
	else:
		transform = transform_offset

	_updating = false
#endregion
