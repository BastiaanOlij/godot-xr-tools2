# xrt2_static_player_rig.gd
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

extends XROrigin3D
class_name XRT2StaticPlayerRig

## This player rig is meant for simulation games such as driving games
## or flight simulation.
## It is designed on the assumption this node is placed where the players
## head should be by default.


## Maximum distance the players head can be from the origin point before we fade to black.
@export var max_head_distance : float = 0.5

## Distance over which we fade
@export var fade_distance : float = 0.1

signal left_hand_tracking_changed(tracking : bool)
signal right_hand_tracking_changed(tracking : bool)

# Node helpers
@onready var _xr_camera : XRCamera3D = $XRCamera3D
@onready var _fade : XRT2EffectFade = $XRCamera3D/Fade
@onready var _left_hand : XRController3D = $LeftHand
@onready var _right_hand : XRController3D = $RightHand

var _start_xr : XRT2StartXR


## Returns true left left hand has tracking data
func left_hand_has_tracking() -> bool:
	return _left_hand.get_has_tracking_data()


## Returns true if right hand has tracking data
func right_hand_has_tracking() -> bool:
	return _right_hand.get_has_tracking_data()


# User triggered pose recenter.
func _on_xr_pose_recenter() -> void:
	if not _start_xr:
		# Huh? how did we even get the signal?
		return

	var play_area_mode : XRInterface.PlayAreaMode = _start_xr.get_play_area_mode()
	if play_area_mode == XRInterface.XR_PLAY_AREA_SITTING:
		# This is already handled by the headset, no need to do more!
		pass
	elif play_area_mode == XRInterface.XR_PLAY_AREA_ROOMSCALE:
		# Using center on HMD could mess things up here
		push_warning("Static player rig does not work with roomscale setting")
	else:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, false)


# Called when the node enters the scene tree for the first time.
func _ready():
	_start_xr = XRT2StartXR.get_singleton()
	if _start_xr:
		_start_xr.xr_pose_recenter.connect(_on_xr_pose_recenter)


func _exit_tree():
	if _start_xr:
		_start_xr.xr_pose_recenter.disconnect(_on_xr_pose_recenter)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var distance = _xr_camera.position.length()
	if distance > max_head_distance:
		_fade.fade = clamp((distance - max_head_distance) / fade_distance, 0.0, 1.0)
	else:
		_fade.fade = 0


func _on_left_hand_tracking_changed(tracking):
	left_hand_tracking_changed.emit(tracking)


func _on_right_hand_tracking_changed(tracking):
	right_hand_tracking_changed.emit(tracking)
