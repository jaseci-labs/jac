"""System V AMD64 ABI lowering for foreign (clib) structs — Phase 1.

This module gives the native backend a real platform-ABI classifier instead of
the previous all-integer ≤64-bit heuristic. A foreign struct passed/returned by
value is classified per the System V AMD64 psABI eightbyte algorithm into either
MEMORY (passed via a `byval` pointer / returned via `sret`) or a sequence of
register coerce types (INTEGER -> iN, SSE -> float/double/<2 x float>), matching
what clang/gcc emit. The result is a per-function ABI plan stored on
`self.clib_fn_abi`, consumed by `_codegen_clib_call` — so a foreign call's
marshalling is decided once from the declared types, never re-derived from the
shape of an LLVM value (which is what corrupted scalar returns sharing a type
with a struct, gap #7).

Scope: x86_64 System V only (the default Linux/Intel-macOS target). AArch64
AAPCS is Phase 2; off-x86_64 targets keep the legacy path in
`_declare_clib_ability`.
"""

"""The memoized foreign declaration model (Phase 8): clib struct shapes
collected centrally over this pass's module universe. The memo is keyed
on the universe size because the universe grows mid-transform: the entry
module's clib imports are processed (Phase 0) before
_register_imported_struct_types assembles _foreign_modules, so a model
built early for an entry-declared function must be rebuilt once the
transitively imported modules join the universe."""
impl NaIRGenPass._foreign_model -> dict {
    import from jaclang.compiler.targets.foreign { collect_foreign_structs }
    universe = [self.ir_in] + self._foreign_modules;
    if self._foreign_structs is None or self._foreign_model_nmods != len(universe) {
        self._foreign_structs = collect_foreign_structs(universe);
        self._foreign_model_nmods = len(universe);
    }
    return self._foreign_structs;
}

"""The memoized foreign function declarations (Phase 8): clib signature
names collected centrally over this pass's module universe, keyed on the
universe size for the same mid-transform growth reason as
_foreign_model."""
impl NaIRGenPass._foreign_fns -> dict {
    import from jaclang.compiler.targets.foreign { collect_foreign_fns }
    universe = [self.ir_in] + self._foreign_modules;
    if self._foreign_fn_decls is None or self._foreign_fns_nmods != len(universe) {
        self._foreign_fn_decls = collect_foreign_fns(universe);
        self._foreign_fns_nmods = len(universe);
    }
    return self._foreign_fn_decls;
}

"""Ordered (field_name, nested_struct_name | None) pairs for a clib
struct, from the foreign declaration model - the single answer to
'which fields are nested clib structs'. Position in this list IS the
field's GEP index in both the Jac struct and the C-laid-out struct:
the model's order and the backend's struct_field_indices both derive
from the declaration's has-var order. The copiers address both
representations by this position, so the invariant is asserted here
(the shared chokepoint) rather than trusted silently."""
impl NaIRGenPass._foreign_fields_of(name: str) -> list {
    model = self._foreign_model();
    indices = self.struct_field_indices.get(name, {});
    out: list = [];
    for (i, (fn, tn)) in enumerate(model.get(name, [])) {
        assert fn not in indices or indices[fn] == i , f"foreign field order mismatch for {name}.{fn}";
        out.append((fn, tn if (tn is not None and tn in model) else None));
    }
    return out;
}

"""Compute the C in-memory layout of a clib struct.

Returns (size, align, scalars) where scalars is a flat list of
(byte_offset, is_sse, bits). Nested clib structs are inlined recursively so the
layout matches the C ABI rather than the Jac pointer-nested representation.
"""
impl NaIRGenPass._clib_struct_layout(name: str) -> tuple {
    # The C layout is the foreign declaration model's job (Phase 8); the
    # pass only supplies its module universe (entry + transitive native
    # imports, assembled in _register_imported_struct_types).
    import from jaclang.compiler.targets.foreign { foreign_struct_layout }
    return foreign_struct_layout(self._foreign_model(), name);
}

