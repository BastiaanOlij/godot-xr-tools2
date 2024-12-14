extends XRT2Construct

# Called every frame
func _process(delta):
	super._process(delta)

	if %FollowPlayer.button_pressed:
		var vr_camera = %VRSubViewport.get_camera_3d()
		if vr_camera:
			%Xrt2SpectatorCamera.look_at(vr_camera.global_position)


func _on_main_showing_loaded_scene():
	%SplashImage.visible = false
	%DesktopSubViewport.disable_3d = false
	%UI.visible = true


func _on_main_showing_loading_screen():
	%SplashImage.visible = true
	%DesktopSubViewport.disable_3d = true
	%UI.visible = false
