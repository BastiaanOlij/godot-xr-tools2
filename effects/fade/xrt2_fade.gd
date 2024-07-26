@tool
class_name XRT2EffectFade
extends Node3D

@export_range(0.0, 1.0, 0.05) var fade : float = 0.0:
	set(value):
		fade = value
		if is_inside_tree():
			_update_fade()

@export_multiline var message : String = "":
	set(value):
		message = value
		if is_inside_tree():
			_update_message()
			_update_fade()

@export_range(0.1, 10.0, 0.1) var message_distance = 1.0:
	set(value):
		message_distance = value
		if is_inside_tree():
			_update_message_distance()

func _update_fade():
	if fade == 0.0:
		$ScreenQuad.visible = false
		$Message.visible = false
	else:
		$ScreenQuad.visible = true
		$Message.visible = not message.is_empty()
		if $Message.visible:
			$Message.modulate = Color(1.0, 1.0, 1.0, fade)
			$Message.outline_modulate = Color(0.0, 0.0, 0.0, fade)
		var material : ShaderMaterial = $ScreenQuad.material_override
		if material:
			material.set_shader_parameter("alpha", fade)

func _update_message():
	$Message.text = message

func _update_message_distance():
	$Message.transform.origin.z = -message_distance

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_message()
	_update_message_distance()
	_update_fade()

	if not Engine.is_editor_hint():
		var t : Transform3D = $Message.global_transform
		$Message.top_level = true
		$Message.transform = t

func _process(delta):
	# Don't run this in the editor
	if Engine.is_editor_hint():
		set_process(false)
		return

	if $Message.visible:
		var t : Transform3D = global_transform
		var forward : Vector3 = -t.basis.z
		forward.y = 0.0
		forward = forward.normalized()

		t.origin += forward * message_distance
		t = t.looking_at(t.origin + forward)

		$Message.transform.basis = $Message.transform.basis.slerp(t.basis, delta)
		$Message.transform.origin = $Message.transform.origin.lerp(t.origin, delta)
