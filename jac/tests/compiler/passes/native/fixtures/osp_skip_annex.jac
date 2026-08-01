"""Regression fixture for issue #6794: a `skip` inside a walker event ability
whose body lives in an IMPL ANNEX (`impl/osp_skip_annex.impl.jac`) must be
accepted by native. `skip` is a valid Return-family statement in a walker
`with X entry` event ability, and native lowers it there.

Before the fix, once `iter_context_stmts` began scanning annex bodies (#6754),
the native capability check reached this annex `skip`, saw that its nearest
enclosing node is an `ImplDef` (the `impl Collector.grab with Item entry {...}`)
rather than an inline `Ability`, and falsely flagged it as unsupported. That
dropped the module's LLVM IR (E5090), so a module importing it failed to link
(E5024) and `jac test` reported "native engine unavailable" for every test.
"""

node Item {
    has val: int;
}

walker Collector {
    has total: int = 0;

    can grab with Item entry;
}

def collect(a: int, b: int, c: int) -> int;
