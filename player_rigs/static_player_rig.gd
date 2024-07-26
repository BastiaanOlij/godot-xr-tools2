extends XROrigin3D
class_name XRT2StaticPlayerRig

## This player rig is meant for simulation games such as driving games
## or flight simulation.
## It is designed on the assumption this node is placed where the players
## head should be by default.


## Maximum distance the players head can be from the origin point before we fade to black.
@onready var max_head_distance : float = 0.5
@onready var fade_distance : float = 0.1


var _start_xr : XRT2StartXR

# Node helpers
@onready var _xr_camera : XRCamera3D = $XRCamera3D
@onready var _fade : XRT2EffectFade = $XRCamera3D/Fade


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
