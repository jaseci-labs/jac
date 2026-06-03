"""Fixture exercising the `llvmlite.ir` API surface the native pass relies on.

Type-checks cleanly only when the hand-written `llvmlite` stub resolves; with
llvmlite's unannotated source these all come through as `object` / missing
attributes (`Value.type`, `PointerType.pointee`, `Type.as_pointer()`, the
`IRBuilder` builders, and `dict[str, ir.Type]` lookups).
"""

import from llvmlite { ir }

def value_type(v: ir.Value) -> ir.Type {
    return v.type;
}

def pointer_pointee(p: ir.PointerType) -> ir.Type {
    return p.pointee;
}

def make_pointer(t: ir.Type) -> ir.PointerType {
    return t.as_pointer();
}

def build_phi(b: ir.IRBuilder, blk: ir.Block) -> ir.Value {
    i64 = ir.IntType(64);
    phi_node = b.phi(i64, name="p");
    phi_node.add_incoming(ir.Constant(i64, 0), blk);
    return phi_node;
}

obj TypeRegistry {
    # Mirrors the native pass's struct registries (the Cat C pattern).
    has types: dict[str, ir.Type] = {};

    def ptr_for(key: str) -> ir.Type {
        return self.types[key].as_pointer();
    }
}
