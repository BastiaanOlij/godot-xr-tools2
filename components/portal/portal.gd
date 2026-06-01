@tool
extends Node3D

## If true, player can go through portal.
@export var enabled: bool = true

## Image to use for our portal effect.
@export var portal_image: Texture2D:
	set(value):
		portal_image = value
		if is_inside_tree():
			_update_image()

## Title to show at the top.
@export var title: String = "Testing":
	set(value):
		title = value
		if is_inside_tree():
			_update_title()

## If player gets closer than this, the doors open.
@export_range(0.5, 10.0, 0.5) var door_open_distance: float = 3.0

## If player gets closer than this, we teleport.
@export_range(0.5, 10.0, 0.5) var teleport_distance: float = 1.0

## Scene to portal to, if empty we return to our main scene.
@export_file("*.tscn") var portal_scene: String

@onready var _label: Label = $Title/SubViewport/Label
@onready var _vp: SubViewport = $Title/SubViewport

var _is_closed: bool = true
var _is_teleporting: bool = false
var _slide: float = 0.0

func _update_image():
	var material: ShaderMaterial = $PortalImage.material_override
	if material:
		material.set_shader_parameter("albedo_texture", portal_image)


func _update_title():
	_label.text = title
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _ready():
	_update_image()
	_update_title()


func _process(delta):
	if Engine.is_editor_hint():
		return

	var closed: bool = true
	var teleport: bool = false
	if enabled:
		var camera = get_viewport().get_camera_3d()
		if camera:
			var dist: float = (camera.global_position * Vector3(1.0, 0.0, 1.0) - global_position).length()
			closed = dist > door_open_distance
			teleport = dist < teleport_distance

	# Going from open to closed or vise versa?
	if _is_closed != closed:
		# Play sounds!
		$SlideSound.play()

		_is_closed = closed

	if closed:
		_slide = clamp(_slide - delta, 0.0, 1.0)
	else:
		_slide = clamp(_slide + delta, 0.0, 1.0)

	$PortalImage.visible = _slide > 0.0
	$LeftDoor.position.x = -0.5 - _slide
	$RightDoor.position.x = 0.5 + _slide

	if teleport and not _is_teleporting:
		_is_teleporting = true
		var stage = XRT2StageBase.get_stage(self)
		if stage:
			if portal_scene:
				stage.load_scene(portal_scene)
			else:
				stage.exit_to_main_menu()
