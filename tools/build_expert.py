"""Deterministic offline puzzle authoring and exhaustive Hamiltonian-path audit.

No runtime dependency. A capped search is never reported as a uniqueness proof.
"""
import argparse
import json
import random
from pathlib import Path

STEPS = ((0, -1), (1, 0), (0, 1), (-1, 0))
ROOT = Path(__file__).resolve().parents[1]


def graph(rows):
    cells = [(x, y) for y, row in enumerate(rows) for x, ch in enumerate(row) if ch != '#']
    ids = {cell: i for i, cell in enumerate(cells)}
    neighbors = [[ids[(x + dx, y + dy)] for dx, dy in STEPS if (x + dx, y + dy) in ids] for x, y in cells]
    start = next(i for i, (x, y) in enumerate(cells) if rows[y][x] == 'S')
    goal = next(i for i, (x, y) in enumerate(cells) if rows[y][x] == 'F')
    return cells, neighbors, start, goal


def audit(rows, limit=200_000):
    cells, neighbors, start, goal = graph(rows)
    masks = [sum(1 << v for v in ns) for ns in neighbors]
    full = (1 << len(cells)) - 1
    solutions = []
    nodes = 0
    complete = True

    def dfs(current, remaining, path):
        nonlocal nodes, complete
        nodes += 1
        if nodes > limit:
            complete = False
            return
        if current == goal:
            if not remaining:
                solutions.append(path[:])
            return
        if len(solutions) >= 2:
            return
        # In a path, every remaining non-goal vertex needs two incident edges.
        available = remaining | (1 << current)
        pending = remaining
        forced = []
        while pending:
            bit = pending & -pending
            pending -= bit
            vertex = bit.bit_length() - 1
            edges = masks[vertex] & available
            degree = edges.bit_count()
            if degree < (1 if vertex == goal else 2):
                return
            if vertex != goal and degree == 2 and edges & (1 << current):
                forced.append(vertex)
        if len(forced) > 1:
            return
        # Remaining vertices must stay connected after leaving current.
        reached = remaining & -remaining
        front = reached
        while front:
            bit = front & -front
            front -= bit
            extra = masks[bit.bit_length() - 1] & remaining & ~reached
            reached |= extra
            front |= extra
        if reached != remaining:
            return
        options = forced or [v for v in neighbors[current] if remaining & (1 << v)]
        options.sort(key=lambda v: (masks[v] & remaining).bit_count())
        for nxt in options:
            if nxt == goal and remaining != (1 << goal):
                continue
            dfs(nxt, remaining ^ (1 << nxt), path + [nxt])
            if not complete or len(solutions) >= 2:
                return

    dfs(start, full ^ (1 << start), [start])
    return {'solutions': len(solutions), 'exhaustive': complete and len(solutions) < 2,
            'search_nodes': nodes, 'route': [list(cells[i]) for i in solutions[0]] if solutions else []}


def make_candidate(rng, size, length):
    # A backbite move randomizes a known spanning snake while preserving adjacency.
    path = [(x if y % 2 == 0 else size - 1 - x, y) for y in range(size) for x in range(size)]
    for _ in range(size * size * 30):
        if rng.randrange(2):
            path.reverse()
        x, y = path[-1]
        options = [(x + dx, y + dy) for dx, dy in STEPS if 0 <= x + dx < size and 0 <= y + dy < size and (x + dx, y + dy) != path[-2]]
        if options:
            index = path.index(rng.choice(options))
            path = path[:index + 1] + path[index + 1:][::-1]
    while len(path) > length + 1:
        ears = [i for i in range(len(path) - 3) if abs(path[i][0] - path[i + 3][0]) + abs(path[i][1] - path[i + 3][1]) == 1]
        if not ears:
            break
        i = rng.choice(ears)
        del path[i + 1:i + 3]
    if len(path) > length:
        offset = rng.randrange(len(path) - length + 1)
        path = path[offset:offset + length]
    occupied = set(path)
    rows = [''.join('S' if (x, y) == path[0] else 'F' if (x, y) == path[-1] else '.' if (x, y) in occupied else '#' for x in range(size)) for y in range(size)]
    return rows


