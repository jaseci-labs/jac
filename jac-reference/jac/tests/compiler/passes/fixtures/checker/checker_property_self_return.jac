"""Test property returning Self resolves to the owning class type."""

import from pathlib { Path }

with entry {
    # Property returning Self should resolve to the class instance type
    p = Path("a/b/c");
    parent: Path = p.parent;  # <-- OK
    chained: Path = p.parent.parent;  # <-- OK (chained Self resolution)
    name_val: str = p.parent.name;  # <-- OK (access str attr on resolved Path)
    wrong: int = p.parent;  # <-- Error (Path assigned to int)
    wrong_chained: int = p.parent.parent;  # <-- Error (Path assigned to int)
}
