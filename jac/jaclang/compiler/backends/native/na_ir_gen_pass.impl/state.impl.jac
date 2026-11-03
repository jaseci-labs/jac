impl NaIRGenPass.emit(
    diag: DiagnosticInfo,
    node_override: (uni.UniNode | None) = None,
    related: (list[tuple[str, uni.UniNode]] | None) = None,
    help_text: (str | None) = None,
    **kwargs: any
) -> bool {
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

impl NaIRGenPass._release_iter_end(
    spill: (ir.Value | None),
    slot_var: (str | None),
    owns_iter: bool,
    iter_val: ir.Value,
    loc: str
) -> None {
    if spill is not None {
        _it_end = self._mark_owned(self.builder.load(spill, name="iterf.it.end"));
        self._emit_rc_release_simple(_it_end, op="iter_end", loc=loc);
        self.builder.store(ir.Constant(_it_end.type, None), spill);
    } elif slot_var is not None {
        self._release_loop_coll_slot(slot_var, op="iter_end", loc=loc);
    } elif owns_iter {
        self._emit_rc_release_simple(iter_val, op="iter_end", loc=loc);
    }
}

impl NaIRGenPass._release_for_coll(
    spill: (ir.Value | None),
    slot_var: (str | None),
    release_op: str,
    collection_val: ir.Value,
    loc: str
) -> None {
    if spill is not None {
        _coll_end = self.builder.load(spill, name="for.coll.end");
        self._emit_rc_release_simple(_coll_end, op=release_op or "for_coll", loc=loc);
        self.builder.store(ir.Constant(_coll_end.type, None), spill);
    } elif slot_var is not None {
        self._release_loop_coll_slot(slot_var, op=release_op, loc=loc);
    } elif release_op
        and isinstance(collection_val.type, ir.PointerType)
        and self._is_owned(collection_val) {
        self._emit_rc_release_simple(collection_val, op=release_op, loc=loc);
    }
}
