@tool
class_name PortalProbe3D
extends Node3D

@export var bake: bool = false

@export_file_path("*.png") var probe_image

@export var base_size: Vector2i = Vector2i(256, 256):
	set(value):
		base_size = value
		if is_inside_tree():
			_update_base_size()

@export_flags_3d_render var cull_mask = 1:
	set(value):
		cull_mask = value
		if is_inside_tree():
			_update_layers()


const _offsets: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(2, 1)
]

const _scales: Array[Vector2] = [
	Vector2(-1.0,  1.0),
	Vector2(-1.0,  1.0),
	Vector2(-1.0,  1.0),
	Vector2(-1.0,  1.0),
	Vector2(-1.0,  1.0),
	Vector2( 1.0, -1.0),
]

const _orientations: Array[Basis] = [
	Basis(Vector3.UP, deg_to_rad(180.0)),
	Basis(Vector3.UP, deg_to_rad(270.0)),
	Basis(Vector3.UP, deg_to_rad(0.0)),
	Basis(Vector3.UP, deg_to_rad(90.0)),
	Basis(Vector3.RIGHT, deg_to_rad(90.0)),
	Basis(Vector3.RIGHT, deg_to_rad(-90.0))
]

var _capture_viewport: SubViewport
var _sides: Array[SubViewportContainer]
var _viewports: Array[SubViewport]
var _cameras: Array[Camera3D]

func get_texture() -> Texture2D:
	if _capture_viewport:
		return _capture_viewport.get_texture()
	else:
		return null


func _update_base_size():
	# We only run this as an editor tool!
	if not Engine.is_editor_hint():
		return

	if _capture_viewport:
		_capture_viewport.size = Vector2(base_size.x * 3, base_size.y * 4)

	var i : int = 0
	for side in _sides:
		var o: Vector2i = _offsets[i % 6]
		var s: Vector2 = _scales[i % 6]
		if s.x < 0.0:
			o.x += 1
		if s.y < 0.0:
			o.y += 1
		if i >= 6:
			o.y += 2
		side.position = o * base_size
		side.scale = s

		var viewport: SubViewport = side.get_node("SubViewport")
		if viewport:
			viewport.size = base_size

		i += 1


func _update_layers():
	# We only run this as an editor tool!
	if not Engine.is_editor_hint():
		return

	for camera: Camera3D in _cameras:
		camera.cull_mask = cull_mask


func _enter_tree():
	# We only run this as an editor tool!
	if not Engine.is_editor_hint():
		return

	_capture_viewport = SubViewport.new()
	_capture_viewport.disable_3d = true
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_capture_viewport, false, Node.INTERNAL_MODE_BACK)

	for side in range(12):
		var container: SubViewportContainer = SubViewportContainer.new()
		_capture_viewport.add_child(container, false, Node.INTERNAL_MODE_BACK)

		var viewport: SubViewport = SubViewport.new()
		viewport.name = "SubViewport"
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		container.add_child(viewport, true, Node.INTERNAL_MODE_BACK)

		var camera: Camera3D = Camera3D.new()
		camera.name = "Camera3D"
		camera.fov = 90
		viewport.add_child(camera, true, Node.INTERNAL_MODE_BACK)

		_sides.push_back(container)
		_viewports.push_back(viewport)
		_cameras.push_back(camera)


func _ready():
	_update_base_size()
	_update_layers()


func _exit_tree():
	if _capture_viewport:
		# This will also free our views
		_capture_viewport.queue_free()
		remove_child(_capture_viewport)

	_sides.clear()
	_viewports.clear()
	_cameras.clear()


func _process(_delta):
	# We only run this as an editor tool!
	if not Engine.is_editor_hint():
		set_process(false)
		return

	var i: int = 0
	for camera in _cameras:
		camera.global_transform = global_transform * Transform3D(_orientations[i % 6], Vector3(-0.003 if i < 6 else 0.003, 0.0, 0.0))
		i += 1

	if bake:
		if _capture_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
			_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			for viewport in _viewports:
				viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			# Save
			if probe_image:
				var texture: ViewportTexture = _capture_viewport.get_texture()
				var image: Image = texture.get_image()
				image.save_png(probe_image)
				EditorInterface.get_resource_filesystem().reimport_files([ probe_image ])

			_capture_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			for viewport in _viewports:
				viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			bake = false
			notify_property_list_changed()
