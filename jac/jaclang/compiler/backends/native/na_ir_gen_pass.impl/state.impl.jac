import from jaclang.compiler.backends.native.llvm { ir }

impl NaIRGenPass.builder.getter -> ir.IRBuilder {
    if self._builder is None {
        raise RuntimeError(
            "NaIRGenPass.builder read with no active IRBuilder "
            "(outside a function body)"
        );
    }
    return self._builder;
}

impl NaIRGenPass.llvm_module.getter -> ir.Module {
    if self._llvm_module is None {
        raise RuntimeError("NaIRGenPass.llvm_module read before postinit built it");
    }
    return self._llvm_module;
}

impl NaIRGenPass.type_map.getter -> dict[str, ir.Type] {
    if self._type_map is None {
        raise RuntimeError("NaIRGenPass.type_map read before postinit built it");
    }
    return self._type_map;
}

impl NaIRGenPass.complex_struct_type.getter -> ir.IdentifiedStructType {
    if self._complex_struct_type is None {
        raise RuntimeError(
            "NaIRGenPass.complex_struct_type read before postinit built it"
        );
    }
    return self._complex_struct_type;
}

impl NaIRGenPass.range_struct_type.getter -> ir.IdentifiedStructType {
    if self._range_struct_type is None {
        raise RuntimeError(
            "NaIRGenPass.range_struct_type read before postinit built it"
        );
    }
    return self._range_struct_type;
}

impl NaIRGenPass.slice_struct_type.getter -> ir.IdentifiedStructType {
    if self._slice_struct_type is None {
        raise RuntimeError(
            "NaIRGenPass.slice_struct_type read before postinit built it"
        );
    }
    return self._slice_struct_type;
}

impl NaIRGenPass.jacval_type.getter -> ir.IdentifiedStructType {
    if self._jacval_type is None {
        raise RuntimeError("NaIRGenPass.jacval_type read before postinit built it");
    }
    return self._jacval_type;
}

impl NaIRGenPass._loop_exit_blocks(
    func: ir.Function,
    nd: (uni.WhileStmt | uni.InForStmt | uni.IterForStmt),
    prefix: str
) -> tuple {
    else_bb = (
        func.append_basic_block(name=f"{prefix}.else")
            if nd.else_body is not None
            else None
    );
    end_bb = func.append_basic_block(name=f"{prefix}.end");
    return (else_bb, end_bb);
}

impl NaIRGenPass._emit_loop_else(
    nd: (uni.WhileStmt | uni.InForStmt | uni.IterForStmt),
    else_bb: (ir.Block | None),
    end_bb: ir.Block
) -> None {
    if else_bb is not None {
        self.builder.position_at_end(else_bb);
        loop_else = nd.else_body;
        if loop_else is not None and isinstance(loop_else.body, (list, tuple)) {
            self._codegen_body(loop_else.body);
        }
        if not self.builder.block.is_terminated {
            self.builder.branch(end_bb);
        }
    }
    self.builder.position_at_end(end_bb);
}
