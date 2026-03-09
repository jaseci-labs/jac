"""Production test: Set comprehensions must infer element types.

{x * 2 for x in nums} where nums: list[int] must infer as set[int].

Expected errors: 2
  1. bad1: str = s            — set[int] not assignable to str
  2. bad2: set[str] = s       — set[int] not assignable to set[str]
"""

with entry {
    nums: list[int] = [1, 2, 3, 4, 5];

    s = {x * 2 for x in nums};
    ok1: set[int] = s;                    # Ok
    bad1: str = s;                        # Error: set[int] -> str
    bad2: set[str] = s;                   # Error: set[int] -> set[str]
}
