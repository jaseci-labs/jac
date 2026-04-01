"""Production test: Filter comprehensions must infer element type from type filter.

Two syntax forms:
  [root-->][?:Todo]   — two brackets, FilterCompr as AtomTrailer sibling
  [-->[?:Todo]]       — single bracket, FilterCompr inside EdgeRefTrailer.chain

Both must infer as list[Todo], not list[Any] or Unknown.

Expected errors: 2
  1. bad1: str = todos           — list[Todo] not assignable to str
  2. bad2: dict = todos          — list[Todo] not assignable to dict
"""

node Todo {
    has title: str,
        done: bool = False;
}

node Other {
    has value: int;
}

# Two-bracket form: AtomTrailer(EdgeRefTrailer, FilterCompr)
def get_todos -> list[Todo] {
    return [root-->][?:Todo];            # Must infer as list[Todo], no error
}

def get_others -> list[Other] {
    return [root-->][?:Other];           # Must infer as list[Other], no error
}

# Single-bracket form: EdgeRefTrailer with FilterCompr in chain
walker TodoGetter {
    has result: list[Todo] = [];

    can collect with entry {
        result = [-->[?:Todo]];          # Must infer as list[Todo], no error
    }
}

walker OtherGetter {
    has result: list[Other] = [];

    can collect with entry {
        result = [-->[?:Other]];         # Must infer as list[Other], no error
    }
}

with entry {
    todos = [root-->][?:Todo];
    ok1: list[Todo] = todos;             # Ok — exact match
    ok2: list = todos;                   # Ok — broad list
    bad1: str = todos;                   # Error: list[Todo] -> str
    bad2: dict = todos;                  # Error: list[Todo] -> dict
}
