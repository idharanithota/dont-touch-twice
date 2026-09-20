# Don't Touch Twice

A strategic 2D puzzle game built with **Godot 4** and **GDScript** where every tile disappears after you step on it—including your starting tile. Plan your path carefully and reach the goal without revisiting a tile.

## Play

🎮 **Play in your browser:** https://idharanithota.github.io/dont-touch-twice/

Or run locally:

1. Download the standard edition of Godot 4 (tested with 4.5.1; no .NET required).
2. In Godot's project manager, select **Import** and choose `project.godot`.
3. Open the project and press **F5**.

Use **arrow keys / WASD**, click an adjacent tile, swipe on the board, or use the on-screen direction buttons. **R** restarts; **Escape** opens the level picker. Tab and Enter work on buttons. All three tiers are available immediately.

## 25 levels, three tiers

| Tier | Levels | Objective |
| --- | --- | --- |
| Classic | 01–10 | Reach the flag without revisiting a tile. |
| Adventure | 11–15 | Learn keys, doors, crystals, teleporters, and ice; combine them in a timed challenge. |
| Expert | 16–25 | Visit **every** non-wall tile exactly once and reach the flag **last**, while collecting keys and opening doors. |

The main menu has direct buttons for Adventure and Expert. The level picker has tabs for all three tiers. Existing Classic progress is preserved.

## Obstacles and special tiles

| Tile | Rule |
| --- | --- |
| Brick wall | Impassable. Does not count toward coverage. |
| Gold key | Collects one key. |
| Gold door | Requires and consumes one key. Each door tile is used once. |
| Cyan crystal | Every crystal must be collected before the flag unlocks. |
| Violet portal | Teleports to its matching partner. **Both** ends are consumed; teleporting back is impossible. |
| Blue ice | Continues your move in the same direction until you reach ordinary floor or the next tile is blocked. Every crossed tile is consumed. You can turn after the slide stops. |
| Locked flag | Cannot be entered while crystals remain, or before full coverage in Expert. |
| Timer | Level 15 gives you 45 seconds from level start. Reaching zero ends the attempt; restarting resets it. |

There is no undo or in-game solution hint. Invalid input does not change the board or move count, though a running timer continues. The move counter counts **tiles entered**, including automatic ice movement and both portal ends. Best scores and sound preferences are stored locally in `user://progress.cfg`.

A dead-end screen appears when there is no legal adjacent move. The game does not reveal that a later move has become impossible; planning ahead is part of Expert. A won or failed attempt ignores movement until you restart or select another level.

## Expert difficulty

The ten Expert boards have **exactly one full-coverage solution each**, verified by exhaustive search. Each requires 42–64 tile entries on an 8×8, 9×9, or 10×10 board, with two keys, two doors, and a crystal. Full coverage makes reaching the flag by a short route insufficient.

These are designed to be difficult, not literally impossible. Random-choice benchmarks are documented in [the difficulty audit](docs/expert-difficulty.md); they do not measure human ability, and human difficulty has not been playtested.

## Learn the project

| File | Responsibility |
| --- | --- |
| `main.tscn` | Main 2D UI scene |
| `scripts/main.gd` | Tier navigation, tile drawings, animation, input, sound, timer display, and saved progress |
| `scripts/game_state.gd` | Collision, inventory, teleportation, sliding, coverage, timer, and win/dead-end rules |
| `scripts/levels.gd` | All maps and level settings |
| `tests/test_game.gd` | Replays all 25 solutions and checks mechanics and edge cases |
| `tests/test_ui.gd` | Input, tier selection, win/restart/timeout, and rendered screenshots |
| `tools/build_expert.py` | Offline generator and exhaustive uniqueness audit; Python standard library only |
| `tools/test_audit.py` | Compares the optimized audit to independent brute-force search |
| `tests/fixtures/expert_solutions.json` | Verified expert paths and audit data — **contains spoilers** |

Map symbols: `S` start, `F` flag, `.` floor, `#` wall, `K` key, `D` door, `G` crystal, `I` ice, `1`/`2` matching portal pairs. Keep rows equally wide, with exactly one start and flag, and exactly two instances of each portal identifier. `require_all` enables Expert coverage; `time_limit` is in seconds.

## Test

With Godot on your PATH, from this directory:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_game.gd
godot --headless --path . --script tests/test_ui.gd
python3 tools/test_audit.py
python3 tools/build_expert.py
```

## Browser Version

The game is exported to HTML5/WebAssembly and can be played directly in a web browser through GitHub Pages. No installation is required.

On macOS, substitute `/path/to/Godot.app/Contents/MacOS/Godot` for `godot`. Run the UI test without `--headless` on macOS to capture screenshots in `/private/tmp/dtt-*.png`.

No network requests, analytics, external assets, or runtime dependencies. Native mobile distribution still requires export templates, SDKs/signing, and real-device testing. This is an importable Godot project, not a signed mobile app.
