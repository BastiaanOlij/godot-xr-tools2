@tool
extends StaticBody3D

signal value_changed(new_value : float)

## Lower limit
@export var lower_value : float = 0.0:
	set(new_value):
		lower_value = new_value
		if is_inside_tree():
			_update_value()

## Upper limit
@export var upper_value : float = 100.0:
	set(new_value):
		upper_value = new_value
		if is_inside_tree():
			_update_value()

## Current value
@export var value : float = 50.0:
	set(new_value):
		value = new_value
		if is_inside_tree():
			_update_label()
			if not _is_in_process:
				_update_value()

@export var prefix : String = "":
	set(new_value):
		prefix = new_value
		if is_inside_tree():
			_update_label()

@onready var _handle : RigidBody3D = $Handle
@onready var _value : Label3D = $Value

var _was_position : float
var _is_in_process : bool = false

func _update_label():
	var text : String = "%0.2f" % [ value ]
	if prefix != "":
		text = prefix + " " + text
	_value.text = text

func _update_value():
	if upper_value == lower_value:
		return

	var pos : float = clamp((value - lower_value) / (upper_value - lower_value), 0.0, 1.0)
	_handle.position.x = pos * 0.5 - 0.25
	_was_position = _handle.position.x 


# Called when the node enters the scene tree for the first time.
func _ready():
	_update_label()
	_update_value()

func _process(_delta):
	if Engine.is_editor_hint():
		return

	if upper_value == lower_value:
		return

	_is_in_process = true

	if _was_position != position.x:
		var pos : float = (_handle.position.x + 0.25) * 2.0

		# (value - lower_value) / (upper_value - lower_value)
		value = (pos * (upper_value - lower_value)) + lower_value

		value_changed.emit(value)

	_is_in_process = false

func _physics_process(delta):
	if Engine.is_editor_hint():
		return

	# make sure our slider can't be pulled up
	if position.y > 0.05:
		_handle.apply_central_force(global_basis.y * -50.0 * delta)
