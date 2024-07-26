@tool
class_name XRT2LoadingScreen
extends Node3D

## User pressed the continue
signal continue_pressed


## Enabled the follow camera
@export var follow_camera_enabled : bool = false:
	set(value):
		follow_camera_enabled = value
		if is_inside_tree():
			_update_follow_camera()

## The camera the screen will follow
@export var follow_camera : XRCamera3D:
	set(value):
		follow_camera = value
		if is_inside_tree():
			_update_follow_camera()

## Curve for following the camera
@export var follow_speed : Curve

## Splash screen texture
@export var splash_screen : Texture2D:
	set(value):
		splash_screen = value
		if is_inside_tree():
			_update_splash_screen()

## Progress bar
@export_range(0.0, 1.0, 0.01) var progress : float = 0.5:
	set(value):
		progress = value
		if is_inside_tree():
			_update_progress_bar()

## If true, the contine message is shown, if false the progress bar is visible.
@export var enable_press_to_continue : bool = false:
	set(value):
		enable_press_to_continue = value
		if is_inside_tree():
			_update_press_to_continue()

# Splash screen material
var _splash_screen_material : ShaderMaterial


func _update_follow_camera() -> void:
	if follow_camera and follow_camera_enabled and !Engine.is_editor_hint():
		set_process(true)
	else:
		set_process(false)


func _update_splash_screen() -> void:
	if _splash_screen_material:
		_splash_screen_material.set_shader_parameter("texture_albedo", splash_screen)


func _update_progress_bar() -> void:
	# TODO IMPLEMENT!
	pass


func _update_press_to_continue() -> void:
	if is_inside_tree():
		# $ProgressBar.visible = !enable_press_to_continue
		$PressToContinue.visible = enable_press_to_continue
		$PressToContinue/HoldButton.enabled = enable_press_to_continue


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get materials
	_splash_screen_material = $SplashScreen.material_override

	_update_follow_camera()
	_update_splash_screen()
	_update_progress_bar()
	_update_press_to_continue()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Disable if in editor
	if Engine.is_editor_hint():
		set_process(false)
		return

	# Disable if follow camera is disabled
	if !follow_camera_enabled:
		set_process(false)
		return

	# Disable if no camera to track
	if !follow_camera:
		set_process(false)
		return

	# Get the camera direction (horizontal only)
	var camera_dir := follow_camera.global_transform.basis.z
	camera_dir.y = 0.0
	camera_dir = camera_dir.normalized()

	# Get the loading screen direction
	var loading_screen_dir := global_transform.basis.z

	# Get the angle
	var angle := loading_screen_dir.signed_angle_to(camera_dir, Vector3.UP)
	if angle == 0:
		return

	# Do rotation based on the curve
	global_transform.basis = global_transform.basis.rotated(
			Vector3.UP * sign(angle),
			follow_speed.sample_baked(abs(angle) / PI) * delta
	).orthonormalized()


func _on_hold_button_pressed() -> void:
	continue_pressed.emit()
