extends Control

## This is just a little sample game to show how you can interact.
## You can test this by running this scene and just using your mouse.
## Be sure to run in regular mode!

# TODO: replace things with some nice graphics and actually turn this
# into something nice to play, not just a placeholder.

enum GameState {
	IN_MENU,
	GAME_RUNNING,
	GAME_ENDED
}

@export var default_max_speed: float = 150.0
@export var speed_increase: float = 10.0
@export var base_hit_score: int = 150
@export var score_increase: int = 10
@export var cooldown_time: float = 0.3

#region Private variables
@onready var _main_menu: Node2D = $MainMenu
@onready var _game: Node2D = $Game
@onready var _target: Button = $Game/Target
@onready var _score_label: Label = $Game/Score
@onready var _end_screen: Node2D = $EndScreen

var _game_state: GameState = GameState.IN_MENU
var _score: int = 0
var _time_since_last_spawn: float = 0.0
var _min_spawn_duration: float = 1.0
var _spawn_chance: float = 0.1
var _target_direction: Vector2
var _target_max_speed: float
var _hit_score: int
var _miss_count: int
var _cooldown: float
#endregion


#region Private functions
func _change_game_state(new_state: GameState) -> void:
	_game_state = new_state
	_main_menu.visible = (_game_state == GameState.IN_MENU)
	_game.visible = (_game_state == GameState.GAME_RUNNING)
	_end_screen.visible = (_game_state == GameState.GAME_ENDED)


func _set_score(new_score: int) -> void:
	_score = new_score
	_score_label.text = "Score: %09d" % [ _score ]


func _reset_miss_count() -> void:
	_miss_count = 0

	# TODO: Redraw bullets


func _increase_miss_count() -> void:
	_miss_count += 1

	# TODO: Redraw bullets

	if _miss_count == 3:
		_change_game_state(GameState.GAME_ENDED)


func _start_game() -> void:
	_set_score(0)
	_change_game_state(GameState.GAME_RUNNING)
	_target.visible = false
	_time_since_last_spawn = 0.0
	_target_max_speed = default_max_speed
	_hit_score = base_hit_score
	_reset_miss_count()


func _ready() -> void:
	_change_game_state(GameState.IN_MENU)


func _process(delta) -> void:
	if _game_state != GameState.GAME_RUNNING:
		return

	if _cooldown > 0.0:
		_cooldown = max(0.0, _cooldown - delta)

	if _target.visible:
		# TODO move target!
		_target.position += _target_direction * delta
		if _target.position.y < -50.0:
			_increase_miss_count()
			_target.visible = false
		elif _target.position.x < 0.0:
			_target.position.x *= -1.0
			_target_direction.x *= -1.0
		elif _target.position.x > (800.0 - 50.0):
			_target.position.x = (1600.0 - 100.0) - _target.position.x
			_target_direction.x *= -1.0
	else:
		_time_since_last_spawn += delta

		if _time_since_last_spawn > _min_spawn_duration and randf() < _spawn_chance:
			_target.position = Vector2(randf_range(0.0, 800.0 - 50.0), 500.0 - 50.0)
			_target.visible = true
			_target_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, -1.0)) * _target_max_speed

			_time_since_last_spawn = 0.0
#endregion


#region Signal functions
func _on_start_game_pressed() -> void:
	_start_game()


func _on_bg_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Cooldown on shot
		if _cooldown > 0.0:
			return
		_cooldown = cooldown_time

		# TODO: show missed effect

		_increase_miss_count()


func _on_target_pressed() -> void:
	# Cooldown on shot
	if _cooldown > 0.0:
		return
	_cooldown = cooldown_time

	# Increase score
	_set_score(_score + _hit_score)
	_hit_score += score_increase

	# Increase max speed
	_target_max_speed += speed_increase

	# Despawn
	_target.visible = false

	# Reset miss count
	_reset_miss_count()


func _on_record_pressed() -> void:
	# TODO: Record score

	_change_game_state(GameState.IN_MENU)
#endregion
