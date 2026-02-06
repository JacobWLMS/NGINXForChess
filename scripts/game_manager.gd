extends Node

## Global game state singleton

signal score_changed(new_score: int)
signal coins_changed(new_coins: int)
signal combo_changed(combo: int)
signal game_over
signal ball_merged(tier: int, position: Vector2)

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

var state: GameState = GameState.MENU
var score: int = 0
var coins: int = 0
var combo: int = 0
var combo_timer: float = 0.0
var highest_merge: int = 0
var best_combo: int = 0
var coins_earned_this_game: int = 0
var revived: bool = false

# Ball tier definitions: [radius, color, points, label]
# Tiers go from 1 (smallest) to 11 (biggest) - like Suika game
const BALL_TIERS = {
	1:  { "radius": 22,  "color": Color(1.0, 0.2, 0.3),    "points": 2,     "label": "2" },
	2:  { "radius": 30,  "color": Color(1.0, 0.5, 0.1),    "points": 4,     "label": "4" },
	3:  { "radius": 38,  "color": Color(1.0, 0.75, 0.05),   "points": 8,     "label": "8" },
	4:  { "radius": 46,  "color": Color(0.3, 0.85, 0.2),   "points": 16,    "label": "16" },
	5:  { "radius": 54,  "color": Color(0.1, 0.8, 0.7),    "points": 32,    "label": "32" },
	6:  { "radius": 62,  "color": Color(0.2, 0.5, 1.0),    "points": 64,    "label": "64" },
	7:  { "radius": 70,  "color": Color(0.55, 0.3, 1.0),   "points": 128,   "label": "128" },
	8:  { "radius": 78,  "color": Color(0.85, 0.2, 0.9),   "points": 256,   "label": "256" },
	9:  { "radius": 88,  "color": Color(1.0, 0.4, 0.7),    "points": 512,   "label": "512" },
	10: { "radius": 100, "color": Color(1.0, 0.85, 0.0),   "points": 1024,  "label": "1K" },
	11: { "radius": 115, "color": Color(1.0, 1.0, 1.0),    "points": 2048,  "label": "2K" },
}

const COMBO_TIMEOUT := 2.0
const COIN_PER_MERGE := 1
const COIN_BONUS_HIGH_TIER := 5

# Power-ups
var powerups := { "bomb": 3, "shake": 1, "freeze": 2 }

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo = 0
			combo_changed.emit(0)

func start_game() -> void:
	state = GameState.PLAYING
	score = 0
	combo = 0
	combo_timer = 0.0
	highest_merge = 0
	best_combo = 0
	coins_earned_this_game = 0
	revived = false
	score_changed.emit(0)
	combo_changed.emit(0)
	coins_changed.emit(coins)

func add_score(tier: int, pos: Vector2) -> void:
	var points = BALL_TIERS[tier]["points"]

	# Combo system
	combo += 1
	combo_timer = COMBO_TIMEOUT
	if combo > best_combo:
		best_combo = combo
	combo_changed.emit(combo)

	# Apply combo multiplier
	var multiplier = 1.0 + (combo - 1) * 0.5
	var gained = int(points * multiplier)
	score += gained
	score_changed.emit(score)

	# Track highest merge
	if tier > highest_merge:
		highest_merge = tier

	# Coins
	var coin_gain = COIN_PER_MERGE
	if tier >= 6:
		coin_gain += COIN_BONUS_HIGH_TIER
	coins += coin_gain
	coins_earned_this_game += coin_gain
	coins_changed.emit(coins)

	ball_merged.emit(tier, pos)

func trigger_game_over() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.GAME_OVER
	SaveManager.check_and_save_highscore(score)
	SaveManager.save_coins(coins)
	game_over.emit()

func revive_game() -> void:
	revived = true
	state = GameState.PLAYING

func pause_game() -> void:
	if state == GameState.PLAYING:
		state = GameState.PAUSED
		get_tree().paused = true

func resume_game() -> void:
	if state == GameState.PAUSED:
		state = GameState.PLAYING
		get_tree().paused = false

func use_powerup(pu_name: String) -> bool:
	if powerups.get(pu_name, 0) > 0:
		powerups[pu_name] -= 1
		return true
	return false

func get_drop_tiers() -> Array:
	# Only drop tiers 1-5 (small balls) to keep it challenging
	return [1, 2, 3, 4, 5]

func get_random_drop_tier() -> int:
	var tiers = get_drop_tiers()
	# Weight toward smaller tiers for more merging opportunities
	var weights = [35, 30, 20, 10, 5]
	var total = 0
	for w in weights:
		total += w
	var r = randi() % total
	var cumulative = 0
	for i in range(tiers.size()):
		cumulative += weights[i]
		if r < cumulative:
			return tiers[i]
	return tiers[0]
