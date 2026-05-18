#-------------------------------------------------------------------------------
# xrt2_snap_zone_gizmo.gd
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
extends EditorNode3DGizmoPlugin

var start_value: float = 1.0


func _get_gizmo_name():
	return "XRT2SnapZone"


func _has_gizmo(node):
	return node is XRT2SnapZone


func _can_be_hidden():
	true


func _init():
	create_material("lines", Color(1,0,1))
	create_handle_material("handles")


func _redraw(gizmo):
	gizmo.clear()

	var snap_zone: XRT2SnapZone = gizmo.get_node_3d()
	if not snap_zone:
		return

	var lines = PackedVector3Array()

	for angle in range(0, 36):
		var a1: float = deg_to_rad(angle * 10)
		var a2: float = deg_to_rad((angle + 1) * 10)

		lines.push_back(Vector3(snap_zone.radius, 0.0, 0.0).rotated(Vector3.UP, a1))
		lines.push_back(Vector3(snap_zone.radius, 0.0, 0.0).rotated(Vector3.UP, a2))

		lines.push_back(Vector3(0.0, snap_zone.radius, 0.0).rotated(Vector3.RIGHT, a1))
		lines.push_back(Vector3(0.0, snap_zone.radius, 0.0).rotated(Vector3.RIGHT, a2))

		lines.push_back(Vector3(0.0, snap_zone.radius, 0.0).rotated(Vector3.FORWARD, a1))
		lines.push_back(Vector3(0.0, snap_zone.radius, 0.0).rotated(Vector3.FORWARD, a2))

	gizmo.add_lines(lines, get_material("lines", gizmo), false)

	var handles = PackedVector3Array()
	handles.push_back(Vector3(0, snap_zone.radius, 0))
	gizmo.add_handles(handles, get_material("handles", gizmo), [])


func _get_handle_name(gizmo, handle_id, secondary):
	return "radius"


func _get_handle_value(gizmo, handle_id, secondary) -> Variant:
	var snap_zone: XRT2SnapZone = gizmo.get_node_3d()
	if not snap_zone:
		return null

	return snap_zone.radius


func _begin_handle_action(gizmo, handle_id, secondary):
	var snap_zone: XRT2SnapZone = gizmo.get_node_3d()
	if not snap_zone:
		start_value = 1.0
		return

	start_value = snap_zone.radius


func _set_handle(gizmo, handle_id, secondary, camera, screen_pos):
	var snap_zone: XRT2SnapZone = gizmo.get_node_3d()
	if not snap_zone:
		# print("No snap zone")
		return

	var ray_from: Vector3 = camera.project_ray_origin(screen_pos);
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos);

	var plane: Plane = Plane(snap_zone.global_basis.y.cross(camera.global_basis.x), snap_zone.global_position)
	var iray: Vector3 = plane.intersects_ray(ray_from, ray_dir)
	if not iray:
		# print("No intersection")
		return

	var new_radius = (iray - snap_zone.global_position).length()
	snap_zone.radius = new_radius

	# TODO: This is working but not always redrawing the gizmo, need to figure out why


func _commit_handle(gizmo, handle_id, secondary, restore, cancel):
	var snap_zone: XRT2SnapZone = gizmo.get_node_3d()
	if not snap_zone:
		return

	if cancel:
		snap_zone.radius = start_value
		return

	# TODO: This does not seem to work, need to figure this out!
	var undo_redo: UndoRedo = UndoRedo.new()
	undo_redo.create_action("SnapZone radius changed")
	undo_redo.add_do_property(snap_zone, "radius", snap_zone.radius)
	undo_redo.add_undo_property(snap_zone, "radius", start_value)
	undo_redo.commit_action()
	undo_redo.free()
