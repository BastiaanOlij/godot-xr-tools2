extends CharacterBody3D

@export var action_name = "trigger_click"

func _on_left_hand_button_pressed(p_action_name):
	var picked_up = %LeftPickup.get_picked_up()
	if picked_up and p_action_name == action_name and picked_up.has_method("do_action"):
		picked_up.do_action()


func _on_right_hand_button_pressed(p_action_name):
	var picked_up = %RightPickup.get_picked_up()
	if picked_up and p_action_name == action_name and picked_up.has_method("do_action"):
		picked_up.do_action()
