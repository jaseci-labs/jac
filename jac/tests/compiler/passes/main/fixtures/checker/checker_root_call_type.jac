# Test that bare `root` resolves to the Root type (not Unknown).
# `root` is a SpecialVarRef the type checker resolves directly to Root.

with entry {
    r = root;
    x: Root = root;
}
