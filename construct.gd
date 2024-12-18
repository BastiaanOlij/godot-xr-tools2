extends XRT2Construct

func _ready():
	super._ready()

	var window = get_window()
	window.position = Vector2(3440 - 1920, 32)


# Called every frame
func _process(delta):
	super._process(delta)

	if %FollowPlayer.button_pressed:
		var vr_camera = %VRSubViewport.get_camera_3d()
		if vr_camera:
			%Xrt2SpectatorCamera.look_at(vr_camera.global_position)


func _on_main_showing_loaded_scene():
	%SplashImage.visible = false
	%Xrt2SpectatorCamera.visible = true
	%DesktopSubViewport.disable_3d = false
	%UI.visible = true


func _on_main_showing_loading_screen():
	%SplashImage.visible = true
	%Xrt2SpectatorCamera.visible = false
	%DesktopSubViewport.disable_3d = true
	%UI.visible = false
