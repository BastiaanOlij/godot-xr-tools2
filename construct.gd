extends XRT2Construct

func _ready() -> void:
	super()
	_on_camera_selection_dropdown_item_selected(%CameraSelectionDropdown.selected)


func _on_main_showing_loading_screen() -> void:
	%DesktopSubViewport.disable_3d = true
	%LoadingImage.visible = true
	%CameraSelectionDropdown.visible = false
	%Xrt2SpectatorCamera.show_camera_in_hmd = false


func _on_main_showing_loaded_scene() -> void:
	%DesktopSubViewport.disable_3d = false
	%LoadingImage.visible = false
	%CameraSelectionDropdown.visible = true
	%Xrt2SpectatorCamera.show_camera_in_hmd = true


func _on_camera_selection_dropdown_item_selected(index):
	match index:
		0:
			%Xrt2SpectatorCamera.make_current()
		1:
			%Xrt2StabilizedCamera.make_current()