"""Classify a clib struct for the active target's C ABI.

Dispatches to the System V AMD64 or AArch64 AAPCS classifier based on the
module triple. Returns a dict with:
  - "memory": passed indirectly (byval pointer / caller copy / sret)
  - "coerce": list[ir.Type] register pieces when not memory
  - "byval": for memory args, whether the indirect pointer carries `byval`
    (System V: backend copies) vs a caller-made copy passed as a plain pointer
    (AAPCS)
  - "safe": for register structs, whether the coerce pieces must be loaded via
    an over-read-safe buffer (AAPCS coerces a partial struct up to a full
    register) vs loaded in place (System V sizes each eightbyte exactly)
  - "size", "align"
"""
impl NaIRGenPass._classify_clib_struct(name: str) -> dict {
    # Classification is the pure target-ABI library's job (Phase 8); the
    # pass only flattens its struct state into the layout description.
    import from jaclang.compiler.targets.abi { classify_struct }
    (size, align, scalars) = self._clib_struct_layout(name);
    return classify_struct(size, align, scalars, str(self.llvm_module.triple or ""));
}

"""True if a clib struct has a field whose type is itself a clib struct."""
impl NaIRGenPass._clib_has_nested(name: str) -> bool {
    for (_fn, nested) in self._foreign_fields_of(name) {
        if nested is not None {
            return True;
        }
    }
    return False;
}

"""Return the C-laid-out LLVM type for a clib struct.

For flat structs the Jac representation already matches C, so the existing
struct type is returned. For structs with nested clib-struct fields a parallel
`<name>.cabi` identified type is built with the nested structs inlined by value.
"""
impl NaIRGenPass._clib_c_type(name: str) -> ir.Type {
    if not self._clib_has_nested(name) {
        return self.struct_types[name];
    }
    key = name + ".cabi";
    if key in self.struct_types {
        return self.struct_types[key];
    }
    ct = self.llvm_module.context.get_identified_type(key);
    self.struct_types[key] = ct;
    ftypes = self.struct_field_types.get(name, {});
    body: list = [];
    for (fn, nested) in self._foreign_fields_of(name) {
        if nested is not None {
            body.append(self._clib_c_type(nested));
        } else {
            body.append(ftypes.get(fn, ir.IntType(64)));
        }
    }
    ct.set_body(*body);
    return ct;
}

"""Allocate an RC-managed box for a clib struct (Jac representation)."""
impl NaIRGenPass._clib_alloc_box(name: str) -> ir.Value {
    import os;
    stype = self.struct_types[name];
    sptype = stype.as_pointer();
    null_ptr = ir.Constant(sptype, None);
    size_gep = self.builder.gep(
        null_ptr, [ir.Constant(ir.IntType(32), 1)], name="clib.box.sizeof.gep"
    );
    size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="clib.box.sizeof");
    raw_ptr = self._rc_call_with_ctx(
        self.rc_alloc_fn, [size], op="box", name="clib.box.raw"
    );
    typed_ptr = self.builder.bitcast(raw_ptr, sptype, name="clib.box.ptr");
    # Install the typed destructor at obj-8 so RC release dispatches correctly.
    self._emit_struct_release_fn(name);
    dtor_fn = self.struct_release_fns.get(name);
    if dtor_fn is not None {
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        i64p = i64.as_pointer();
        raw_i8 = self.builder.bitcast(typed_ptr, i8p, name="clib.box.i8");
        dtor_slot = self.builder.gep(
            raw_i8, [ir.Constant(i64, -8)], name="clib.box.dtorslot"
        );
        dtor_slot_i64 = self.builder.bitcast(dtor_slot, i64p, name="clib.box.dtori64p");
        dtor_i64 = self.builder.ptrtoint(dtor_fn, i64, name="clib.box.dtori64");
        self.builder.store(dtor_i64, dtor_slot_i64);
    }
    if self.rc_set_type_fn is not None {
        tag_i8 = self.builder.bitcast(
            typed_ptr, ir.IntType(8).as_pointer(), name="clib.box.tag"
        );
        self._emit_set_type_tag(self.builder, tag_i8, name);
    }
    return typed_ptr;
}

