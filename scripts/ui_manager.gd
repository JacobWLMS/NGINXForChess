extends CanvasLayer

## Manages all UI screens - menu, HUD, game over, shop, daily rewards

signal play_pressed
signal retry_pressed
signal home_pressed
signal revive_pressed
signal pause_pressed
signal resume_pressed
signal quit_pressed
signal daily_claimed(doubled: bool)
signal shop_purchase(item_name: String)
signal powerup_used(pu_name: String)

@onready var menu_screen := $MenuScreen
@onready var hud := $HUD
@onready var gameover_screen := $GameOverScreen
@onready var pause_modal := $PauseModal
@onready var daily_modal := $DailyModal
@onready var shop_modal := $ShopModal
@onready var fake_ad_modal := $FakeAdModal

# HUD elements
@onready var score_label := $HUD/ScoreBar/ScoreLabel
@onready var coin_label := $HUD/CoinBar/CoinLabel
@onready var combo_container := $HUD/ComboContainer
@onready var combo_label := $HUD/ComboContainer/ComboLabel
@onready var combo_bar := $HUD/ComboContainer/ComboBar

# Menu elements
@onready var menu_highscore := $MenuScreen/VBox/Stats/HighscoreVal
@onready var menu_coins := $MenuScreen/VBox/Stats/CoinsVal
@onready var menu_streak := $MenuScreen/VBox/Stats/StreakVal
@onready var daily_dot := $MenuScreen/VBox/Buttons/DailyBtn/NotifDot

# Game Over elements
@onready var final_score_label := $GameOverScreen/VBox/ScoreVal
@onready var new_best_label := $GameOverScreen/VBox/NewBest
@onready var earned_coins_label := $GameOverScreen/VBox/Stats/EarnedCoins
@onready var highest_merge_label := $GameOverScreen/VBox/Stats/HighMerge
@onready var best_combo_label := $GameOverScreen/VBox/Stats/BestCombo
@onready var revive_btn := $GameOverScreen/VBox/Buttons/ReviveBtn

var combo_tween: Tween

func _ready() -> void:
	_connect_buttons()
	show_menu()

func _connect_buttons() -> void:
	$MenuScreen/VBox/Buttons/PlayBtn.pressed.connect(_on_play)
	$MenuScreen/VBox/Buttons/ShopBtn.pressed.connect(_on_shop_open)
	$MenuScreen/VBox/Buttons/DailyBtn.pressed.connect(_on_daily_open)
	$GameOverScreen/VBox/Buttons/RetryBtn.pressed.connect(_on_retry)
	$GameOverScreen/VBox/Buttons/HomeBtn.pressed.connect(_on_home)
	$GameOverScreen/VBox/Buttons/ReviveBtn.pressed.connect(_on_revive)
	$HUD/PauseBtn.pressed.connect(_on_pause)
	$PauseModal/Panel/VBox/ResumeBtn.pressed.connect(_on_resume)
	$PauseModal/Panel/VBox/QuitBtn.pressed.connect(_on_quit)
	$DailyModal/Panel/VBox/ClaimBtn.pressed.connect(func(): _on_daily_claim(false))
	$DailyModal/Panel/VBox/ClaimDoubleBtn.pressed.connect(func(): _on_daily_claim(true))
	$DailyModal/Panel/VBox/CloseBtn.pressed.connect(func(): daily_modal.visible = false)
	$ShopModal/Panel/VBox/CloseBtn.pressed.connect(func(): shop_modal.visible = false)
	$FakeAdModal/Panel/VBox/CloseBtn.pressed.connect(_on_fake_ad_close)

	# Power-up buttons
	$HUD/PowerUps/BombBtn.pressed.connect(func(): powerup_used.emit("bomb"))
	$HUD/PowerUps/ShakeBtn.pressed.connect(func(): powerup_used.emit("shake"))
	$HUD/PowerUps/FreezeBtn.pressed.connect(func(): powerup_used.emit("freeze"))

	# Shop items
	for btn in $ShopModal/Panel/VBox/Items.get_children():
		if btn is Button:
			btn.pressed.connect(func(): shop_purchase.emit(btn.name))

