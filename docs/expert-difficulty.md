# Expert difficulty audit

Every listed board has exactly one Hamiltonian path from its start to its flag: a route covering every traversable tile once. `tools/build_expert.py` exhaustively verifies the wall layout with all non-wall tiles treated as ordinary floor. Keys and doors only restrict paths; `tests/test_game.gd` replays the sole witness through the real game rules to verify it remains legal with those restrictions.

The random policy chooses uniformly among legal adjacent tiles, respecting locked doors and the flag-last rule, without looking ahead. Since each board has one winning route, its exact success probability is the reciprocal of the product of legal-choice counts along that route. Seeded simulations provide a second descriptive check, not the uniqueness proof.

**These probabilities are not human solve rates.** A careful player can reason about chokepoints, degrees, and key order; no claim is made that a normal person cannot solve these. The tier is ordered by the random-choice denominator, not a measured human difficulty score.

| Level | Name | Moves | Unique solutions | Random success probability | Wins / 20,000 seeded trials |
| --- | --- | ---: | ---: | ---: | ---: |
| 16 | Loose Ends | 57 | 1 | 1 in 3,072 | 5 |
| 17 | False Hope | 48 | 1 | 1 in 9,216 | 3 |
| 18 | The Divide | 42 | 1 | 1 in 9,216 | 2 |
| 19 | Keyhole | 46 | 1 | 1 in 16,384 | 1 |
| 20 | Crossed Wires | 48 | 1 | 1 in 16,384 | 1 |
| 21 | Afterimage | 54 | 1 | 1 in 16,384 | 2 |
| 22 | Last Exit | 54 | 1 | 1 in 18,432 | 0 |
| 23 | No Mercy | 49 | 1 | 1 in 73,728 | 0 |
| 24 | Blackout | 57 | 1 | 1 in 393,216 | 0 |
| 25 | Singularity | 64 | 1 | 1 in 1,179,648 | 0 |

## Reproduce

Run `python3 tools/test_audit.py` to compare the pruned solver with a simple independent brute-force solver on 400 small seeded boards. Then run `python3 tools/build_expert.py` for exhaustive uniqueness, witness, and random-policy verification on the shipped expert boards. A capped search never counts as a uniqueness proof.

The board pool was authored with `python3 tools/build_expert.py --generate 800` (seed 260920). Candidates were created by randomizing a spanning path and removing short detours while preserving a witness. Ten boards were selected from the unique candidates using search effort and branching; keys and doors were placed in a valid order along their witness. The final boards and witnesses are checked in, so verification does not depend on regenerating that pool. Trial seed: 90210, reset for each board.

The game does not run this solver, display solutions, or expose probability calculations during play.
