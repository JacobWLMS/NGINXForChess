extends Node2D

## Draws the game board container, danger line, and background visuals

const BOARD_LEFT := 60.0
const BOARD_RIGHT := 660.0
const BOARD_TOP := 200.0
const BOARD_BOTTOM := 1220.0
const DANGER_Y := 260.0

var bg_stars: Array = []
var time: float = 0.0

func _ready() -> void:
	z_index = -10
	# Generate background stars
	for i in range(40):
		bg_stars.append({
			"pos": Vector2(randf_range(0, 720), randf_range(0, 1280)),
			"size": randf_range(1, 3),
			"speed": randf_range(0.3, 1.0),
			"brightness": randf_range(0.3, 0.8),
		})

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	# Background gradient
	var bg_top = Color(0.102, 0.039, 0.18)
	var bg_bottom = Color(0.05, 0.02, 0.12)
	draw_rect(Rect2(0, 0, 720, 1280), bg_top)
	# Subtle gradient via overlapping rects
	for i in range(10):
		var t = float(i) / 10.0
		var col = bg_top.lerp(bg_bottom, t)
		col.a = 0.5
		draw_rect(Rect2(0, 128 * i, 720, 128), col)

	# Animated background stars
	for star in bg_stars:
		var brightness = star["brightness"] * (0.5 + 0.5 * sin(time * star["speed"] * 3))
		var col = Color(brightness, brightness, brightness * 1.2, brightness * 0.6)
		draw_circle(star["pos"], star["size"], col)

	# Board container
	var border_color = Color(0.4, 0.2, 0.8, 0.8)
	var fill_color = Color(0.05, 0.02, 0.1, 0.6)

	# Fill
	draw_rect(Rect2(BOARD_LEFT, BOARD_TOP, BOARD_RIGHT - BOARD_LEFT, BOARD_BOTTOM - BOARD_TOP), fill_color)

	# Border glow
	var glow = border_color
	glow.a = 0.3
	draw_rect(Rect2(BOARD_LEFT - 3, BOARD_TOP - 3, BOARD_RIGHT - BOARD_LEFT + 6, BOARD_BOTTOM - BOARD_TOP + 6), glow, false, 6)
	draw_rect(Rect2(BOARD_LEFT, BOARD_TOP, BOARD_RIGHT - BOARD_LEFT, BOARD_BOTTOM - BOARD_TOP), border_color, false, 2)

	# Danger line
	var danger_alpha = 0.3 + 0.2 * sin(time * 4)
	var danger_color = Color(1, 0, 0, danger_alpha)
	draw_dashed_line(Vector2(BOARD_LEFT, DANGER_Y), Vector2(BOARD_RIGHT, DANGER_Y), danger_color, 2, 8)

	# "DANGER" text
	var font = ThemeDB.fallback_font
	var text_color = Color(1, 0, 0, danger_alpha * 0.8)
	draw_string(font, Vector2(BOARD_LEFT + 5, DANGER_Y - 5), "DANGER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)
