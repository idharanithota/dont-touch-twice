extends SceneTree

class TestGame:
	extends "res://scripts/main.gd"
	func save_progress() -> void:
		pass # Exercise UI without overwriting the player's progress.

var failures := 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + description)

func _init() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("/private/tmp/dtt-" + name + ".png")

func run() -> void:
	var view := TestGame.new()
	root.add_child(view)
	view.muted = true
	await process_frame
	check(view.page == "menu", "Main menu opens")
	await capture("menu")
	view.show_levels()
	check(view.controls.get_child_count() == 14, "10 levels, three tier tabs, and back")
	await capture("levels")
	view.start_level(0)
	await capture("game")
	var input := InputEventKey.new()
	input.keycode = KEY_D
	input.pressed = true
	view._input(input)
	check(view.game.moves == 1, "Keyboard movement")
	view.click_tile(view.cell_center(Vector2i(2, 0)))
	check(view.game.moves == 2, "Adjacent tap movement")
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = Vector2(250, 400)
	view._unhandled_input(down)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = Vector2(250, 460)
	view._unhandled_input(up)
	check(view.game.moves == 3 and view.game.player == Vector2i(2, 1), "Swipe moves one tile")
	view.start_level(0)
	var route: Array[Vector2i] = view.game.shortest_route()
	for cell in route: view.attempt(cell - view.game.player)
	check(view.game.won and view.controls.get_child_count() == 3, "Win controls appear")
	await capture("win")
	view.start_level(0)
	check(view.game.moves == 0 and not view.game.won, "UI restart resets")
	for step in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]: view.attempt(step)
	view.attempt(Vector2i.DOWN)
	view.attempt(Vector2i.RIGHT)
	view.attempt(Vector2i.RIGHT)
	view.attempt(Vector2i.UP)
	view.attempt(Vector2i.UP)
	view.attempt(Vector2i.RIGHT)
	view.attempt(Vector2i.DOWN)
	view.attempt(Vector2i.DOWN)
	view.attempt(Vector2i.LEFT)
	check(view.game.stuck == false, "Legal continuation remains")
	# Use a compact deterministic fixture to exercise the blocked overlay.
	view.game.setup(["S.F", ".##"])
	view.attempt(Vector2i.DOWN)
	check(view.game.stuck and view.controls.get_child_count() == 2, "Dead-end controls appear")
	view.start_level(9)
	await capture("level10")
	view.select_tier("adventure")
	check(view.controls.get_child_count() == 9, "Five adventure levels accessible")
	await capture("adventure-picker")
	for index in range(10, 15):
		view.start_level(index)
		await capture("adventure-%d" % index)
		for step in view.Levels.DATA[index].solution:
			view.attempt({"U": Vector2i.UP, "D": Vector2i.DOWN, "L": Vector2i.LEFT, "R": Vector2i.RIGHT}[step])
		check(view.game.won, "Adventure UI reaches win %d" % index)
	view.start_level(14)
	view._process(46.0)
	check(view.game.stuck and view.controls.get_child_count() == 2, "Timer failure shows restart")
	await capture("timeout")
	view.select_tier("expert")
	check(view.controls.get_child_count() == 14, "Expert tier accessible without unlock")
	await capture("expert-picker")
	view.start_level(15)
	check(view.game.require_all and view.par == view.game.floor_count - 1, "Expert rules and move target")
	await capture("expert")
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/expert_solutions.json"))
	for point in fixtures[0].route.slice(1):
		view.attempt(Vector2i(int(point[0]), int(point[1])) - view.game.player)
	check(view.game.won and view.game.tiles_left() == 0, "Expert UI reaches full coverage win")
	await capture("expert-win")
	view.start_level(24)
	await capture("final-expert")
	for point in fixtures[9].route.slice(1):
		view.attempt(Vector2i(int(point[0]), int(point[1])) - view.game.player)
	check(view.game.won and view.controls.get_child(0).text == "Back to main menu", "Last expert does not advance out of bounds")
	view.controls.get_child(0).pressed.emit()
	check(view.page == "menu", "Last expert returns to main menu")
	view.start_level(0)
	check(not view.game.require_all and view.selected_tier == "classic", "Classic rules restored after expert")
	print("UI tests: %d failures." % failures)
	quit(1 if failures else 0)
