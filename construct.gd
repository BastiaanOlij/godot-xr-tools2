extends XRT2Construct

enum PreviewMode {
	SPECTATOR_CAM,
	STABILIZED_CAM,
}

@export var preview_mode : PreviewMode = PreviewMode.SPECTATOR_CAM:
	set(value):
		preview_mode = value
		if is_inside_tree() and not on_loading_screen:
			_update_preview_mode()

var on_loading_screen : bool = true

func _ready():
	super._ready()

	%StabilizeWeight.value = %Xrt2StabilizedCamera.weight

	var window = get_window()
	window.position = Vector2(3440 - 1920, 32)


# Called every frame
func _process(delta):
	super._process(delta)

	if %Xrt2SpectatorCamera.visible and %FollowPlayer.button_pressed:
		var vr_camera = %VRSubViewport.get_camera_3d()
		if vr_camera:
			%Xrt2SpectatorCamera.look_at(vr_camera.global_position)


func _update_preview_mode():
	%Xrt2SpectatorCamera.visible = preview_mode == PreviewMode.SPECTATOR_CAM
	%FollowPlayer.visible = preview_mode == PreviewMode.SPECTATOR_CAM

	%Xrt2StabilizedCamera.visible = preview_mode == PreviewMode.STABILIZED_CAM
	%StabilizeWeight.visible = preview_mode == PreviewMode.STABILIZED_CAM
	
	if preview_mode == PreviewMode.SPECTATOR_CAM:
		%Xrt2SpectatorCamera.make_current()
	elif preview_mode == PreviewMode.STABILIZED_CAM:
		%Xrt2StabilizedCamera.make_current()


func _on_main_showing_loaded_scene():
	on_loading_screen = false
	%SplashImage.visible = false
	%DesktopSubViewport.disable_3d = false
	%UI.visible = true

	_update_preview_mode()


func _on_main_showing_loading_screen():
	on_loading_screen = true
	%SplashImage.visible = true
	%DesktopSubViewport.disable_3d = true
	%UI.visible = false

	%Xrt2SpectatorCamera.visible = false
	%Xrt2StabilizedCamera.visible = false


func _on_preview_mode_item_selected(index):
	preview_mode = index
	_update_preview_mode()


func _on_weight_value_changed(value):
	%Xrt2StabilizedCamera.weight = value
