"""Control: a genuinely wrong initializer must still be surfaced.

Narrowing an `Any` initializer out of `None` is a convenience for imprecise
values, not a blanket suppression: assigning an incompatible *concrete* type to
the slot is a real error and must still be reported at the assignment site.
"""

obj Foo {}

obj Bar {}

glob _inst: (Foo | None) = None;

def get_foo -> Foo {
    global _inst;
    if _inst is None {
        _inst = Bar();
    }
    return _inst;
}
