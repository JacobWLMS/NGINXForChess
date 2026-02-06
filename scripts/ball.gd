extends RigidBody2D

## A droppable, mergeable ball

var tier: int = 1
var is_merging: bool = false
var has_settled: bool = false
var time_alive: float = 0.0

# Visual
var base_color: Color
var label_text: String
var ball_radius: float
var pulse_time: float = 0.0

# Settle detection
var _prev_pos: Vector2
var _settle_counter: float = 0.0
const SETTLE_THRESHOLD := 2.0
const SETTLE_TIME := 0.5

func setup(p_tier: int) -> void:
	tier = p_tier
	var info = GameManager.BALL_TIERS[tier]
	ball_radius = info["radius"]
	base_color = info["color"]
	label_text = info["label"]

	# Set up collision shape
	var shape = CircleShape2D.new()
	shape.radius = ball_radius
	$CollisionShape2D.shape = shape

	# Physics properties for satisfying bouncy feel
	mass = ball_radius * 0.1
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.2
	physics_material_override.friction = 0.6

	# Set collision
	collision_layer = 1
	collision_mask = 1 | 2  # balls + walls

	_prev_pos = global_position
	queue_redraw()

func _process(delta: float) -> void:
	time_alive += delta
	pulse_time += delta

	# Settle detection
	if not has_settled:
		var moved = global_position.distance_to(_prev_pos)
		if moved < SETTLE_THRESHOLD:
			_settle_counter += delta
			if _settle_counter > SETTLE_TIME:
				has_settled = true
		else:
			_settle_counter = 0.0
		_prev_pos = global_position

	queue_redraw()

func _draw() -> void:
	# Outer glow
	var glow_color = base_color
	glow_color.a = 0.3
	draw_circle(Vector2.ZERO, ball_radius + 4, glow_color)

	# Main ball - gradient effect using concentric circles
	var shadow_color = base_color.darkened(0.3)
	draw_circle(Vector2.ZERO, ball_radius, shadow_color)

	var highlight_color = base_color.lightened(0.15)
	draw_circle(Vector2(0, -2), ball_radius - 2, base_color)

	# Highlight
	var shine_color = Color.WHITE
	shine_color.a = 0.3
	draw_circle(Vector2(-ball_radius * 0.25, -ball_radius * 0.3), ball_radius * 0.35, shine_color)

	# Pulse effect on recent spawn
	if time_alive < 0.3:
		var pulse_alpha = (1.0 - time_alive / 0.3) * 0.4
		var pulse_color = Color.WHITE
		pulse_color.a = pulse_alpha
		draw_circle(Vector2.ZERO, ball_radius + 10 * (1.0 - time_alive / 0.3), pulse_color)

	# Number label
	var font = ThemeDB.fallback_font
	var font_size = int(ball_radius * 0.7)
	if font_size < 12:
		font_size = 12
	var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = Vector2(-text_size.x / 2.0, text_size.y / 4.0)

	# Text shadow
	var shadow = Color(0, 0, 0, 0.5)
	draw_string(font, text_pos + Vector2(1, 1), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	# Text
	draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func can_merge_with(other) -> bool:
	return tier == other.tier and not is_merging and not other.is_merging and tier < 11

func start_merge() -> void:
	is_merging = true
	# Disable collision immediately to prevent double merges
	collision_layer = 0
	collision_mask = 0
