import from jaclang.compiler.passes.native.llvm { ir }

impl NaIRGenPass._emit_trace_fn(arch_name: str) -> None {
    if arch_name in self.struct_trace_fns {
        return;
    }
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None {
        return;
    }
    field_types   = self.struct_field_types.get(arch_name, {});
    field_indices = self.struct_field_indices.get(arch_name, {});
    opaque_fields = self.struct_field_opaque.get(arch_name, set());

    # Collect pointer fields that need tracing.
    ptr_fields = [];
    for (fname, ftype) in field_types.items() {
        if fname not in opaque_fields and isinstance(ftype, ir.PointerType) {
            idx = field_indices.get(fname, -1);
            if idx >= 0 {
                ptr_fields.append((fname, idx));
            }
        }
    }
    if not ptr_fields {
        return;  # No pointer fields; trace fn not needed (stays NULL in header).
    }

    i8_ptr        = ir.IntType(8).as_pointer();
    i32           = ir.IntType(32);
    struct_ptype  = struct_type.as_pointer();

    # visitor fn type: void(i8*)
    visitor_fnty  = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    visitor_ptype = visitor_fnty.as_pointer();

    # trace fn type: void(i8* obj, i8* visitor_fn)
    trace_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr, i8_ptr]);
    trace_fn   = ir.Function(
        self.llvm_module, trace_fnty, name=f"__rc_trace_{arch_name}"
    );
    trace_fn.linkage = "private";
    trace_fn.args[0].name = "obj";
    trace_fn.args[1].name = "vis";
    self.struct_trace_fns[arch_name] = trace_fn;

    entry_bb = trace_fn.append_basic_block("entry");
    done_bb  = trace_fn.append_basic_block("done");

    b = ir.IRBuilder(entry_bb);
    # Cast visitor fn pointer back to typed fn ptr.
    _vis = b.bitcast(trace_fn.args[1], visitor_ptype, name="vis.fn");
    # Cast obj to typed struct pointer.
    _obj = b.bitcast(trace_fn.args[0], struct_ptype, name="obj.typed");

    for (fname, fidx) in ptr_fields {
        _fptr = b.gep(
            _obj,
            [ir.Constant(i32, 0), ir.Constant(i32, fidx)],
            name=f"fptr.{fname}"
        );
        _fval = b.load(_fptr, name=f"fval.{fname}");
        _fi8  = b.bitcast(_fval, i8_ptr, name=f"fi8.{fname}");
        b.call(_vis, [_fi8]);
    }
    b.branch(done_bb);

    b = ir.IRBuilder(done_bb);
    b.ret_void();
}

impl NaIRGenPass._emit_set_trace_fn(
    b: ir.IRBuilder, obj_i8: ir.Value, trace_fn: ir.Function
) -> None {
    i64     = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    _tslot  = b.gep(obj_i8, [ir.Constant(i64, HDR_TRACE_OFF)], name="trace.slot");
    _tptr   = b.bitcast(_tslot, i64_ptr, name="trace.ptr");
    _ti64   = b.ptrtoint(trace_fn, i64, name="trace.i64");
    b.store(_ti64, _tptr);
}
