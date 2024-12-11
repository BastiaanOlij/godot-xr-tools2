#-------------------------------------------------------------------------------
# xrt2_grab_point.gd
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
class_name XRT2GrabPoint
extends Node3D

## XRTools2 Grab Point
##
## This node identifies a predefined place a user can grab an object.

# TODO for now this is just a bare bone placeholder:
# - be able to specify a pose for the hand that we'll use, be nice if we can auto generate this.

## Left hand can grab this grab point
@export var left_hand : bool = true

## Right hand can grab this grab point
@export var right_hand : bool = true

## Visualise our hand
## For editor only
@export_enum("Off","Left","Right") var show_hand : int = 0:
	set(value):
		show_hand = value

		if is_inside_tree():
			_update_show_hand()


var _hand_mesh : Node3D

func _get_skeleton_node(node : Node3D) -> Skeleton3D:
	for child in node.get_children():
		if child is Skeleton3D:
			return child

		var ret = _get_skeleton_node(child)
		if ret:
			return ret

	return null


func _update_show_hand():
	if not Engine.is_editor_hint():
		return

	if _hand_mesh:
		remove_child(_hand_mesh)
		_hand_mesh.queue_free()
		_hand_mesh = null

	if show_hand == 0:
		return

	var hand_scene : PackedScene
	var bone_name : String
	if show_hand == 1:
		hand_scene = preload("res://addons/godot-xr-tools2/hands/gltf/LeftHandHumanoid.gltf")
		bone_name = "LeftHand"
	else:
		hand_scene = preload("res://addons/godot-xr-tools2/hands/gltf/RightHandHumanoid.gltf")
		bone_name = "RightHand"

	_hand_mesh = hand_scene.instantiate()
	add_child(_hand_mesh, false, Node.INTERNAL_MODE_BACK)
	var skeleton : Skeleton3D = _get_skeleton_node(_hand_mesh)
	if skeleton:
		var bone_idx = skeleton.find_bone(bone_name)
		if bone_idx != -1:
			var bone_transform : Transform3D = skeleton.get_bone_global_pose(bone_idx)
			var orient_to_godot : Basis = Basis.from_euler(Vector3(0.5 * PI, 0.5 * -PI, 0.0)) \
				if show_hand == 1 else Basis.from_euler(Vector3(0.5 * PI, PI, 0.5 * PI))
			var bone_offset : Transform3D = Transform3D(orient_to_godot, Vector3())
			_hand_mesh.transform = (bone_transform * bone_offset).inverse()

func _ready():
	_update_show_hand()

# Verifies if we have a valid configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	var parent = get_parent()
	if not parent is PhysicsBody3D:
		warnings.push_back("This node should be a child of a PhysicsBody3D node.")

	# Return warnings
	return warnings
