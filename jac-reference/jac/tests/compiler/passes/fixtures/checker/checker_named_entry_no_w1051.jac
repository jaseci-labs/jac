# Regression: a *named* entry block (`with entry:<name>`) was emitting a
# spurious W1051 ("Expression type could not be resolved (Unknown)") on the
# entry-point label itself. Root cause: a ModuleCode's `name` field holds a
# Name node (e.g. `__main__`) that has no symbol and is not a variable
# reference -- it is just a label for the entry block. The type checker's
# exit_name handler type-evaluated it anyway, got UnknownType, and warned.
#
# Anonymous `with entry { ... }` never had this problem (no name node), so the
# bug fired on the idiomatic `with entry:__main__` main guard of essentially
# every runnable Jac program.

obj Widget {
    has size: int = 1;
}

# The `__main__` guard: must produce no W1051 on the label.
with entry:__main__ {
    w = Widget();
    w.size = 2;
}

# An arbitrary named entry: the label is also just a tag, no W1051.
with entry:setup {
    x = Widget();
    x.size = 3;
}

# Anonymous entry, for contrast: was always clean, must stay clean.
with entry {
    y = Widget();
    y.size = 4;
}
