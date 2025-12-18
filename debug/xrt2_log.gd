#-------------------------------------------------------------------------------
# xrt2_log.gd
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
extends Node3D

## Size of our display.
@export var display_size: Vector2 = Vector2(1.0, 1.0):
	set(value):
		display_size = value
		if is_inside_tree():
			_update_display()
			_update_viewport()

## DPI for our screen resolution.
@export var dpi: float = 15.0:
	set(value):
		dpi = value
		if is_inside_tree():
			_update_viewport()

@export_flags_3d_render var layers = 1:
	set(value):
		layers = value
		if is_inside_tree():
			_layers_changed()


@onready var display: MeshInstance3D = $Display
@onready var viewport: SubViewport = $SubViewport
@onready var rtlabel: RichTextLabel = $SubViewport/RichTextLabel

var _logger: XRT2Logger
var _messages_dirty = false


func _update_display():
	display.scale = Vector3(display_size.x, display_size.y, 1.0)


func _update_viewport():
	var size_in_inches: Vector2 = display_size * 39.2701
	var viewport_size: Vector2i = Vector2i(size_in_inches * dpi)
	viewport.size = viewport_size
	rtlabel.size = viewport_size


func _layers_changed():
	$Display.layers = layers


# Called when the node enters the scene tree.
func _enter_tree():
	if Engine.is_editor_hint():
		return

	if not _logger:
		_logger = XRT2Logger.new()
		_logger.message_changed.connect(_on_message_changed)
		OS.add_logger(_logger)


# Called when the node exits the scene tree.
func _exit_tree():
	if Engine.is_editor_hint():
		return

	if _logger:
		OS.remove_logger(_logger)
		_logger = null


# Called when the node enters the scene tree for the first time.
func _ready():
	_update_display()
	_update_viewport()
	_layers_changed()

	if Engine.is_editor_hint():
		return

	rtlabel.text = ""
	_messages_dirty = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Engine.is_editor_hint():
		return

	if _messages_dirty and _logger:
		_messages_dirty = false

		var entries: PackedStringArray = _logger.get_entries()
		for entry in entries:
			rtlabel.append_text(entry)


func _on_message_changed():
	_messages_dirty = true
