#-------------------------------------------------------------------------------
# xrt2_bone_visualiser.gd
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
class_name XRT2BoneVisualiser
extends Node3D

## Debug class for helping us validate our hand bones

@export var show_origin_bone: bool = true

var bone_nodes: Array[Node3D]
var bone_scene: PackedScene = load("res://addons/godot-xr-tools2/debug/xrt2_bone.tscn")

func _get_skeleton() -> Skeleton3D:
	var parent = get_parent()
	while parent:
		if parent is Skeleton3D:
			return parent
		if parent is XRT2CollisionHand:
			# Debug node, let's just grab the skeleton
			return parent._hand_skeleton
		parent = parent.get_parent()

	# Didn't find anything...
	return null


func _clear_nodes():
	for bone in bone_nodes:
		remove_child(bone)
		bone.queue_free()
	bone_nodes.clear()


func _find_first_child(skeleton: Skeleton3D, parent_idx: int) -> int:
	for bone_idx in skeleton.get_bone_count():
		if skeleton.get_bone_parent(bone_idx) == parent_idx:
			return bone_idx

	return -1


func _process(delta):
	var skeleton: Skeleton3D = _get_skeleton()
	if not skeleton:
		_clear_nodes()
		return

	var bone_count:int = skeleton.get_bone_count()
	if bone_count == 0:
		_clear_nodes()
		return

	for bone_idx in bone_count:
		var bone_node:Node3D
		if bone_idx < bone_nodes.size():
			bone_node = bone_nodes[bone_idx]
		else:
			bone_node = bone_scene.instantiate()
			add_child(bone_node, false, Node.INTERNAL_MODE_BACK)
			bone_nodes.push_back(bone_node)

		bone_node.transform = skeleton.get_bone_global_pose(bone_idx)
		var first_child = _find_first_child(skeleton, bone_idx)
		if first_child >= 0:
			var child_transform = skeleton.get_bone_global_pose(first_child)
			var bone_length = (bone_node.transform.origin - child_transform.origin).length()
			bone_node.scale = Vector3(bone_length, bone_length, bone_length)
		else:
			bone_node.scale = Vector3(0.02, 0.02, 0.02)

	if show_origin_bone:
		var bone_node:Node3D
		if bone_count < bone_nodes.size():
			bone_node = bone_nodes[bone_count]
		else:
			bone_node = bone_scene.instantiate()
			add_child(bone_node, false, Node.INTERNAL_MODE_BACK)
			bone_nodes.push_back(bone_node)
			bone_count += 1

			var first_transform = skeleton.get_bone_global_pose(0)
			var bone_length = (bone_node.transform.origin - first_transform.origin).length()
			bone_node.scale = Vector3(bone_length, bone_length, bone_length)

	while bone_nodes.size() > bone_count:
		bone_nodes.remove_at(bone_count)
