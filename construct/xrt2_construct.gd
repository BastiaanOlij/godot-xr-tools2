#-------------------------------------------------------------------------------
# xrt2_construct.gd
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

class_name XRT2Construct
extends Node2D


@export_range(20, 200, 1) var throttle_desktop_fps : int = 30

var _throttle : float = 0.0

# Resize our viewport container to match our window size
func _on_size_changed() -> void:
	# Get the new size of our window
	var window_size  = get_tree().get_root().size

	# Set our container to full screen, this should update our viewport
	$DesktopContainer.size = window_size


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Make sure our main viewport doesn't render 3D
	var vp = get_viewport()
	vp.disable_3d = true

	# Get a signal when our window size changes
	get_tree().get_root().size_changed.connect(_on_size_changed)

	# Call atleast once to initialise
	_on_size_changed()


# Called every frame
func _process(delta):
	_throttle -= delta
	if _throttle < 0.0:
		# Trigger redraw
		%DesktopSubViewport.render_target_update_mode = SubViewport.UPDATE_ONCE

		_throttle = max(0.0, _throttle + (1.0 / throttle_desktop_fps))
