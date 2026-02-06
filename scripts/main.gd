extends Node2D

## Main scene controller - ties everything together

@onready var game_board = $GameBoard
@onready var effects = $EffectsManager
@onready var ui: CanvasLayer = $UIManager
@onready var camera: Camera2D = $Camera2D
@onready var board_renderer: Node2D = $BoardRenderer

func _ready() -> void:
	effects.set_camera(camera)
	_connect_signals()
	# Start at menu
	game_board.visible = false
	board_renderer.visible = false

func _connect_signals() -> void:
	# UI signals
	ui.play_pressed.connect(_on_play)
	ui.retry_pressed.connect(_on_play)
	ui.home_pressed.connect(_on_home)
	ui.revive_pressed.connect(_on_revive)
	ui.pause_pressed.connect(func(): GameManager.pause_game())
	ui.resume_pressed.connect(func(): GameManager.resume_game())
	ui.quit_pressed.connect(_on_home)
	ui.daily_claimed.connect(_on_daily_claimed)
	ui.shop_purchase.connect(_on_shop_purchase)
	ui.powerup_used.connect(_on_powerup)

	# Game signals
	GameManager.score_changed.connect(func(s): ui.update_score(s))
	GameManager.coins_changed.connect(func(c): ui.update_coins(c))
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.ball_merged.connect(_on_ball_merged)

	# Board signals
	game_board.merge_happened.connect(_on_merge_visual)

func _input(event: InputEvent) -> void:
	if GameManager.state == GameManager.GameState.PLAYING:
		game_board.handle_input(event)

func _on_play() -> void:
	GameManager.start_game()
	game_board.visible = true
	board_renderer.visible = true
	game_board.clear_all_balls()
	game_board.can_drop = true
	game_board.drop_cooldown = 0
	game_board.danger_timer = 0
	game_board._spawn_preview_ball()
	ui.show_hud()
	ui.update_powerup_counts()

func _on_home() -> void:
	GameManager.state = GameManager.GameState.MENU
	get_tree().paused = false
	game_board.clear_all_balls()
	game_board.visible = false
	board_renderer.visible = false
	ui.show_menu()

func _on_game_over() -> void:
	AudioManager.play_gameover()
	var is_new_best = SaveManager.check_and_save_highscore(GameManager.score)
	SaveManager.save_coins(GameManager.coins)

	# Big screen shake on game over
	effects.shake(15.0)

	# Show game over with delay for dramatic effect
	await get_tree().create_timer(1.0).timeout

	ui.show_gameover(is_new_best)

	# Check if we should show a fake ad
	if SaveManager.increment_ad_counter():
		await get_tree().create_timer(0.5).timeout
		ui.show_fake_ad()

func _on_revive() -> void:
	GameManager.revive_game()
	game_board.revive_clear_top()
	ui.show_hud()

func _on_combo_changed(combo: int) -> void:
	ui.update_combo(combo)
	if combo >= 2:
		AudioManager.play_combo(combo)

func _on_ball_merged(tier: int, pos: Vector2) -> void:
	var info = GameManager.BALL_TIERS[tier]
	var points = info["points"]

	# Float text showing points
	var multiplier = 1.0 + (GameManager.combo - 1) * 0.5
	var gained = int(points * multiplier)
	effects.spawn_float_text(pos + Vector2(0, -30), "+" + str(gained), info["color"], 24 + tier * 2)

	# Combo text
	if GameManager.combo >= 2:
		effects.spawn_combo_text(pos, GameManager.combo)

	# Coin particles
	effects.spawn_coin_particles(pos, 3)

func _on_merge_visual(tier: int, pos: Vector2) -> void:
	var info = GameManager.BALL_TIERS[tier]
	effects.spawn_merge_particles(pos, info["color"], tier)

func _on_daily_claimed(doubled: bool) -> void:
	var reward = SaveManager.claim_daily_reward()
	if doubled:
		SaveManager.data["coins"] += reward  # Double it
		GameManager.coins = SaveManager.data["coins"]
		SaveManager.save_data()
	AudioManager.play_coin()
	ui.show_menu()

func _on_shop_purchase(item_name: String) -> void:
	# Handle shop purchases
	var costs = {
		"bomb_pack": 100,
		"shake_pack": 200,
		"freeze_pack": 150,
		"combo_upgrade": 500,
		"coin_multiplier": 750,
	}
	var cost = costs.get(item_name, 999999)
	if SaveManager.buy_upgrade(item_name, cost):
		AudioManager.play_coin()
		if item_name == "bomb_pack":
			GameManager.powerups["bomb"] += 3
		elif item_name == "shake_pack":
			GameManager.powerups["shake"] += 2
		elif item_name == "freeze_pack":
			GameManager.powerups["freeze"] += 3
		ui.update_powerup_counts()

func _on_powerup(pu_name: String) -> void:
	match pu_name:
		"bomb":
			game_board.use_bomb()
		"shake":
			game_board.use_shake()
		"freeze":
			game_board.use_freeze()
	ui.update_powerup_counts()
