# Test that root() call returns Root type (not Unknown).
# root() is an ambient builtin that returns a Root node.

with entry {
    r = root();
    x: Root = root();
}
