"""Fixture: a keyword-argument key spelled like an ambient runtime builtin.

`store` is in `jaclang.runtime.builtin.__all__`, so a name that reaches
the reference lowering pulls a module-level import in behind it. A keyword
key names a parameter of the callee and must pull nothing.
"""

obj Slot {
    has store: int = 0;
}


def keyed(n: int) -> int {
    return Slot(store=n).store;
}
