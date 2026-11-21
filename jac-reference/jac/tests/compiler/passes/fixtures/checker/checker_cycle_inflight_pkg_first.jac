"""Bug #CYCLE-IMPORT-2: imports the llvm `ir` package while the test holds it
mid-compile, so the evaluator answers this import with the guard's stub."""

import jaclang.compiler.backends.native.llvm.ir as ir;

def first_layout(m: ir.Module) -> str {
    return m.data_layout;
}
