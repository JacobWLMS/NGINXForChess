extends Node2D

## Handles all the juicy visual effects - particles, screen shake, floating text, flashes

var camera: Camera2D
var shake_intensity: float = 0.0
var shake_decay: float = 8.0

# Particle pool
var particles: Array = []
const MAX_PARTICLES := 300

# Floating texts
var float_texts: Array = []

func _ready() -> void:
	z_index = 100  # Draw on top of everything

func set_camera(cam: Camera2D) -> void:
	camera = cam

func _process(delta: float) -> void:
	# Screen shake
	if camera and shake_intensity > 0:
		camera.offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_intensity = maxf(shake_intensity - shake_decay * delta, 0)
		if shake_intensity <= 0.1:
			shake_intensity = 0
			camera.offset = Vector2.ZERO

	# Update particles
	var i = particles.size() - 1
	while i >= 0:
		var p = particles[i]
		p["life"] -= delta
		if p["life"] <= 0:
			particles.remove_at(i)
		else:
			p["pos"] += p["vel"] * delta
			p["vel"].y += 400 * delta  # gravity
			p["vel"] *= 0.98  # drag
			var life_ratio = p["life"] / p["max_life"]
			p["alpha"] = life_ratio
			p["size"] = p["base_size"] * life_ratio
		i -= 1

	# Update floating texts
	i = float_texts.size() - 1
	while i >= 0:
		var ft = float_texts[i]
		ft["life"] -= delta
		if ft["life"] <= 0:
			float_texts.remove_at(i)
		else:
			ft["pos"].y -= 120 * delta  # Float upward
			ft["alpha"] = ft["life"] / ft["max_life"]
			ft["scale"] = 1.0 + (1.0 - ft["life"] / ft["max_life"]) * 0.3
		i -= 1

	queue_redraw()

func _draw() -> void:
	# Draw particles
	for p in particles:
		var color = p["color"]
		color.a = p["alpha"]
		if p.get("type", "circle") == "circle":
			draw_circle(p["pos"], p["size"], color)
		elif p["type"] == "star":
			_draw_star(p["pos"], p["size"], color)
		elif p["type"] == "ring":
			# Expanding ring
			var ring_color = color
			ring_color.a *= 0.5
			draw_arc(p["pos"], p["size"] * 3, 0, TAU, 32, ring_color, 2.0)

	# Draw floating texts
	var font = ThemeDB.fallback_font
	for ft in float_texts:
		var color = ft["color"]
		color.a = ft["alpha"]
		var font_size = int(ft["font_size"] * ft["scale"])
		var text_size = font.get_string_size(ft["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var pos = ft["pos"] - text_size / 2

		# Outline
		var outline = Color.BLACK
		outline.a = color.a * 0.8
		for ox in [-2, 0, 2]:
			for oy in [-2, 0, 2]:
				if ox != 0 or oy != 0:
					draw_string(font, pos + Vector2(ox, oy), ft["text"],
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline)
		draw_string(font, pos, ft["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_star(pos: Vector2, size: float, color: Color) -> void:
	var points = PackedVector2Array()
	for j in range(10):
		var angle = j * TAU / 10 - PI / 2
		var r = size if j % 2 == 0 else size * 0.4
		points.append(pos + Vector2(cos(angle), sin(angle)) * r)
	var colors = PackedColorArray()
	for j in range(10):
		colors.append(color)
	if points.size() >= 3:
		draw_polygon(points, colors)

# --- Effect spawners ---

func shake(intensity: float) -> void:
	shake_intensity = maxf(shake_intensity, intensity)

func spawn_merge_particles(pos: Vector2, color: Color, tier: int) -> void:
	var count = 8 + tier * 4  # More particles for higher tiers
	var speed = 150 + tier * 30.0
	for j in range(count):
		if particles.size() >= MAX_PARTICLES:
			break
		var angle = randf() * TAU
		var spd = randf_range(speed * 0.5, speed)
		var p = {
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"life": randf_range(0.3, 0.8),
			"max_life": 0.8,
			"color": color.lightened(randf_range(0, 0.3)),
			"size": randf_range(3, 8),
			"base_size": randf_range(3, 8),
			"alpha": 1.0,
			"type": ["circle", "star"][randi() % 2]
		}
		particles.append(p)

	# Expanding ring effect for tier >= 5
	if tier >= 5:
		particles.append({
			"pos": pos,
			"vel": Vector2.ZERO,
			"life": 0.5,
			"max_life": 0.5,
			"color": Color.WHITE,
			"size": float(tier * 5),
			"base_size": float(tier * 10),
			"alpha": 0.8,
			"type": "ring"
		})

	# Screen shake scales with tier
	shake(2.0 + tier * 1.5)

func spawn_float_text(pos: Vector2, text: String, color: Color, size: int = 28) -> void:
	float_texts.append({
		"pos": pos,
		"text": text,
		"color": color,
		"font_size": size,
		"life": 1.0,
		"max_life": 1.0,
		"alpha": 1.0,
		"scale": 1.0,
	})

func spawn_combo_text(pos: Vector2, combo: int) -> void:
	var colors = [
		Color.WHITE,
		Color(1, 1, 0),       # x2 yellow
		Color(1, 0.5, 0),     # x3 orange
		Color(1, 0, 0.4),     # x4 pink
		Color(0.8, 0, 1),     # x5 purple
		Color(0, 0.8, 1),     # x6+ cyan
	]
	var color_idx = mini(combo - 1, colors.size() - 1)
	var size = 28 + combo * 4
	spawn_float_text(pos + Vector2(0, -60), "x" + str(combo) + " COMBO!", colors[color_idx], size)

	# Extra particles for big combos
	if combo >= 3:
		for j in range(combo * 3):
			if particles.size() >= MAX_PARTICLES:
				break
			particles.append({
				"pos": pos + Vector2(randf_range(-50, 50), randf_range(-50, 50)),
				"vel": Vector2(randf_range(-200, 200), randf_range(-300, -100)),
				"life": randf_range(0.5, 1.0),
				"max_life": 1.0,
				"color": colors[color_idx],
				"size": randf_range(2, 5),
				"base_size": randf_range(2, 5),
				"alpha": 1.0,
				"type": "star"
			})

func spawn_coin_particles(pos: Vector2, count: int) -> void:
	for j in range(count):
		if particles.size() >= MAX_PARTICLES:
			break
		particles.append({
			"pos": pos,
			"vel": Vector2(randf_range(-100, 100), randf_range(-250, -100)),
			"life": randf_range(0.4, 0.7),
			"max_life": 0.7,
			"color": Color(1, 0.85, 0),
			"size": randf_range(3, 6),
			"base_size": randf_range(3, 6),
			"alpha": 1.0,
			"type": "star"
		})
