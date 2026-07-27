"""Reassigning an existing module-level glob inside a with entry block.

`config` is already declared as a module-level `glob`, so `config = 2` inside
the with entry block is a reassignment, not a declaration. It must stay a
reassignment instead of being merged into a second `glob config` declaration.
`fresh` is bound exactly once and is still extracted to a glob.
"""

glob config = 1;

with entry {
    config = 2;
    fresh = 10;
}
