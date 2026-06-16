#-------------------------------------------------------------------------------
# xrt2_ui_2d_in_3d.gd
#-------------------------------------------------------------------------------
# MIT License
#
# Copyright (c) 2024-present Bastiaan Olij, Malcolm A Nixon and contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#-------------------------------------------------------------------------------


@tool
class_name XRT2UI2Din3D
extends Node3D

#region Export variables
## Size of our display
@export var display_size: Vector2 = Vector2(2.0, 1.0):
	set(value):
		display_size = value
		if is_inside_tree():
			_update_display_size()

## Viewports whose content we display
@export var display_viewport: Viewport:
	set(value):
		display_viewport = value
		if _area:
			_area.display_viewport = display_viewport
		if is_inside_tree():
			if display_viewport and display_viewport.transparent_bg != _transparent_bg:
				_update_material()
			else:
				_set_shader_parameters()

## Set a rectangle within our viewport that we show.
## If not set, we show the entire viewport. 
@export var display_subrect: Rect2i = Rect2i():
	set(value):
		display_subrect = value
		if is_inside_tree():
			_update_area()
			_set_shader_parameters()

## Do not apply lighting to our display
@export var unshaded: bool = true:
	set(value):
		unshaded = value
		if is_inside_tree():
			_update_material()

## Do we use linear filtering displaying the viewport?
@export var linear_filtering: bool = true:
	set(value):
		linear_filtering = value
		if is_inside_tree():
			_update_material()

## Custom material to use
@export var custom_material: Material:
	set(value):
		custom_material = value

		if is_inside_tree():
			_update_area()
			_update_material()
#endregion


#region Private variables
var _area: Area3D
var _collision: CollisionShape3D
var _collision_box: BoxShape3D
var _material: ShaderMaterial
var _display: MeshInstance3D
var _transparent_bg: bool = false
var _viewport_size: Vector2i = Vector2i(0, 0)
#endregion


#region Private functions
func _update_area():
	if _area:
		if not custom_material:
			_area.display_subrect = display_subrect
		else:
			_area.display_subrect = Rect2i()


func _update_display_size():
	if _area:
		_area.display_size = display_size
	if _collision_box:
		# Non-uniform scales don't work here however there is no problem in modifying the shape
		_collision_box.size = Vector3(display_size.x, display_size.y, 0.01)
	if _display:
		# But for our mesh we do scale to prevent having to sent a new mesh to the GPU
		_display.scale = Vector3(display_size.x, display_size.y, 1.0)


func _update_material():
	if custom_material:
		_display.material_override = custom_material
	else:
		if not _material:
			_material = ShaderMaterial.new()
			_material.shader = Shader.new()

		# TODO: Generating shader code like this risks compilation during runtime,
		# and prevents the shader baker being usable.
		# We'll come up with something better, likely precompiling some variants,
		# but for now this will suffice for a v1 release.
		# Use a custom material is this does become a problem for now.

		var render_modes = ""
		if unshaded:
			render_modes = "unshaded"

		var new_code = "shader_type spatial;\n"
		if not render_modes.is_empty():
			new_code += "render_mode " + render_modes + ";\n"
		new_code += "\n"
		new_code += "uniform sampler2D albedo_texture: source_color" + (", filter_linear" if linear_filtering else ", filter_nearest") + ";\n"
		new_code += "uniform vec2 uv_offset = vec2(0.0);\n"
		new_code += "uniform vec2 uv_scale = vec2(1.0);\n"
		new_code += "\n"
		new_code += "void vertex() {\n"
		new_code += "	UV = UV * uv_scale + uv_offset;\n"
		new_code += "}\n"
		new_code += "\n"
		new_code += "void fragment() {\n"
		new_code += "	vec4 color = texture(albedo_texture, UV);\n"
		new_code += "	ALBEDO = color.rgb;\n"
		if display_viewport and display_viewport.transparent_bg:
			_transparent_bg = true
			new_code += "	ALPHA = color.a;\n"
		else:
			_transparent_bg = false
		new_code += "}\n"

		if _material.shader.code != new_code:
			_material.shader.code = new_code

		_set_shader_parameters()

		_display.material_override = _material


func _set_shader_parameters():
	if display_viewport:
		_material.set_shader_parameter("albedo_texture", display_viewport.get_texture())

		_viewport_size = display_viewport.size
		if display_subrect == Rect2i(0, 0, 0, 0):
			_material.set_shader_parameter("uv_offset", Vector2(0.0, 0.0))
			_material.set_shader_parameter("uv_scale", Vector2(1.0, 1.0))
		else:
			_material.set_shader_parameter("uv_offset", Vector2(display_subrect.position) / Vector2(_viewport_size))
			_material.set_shader_parameter("uv_scale", Vector2(display_subrect.size) / Vector2(_viewport_size))
	else:
		_material.set_shader_parameter("albedo_texture", null)


# Update our properties
func _validate_property(property) -> void:
	# If we have a custom material, we don't set a number of properties.
	if custom_material and property.name in [ "display_viewport", "unshaded", "linear_filtering" ]:
		property.usage = PROPERTY_USAGE_NO_EDITOR


# Called when the node enters the scene tree for the first time.
func _ready():
	_area = Area3D.new()
	_area.set_script(load("res://addons/godot-xr-tools2/components/ui/xrt2_ui_2d_in_3d_area.gd"))
	add_child(_area, false, Node.INTERNAL_MODE_BACK)
	_area.display_viewport = display_viewport

	_collision_box = BoxShape3D.new()
	_collision = CollisionShape3D.new()
	_collision.shape = _collision_box
	_area.add_child(_collision, false, Node.INTERNAL_MODE_BACK)

	_display = MeshInstance3D.new()
	_display.mesh = QuadMesh.new() # default quadmesh is perfect, 1x1 panel size!
	add_child(_display, false, Node.INTERNAL_MODE_BACK)

	_update_area()
	_update_display_size()
	_update_material()


func _process(delta):
	if display_viewport:
		if display_viewport.transparent_bg != _transparent_bg:
			_update_material()
		elif display_viewport.size != _viewport_size:
			_set_shader_parameters()
#endregion