func show_menu() -> void:
	menu_screen.visible = true
	hud.visible = false
	gameover_screen.visible = false
	pause_modal.visible = false
	daily_modal.visible = false
	shop_modal.visible = false
	fake_ad_modal.visible = false

	# Update stats
	menu_highscore.text = _format_number(SaveManager.get_highscore())
	menu_coins.text = _format_number(SaveManager.get_coins())
	menu_streak.text = str(SaveManager.get_daily_streak())
	daily_dot.visible = SaveManager.can_claim_daily()

func show_hud() -> void:
	menu_screen.visible = false
	hud.visible = true
	gameover_screen.visible = false
	combo_container.visible = false

func show_gameover(is_new_best: bool) -> void:
	gameover_screen.visible = true
	hud.visible = false

	final_score_label.text = _format_number(GameManager.score)
	new_best_label.visible = is_new_best
	earned_coins_label.text = str(GameManager.coins_earned_this_game)
	highest_merge_label.text = str(GameManager.highest_merge)
	best_combo_label.text = str(GameManager.best_combo)
	revive_btn.visible = not GameManager.revived

	# Animate score counting up
	_animate_score_reveal()

func show_fake_ad() -> void:
	fake_ad_modal.visible = true

func update_score(value: int) -> void:
	score_label.text = _format_number(value)
	# Punch animation
	var tween = create_tween()
	tween.tween_property(score_label, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.15)

func update_coins(value: int) -> void:
	coin_label.text = _format_number(value)

func update_combo(value: int) -> void:
	if value <= 1:
		combo_container.visible = false
		return
	combo_container.visible = true
	combo_label.text = "x" + str(value) + " COMBO"

	# Flash and scale effect
	if combo_tween:
		combo_tween.kill()
	combo_tween = create_tween()
	combo_label.modulate = Color(1, 1, 0)
	combo_tween.tween_property(combo_label, "scale", Vector2(1.5, 1.5), 0.08)
	combo_tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.15)
	combo_tween.parallel().tween_property(combo_label, "modulate", Color.WHITE, 0.3)

	# Combo bar (timeout visual) - resets each combo
	combo_bar.value = 100

func update_combo_bar(ratio: float) -> void:
	if combo_bar:
		combo_bar.value = ratio * 100

func update_powerup_counts() -> void:
	$HUD/PowerUps/BombBtn/Count.text = str(GameManager.powerups["bomb"])
	$HUD/PowerUps/ShakeBtn/Count.text = str(GameManager.powerups["shake"])
	$HUD/PowerUps/FreezeBtn/Count.text = str(GameManager.powerups["freeze"])

func _animate_score_reveal() -> void:
	var target = GameManager.score
	final_score_label.text = "0"
	var tween = create_tween()
	tween.tween_method(func(val: float):
		final_score_label.text = _format_number(int(val))
	, 0.0, float(target), 1.0)

func _format_number(n: int) -> String:
	if n >= 1000000:
		return str(snapped(n / 1000000.0, 0.1)) + "M"
	elif n >= 1000:
		return str(snapped(n / 1000.0, 0.1)) + "K"
	return str(n)

# Button callbacks
func _on_play() -> void:
	AudioManager.play_button()
	play_pressed.emit()

func _on_retry() -> void:
	AudioManager.play_button()
	retry_pressed.emit()

func _on_home() -> void:
	AudioManager.play_button()
	home_pressed.emit()

func _on_revive() -> void:
	AudioManager.play_button()
	# Show fake ad first, then revive
	show_fake_ad()
	revive_pressed.emit()

func _on_pause() -> void:
	AudioManager.play_button()
	pause_modal.visible = true
	pause_pressed.emit()

func _on_resume() -> void:
	AudioManager.play_button()
	pause_modal.visible = false
	resume_pressed.emit()

func _on_quit() -> void:
	AudioManager.play_button()
	pause_modal.visible = false
	quit_pressed.emit()

func _on_shop_open() -> void:
	AudioManager.play_button()
	_populate_shop()
	shop_modal.visible = true

func _on_daily_open() -> void:
	AudioManager.play_button()
	daily_modal.visible = true

func _on_daily_claim(doubled: bool) -> void:
	if not SaveManager.can_claim_daily():
		return
	AudioManager.play_coin()
	daily_claimed.emit(doubled)
	daily_modal.visible = false

func _on_fake_ad_close() -> void:
	fake_ad_modal.visible = false

func _populate_shop() -> void:
	# Update shop item labels with current levels and costs
	pass  # Items are defined in the scene
