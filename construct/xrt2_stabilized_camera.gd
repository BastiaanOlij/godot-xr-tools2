#-------------------------------------------------------------------------------
# xrt2_stabilized_camera.gd
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

class_name XRT2StabilizedCamera
extends Node3D

@export_range(0.01, 1.0, 0.01) var weight = 0.08

var previous_transform : Transform3D

## Make this camera current
func make_current():
	$StabilizedCamera3D.current = true

# Position for our player
func _process(delta):
	var camera_tracker : XRPositionalTracker = XRServer.get_tracker("head")
	if camera_tracker:
		var pose : XRPose = camera_tracker.get_pose("default")
		if pose and pose.has_tracking_data:
			var camera_transform = pose.get_adjusted_transform()
			camera_transform = camera_transform.looking_at(camera_transform.origin - camera_transform.basis.z)
			camera_transform.origin += camera_transform.basis.z * 0.01

			if (camera_transform.origin - previous_transform.origin).length() < 0.5:
				# Stabilize logic
				camera_transform = previous_transform.interpolate_with(camera_transform, weight)


			$StabilizedCamera3D.global_transform = XRServer.world_origin * camera_transform
			previous_transform = camera_transform
