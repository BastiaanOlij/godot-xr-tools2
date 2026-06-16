#-------------------------------------------------------------------------------
# xrt2_frame_limited_sub_viewport.gd
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
class_name XRT2FrameLimitedSubViewport
extends SubViewport

#region Export variables
## Target FPS:[br]
## Set to 0 to disable updates[br]
## Set to -1 to always update[br]
## This does not guarantee FPS
@export_range(-1, 240, 1) var target_fps: int = 30:
	set(value):
		target_fps = value
		if is_inside_tree():
			render_target_update_mode = SubViewport.UPDATE_ONCE if target_fps >= 0 else SubViewport.UPDATE_ALWAYS
#endregion

#region Private variables
var _time_passed: float = 0.0
#endregion

#region Private functions
# Update our properties
func _validate_property(property) -> void:
	if property.name == "render_target_update_mode":
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _ready() -> void:
	render_target_update_mode = SubViewport.UPDATE_ONCE if target_fps >= 0 else SubViewport.UPDATE_ALWAYS


func _process(delta: float) -> void:
	if target_fps == 0:
		return

	_time_passed += delta
	var target_time = (1.0 / float(target_fps))
	if _time_passed >= target_time:
		render_target_update_mode = SubViewport.UPDATE_ONCE
		_time_passed = fmod(0.0, target_time)


# Pass through input events
func _input(event):
	if Engine.is_editor_hint():
		return

	# For now we only forward key events.
	if event is InputEventKey:
		push_input(event)


# Pass through input events
func _unhandled_input(event):
	if Engine.is_editor_hint():
		return

	# For now we only forward key events.
	if event is InputEventKey:
		push_input(event)
#endregion
