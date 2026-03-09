"""Production test: Dict comprehensions must infer key/value types.

{k: v for k, v in items} must infer as dict[K, V] based on
the source types. Assigning to wrong types must error.

Expected errors: 3
  1. bad1: str = d             — dict not assignable to str
  2. bad2: list = d            — dict not assignable to list
  3. bad3: dict[int, int] = d2 — dict[str, int] not assignable to dict[int, int]
"""

with entry {
    names: list[str] = ["alice", "bob", "charlie"];

    # Dict from enumeration — should infer dict[int, str] or similar
    d = {i: name for (i, name) in enumerate(names)};
    ok1: dict = d;                          # Ok (broad dict)
    bad1: str = d;                          # Error: dict -> str
    bad2: list = d;                         # Error: dict -> list

    # Dict with explicit types
    words: list[str] = ["hello", "world"];
    d2 = {w: len(w) for w in words};
    ok2: dict[str, int] = d2;              # Ok
    bad3: dict[int, int] = d2;             # Error: dict[str,int] -> dict[int,int]
}
