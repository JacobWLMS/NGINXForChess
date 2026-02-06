extends Node

## Handles persistence - save/load game data

const SAVE_PATH = "user://mergedropx_save.json"

var data := {
	"highscore": 0,
	"coins": 0,
	"total_merges": 0,
	"total_games": 0,
	"daily_streak": 0,
	"last_daily_claim": "",
	"last_login_date": "",
	"powerups": { "bomb": 3, "shake": 1, "freeze": 2 },
	"shop_upgrades": {
		"starting_coins_bonus": 0,
		"combo_timeout_bonus": 0,
		"coin_multiplier": 0,
	},
	"skins_owned": ["default"],
	"active_skin": "default",
	"games_since_ad": 0,
}

func _ready() -> void:
	load_data()
	check_daily_login()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_data()
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var result = json.parse(file.get_as_text())
		if result == OK:
			var loaded = json.data
			# Merge loaded data over defaults so new keys are preserved
			for key in loaded:
				data[key] = loaded[key]
		file.close()

func save_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func check_and_save_highscore(score: int) -> bool:
	data["total_games"] += 1
	var is_new = score > data["highscore"]
	if is_new:
		data["highscore"] = score
	save_data()
	return is_new

func save_coins(amount: int) -> void:
	data["coins"] = amount
	save_data()

func get_highscore() -> int:
	return data["highscore"]

func get_coins() -> int:
	return data["coins"]

func get_daily_streak() -> int:
	return data["daily_streak"]

func check_daily_login() -> void:
	var today = Time.get_date_string_from_system()
	if data["last_login_date"] != today:
		data["last_login_date"] = today
		save_data()

func can_claim_daily() -> bool:
	var today = Time.get_date_string_from_system()
	return data["last_daily_claim"] != today

func claim_daily_reward() -> int:
	var today = Time.get_date_string_from_system()
	# Check streak
	# Simple: if claimed yesterday, streak continues; otherwise reset
	data["daily_streak"] += 1
	data["last_daily_claim"] = today

	# Reward scales with streak (addictive escalation)
	var base_reward = 50
	var streak_bonus = data["daily_streak"] * 25
	var reward = base_reward + streak_bonus

	data["coins"] += reward
	GameManager.coins = data["coins"]
	save_data()
	return reward

func increment_ad_counter() -> bool:
	# Show a "fake ad" every 3 games
	data["games_since_ad"] += 1
	if data["games_since_ad"] >= 3:
		data["games_since_ad"] = 0
		save_data()
		return true
	save_data()
	return false

func buy_upgrade(upgrade_name: String, cost: int) -> bool:
	if data["coins"] >= cost:
		data["coins"] -= cost
		data["shop_upgrades"][upgrade_name] += 1
		GameManager.coins = data["coins"]
		save_data()
		return true
	return false

func get_upgrade_level(upgrade_name: String) -> int:
	return data["shop_upgrades"].get(upgrade_name, 0)
