@tool
class_name XRT2LoadingScreen
extends Node3D

## User pressed the continue
signal continue_pressed

# Node helpers
@onready var _splash_screen : MeshInstance3D = $SplashScreen
@onready var _spinning_logo : MeshInstance3D = $SpinningLogo
# @onready var _progress_bar : Node3D = $ProgressBar
@onready var _press_to_continue : Label3D = $PressToContinue
@onready var _hold_button : XRT2HoldButton = $PressToContinue/HoldButton

# Materials
var _splash_screen_material : ShaderMaterial
var _spinning_logo_material : ShaderMaterial

## Enabled the follow camera
@export var follow_camera_enabled : bool = false:
	set(value):
		follow_camera_enabled = value

## The camera the screen will follow
@export var follow_camera : XRCamera3D:
	set(value):
		follow_camera = value

## Curve for following the camera
@export var follow_speed : Curve

## Splash screen texture
@export var splash_screen : Texture2D:
	set(value):
		splash_screen = value
		if is_inside_tree():
			_update_splash_screen()

## Splash screen texture
@export var spinning_logo : Texture2D:
	set(value):
		spinning_logo = value
		if is_inside_tree():
			_update_spinning_logo()

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

const SPIN_SPEED = 2.0
var spinning_logo_angle = 0.0


func _update_splash_screen() -> void:
	if _splash_screen_material:
		_splash_screen_material.set_shader_parameter("texture_albedo", splash_screen)

func _update_spinning_logo() -> void:
	if _spinning_logo_material:
		_spinning_logo_material.set_shader_parameter("texture_albedo", spinning_logo)

func _update_progress_bar() -> void:
	# TODO IMPLEMENT!
	pass


func _update_press_to_continue() -> void:
	if is_inside_tree():
		# _progress_bar.visible = !enable_press_to_continue
		_spinning_logo.visible = !enable_press_to_continue
		_press_to_continue.visible = enable_press_to_continue
		_hold_button.enabled = enable_press_to_continue


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get materials
	_splash_screen_material = _splash_screen.material_override
	_spinning_logo_material = _spinning_logo.material_override

	_update_splash_screen()
	_update_spinning_logo()
	_update_progress_bar()
	_update_press_to_continue()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	spinning_logo_angle = spinning_logo_angle + delta * SPIN_SPEED
	if spinning_logo_angle > PI * 2.0:
		spinning_logo_angle -= PI * 2.0
	_spinning_logo.rotation.y = spinning_logo_angle

	# Skip the rest if in editor
	if Engine.is_editor_hint():
		return

	if follow_camera && follow_camera_enabled:
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
