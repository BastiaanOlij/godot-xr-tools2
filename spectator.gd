extends Node2D

func _ready() -> void:
	_on_camera_selection_dropdown_item_selected($CameraSelectionDropdown.selected)
	_on_main_showing_loading_screen()

	# Get a signal when our window size changes
	get_tree().get_root().size_changed.connect(_on_size_changed)

	# Call atleast once to initialise
	_on_size_changed()


# Resize our viewport container to match our window size
func _on_size_changed() -> void:
	# Get the new size of our window
	var window_size  = get_tree().get_root().size

	$LoadingImage.size = window_size


func _on_main_showing_loading_screen() -> void:
	var vp = get_viewport()
	if vp:
		vp.disable_3d = true
		$LoadingImage.visible = true
		$CameraSelectionDropdown.visible = false
		$Xrt2SpectatorCamera.show_camera_in_hmd = false


func _on_main_showing_loaded_scene() -> void:
	var vp = get_viewport()
	if vp:
		if OS.has_feature("minimum_spectator"):
			# In minimum view, we want a simple UI,
			# for now we just show the loading image.
			# We may add some simple UI here some day.

			vp.disable_3d = true
			$LoadingImage.visible = true
			$CameraSelectionDropdown.visible = false
			$Xrt2SpectatorCamera.show_camera_in_hmd = false
		else:
			vp.disable_3d = false
			$LoadingImage.visible = false
			$CameraSelectionDropdown.visible = true
			$Xrt2SpectatorCamera.show_camera_in_hmd = true


func _on_camera_selection_dropdown_item_selected(index):
	match index:
		0:
			$Xrt2SpectatorCamera.make_current()
		1:
			$Xrt2StabilizedCamera.make_current()
