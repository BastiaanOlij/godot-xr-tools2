#-------------------------------------------------------------------------------
# xrt2_ui_2d_in_3d_area.gd
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

extends Area3D

#region Export variables
# Size of our mesh
@export var display_size: Vector2

# Viewport that we're interacting with
@export var display_viewport: Viewport

# Subrect in viewport we're showing 
@export var display_subrect: Rect2i
#endregion


#region Private variables
# Array of pointers currently interacting with us
var _pointers: Array[XRT2Pointer]
#endregion


#region Private functions
func _point_to_coords(point: Vector3) -> Vector2:
	if display_viewport:
		# Convert point to local space:
		var local_point = global_transform.inverse() * point

		# Convert to coords to 0.0, 0.0 - 1.0, 1.0 range
		var coords = Vector2(clamp(local_point.x/display_size.x + 0.5, 0.0, 1.0), clamp(0.5 - local_point.y/display_size.y, 0.0, 1.0))

		# Apply size
		if display_subrect == Rect2i():
			coords *= Vector2(display_viewport.size)
		else:
			coords = coords * Vector2(display_subrect.size) + Vector2(display_subrect.position)

		return coords

	return Vector2()


func _xr_pointer_input(event: XRT2Pointer.PointerEvent) -> void:
	if display_viewport:
		# TODO: For now convert to simple mouse movement events.
		# If we have multiple pointers engaging simultaniously, we just react to the first one
		# that has focus.
		# Future enhancement we may look at multiple touch control support.

		if event is XRT2Pointer.GainedFocusEvent:
			_pointers.push_back(event.pointer)
		elif event is XRT2Pointer.LostFocusEvent:
			_pointers.erase(event.pointer)
		elif event is XRT2Pointer.MovedEvent:
			if _pointers.is_empty() or _pointers[0] != event.pointer:
				return

			var from: = _point_to_coords(event.was_pointing_at)
			var to := _point_to_coords(event.pointing_at)

			var input_event := InputEventMouseMotion.new()
			input_event.button_mask = 1 if event.pressed else 0
			input_event.position = to
			input_event.global_position = input_event.position
			input_event.relative = to - from

			display_viewport.push_input(input_event)
		elif event is XRT2Pointer.PressedEvent:
			if _pointers.is_empty() or _pointers[0] != event.pointer:
				return

			var input_event := InputEventMouseButton.new()
			input_event.button_mask = 1
			input_event.position = _point_to_coords(event.pointing_at)
			input_event.global_position = input_event.position
			input_event.button_index = MOUSE_BUTTON_LEFT
			input_event.pressed = true
			display_viewport.push_input(input_event)
		elif event is XRT2Pointer.ReleasedEvent:
			if _pointers.is_empty() or _pointers[0] != event.pointer:
				return

			var input_event := InputEventMouseButton.new()
			input_event.button_mask = 0
			input_event.position = _point_to_coords(event.pointing_at)
			input_event.global_position = input_event.position
			input_event.button_index = MOUSE_BUTTON_LEFT
			input_event.pressed = false
			display_viewport.push_input(input_event)
#endregion
