extends XRT2Construct


func _on_main_showing_loading_screen():
	%DesktopSubViewport.disable_3d = true
	%LoadingImage.visible = true
	%Xrt2SpectatorCamera.show_camera_in_hmd = false


func _on_main_showing_loaded_scene():
	%DesktopSubViewport.disable_3d = false
	%LoadingImage.visible = false
	%Xrt2SpectatorCamera.show_camera_in_hmd = true