def random_trials(rows, trials=20_000, seed=90210):
    cells, neighbors, start, goal = graph(rows)
    rng = random.Random(seed)
    wins = 0
    for _ in range(trials):
        current = start
        visited = {start}
        keys = 0
        while current != goal:
            choices = [v for v in neighbors[current] if v not in visited and (v != goal or len(visited) == len(neighbors) - 1) and (rows[cells[v][1]][cells[v][0]] != 'D' or keys > 0)]
            if not choices:
                break
            current = rng.choice(choices)
            visited.add(current)
            tile = rows[cells[current][1]][cells[current][0]]
            keys += (tile == 'K') - (tile == 'D')
        wins += current == goal and len(visited) == len(neighbors)
    return wins


def choice_denominator(rows, route):
    """Exact 1/N success probability for uniform legal choices on a unique route.

    This is an unaided random-walk baseline, NOT a measure of human ability.
    """
    cells, neighbors, start, goal = graph(rows)
    ids = {cell: i for i, cell in enumerate(cells)}
    visited = {start}
    keys = 0
    denominator = 1
    for here, there in zip(route, route[1:]):
        current = ids[tuple(here)]
        choices = [v for v in neighbors[current] if v not in visited and (v != goal or len(visited) == len(neighbors) - 1) and (rows[cells[v][1]][cells[v][0]] != 'D' or keys > 0)]
        target = ids[tuple(there)]
        assert target in choices
        denominator *= len(choices)
        visited.add(target)
        tile = rows[there[1]][there[0]]
        keys += (tile == 'K') - (tile == 'D')
    return denominator


def generate(attempts):
    rng = random.Random(260920)
    candidates = []
    for attempt in range(attempts):
        size = rng.choice([8, 9, 10])
        length = rng.randint(int(size * size * .52), int(size * size * .72))
        rows = make_candidate(rng, size, length)
        result = audit(rows)
        if result['exhaustive'] and result['solutions'] == 1:
            cells, neighbors, _, _ = graph(rows)
            ids = {tuple(c): i for i, c in enumerate(cells)}
            visited = set()
            branches = 0
            for xy in result['route'][:-1]:
                current = ids[tuple(xy)]
                visited.add(current)
                branches += sum(v not in visited for v in neighbors[current]) > 1
            result.update(map=rows, tiles=length, branches=branches, seed_attempt=attempt)
            candidates.append(result)
            print(f"candidate {attempt}: {size}x{size}, {length} tiles, {branches} choices, {result['search_nodes']} nodes", flush=True)
        if attempt % 50 == 0:
            (ROOT / 'tests/fixtures/expert_candidates.json').write_text(json.dumps(candidates, indent=2) + '\n')
    (ROOT / 'tests/fixtures/expert_candidates.json').write_text(json.dumps(candidates, indent=2) + '\n')
    print(f'{len(candidates)} unique puzzles from {attempts} candidates', flush=True)


def verify():
    fixtures = json.loads((ROOT / 'tests/fixtures/expert_solutions.json').read_text())
    for level in fixtures:
        result = audit(level['map'])
        assert result['exhaustive'] and result['solutions'] == 1, level['name']
        assert result['route'] == level['route'], level['name']
        wins = random_trials(level['map'])
        assert wins == level['random_wins'], level['name']
        denominator = choice_denominator(level['map'], result['route'])
        assert denominator == level['random_denominator']
        print(f"{level['name']}: unique solution, {len(result['route']) - 1} moves, 1/{denominator:,} random success probability, {wins}/20000 random wins", flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--generate', type=int, metavar='CANDIDATES')
    args = parser.parse_args()
    if args.generate:
        generate(args.generate)
    else:
        verify()
