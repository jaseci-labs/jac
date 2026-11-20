"""Regression fixture for issue #6660: glob-init ordering across entry blocks.

Module-level `glob` initializers run inside `__jac_glob_init`, which `jac_entry`
calls once at the very start — before ANY `with entry` body. So a `glob`
physically placed *between* two entry blocks still initializes before both,
NOT in strict Python source order (where the first block, textually above the
glob, would run before the glob is even defined).

This fixture pins that documented native behavior. The first block appends to
`shared` even though the glob is declared *below* it: that append can only
succeed because `__jac_glob_init` already set `shared` to a real (empty) list
before the block ran — a null/uninitialized list would crash here. The second
block appends again, proving the same single glob persists across both blocks.

Expected stdout (source order): "A_RAN" then "B_RAN", exit code 0. If glob-init
ever moved to strict source order, the first block would touch an
uninitialized glob and this would crash instead.
"""

with entry {
    shared.append("a");
    print("A_RAN");
}

glob shared = [];

with entry {
    shared.append("b");
    print("B_RAN");
}
