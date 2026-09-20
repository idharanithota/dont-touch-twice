extends RefCounted

var rows: Array = []
var player := Vector2i.ZERO
var goal := Vector2i.ZERO
var visited: Dictionary = {}
var path: Array[Vector2i] = []
var moves := 0
var won := false
var stuck := false
var require_all := false
var floor_count := 0
var keys := 0
var crystals_left := 0
var portals: Dictionary = {}
var time_limit := 0.0
var time_left := 0.0
var failure_reason := ""

# K: key, D: door, G: crystal, I: ice, 1/2: paired teleporters.
func setup(map: Array, clear_every_tile: bool = false, seconds: float = 0.0) -> void:
	rows = map.duplicate()
	require_all = clear_every_tile
	floor_count = 0
	keys = 0
	crystals_left = 0
	portals.clear()
	visited.clear()
	path.clear()
	moves = 0
	won = false
	stuck = false
	failure_reason = ""
	time_limit = seconds
	time_left = seconds
	for y in rows.size():
		for x in rows[y].length():
			var cell := Vector2i(x, y)
			var tile: String = rows[y][x]
			if tile != "#": floor_count += 1
			if tile == "S": player = cell
			if tile == "F": goal = cell
			if tile == "G": crystals_left += 1
			if tile in ["1", "2"]:
				if not portals.has(tile): portals[tile] = []
				portals[tile].append(cell)
	visited[player] = true
	path.append(player)

func is_floor(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < rows.size() and cell.x >= 0 and cell.x < rows[cell.y].length() and rows[cell.y][cell.x] != "#"

func tile_at(cell: Vector2i) -> String:
	return rows[cell.y][cell.x] if is_floor(cell) else "#"

func portal_exit(cell: Vector2i) -> Vector2i:
	var pair: Array = portals.get(tile_at(cell), [])
	if pair.size() != 2: return cell
	return pair[1] if pair[0] == cell else pair[0]

func entry_error(cell: Vector2i) -> String:
	if not is_floor(cell): return "wall"
	if visited.has(cell): return "visited"
	var tile := tile_at(cell)
	if tile == "D" and keys == 0: return "door_locked"
	if cell == goal and goal_locked(): return "goal_locked"
	if tile in ["1", "2"]:
		var destination := portal_exit(cell)
		if destination == cell or visited.has(destination): return "portal_blocked"
	return ""

func can_enter(cell: Vector2i) -> bool:
	return entry_error(cell).is_empty()

func tiles_left() -> int:
	return floor_count - visited.size()

func goal_locked() -> bool:
	return crystals_left > 0 or (require_all and tiles_left() > 1)

func enter(cell: Vector2i) -> void:
	player = cell
	visited[cell] = true
	path.append(cell)
	moves += 1
	match tile_at(cell):
		"K": keys += 1
		"D": keys -= 1
		"G": crystals_left -= 1

# One input can traverse several ice tiles or both ends of a portal.
# Moves count tiles entered; rejected input never mutates state.
func move(direction: Vector2i) -> String:
	if won or stuck: return "finished"
	if abs(direction.x) + abs(direction.y) != 1: return "invalid"
	var target := player + direction
	var error := entry_error(target)
	if not error.is_empty(): return error
	while true:
		enter(target)
		var tile := tile_at(player)
		if tile in ["1", "2"]: enter(portal_exit(player))
		if player == goal:
			won = true
			return "won"
		if tile != "I": break
		target = player + direction
		if not can_enter(target): break
	stuck = true
	for step in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if can_enter(player + step): stuck = false
	if stuck: failure_reason = "No legal move remains."
	return "stuck" if stuck else "moved"

func advance_time(delta: float) -> bool:
	if won or stuck or time_limit <= 0: return false
	time_left = maxf(0, time_left - maxf(delta, 0))
	if time_left <= 0:
		stuck = true
		failure_reason = "Time ran out."
		return true
	return false

func shortest_route() -> Array[Vector2i]:
	# Only a classic reach-the-flag BFS. Special and coverage routes are verified
	# offline and replayed through move() in tests, not solved on the UI thread.
	if require_all or not portals.is_empty() or crystals_left > 0: return []
	for row in rows:
		if "K" in row or "D" in row or "I" in row: return []
	var frontier: Array[Vector2i] = [player]
	var previous: Dictionary = {player: player}
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		if current == goal:
			var route: Array[Vector2i] = []
			while current != player:
				route.push_front(current)
				current = previous[current]
			return route
		for step in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = current + step
			if can_enter(next) and not previous.has(next):
				previous[next] = current
				frontier.append(next)
	return []
