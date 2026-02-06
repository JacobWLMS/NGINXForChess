extends Node2D

## The main game board - handles dropping balls, merging, and game over detection

signal merge_happened(tier: int, pos: Vector2)
signal ball_dropped

const BOARD_LEFT := 60.0
const BOARD_RIGHT := 660.0
const BOARD_TOP := 200.0
const BOARD_BOTTOM := 1220.0
const DANGER_Y := 260.0
const DROP_Y := 180.0

const BallScript = preload("res://scripts/ball.gd")

var current_ball = null
var next_tier: int = 1
var can_drop: bool = true
var drop_cooldown: float = 0.0
var drop_x: float = 360.0
var danger_timer: float = 0.0
var is_frozen: bool = false
var freeze_timer: float = 0.0

var ball_scene: PackedScene

@onready var balls_container := $BallsContainer
@onready var walls := $Walls

func _ready() -> void:
	_create_ball_scene()
	_setup_walls()
	next_tier = GameManager.get_random_drop_tier()
	_spawn_preview_ball()

func _create_ball_scene() -> void:
	ball_scene = PackedScene.new()
	var ball = RigidBody2D.new()
	ball.set_script(BallScript)

	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = CircleShape2D.new()
	ball.add_child(collision)
	collision.owner = ball

	ball_scene.pack(ball)

func _setup_walls() -> void:
	var wall_body = StaticBody2D.new()
	wall_body.collision_layer = 2
	wall_body.collision_mask = 1
	walls.add_child(wall_body)

	_add_wall_segment(wall_body, Vector2(BOARD_LEFT, (BOARD_TOP + BOARD_BOTTOM) / 2),
		Vector2(10, BOARD_BOTTOM - BOARD_TOP))
	_add_wall_segment(wall_body, Vector2(BOARD_RIGHT, (BOARD_TOP + BOARD_BOTTOM) / 2),
		Vector2(10, BOARD_BOTTOM - BOARD_TOP))
	_add_wall_segment(wall_body, Vector2((BOARD_LEFT + BOARD_RIGHT) / 2, BOARD_BOTTOM),
		Vector2(BOARD_RIGHT - BOARD_LEFT + 20, 10))

