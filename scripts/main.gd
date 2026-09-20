extends Control

const Levels = preload("res://scripts/levels.gd")
const State = preload("res://scripts/game_state.gd")
const BG = Color("0b0e18")
const PANEL = Color("141a2b")
const TILE = Color("29344c")
const INK = Color("f2f0ff")
const MUTED = Color("8893ad")
const PURPLE = Color("bba5ff")
const MINT = Color("91e7c5")
const EMBER = Color("ffb18c")
const CLASSIC_COUNT = 10
const EXPERT_START = 15

var game = State.new()
var page := "menu"
var level := 0
var best: Dictionary = {}
var muted := false
var clock := 0.0
var message := ""
var message_time := 0.0
var avatar := Vector2.ZERO
var touch_start := Vector2.ZERO
var controls: Control
var sound: AudioStreamPlayer
var font: Font = ThemeDB.fallback_font
var par := 0
var flash := 0.0
var expert_selected := false
var selected_tier := "classic"

func _ready() -> void:
	controls = Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(controls)
	sound = AudioStreamPlayer.new()
	add_child(sound)
	var save := ConfigFile.new()
	if save.load("user://progress.cfg") == OK:
		best = save.get_value("progress", "best", {})
		muted = save.get_value("settings", "muted", false)
	show_menu()

func _process(delta: float) -> void:
	clock += delta
	message_time = maxf(0, message_time - delta)
	flash = maxf(0, flash - delta * 3)
	if page == "game":
		avatar = avatar.lerp(cell_center(game.player), 1.0 - exp(-22.0 * delta))
		if game.advance_time(delta):
			play_tone(130, 0.2)
			show_result()
	queue_redraw()

func save_progress() -> void:
	var save := ConfigFile.new()
	save.set_value("progress", "best", best)
	save.set_value("settings", "muted", muted)
	var error := save.save("user://progress.cfg")
	if error != OK: push_warning("Progress could not be saved: %s" % error)

func clear_controls() -> void:
	for child in controls.get_children():
		controls.remove_child(child)
		child.queue_free()

