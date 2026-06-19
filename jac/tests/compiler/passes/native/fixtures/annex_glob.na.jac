"""Regression fixture for issue #6754: a `glob` declared in an impl annex
(`impl/annex_glob.impl.jac` -- the canonical bare annex of this `.na.jac` head),
not this head file, must be registered in the native module's global symbol
table and resolved by references in the annexed ability bodies.

Before the fix, native global collection (and `iter_context_stmts` in general)
swept only the head module's `body`, so the annex-declared glob was never
emitted; references to it bailed with `error[E5090]: Native pathway does not
yet support expression 'Name'` (bare reference) / `'BinaryExpr'` (in arithmetic),
blaming the reference expression instead of the unresolved global. The
byte-identical program with the glob in this head file always compiled.
"""

def get_sz() -> int;
def double_sz() -> int;
