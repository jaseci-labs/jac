"""Reassigning a module global via `global x;` from an impl-file body.

The global keeps its declared type across the decl/impl boundary, so the
arithmetic below resolves int operators rather than tripping `__mul__` /
`__add__` / `__mod__` overload-resolution errors on a shadow `Unknown`.
"""

glob _rand_state: int = 12345;

def random_int(max_val: int) -> int;
