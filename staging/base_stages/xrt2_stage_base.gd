@tool
class_name XRT2StageBase
extends Node3D

## This signal is used to request the staging transition to the main-menu
## scene. Developers should use [method exit_to_main_menu] rather than
## emitting this signal directly.
signal request_exit_to_main_menu

## This signal is used to request the staging transition to the specified
## scene. Developers should use [method load_scene] rather than emitting
## this signal directly.
##
## The [param user_data] parameter is passed through staging to the new scenes.
signal request_load_scene(p_scene_path, user_data)

## This signal is used to request the staging reload this scene. Developers
## should use [method reset_scene] rather than emitting this signal directly.
##
## The [param user_data] parameter is passed through staging to the new scenes.
signal request_reset_scene(user_data)

# TODO update documentation for entry points, there are differences with how 
# this worked in XR Tools 2 around centering the player

## This is called after the scene is loaded and added to our scene tree
func scene_loaded(user_data = null) -> void:
	pass


## This is called once our scene has become fully visible
func scene_visible(user_data = null) -> void:
	pass


## This is called prior to our scene becoming unloaded
func scene_pre_exiting(user_data = null) -> void:
	pass


## This is called just before our scene is removed from the scene tree
func scene_exiting(user_data = null) -> void:
	pass


## This is called when the user has requested to recenter the player
func pose_recenter() -> void:
	pass


## Call this to exit back to main menu
func exit_to_main_menu() -> void:
	request_exit_to_main_menu.emit()


## Call this to queue loading a new scene
func load_scene(p_scene_path : String, user_data = null) -> void:
	request_load_scene.emit(p_scene_path, user_data)


## Call this to reset the current scene
func reset_scene(user_data = null) -> void:
	request_reset_scene.emit(user_data)


func _ready() -> void:
	pass
