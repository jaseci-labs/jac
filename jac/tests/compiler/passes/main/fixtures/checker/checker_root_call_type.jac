# Test that bare `root` and compatibility `root()` resolve to Root (not Unknown).
# `root` is a SpecialVarRef; `root()` remains accepted with a deprecation warning.

with entry {
    r = root;
    x: Root = root;
    old_r = root();
    old_x: Root = root();
}