"""Recursively copy a Jac clib-struct value into a C-laid-out buffer."""
impl NaIRGenPass._clib_copy_jac_to_c(
    jac_ptr: ir.Value, c_ptr: ir.Value, name: str
) -> None {
    for (ix, (fn, tn)) in enumerate(self._foreign_fields_of(name)) {
        jac_field = self.builder.gep(
            jac_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), ix)],
            name="clib.j2c.jf"
        );
        c_field = self.builder.gep(
            c_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), ix)],
            name="clib.j2c.cf"
        );
        if tn is not None {
            sub_jac = self.builder.load(jac_field, name="clib.j2c.subptr");
            self._clib_copy_jac_to_c(sub_jac, c_field, tn);
        } else {
            v = self.builder.load(jac_field, name="clib.j2c.v");
            self.builder.store(v, c_field);
        }
    }
}

"""Recursively copy a C-laid-out buffer into a fresh Jac clib-struct value."""
impl NaIRGenPass._clib_copy_c_to_jac(
    c_ptr: ir.Value, jac_ptr: ir.Value, name: str
) -> None {
    for (ix, (fn, tn)) in enumerate(self._foreign_fields_of(name)) {
        c_field = self.builder.gep(
            c_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), ix)],
            name="clib.c2j.cf"
        );
        jac_field = self.builder.gep(
            jac_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), ix)],
            name="clib.c2j.jf"
        );
        if tn is not None {
            sub_box = self._clib_alloc_box(tn);
            self._clib_copy_c_to_jac(c_field, sub_box, tn);
            self.builder.store(sub_box, jac_field);
            self._mark_owned(sub_box);
        } else {
            v = self.builder.load(c_field, name="clib.c2j.v");
            self.builder.store(v, jac_field);
        }
    }
}

"""Produce a pointer to a C-laid-out copy of a Jac clib-struct value."""
impl NaIRGenPass._clib_materialize_c_ptr(jac_ptr: ir.Value, name: str) -> ir.Value {
    if not self._clib_has_nested(name) {
        # Flat structs already have C layout; reuse the pointer directly.
        return jac_ptr;
    }
    ct = self._clib_c_type(name);
    cbuf = self._entry_alloca(ct, "clib.cabi.arg");
    self._clib_copy_jac_to_c(jac_ptr, cbuf, name);
    return cbuf;
}

"""Box a C-laid-out struct pointer into an RC-managed Jac struct pointer."""
impl NaIRGenPass._clib_box_c_ptr(c_ptr: ir.Value, name: str) -> ir.Value {
    box = self._clib_alloc_box(name);
    if not self._clib_has_nested(name) {
        # Flat: Jac and C layouts coincide; copy the whole value.
        val = self.builder.load(c_ptr, name="clib.ret.load");
        self.builder.store(val, box);
    } else {
        self._clib_copy_c_to_jac(c_ptr, box, name);
    }
    self._mark_owned(box);
    return box;
}

