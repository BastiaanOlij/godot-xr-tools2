@tool
extends XRT2StageBase

var _angular_pd_controller : XRT2AngularPDController 

# Called when the node enters the scene tree for the first time.
func _ready():
	super()
	_angular_pd_controller = $XRT2CharacterBody3D/XROrigin3D/XRT2LeftCollisionHand.angular_pd_controller


func _on_proportional_gain_slider_value_changed(new_value):
	_angular_pd_controller.proportional_gain = new_value


func _on_derivative_gain_slider_value_changed(new_value):
	_angular_pd_controller.derivative_gain = new_value
