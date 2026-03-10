"""Gap #49: TYPE_CHECKING-guarded imports not resolved in type annotations.

Types imported under `if TYPE_CHECKING` guard should be resolvable when
used in function signatures and variable annotations. The checker should
treat these imports as available for type analysis even though they don't
execute at runtime.

Currently, string annotations like 'Path' (where Path is imported under
TYPE_CHECKING) may resolve to Literal["Path"] or Unknown instead of the
actual pathlib.Path class, causing false "has no attribute" errors on
valid attribute access.

Expected errors:
  1. bad1: int = get_name(p)  — str not assignable to int
  2. bad2: int = p.stem       — str not assignable to int

No errors expected for:
  - p.name resolves to str (Path attribute)
  - get_name(p) resolves to str (return type properly inferred)
  - accept_path(p) resolves to str
"""

import from typing { TYPE_CHECKING }

with entry {
    if TYPE_CHECKING {
        import from pathlib { Path }
    }
}

def make_path(s: str) -> 'Path' {
    import from pathlib { Path as _P }
    return _P(s);
}

def get_name(p: 'Path') -> str {
    return p.name;
}

def accept_path(p: 'Path') -> str {
    return str(p);
}

with entry {
    p = make_path("/tmp/test.txt");

    # Forward ref 'Path' should resolve to pathlib.Path
    good1: str = p.name;               # Ok: Path.name is str
    good2: str = get_name(p);          # Ok: returns str
    good3: str = accept_path(p);       # Ok: returns str

    # True errors (type mismatches)
    bad1: int = get_name(p);           # Error: str not assignable to int
    bad2: int = p.stem;                # Error: str not assignable to int
}
