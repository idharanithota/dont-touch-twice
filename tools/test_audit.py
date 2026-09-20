"""Cross-check the pruned uniqueness solver against simple exhaustive search."""
import random
import unittest
from build_expert import audit, graph


def brute_count(rows):
    cells, neighbors, start, goal = graph(rows)
    def visit(current, used):
        if current == goal:
            return int(len(used) == len(cells))
        total = 0
        for nxt in neighbors[current]:
            if nxt not in used:
                total += visit(nxt, used | {nxt})
                if total >= 2:
                    return 2
        return total
    return visit(start, {start})


class AuditTests(unittest.TestCase):
    def test_matches_independent_exhaustive_search(self):
        rng = random.Random(1441)
        for _ in range(400):
            cells = rng.sample(range(16), rng.randint(5, 14))
            board = [['#'] * 4 for _ in range(4)]
            for i in cells:
                board[i // 4][i % 4] = '.'
            board[cells[0] // 4][cells[0] % 4] = 'S'
            board[cells[-1] // 4][cells[-1] % 4] = 'F'
            rows = [''.join(row) for row in board]
            self.assertEqual(audit(rows)['solutions'], brute_count(rows), rows)

    def test_capped_search_never_claims_unique(self):
        result = audit(['S..', '...', '..F'], limit=1)
        self.assertFalse(result['exhaustive'])


if __name__ == '__main__':
    unittest.main()