func box(rect: Rect2, color: Color, radius: int = 16, border: Color = Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border.a > 0:
		style.set_border_width_all(1)
		style.border_color = border
	draw_style_box(style, rect)

func label_at(text: String, point: Vector2, size_px: int, color: Color = INK) -> void:
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func centered(text: String, y: float, size_px: int, color: Color = INK) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	label_at(text, Vector2((600 - width) / 2, y), size_px, color)

func button(text: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = text
	result.position = rect.position
	result.size = rect.size
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_color_override("font_color", BG if primary else INK)
	result.add_theme_color_override("font_hover_color", BG if primary else INK)
	result.add_theme_color_override("font_pressed_color", BG if primary else INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = PURPLE if primary else PANEL
		if state == "hover": style.bg_color = style.bg_color.lightened(0.12)
		if state == "pressed": style.bg_color = style.bg_color.darkened(0.12)
		style.set_corner_radius_all(14)
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
			style.border_color = MINT
		result.add_theme_stylebox_override(state, style)
	result.pressed.connect(action)
	controls.add_child(result)
	return result

func show_menu() -> void:
	page = "menu"
	clear_controls()
	var next := 0
	while next < Levels.DATA.size() - 1 and best.has(str(next)): next += 1
	button("Let's play  →" if best.is_empty() else "Continue journey  →", Rect2(100, 592, 400, 60), start_level.bind(next), true)
	button("Explore obstacles & special tiles", Rect2(100, 666, 400, 54), select_tier.bind("adventure"))
	var expert_button := button("EXPERT  /  Clear every tile  →", Rect2(100, 734, 400, 48), select_tier.bind("expert"))
	expert_button.add_theme_color_override("font_color", EMBER)
	button("Sound: off" if muted else "Sound: on", Rect2(205, 794, 190, 40), toggle_sound)

func toggle_sound() -> void:
	muted = not muted
	save_progress()
	show_menu()

func show_levels() -> void:
	page = "levels"
	clear_controls()
	button("← Back", Rect2(40, 36, 110, 46), show_menu)
	button("Classic  01–10", Rect2(40, 181, 168, 42), select_tier.bind("classic"), selected_tier == "classic").add_theme_font_size_override("font_size", 14)
	button("Adventure  11–15", Rect2(216, 181, 168, 42), select_tier.bind("adventure"), selected_tier == "adventure").add_theme_font_size_override("font_size", 14)
	button("Expert  16–25", Rect2(392, 181, 168, 42), select_tier.bind("expert"), selected_tier == "expert").add_theme_font_size_override("font_size", 14)
	var first := tier_first()
	var end := tier_end()
	for i in range(first, end):
		var slot := i - first
		var x := 62 + (slot % 2) * 246
		var y := 242 + (slot / 2) * 96
		var text := "%02d   %s" % [i + 1, Levels.DATA[i].name]
		if best.has(str(i)): text += "  ✓"
		var choice := button(text, Rect2(x, y, 230, 80), start_level.bind(i))
		choice.add_theme_font_size_override("font_size", 15)
		if expert_selected: choice.add_theme_color_override("font_color", EMBER)

func select_tier(tier: String) -> void:
	selected_tier = tier
	expert_selected = tier == "expert"
	show_levels()

func tier_first() -> int:
	return EXPERT_START if selected_tier == "expert" else (CLASSIC_COUNT if selected_tier == "adventure" else 0)

func tier_end() -> int:
	return Levels.DATA.size() if selected_tier == "expert" else (EXPERT_START if selected_tier == "adventure" else CLASSIC_COUNT)

func tier_completed() -> int:
	var total := 0
	var first := tier_first()
	var end := tier_end()
	for i in range(first, end):
		if best.has(str(i)): total += 1
	return total

func start_level(index: int) -> void:
	level = index
	expert_selected = bool(Levels.DATA[level].get("require_all", false))
	selected_tier = Levels.DATA[level].get("tier", "classic")
	game.setup(Levels.DATA[level].map, expert_selected, float(Levels.DATA[level].get("time_limit", 0.0)))
	par = game.floor_count - 1 if expert_selected else game.shortest_route().size()
	avatar = cell_center(game.player)
	page = "game"
	message_time = 0
	clear_controls()
	button("← Levels", Rect2(36, 30, 124, 44), show_levels)
	button("Restart  ↻", Rect2(438, 30, 126, 44), start_level.bind(level))
	button("↑", Rect2(269, 728, 62, 52), attempt.bind(Vector2i.UP))
	button("←", Rect2(197, 790, 62, 52), attempt.bind(Vector2i.LEFT))
	button("↓", Rect2(269, 790, 62, 52), attempt.bind(Vector2i.DOWN))
	button("→", Rect2(341, 790, 62, 52), attempt.bind(Vector2i.RIGHT))

func grid_rect() -> Rect2:
	return Rect2(60, 228, 480, 440)

func cell_size() -> float:
	return minf(480.0 / game.rows[0].length(), 440.0 / game.rows.size())

func grid_origin() -> Vector2:
	var extent := Vector2(game.rows[0].length(), game.rows.size()) * cell_size()
	return grid_rect().get_center() - extent / 2

func cell_center(cell: Vector2i) -> Vector2:
	return grid_origin() + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size()

func attempt(direction: Vector2i) -> void:
	if page != "game" or game.won or game.stuck: return
	var used_portal: bool = game.tile_at(game.player + direction) in ["1", "2"]
	var outcome: String = game.move(direction)
	if used_portal and outcome in ["moved", "stuck", "won"]: avatar = cell_center(game.player)
	match outcome:
		"goal_locked":
			message = ("Flag locked: collect %d more crystals." % game.crystals_left) if game.crystals_left > 0 else ("Flag locked: clear the other %d tiles first." % (game.tiles_left() - 1))
			message_time = 2.8
			flash = 1
			play_tone(160, 0.07)
		"door_locked", "portal_blocked":
			message = "This door needs a key. Find a gold key first." if outcome == "door_locked" else "That portal's exit is gone. Try another way."
			message_time = 2.8
			flash = 1
			play_tone(160, 0.07)
		"wall", "visited":
			message = "That tile is gone. Try another way." if outcome == "visited" else "No path there. Try another direction."
			message_time = 2.2
			flash = 1
			play_tone(160, 0.07)
		"moved":
			message_time = 0
			play_tone(390 + game.moves * 12, 0.06)
		"won":
			var key := str(level)
			best[key] = mini(int(best.get(key, 9999)), game.moves)
			save_progress()
			play_tone(780, 0.24)
			show_result()
		"stuck":
			play_tone(130, 0.2)
			show_result()

func show_result() -> void:
	clear_controls()
	if game.won:
		var last := level == Levels.DATA.size() - 1
		var next_text := "Enter Expert  →" if level == EXPERT_START - 1 else ("Enter Adventure  →" if level == CLASSIC_COUNT - 1 else "Next level  →")
		button("Back to main menu" if last else next_text, Rect2(135, 506, 330, 56), show_menu if last else start_level.bind(level + 1), true)
		button("Play again", Rect2(135, 576, 156, 48), start_level.bind(level))
		button("All levels", Rect2(309, 576, 156, 48), show_levels)
	else:
		button("Try again  ↻", Rect2(135, 506, 330, 56), start_level.bind(level), true)
		button("Choose a level", Rect2(135, 576, 330, 48), show_levels)

func _input(event: InputEvent) -> void:
	if page != "game": return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W: attempt(Vector2i.UP)
			KEY_DOWN, KEY_S: attempt(Vector2i.DOWN)
			KEY_LEFT, KEY_A: attempt(Vector2i.LEFT)
			KEY_RIGHT, KEY_D: attempt(Vector2i.RIGHT)
			KEY_R: start_level(level)
			KEY_ESCAPE: show_levels()
		if event.keycode in [KEY_UP, KEY_W, KEY_DOWN, KEY_S, KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D, KEY_R, KEY_ESCAPE]:
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if page != "game": return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
		else:
			var delta: Vector2 = event.position - touch_start
			if delta.length() > 25:
				attempt(Vector2i(signi(int(delta.x)), 0) if absf(delta.x) > absf(delta.y) else Vector2i(0, signi(int(delta.y))))
			else: click_tile(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click_tile(event.position)

func click_tile(point: Vector2) -> void:
	var local := (point - grid_origin()) / cell_size()
	var target := Vector2i(floori(local.x), floori(local.y))
	if game.is_floor(target) and abs(target.x - game.player.x) + abs(target.y - game.player.y) == 1:
		attempt(target - game.player)

func play_tone(frequency: float, duration: float) -> void:
	if muted: return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := int(duration * 22050)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in samples:
		var envelope := sin(PI * float(i) / samples) * 0.13
		bytes.encode_s16(i * 2, int(sin(TAU * frequency * i / 22050.0) * envelope * 32767))
	stream.data = bytes
	sound.stream = stream
	sound.play()

func draw_avatar(point: Vector2, width: float) -> void:
	box(Rect2(point - Vector2.ONE * width / 2 + Vector2(0, 5), Vector2.ONE * width), Color("66558f"), int(width * 0.28))
	box(Rect2(point - Vector2.ONE * width / 2, Vector2.ONE * width), PURPLE, int(width * 0.28))
	draw_circle(point + Vector2(-0.16, -0.06) * width, width * 0.045, BG)
	draw_circle(point + Vector2(0.16, -0.06) * width, width * 0.045, BG)
	draw_arc(point + Vector2(0, 0.05) * width, width * 0.14, 0.25, PI - 0.25, 16, BG, 2.0, true)

func draw_flag(point: Vector2, width: float) -> void:
	draw_line(point + Vector2(-0.18, 0.28) * width, point + Vector2(-0.18, -0.3) * width, MINT, 3, true)
	draw_colored_polygon(PackedVector2Array([point + Vector2(-0.16, -0.3) * width, point + Vector2(0.3, -0.16) * width, point + Vector2(-0.16, 0.02) * width]), MINT)

func draw_lock(point: Vector2) -> void:
	draw_circle(point, 9, BG)
	draw_arc(point + Vector2(0, -3), 3, PI, TAU, 12, EMBER, 2, true)
	box(Rect2(point + Vector2(-4, -3), Vector2(8, 8)), EMBER, 2)

func tile_color(tile: String) -> Color:
	match tile:
		"K", "D": return Color("574630")
		"G": return Color("214958")
		"1", "2": return Color("473563")
		"I": return Color("29526a")
		"F": return Color("24443f")
	return TILE

func draw_wall(rect: Rect2) -> void:
	var brick := rect.grow(-3)
	box(brick, Color("343344"), 6)
	draw_line(Vector2(brick.position.x, brick.get_center().y), Vector2(brick.end.x, brick.get_center().y), BG, 2)
	draw_line(Vector2(brick.get_center().x - brick.size.x * 0.18, brick.position.y), Vector2(brick.get_center().x - brick.size.x * 0.18, brick.get_center().y), BG, 2)
	draw_line(Vector2(brick.get_center().x + brick.size.x * 0.18, brick.get_center().y), Vector2(brick.get_center().x + brick.size.x * 0.18, brick.end.y), BG, 2)

func draw_special(tile: String, p: Vector2, tile_size: float) -> void:
	var unit := tile_size * 0.23
	match tile:
		"K":
			draw_arc(p + Vector2(-unit * 0.4, -unit * 0.3), unit * 0.4, 0, TAU, 24, Color("ffd379"), 2.5, true)
			draw_line(p + Vector2(-unit * 0.1, 0), p + Vector2(unit * 0.65, unit * 0.75), Color("ffd379"), 3, true)
			draw_line(p + Vector2(unit * 0.4, unit * 0.5), p + Vector2(unit * 0.75, unit * 0.15), Color("ffd379"), 3, true)
		"D":
			box(Rect2(p - Vector2(unit * 0.65, unit), Vector2(unit * 1.3, unit * 2)), Color("ffd379"), 3)
			draw_circle(p + Vector2(0, -unit * 0.12), unit * 0.22, BG)
			draw_line(p, p + Vector2(0, unit * 0.45), BG, 3)
		"G":
			var points := PackedVector2Array([p + Vector2(0, -unit), p + Vector2(unit * 0.65, 0), p + Vector2(0, unit), p + Vector2(-unit * 0.65, 0)])
			draw_colored_polygon(points, Color("76e3fa"))
			draw_line(p + Vector2(0, -unit), p + Vector2(0, unit), Color("d6fbff"), 2, true)
		"1", "2":
			draw_arc(p, unit, clock, clock + TAU * 0.8, 32, PURPLE, 3, true)
			draw_arc(p, unit * 0.58, -clock, -clock + TAU * 0.8, 24, MINT, 2, true)
		"I":
			for i in 3:
				var a := Vector2.RIGHT.rotated(i * PI / 3) * unit
				draw_line(p - a, p + a, Color("a9e5ff"), 2, true)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 600, 900), BG)
	for x in range(20, 600, 28):
		for y in range(14, 900, 28): draw_circle(Vector2(x, y), 0.7, Color("202638"))
	if page == "menu": draw_menu()
	elif page == "levels":
		centered("NO ROOM FOR ERROR" if expert_selected else ("EXPECT THE UNEXPECTED" if selected_tier == "adventure" else "PICK YOUR PATH"), 129, 29, EMBER if expert_selected else INK)
		centered("Ten puzzles. Exactly one solution each." if expert_selected else ("Keys, crystals, portals, ice & a ticking clock." if selected_tier == "adventure" else "10 little journeys. One simple rule."), 159, 16, MUTED)
		if expert_selected:
			centered("Visit EVERY floor tile. Reach the flag LAST.", 756, 16, EMBER)
			centered("No undo. No hints. Plan the entire route.", 785, 15, MUTED)
		elif selected_tier == "adventure":
			centered("MEET THE TILES", 556, 12, MUTED)
			var symbols := ["K", "D", "G", "1", "I"]
			var names := ["Key", "Door", "Crystal", "Portal", "Ice"]
			for i in symbols.size():
				var point := Vector2(100 + i * 100, 604)
				box(Rect2(point - Vector2(27, 27), Vector2(54, 54)), tile_color(symbols[i]), 12)
				draw_special(symbols[i], point, 64)
				var width := font.get_string_size(names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				label_at(names[i], Vector2(point.x - width / 2, 653), 13, MUTED)
			centered("Learn each mechanic, then combine them.", 756, 16, MINT)
			centered("Walls block. Doors unlock. Ice won't let you stop.", 785, 15, MUTED)
		else:
			centered("Reach the flag without retracing your steps.", 766, 16, MUTED)
		centered("%d / %d completed  •  Play in any order" % [tier_completed(), tier_end() - tier_first()], 840, 16, MUTED)
	elif page == "game": draw_game()

func draw_menu() -> void:
	box(Rect2(198, 66, 204, 32), PANEL, 16)
	centered("A LITTLE PATH PUZZLE", 88, 12, MINT)
	centered("Don't Touch", 169, 50)
	centered("Twice.", 227, 58, PURPLE)
	centered("Every step is a one-way trip.", 272, 19, MUTED)
	box(Rect2(116, 310, 368, 204), PANEL, 26, Color("293047"))
	var points := [Vector2(169, 367), Vector2(252, 367), Vector2(335, 367), Vector2(335, 451), Vector2(418, 451)]
	for i in range(1, points.size()): draw_line(points[i - 1], points[i], Color("66558f"), 3, true)
	for y in 2:
		for x in 4:
			var p := Vector2(169 + 83 * x, 367 + 84 * y)
			box(Rect2(p - Vector2(32, 32), Vector2(64, 64)), TILE, 13)
	for i in 3:
		box(Rect2(points[i] - Vector2(32, 32), Vector2(64, 64)), BG, 13)
		draw_circle(points[i], 4, Color("66558f"))
	draw_avatar(points[3] + Vector2(0, sin(clock * 2) * 3), 44)
	draw_flag(points[4], 45)
	centered("Find the flag. Never retrace your steps.", 551, 17, MUTED)
	centered("ARROWS / WASD   ·   TAP / SWIPE", 874, 12, MUTED)

func draw_game() -> void:
	centered("DON'T TOUCH TWICE", 58, 13, MUTED)
	label_at(("EXPERT %02d / %d  ·  CLEAR ALL" if game.require_all else "LEVEL %02d / %d") % [level + 1, Levels.DATA.size()], Vector2(40, 111), 12, EMBER if game.require_all else MINT)
	label_at(Levels.DATA[level].name, Vector2(40, 151), 32)
	box(Rect2(429, 94, 132, 75), PANEL, 16)
	label_at("%02d" % game.moves, Vector2(445, 127), 28, PURPLE)
	label_at("%d TILES LEFT" % game.tiles_left() if game.require_all else ("TILES ENTERED" if selected_tier == "adventure" else "MOVES / %d PAR" % par), Vector2(445, 151), 10, EMBER if game.require_all else MUTED)
	label_at(Levels.DATA[level].hint, Vector2(40, 193), 15, MUTED)
	box(Rect2(40, 210, 520, 474), PANEL, 24, Color("30384e"))
	var size_px := cell_size()
	for y in game.rows.size():
		for x in game.rows[y].length():
			var cell := Vector2i(x, y)
			var p := cell_center(cell)
			var rect := Rect2(p - Vector2.ONE * (size_px - 10) / 2, Vector2.ONE * (size_px - 10))
			if not game.is_floor(cell):
				draw_wall(rect)
			elif game.visited.has(cell):
				box(rect, BG, 13)
				draw_circle(p, 3, Color("675b86"))
			else:
				box(Rect2(rect.position + Vector2(0, 4), rect.size), Color("1b2336"), 13)
				box(rect, tile_color(game.tile_at(cell)), 13)
				draw_special(game.tile_at(cell), p, size_px)
				if cell == game.goal:
					draw_flag(p, size_px * 0.55)
					if game.goal_locked(): draw_lock(p + Vector2(size_px * 0.18, size_px * 0.18))
	for i in range(1, game.path.size()):
		var step: Vector2i = game.path[i] - game.path[i - 1]
		if absi(step.x) + absi(step.y) == 1:
			draw_line(cell_center(game.path[i - 1]), cell_center(game.path[i]), Color(0.58, 0.48, 0.77, 0.3), 2, true)
	draw_avatar(avatar + Vector2(sin(clock * 70) * flash * 4, 0), size_px * 0.53)
	if message_time > 0: centered(message, 711, 15, Color("ffc0b8"))
	elif game.require_all: centered("%d tiles left   ·   %d keys   ·   %d crystals" % [game.tiles_left(), game.keys, game.crystals_left], 711, 14, EMBER)
	elif selected_tier == "adventure":
		var status := "%d keys   ·   %d crystals left" % [game.keys, game.crystals_left]
		if game.time_limit > 0: status += "   ·   %ds left" % ceili(game.time_left)
		centered(status, 711, 16, EMBER if game.time_limit > 0 and game.time_left < 10 else MINT)
	else: centered("You     ·     Gone     ·     Flag = finish", 711, 13, MUTED)
	centered("ARROWS / WASD TO MOVE    ·    R TO RESTART", 877, 11, MUTED)
	if game.won or game.stuck: draw_result()

func draw_result() -> void:
	draw_rect(Rect2(0, 0, 600, 900), Color(0.025, 0.03, 0.055, 0.88))
	box(Rect2(100, 257, 400, 403), PANEL, 28, Color("49405e"))
	if game.won:
		for i in 18:
			var p := Vector2(120 + fmod(i * 79.0, 364), 230 + fmod(clock * 35 + i * 39, 450))
			draw_circle(p, 2.5, PURPLE if i % 2 == 0 else MINT)
		draw_flag(Vector2(300, 316), 68)
		centered("Expert conquered!" if game.require_all else "Beautifully done.", 391, 30)
		centered("%d tiles entered  ·  Best %d" % [game.moves, best[str(level)]] if selected_tier == "adventure" else "%d moves  ·  Best %d  ·  Par %d" % [game.moves, best[str(level)], par], 435, 17, MUTED)
		centered("Every tile. Exactly once." if game.require_all else ("A perfect path!" if game.moves == par else "A fresh path, all your own."), 470, 16, MINT)
	else:
		draw_avatar(Vector2(300, 318), 60)
		centered("Out of time." if game.failure_reason == "Time ran out." else ("The route is broken." if game.require_all else "A little dead end."), 391, 29)
		centered("%d tiles remain. No legal move." % game.tiles_left() if game.require_all else game.failure_reason, 435, 17, MUTED)
		centered("A new path is one restart away.", 470, 16, PURPLE)
