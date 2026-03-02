"""Fixture for testing comprehension type inference."""

glob pool: list[int] = [1, 2, 3],
     any_p = any(isinstance(p, int) for p in pool),
     doubled = [x * 2 for x in pool],
     unique = {y for y in pool},
     mapping = {z: z * 2 for z in pool};
