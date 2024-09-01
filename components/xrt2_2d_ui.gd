@tool
extends Node3D

@export var screen_size : Vector2 = Vector2(1.0, 1.0):
	set(value):
		screen_size = value
		if is_inside_tree():
			_update_screen_size()

# Node helpers
@onready var _origin : Node3D = $FollowXROrigin3D
@onready var _composition_layer : OpenXRCompositionLayerQuad = $FollowXROrigin3D/OpenXRCompositionLayerQuad


# Called when our screen size was changed
func _update_screen_size() -> void:
	_composition_layer.quad_size = screen_size


# Called when the node enters the scene tree for the first time.
func _ready():
	_update_screen_size()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Don't run in editor
	if Engine.is_editor_hint():
		return

	# Need to reposition our quad so its local transform matches our world origin
	# as it is rendered on our compositor
	_origin.global_transform = XRServer.world_origin
	_composition_layer.global_transform = global_transform
