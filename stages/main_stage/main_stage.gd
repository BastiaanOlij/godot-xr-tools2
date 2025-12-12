@tool
extends XRT2StageBase

@onready var left_hand : XRT2CollisionHand = $XRT2CharacterBody3D/XROrigin3D/XRT2LeftCollisionHand
@onready var right_hand : XRT2CollisionHand = $XRT2CharacterBody3D/XROrigin3D/XRT2RightCollisionHand

# Called when the node enters the scene tree for the first time.
func _ready():
	super()

	# We assume left and right hands are setup the same...
	$PosProportionalGainSlider.value = left_hand.linear_proportional_gain
	$PosDerivativeGainSlider.value = left_hand.linear_derivative_gain
	$RotProportionalGainSlider.value = left_hand.rotational_proportional_gain
	$RotDerivativeGainSlider.value = left_hand.rotational_derivative_gain


func _on_positional_proportional_gain_slider_value_changed(new_value):
	left_hand.linear_proportional_gain = new_value
	right_hand.linear_proportional_gain = new_value


func _on_positional_derivative_gain_slider_value_changed(new_value):
	left_hand.linear_derivative_gain = new_value
	right_hand.linear_derivative_gain = new_value

func _on_rotational_proportional_gain_slider_value_changed(new_value):
	left_hand.rotational_proportional_gain = new_value
	right_hand.rotational_proportional_gain = new_value


func _on_rotational_derivative_gain_slider_value_changed(new_value):
	left_hand.rotational_derivative_gain = new_value
	right_hand.rotational_derivative_gain = new_value
