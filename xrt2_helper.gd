# xrt2_helper.gd
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
extends Node
class_name XRT2Helper

static func get_xr_controller(p_node : Node3D) -> XRController3D:
	var parent = p_node.get_parent()
	while parent:
		if parent is XRController3D:
			return parent

		parent = parent.get_parent()

	# Not found
	return null


static func get_xr_node(p_node : Node3D) -> XRNode3D:
	var parent = p_node.get_parent()
	while parent:
		if parent is XRNode3D:
			return parent

		parent = parent.get_parent()

	# Not found
	return null


static func get_xr_origin(p_node : Node3D) -> XROrigin3D:
	var parent = p_node.get_parent()
	while parent:
		if parent is XROrigin3D:
			return parent

		parent = parent.get_parent()

	# Not found
	return null
