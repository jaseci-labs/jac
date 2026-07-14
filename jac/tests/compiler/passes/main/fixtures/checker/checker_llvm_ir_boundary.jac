"""Regression guard for issue #7163.

The vendored llvm `ir` package re-exports its API via `include` (absorb), and
its submodules import back from the package (circular self-import). Consumers
(the native passes) reach the surface through the package namespace, e.g.
`ir.Value`. Before the fix that member access resolved to Unknown, poisoning
every native pass with ~1,700 downstream E1030/E1032 errors.

This must type-check clean: `ir.Value` resolves to the class and `.type`
resolves to its declared llvm Type.
"""

import from jaclang.compiler.passes.native.llvm { ir }

def value_type(v: ir.Value) -> None {
    print(v.type);
}