func _add_wall_segment(body: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = pos
	body.add_child(shape)

func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return

	if not can_drop:
		drop_cooldown -= delta
		if drop_cooldown <= 0:
			can_drop = true
			_spawn_preview_ball()

	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0:
			is_frozen = false
			_unfreeze_balls()

	_check_danger_zone(delta)

	if current_ball and can_drop:
		current_ball.global_position.x = drop_x
		current_ball.global_position.y = DROP_Y

func _physics_process(_delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	_check_merges()

func handle_input(event: InputEvent) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return

	if event is InputEventMouseButton:
		if event.pressed and can_drop and current_ball:
			_drop_current_ball()
	elif event is InputEventMouseMotion:
		if can_drop:
			drop_x = clampf(event.position.x, BOARD_LEFT + 30, BOARD_RIGHT - 30)

	if event is InputEventScreenTouch:
		if event.pressed and can_drop and current_ball:
			drop_x = clampf(event.position.x, BOARD_LEFT + 30, BOARD_RIGHT - 30)
			if current_ball:
				current_ball.global_position.x = drop_x
			_drop_current_ball()
	elif event is InputEventScreenDrag:
		if can_drop:
			drop_x = clampf(event.position.x, BOARD_LEFT + 30, BOARD_RIGHT - 30)

func _spawn_preview_ball() -> void:
	current_ball = ball_scene.instantiate()
	current_ball.setup(next_tier)
	current_ball.global_position = Vector2(drop_x, DROP_Y)
	current_ball.freeze = true
	current_ball.gravity_scale = 0
	balls_container.add_child(current_ball)
	next_tier = GameManager.get_random_drop_tier()

func _drop_current_ball() -> void:
	if not current_ball:
		return

	current_ball.freeze = false
	current_ball.gravity_scale = 1.0
	current_ball.linear_velocity = Vector2(0, 50)

	AudioManager.play_drop()
	ball_dropped.emit()

	current_ball = null
	can_drop = false
	drop_cooldown = 0.5

func _is_ball(node) -> bool:
	return is_instance_valid(node) and node is RigidBody2D and node.has_method("setup")

func _check_merges() -> void:
	var balls = balls_container.get_children()
	var merge_pairs: Array = []

	for i in range(balls.size()):
		if not _is_ball(balls[i]):
			continue
		var a = balls[i]
		if a.is_merging:
			continue

		for j in range(i + 1, balls.size()):
			if not _is_ball(balls[j]):
				continue
			var b = balls[j]
			if b.is_merging:
				continue

			if a.can_merge_with(b):
				var dist = a.global_position.distance_to(b.global_position)
				var touch_dist = a.ball_radius + b.ball_radius + 4
				if dist < touch_dist:
					merge_pairs.append([a, b])

	for pair in merge_pairs:
		var a = pair[0]
		var b = pair[1]
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		if a.is_merging or b.is_merging:
			continue
		_merge_balls(a, b)

func _merge_balls(a, b) -> void:
	a.start_merge()
	b.start_merge()

	var new_tier = a.tier + 1
	var merge_pos = (a.global_position + b.global_position) / 2.0

	a.queue_free()
	b.queue_free()

	var new_ball = ball_scene.instantiate()
	new_ball.setup(new_tier)
	new_ball.global_position = merge_pos
	balls_container.add_child(new_ball)

	GameManager.add_score(new_tier, merge_pos)
	AudioManager.play_merge(new_tier)
	merge_happened.emit(new_tier, merge_pos)

func _check_danger_zone(delta: float) -> void:
	var any_above = false
	for ball in balls_container.get_children():
		if not _is_ball(ball):
			continue
		if ball == current_ball:
			continue
		if not ball.has_settled:
			continue
		if ball.global_position.y < DANGER_Y and ball.time_alive > 2.0:
			any_above = true
			break

	if any_above:
		danger_timer += delta
		if danger_timer > 3.0:
			GameManager.trigger_game_over()
	else:
		danger_timer = maxf(danger_timer - delta * 2, 0)

func clear_all_balls() -> void:
	for ball in balls_container.get_children():
		if is_instance_valid(ball):
			ball.queue_free()
	current_ball = null

func get_ball_count() -> int:
	return balls_container.get_child_count()

func use_bomb() -> void:
	if not GameManager.use_powerup("bomb"):
		return
	AudioManager.play_powerup()
	var lowest_tier = 99
	for ball in balls_container.get_children():
		if _is_ball(ball) and ball != current_ball:
			if ball.tier < lowest_tier:
				lowest_tier = ball.tier
	for ball in balls_container.get_children():
		if _is_ball(ball) and ball != current_ball:
			if ball.tier == lowest_tier:
				merge_happened.emit(ball.tier, ball.global_position)
				ball.queue_free()

func use_shake() -> void:
	if not GameManager.use_powerup("shake"):
		return
	AudioManager.play_powerup()
	for ball in balls_container.get_children():
		if _is_ball(ball) and ball != current_ball:
			ball.apply_central_impulse(Vector2(randf_range(-300, 300), randf_range(-500, -100)))

func use_freeze() -> void:
	if not GameManager.use_powerup("freeze"):
		return
	AudioManager.play_powerup()
	is_frozen = true
	freeze_timer = 5.0
	for ball in balls_container.get_children():
		if _is_ball(ball) and ball != current_ball:
			ball.freeze = true

func _unfreeze_balls() -> void:
	for ball in balls_container.get_children():
		if _is_ball(ball) and ball != current_ball:
			ball.freeze = false

func revive_clear_top() -> void:
	for ball in balls_container.get_children():
		if _is_ball(ball):
			if ball.global_position.y < DANGER_Y + 100:
				ball.queue_free()
	danger_timer = 0.0
	can_drop = true
	_spawn_preview_ball()
