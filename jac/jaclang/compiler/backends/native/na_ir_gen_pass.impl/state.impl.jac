import from jaclang.compiler.backends.native.llvm { ir }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.diagnostics { DiagnosticInfo }

impl NaIRGenPass.emit(
    diag: DiagnosticInfo,
    node_override: (uni.UniNode | None) = None,
    related: (list[tuple[str, uni.UniNode]] | None) = None,
    help_text: (str | None) = None,
    **kwargs: any
) -> bool {
    """A lowering diagnostic is a routing fact before it is a report: the
demotion of a function is decided by the errors its lowering recorded, so a
suppressed code must still be recorded here. The pass driver applies the
policy when it delivers the pass's alerts to the program, so a suppressed
diagnostic never reaches a user.""";
    saved = self.ctx.policy;
    self.ctx.policy = None;
    try {
        return self.ctx.emit(
            diag,
            node_override=node_override,
            related=related,
            help_text=help_text,
            **kwargs
        );
    } finally {
        self.ctx.policy = saved;
    }
}

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
) -> tuple[(ir.Block | None), ir.Block] {
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
