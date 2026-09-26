#!/usr/bin/env python3
"""Generates the 150 Neon Flow levels (50 easy, 50 medium, 50 hard).

Method: build a random Hamiltonian path over an NxN grid (backbite algorithm),
then cut it into K consecutive segments. Every segment becomes one colour whose
two ends are the dots. Because the segments tile the grid, every level is
solvable by construction and the full solution is stored for the hint system.

Every level is re-validated with an independent checker before it is written.

Usage: python3 tools/generate_levels.py
"""
import json
import os
import random

# (difficulty, first_level, last_level, grid_size, min_colors, max_colors)
PLAN = [
    ("easy", 1, 20, 5, 4, 5),
    ("easy", 21, 50, 6, 5, 6),
    ("medium", 51, 80, 7, 6, 7),
    ("medium", 81, 100, 8, 7, 8),
    ("hard", 101, 115, 8, 8, 9),
    ("hard", 116, 150, 9, 9, 11),
]
MIN_SEG = 3
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "levels", "levels.json")


def neighbours(cell, n):
    r, c = cell
    for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        rr, cc = r + dr, c + dc
        if 0 <= rr < n and 0 <= cc < n:
            yield (rr, cc)


def snake(n):
    path = []
    for r in range(n):
        cols = range(n) if r % 2 == 0 else range(n - 1, -1, -1)
        for c in cols:
            path.append((r, c))
    return path


def random_hamiltonian(n, rng, iters=4000):
    path = snake(n)
    for _ in range(iters):
        if rng.random() < 0.5:
            path.reverse()
        head = path[-1]
        prev = path[-2]
        options = [q for q in neighbours(head, n) if q != prev]
        q = rng.choice(options)
        j = path.index(q)
        path = path[: j + 1] + path[j + 1:][::-1]
    return path


def split(path, k, rng):
    total = len(path)
    lengths = [MIN_SEG] * k
    weights = [rng.random() ** 2 + 0.15 for _ in range(k)]
    for _ in range(total - MIN_SEG * k):
        idx = rng.choices(range(k), weights)[0]
        lengths[idx] += 1
    segs, pos = [], 0
    for ln in lengths:
        segs.append(path[pos: pos + ln])
        pos += ln
    return segs


def adjacent(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) == 1


def is_straight(seg):
    return len({p[0] for p in seg}) == 1 or len({p[1] for p in seg}) == 1


def validate(size, segs):
    """Independent validation: paths are contiguous, disjoint, fill the grid."""
    seen = set()
    for seg in segs:
        if len(seg) < 2:
            return False
        for a, b in zip(seg, seg[1:]):
            if not adjacent(a, b):
                return False
        for cell in seg:
            if cell in seen:
                return False
            if not (0 <= cell[0] < size and 0 <= cell[1] < size):
                return False
            seen.add(cell)
        if adjacent(seg[0], seg[-1]):
            return False  # trivial pair
    return len(seen) == size * size


def make_level(number, diff, size, kmin, kmax):
    rng = random.Random(number * 7919 + 13)
    max_straight = 2 if diff == "easy" else 1 if diff == "medium" else 0
    while True:
        k = rng.randint(kmin, kmax)
        path = random_hamiltonian(size, rng)
        segs = split(path, k, rng)
        if not validate(size, segs):
            continue
        if sum(1 for s in segs if is_straight(s)) > max_straight:
            continue
        rng.shuffle(segs)
        return {
            "id": number,
            "difficulty": diff,
            "size": size,
            "pairs": [
                {"color": i, "solution": [list(p) for p in seg]}
                for i, seg in enumerate(segs)
            ],
        }


def main():
    levels = []
    for diff, first, last, size, kmin, kmax in PLAN:
        for n in range(first, last + 1):
            lvl = make_level(n, diff, size, kmin, kmax)
            segs = [[tuple(p) for p in pr["solution"]] for pr in lvl["pairs"]]
            assert validate(size, segs), n
            levels.append(lvl)
    assert len(levels) == 150
    with open(OUT, "w") as f:
        json.dump({"version": 1, "levels": levels}, f, separators=(",", ":"))
    by = {}
    for l in levels:
        by[l["difficulty"]] = by.get(l["difficulty"], 0) + 1
    print("Wrote", len(levels), "levels:", by, "->", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
