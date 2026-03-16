"""Module A for third-module-struct fix test (FIX 3b).

Defines DataA and a constructor.  fix_third_b.na.jac imports DataA as a
parameter type; fix_third_entry.na.jac imports both modules.  Before the
fix, the compiler emitted i64 instead of %"DataA"* for the argument at
the cross-module call site.
"""

obj:pub DataA {
    has value: int;
    has tag: int;
}

def:pub make_data_a(v: int, t: int) -> DataA {
    return DataA(value=v, tag=t);
}