"""Marshal a foreign call from its stored System V ABI plan.

`args` are the source argument values (1:1 with the declared parameters, before
any register expansion). Struct arguments are materialized to C layout and then
either sliced into register pieces or passed via a byval pointer; a MEMORY
return is collected through an sret buffer. The result is reconstructed into the
Jac representation (struct pointer) or returned as the scalar it is.
"""
impl NaIRGenPass._codegen_clib_call(
    func: ir.Function, func_name: str, args: list[ir.Value]
) -> (ir.Value | None) {
    plan = self.clib_fn_abi[func_name];
    param_plans = plan["params"];
    ret_plan = plan["ret"];
    call_args: list = [];
    # Call-site argument attributes. byval/sret must be marked on BOTH the
    # declaration and the call instruction or LLVM passes the pointer in a
    # register instead of copying the aggregate per the ABI.
    arg_attrs: dict = {};
    sret_buf = None;
    if plan["sret"] {
        sret_ct = self._clib_c_type(ret_plan["sname"]);
        sret_buf = self._entry_alloca(sret_ct, "clib.sret.buf");
        sret_aa = ir.ArgumentAttributes();
        sret_aa.add("sret");
        sret_aa.type = sret_ct;
        _sret_al = ret_plan["align"];
        sret_aa.align = _sret_al if _sret_al > 8 else 8;
        arg_attrs[len(call_args)] = sret_aa;
        call_args.append(sret_buf);
    }
    for (i, pp) in enumerate(param_plans) {
        jac_val = args[i] if i < len(args) else None;
        kind = pp["kind"];
        if kind == "scalar" {
            if jac_val is None {
                call_args.append(ir.Constant(pp["type"], 0));
            } else {
                call_args.append(self._coerce_type(jac_val, pp["type"]));
            }
        } elif kind == "struct_mem" {
            c_ptr = self._clib_materialize_c_ptr(jac_val, pp["sname"]);
            if pp["byval"] {
                # System V: pass the pointer with `byval`; the backend copies.
                byval_aa = ir.ArgumentAttributes();
                byval_aa.add("byval");
                byval_aa.type = self._clib_c_type(pp["sname"]);
                _bv_al = pp["align"];
                byval_aa.align = _bv_al if _bv_al > 8 else 8;
                arg_attrs[len(call_args)] = byval_aa;
                call_args.append(c_ptr);
            } else {
                # AAPCS: pass a plain pointer to a caller-made copy.
                _ct = self._clib_c_type(pp["sname"]);
                _copy = self._entry_alloca(_ct, "clib.indir.copy");
                self.builder.store(
                    self.builder.load(c_ptr, name="clib.indir.load"), _copy
                );
                call_args.append(_copy);
            }
        } else {
            # struct_reg: slice the C-laid-out struct into its register pieces.
            c_ptr = self._clib_materialize_c_ptr(jac_val, pp["sname"]);
            coerce = pp["coerce"];
            ct = ir.LiteralStructType(coerce);
            if pp["safe"] {
                # AAPCS: a register coerce (i64 / [2 x i64] / [N x float]) can be
                # wider than the struct, so copy into a coerce-sized buffer first
                # to avoid reading past the struct's end.
                _buf = self._entry_alloca(ct, "clib.arg.buf");
                _sct = self._clib_c_type(pp["sname"]);
                self.builder.store(
                    self.builder.load(c_ptr, name="clib.arg.sload"),
                    self.builder.bitcast(_buf, _sct.as_pointer(), name="clib.arg.bcopy")
                );
                ct_ptr = _buf;
            } else {
                ct_ptr = self.builder.bitcast(
                    c_ptr, ct.as_pointer(), name="clib.arg.cast"
                );
            }
            for j in range(len(coerce)) {
                piece_ptr = self.builder.gep(
                    ct_ptr,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), j)],
                    name="clib.arg.piece"
                );
                call_args.append(self.builder.load(piece_ptr, name="clib.arg.load"));
            }
        }
    }
    result = self.builder.call(
        func, call_args, name=f"call.{func_name}", arg_attrs=arg_attrs
    );
    rkind = ret_plan["kind"];
    if rkind == "sret" {
        return self._clib_box_c_ptr(sret_buf, ret_plan["sname"]);
    }
    if rkind == "struct_reg" {
        sname = ret_plan["sname"];
        coerce = ret_plan["coerce"];
        # AAPCS coerces (i64 / [2 x i64] / [N x float]) can be wider than the
        # struct, so the receiving buffer is sized to the coerce, not the struct;
        # the box step then reads back only the struct's bytes. System V sizes
        # each eightbyte exactly, so its struct-sized buffer is in bounds.
        if ret_plan["safe"] {
            rbuf = self._entry_alloca(ir.LiteralStructType(coerce), "clib.ret.rbuf");
        } else {
            rbuf = self._entry_alloca(self._clib_c_type(sname), "clib.ret.cbuf");
        }
        if len(coerce) == 1 {
            slot = self.builder.bitcast(
                rbuf, coerce[0].as_pointer(), name="clib.ret.cast"
            );
            self.builder.store(result, slot);
        } else {
            ct = ir.LiteralStructType(coerce);
            ct_ptr = self.builder.bitcast(rbuf, ct.as_pointer(), name="clib.ret.cast");
            for j in range(len(coerce)) {
                piece = self.builder.extract_value(result, j, name="clib.ret.piece");
                piece_ptr = self.builder.gep(
                    ct_ptr,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), j)],
                    name="clib.ret.slot"
                );
                self.builder.store(piece, piece_ptr);
            }
        }
        c_view = self.builder.bitcast(
            rbuf, self._clib_c_type(sname).as_pointer(), name="clib.ret.cview"
        );
        return self._clib_box_c_ptr(c_view, sname);
    }
    # Scalar return: hand back exactly what C produced. No struct boxing — this
    # is what closes gap #7 (an int return is never mistaken for a struct).
    if isinstance(result.type, ir.PointerType) {
        self._mark_owned(result);
    }
    return result;
}
