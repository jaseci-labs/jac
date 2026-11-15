"""Bug #CYCLE-IMPORT-2: imports the llvm `ir` package after its compile has
settled; `ir.Module` must resolve to the class, not to a cached stub."""

import jaclang.compiler.backends.native.llvm.ir as ir;

def second_layout(m: ir.Module) -> str {
    return m.data_layout;
}
