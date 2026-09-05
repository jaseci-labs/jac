impl NaIRGenVtable._build_vtable(arch_name: str) -> None {
    lay = self._arch_layout(arch_name);
    if lay is None or not lay.has_vtable {
        self.vtable_layouts[arch_name] = [];
        self.vtable_method_indices[arch_name] = {};
        return;
    }
    self.vtable_layouts[arch_name] = [m.name for m in lay.methods];
    self.vtable_method_indices[arch_name] = dict(lay.method_index);
}

impl NaIRGenVtable._emit_vtable_global(arch_name: str) -> None {
    layout = self.vtable_layouts.get(arch_name);

    if layout is None {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();

    vtable_type = ir.ArrayType(i8_ptr, len(layout) + VTABLE_HEADER_SLOTS);
    entries: list[ir.Constant] = [self._emit_class_name_const(arch_name)];
    for method_name in layout {
        func = self._resolve_method(arch_name, method_name);
        if func is not None {
            entries.append(func.bitcast(i8_ptr));
        } else {
            entries.append(ir.Constant(i8_ptr, None));
        }
    }
    vtable_init = ir.Constant(vtable_type, entries);

    vtable_global = self.vtable_globals.get(arch_name);
    if vtable_global is None {
        vtable_global = ir.GlobalVariable(
            self.llvm_module, vtable_type, name=self._vtable_symbol(arch_name)
        );
        self.vtable_globals[arch_name] = vtable_global;
    }
    vtable_global.global_constant = True;

    vtable_global.linkage = "";
    vtable_global.initializer = vtable_init;
    self._record_export(f"{arch_name}.__vtable", vtable_global.name, "vtable");
}

"""The vtable symbol of a class lives under its defining unit's prefix, so a
consumer's forward reference and the definer's definition name one object."""
impl NaIRGenVtable._vtable_symbol(arch_name: str) -> str {
    import from jaclang.compiler.frontend.codeinfo { native_symbol_name }
    src = self._struct_source_mod.get(arch_name, "");
    prefix = self._prefix_of_path(src) if src else self._own_prefix();
    return native_symbol_name(prefix, f"{arch_name}.__vtable");
}

impl NaIRGenVtable._vtable_global_for(arch_name: str) -> (ir.GlobalVariable | None) {
    existing = self.vtable_globals.get(arch_name);
    if existing is not None {
        return existing;
    }
    lay = self._arch_layout(arch_name);
    if lay is None or not lay.has_vtable or arch_name not in self.struct_types {
        return None;
    }

    i8_ptr = ir.IntType(8).as_pointer();
    vtable_type = ir.ArrayType(i8_ptr, len(lay.methods) + VTABLE_HEADER_SLOTS);
    vtable_ref = ir.GlobalVariable(
        self.llvm_module, vtable_type, name=self._vtable_symbol(arch_name)
    );
    vtable_ref.global_constant = True;
    vtable_ref.linkage = "external";
    self.vtable_globals[arch_name] = vtable_ref;
    return vtable_ref;
}

impl NaIRGenVtable._vtable_candidates(names: list[str]) -> list[ir.GlobalVariable] {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }

    reg = get_layout_registry(self.ir_in, self.prog);
    out: list[ir.GlobalVariable] = [];
    for cand in reg.mro_order {
        cand_mro = self._mro_of(cand);
        for name in names {
            if name in cand_mro {
                vt = self._vtable_global_for(cand);
                if vt is not None {
                    out.append(vt);
                }
                break;
            }
        }
    }
    return out;
}

impl NaIRGenVtable._isinstance_needs_class_name(names: list[str]) -> bool {
    """Is some class that answers `True` for these names missing a vtable?

    The vtable-pointer compare can only see classes whose layout carries a
    vtable slot, and a class earns that slot from facts its OWN module can see:
    it has a base, something there subclasses it, or something there names it in
    an `isinstance`. A flat archetype an importer is the first to test satisfies
    none of those, so it carries no slot -- and then the pointer compare has
    nothing to compare against (the site demotes) or, once a consumer-side
    subclass puts a vtable-carrying class in the candidate set, reads the
    instance's first field as if it were a vtable pointer and answers from
    garbage. Either way the answer has to come from the class-name identity
    every instance carries instead.
    """;
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }

    _reach = self._vtable_less_reach;
    if _reach is None {
        reg = get_layout_registry(self.ir_in, self.prog);
        _reach = set();
        for cand in reg.mro_order {
            if self._arch_has_vtable(cand) {
                continue;
            }
            for step in self._mro_of(cand) {
                _reach.add(step);
            }
        }
        self._vtable_less_reach = _reach;
    }
    for name in names {
        if name in _reach {
            return True;
        }
    }
    return False;
}

impl NaIRGenVtable._isinstance_unprovable_class(
    names: list[str], operand_arch: (str | None)
) -> (str | None) {
    """A class this operand could be whose MRO is too short to decide these names.

    A class that subclasses an imported one is linearized by its own module,
    which reaches the base's name but not the base's own bases -- those live in
    a registry that is only merged in later. The recorded MRO then stops one
    link short, and every ancestor past that link silently drops out of the
    hierarchy. Answering from those facts is how `isinstance` came to report
    `False` for a base a class genuinely derives from, so a site whose targets
    fall in the missing span refuses instead.

    A short chain elsewhere in the program is only this site's problem if the
    operand could actually hold one: a statically typed operand narrows the
    candidates to itself and its subclasses, and only an erased one has to
    answer for every class. That narrowing walks the candidate's chain link by
    link rather than reading its recorded MRO, because the recorded MRO is the
    very thing that is short -- reading it would drop a candidate precisely
    when the ancestor it omits is the operand's declared type, which is the
    case that most needs the refusal. Returns the class whose MRO is short, or
    `None` when every chain this operand could take is whole.
    """;
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }

    _missing = self._short_mro_reach;
    if _missing is None {
        reg = get_layout_registry(self.ir_in, self.prog);
        _missing = {};
        for cand in reg.mro_order {
            recorded = self._mro_of(cand);
            _cand_lay = reg.layouts.get(cand);
            _parents = list(_cand_lay.parents or []) if _cand_lay is not None else [];
            _pmods = list(_cand_lay.parent_mods or []) if _cand_lay is not None else [];
            for step in recorded {
                if step != cand and step in _parents {
                    _pi = _parents.index(step);
                    _want = _pmods[_pi] if _pi < len(_pmods) else "";
                    _step_lay = reg.layouts.get(step);
                    _decl = _step_lay.decl_mod if _step_lay is not None else "";
                    if _want != _decl {
                        continue;
                    }
                }
                for anc in self._mro_of(step) {
                    if anc in recorded {
                        continue;
                    }
                    _short_of = _missing.get(anc);
                    if _short_of is None {
                        _missing[anc] = [cand];
                    } elif cand not in _short_of {
                        _short_of.append(cand);
                    }
                }
            }
        }
        self._short_mro_reach = _missing;
    }
    for name in names {
        for cand in (_missing.get(name) or []) {
            if operand_arch is None {
                return cand;
            }
            for step in self._mro_of(cand) {
                if operand_arch in self._mro_of(step) {
                    return cand;
                }
            }
        }
    }
    return None;
}

impl NaIRGenVtable._isinstance_class_name_hit(
    obj_ptr: ir.Value, names: list[str]
) -> (ir.Value | None) {
    """Does the object's runtime class name answer for any of these names?

    Every archetype instantiation stamps its class name into the allocation
    header, so this identity survives the module boundary the vtable does not:
    the name is the same string whichever unit allocated the object. `__jac_isa`
    matches it against the program-wide `(class, ancestor)` table, whose rows
    come from the same merged `mro_order` that
    `_register_imported_hierarchy` fills, so an imported base matches through an
    imported MRO without a second identity scheme. `None` when no header is
    around to read -- a headerless build keeps the site loud rather than
    guessing.
    """;
    if self._emit_runtime_class_name_fn() is None {
        return None;
    }
    cls_id = self._codegen_runtime_class_name(obj_ptr);
    if cls_id is None {
        return None;
    }
    isa_fn = self._emit_isa_fn();
    hit: (ir.Value | None) = None;
    for name in names {
        one = self.builder.call(
            isa_fn, [cls_id, self._emit_class_name_const(name)], name="isinst.nm.res"
        );
        hit = one if hit is None else self.builder.or_(hit, one, name="isinst.nm.or");
    }
    return hit;
}

impl NaIRGenVtable._codegen_virtual_call(
    obj_val: ir.Value, method_name: str, args: list[ir.Value], obj_type_name: str
) -> (ir.Value | None) {
    _vc_struct = self.struct_types.get(obj_type_name);
    if _vc_struct is not None and obj_val.type != _vc_struct.as_pointer() {
        obj_val = self._coerce_type(obj_val, _vc_struct.as_pointer());
    }
    if not isinstance(obj_val.type, ir.PointerType) {
        return None;
    }
    _vc_force_variants = False;
    indices = self.vtable_method_indices.get(obj_type_name);
    if indices is None or method_name not in indices {
        import from jaclang.compiler.passes.layout_pass {
            get_layout_registry as _vc_glr
        }
        _vc_lay = _vc_glr(self.ir_in, self.prog).get_layout(obj_type_name);
        if (
            _vc_lay is None
            or not _vc_lay.has_vtable
            or method_name not in _vc_lay.method_index
        ) {
            return None;
        }
        indices = _vc_lay.method_index;
        _vc_force_variants = _vc_lay.vtable_by_dispatch;
    }

    func = self._resolve_method(obj_type_name, method_name);
    if func is None {
        return None;
    }
    fn_type = func.function_type;

    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(fn_type.args) {
            coerced.append(self._coerce_type(arg, fn_type.args[i]));
        } else {
            coerced.append(arg);
        }
    }

    non_overridden = self._non_overridden_methods.get(obj_type_name);
    if non_overridden is not None and method_name in non_overridden {
        _dv_res = self.builder.call(func, coerced, name=f"call.{method_name}");

        self._release_owned_args(coerced, op="mcall_arg");
        return _dv_res;
    }

    method_idx = indices[method_name] + VTABLE_HEADER_SLOTS;
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();

    _vd_variants: list[tuple] = [];
    _vd_uniform = True;
    import from jaclang.compiler.passes.layout_pass { get_layout_registry as _vd_glr }
    _vd_reg = _vd_glr(self.ir_in, self.prog);
    for _vd_cls in _vd_reg.mro_order {
        if obj_type_name not in self._mro_of(_vd_cls) {
            continue;
        }
        _vd_lay = _vd_reg.get_layout(_vd_cls);
        if _vd_lay is None or not _vd_lay.has_vtable {
            continue;
        }
        _vd_idx = _vd_lay.method_index.get(method_name);
        _vd_fn = self._resolve_method(_vd_cls, method_name);
        _vd_vt = self._vtable_global_for(_vd_cls);
        if _vd_vt is None or _vd_fn is None {
            continue;
        }
        _vd_variants.append((_vd_cls, _vd_vt, _vd_fn));
        if _vd_idx != indices[method_name] {
            _vd_uniform = False;
        }
    }
    if _vc_force_variants and not _vd_variants {
        return None;
    }
    if (_vc_force_variants or not _vd_uniform) and _vd_variants {
        vtable_ptr_ptr = self.builder.gep(
            obj_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="vt.id.pp"
        );
        _vd_vtp = self.builder.load(vtable_ptr_ptr, name="vt.id");
        _vd_fnc = self.builder.function;
        _vd_done = _vd_fnc.append_basic_block(name=f"vd.{method_name}.done");
        _vd_incoming: list[tuple] = [];
        for (_vc, _vt, _vf) in _vd_variants {
            _vd_hit = _vd_fnc.append_basic_block(name=f"vd.{method_name}.{_vc}");
            _vd_next = _vd_fnc.append_basic_block(name=f"vd.{method_name}.n.{_vc}");
            _vd_eq = self.builder.icmp_unsigned(
                "==",
                _vd_vtp,
                self.builder.bitcast(_vt, _vd_vtp.type, name="vd.cand"),
                name=f"vd.eq.{_vc}"
            );
            self.builder.cbranch(_vd_eq, _vd_hit, _vd_next);
            self.builder.position_at_end(_vd_hit);
            _vd_args: list[ir.Value] = [];
            for (_ai, _av) in enumerate(coerced) {
                if _ai < len(_vf.function_type.args) {
                    _vd_args.append(
                        self._coerce_type(_av, _vf.function_type.args[_ai])
                    );
                } else {
                    _vd_args.append(_av);
                }
            }
            _vd_r = self.builder.call(_vf, _vd_args, name=f"vd.call.{_vc}");
            _vd_ret_t = fn_type.return_type;
            if not isinstance(_vd_ret_t, ir.VoidType) and _vd_r.type != _vd_ret_t {
                _vd_r = self._coerce_type(_vd_r, _vd_ret_t);
            }
            _vd_incoming.append((_vd_r, self.builder.block));
            self.builder.branch(_vd_done);
            self.builder.position_at_end(_vd_next);
        }

        _vd_fb = self.builder.call(func, coerced, name=f"vd.fb.{method_name}");
        _vd_incoming.append((_vd_fb, self.builder.block));
        self.builder.branch(_vd_done);
        self.builder.position_at_end(_vd_done);
        _vd_ret_t = fn_type.return_type;
        if isinstance(_vd_ret_t, ir.VoidType) {
            self._release_owned_args(coerced, op="vcall_arg");
            return _vd_fb;
        }
        _vd_phi = self.builder.phi(_vd_ret_t, name=f"vd.{method_name}.res");
        for (_vr, _vb) in _vd_incoming {
            _vd_phi.add_incoming(_vr, _vb);
        }
        self._release_owned_args(coerced, op="vcall_arg");
        return _vd_phi;
    }

    vtable_ptr_ptr = self.builder.gep(
        obj_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="vtable.ptr.ptr"
    );
    vtable_ptr = self.builder.load(vtable_ptr_ptr, name="vtable.ptr");

    method_slot = self.builder.gep(
        vtable_ptr, [ir.Constant(i32, method_idx)], name=f"vt.{method_name}"
    );
    method_i8 = self.builder.load(method_slot, name=f"fn.{method_name}.raw");

    typed_fn = self.builder.bitcast(
        method_i8, fn_type.as_pointer(), name=f"fn.{method_name}"
    );
    _vt_res = self.builder.call(typed_fn, coerced, name=f"vcall.{method_name}");

    self._release_owned_args(coerced, op="vcall_arg");
    return _vt_res;
}

impl NaIRGenVtable._emit_class_name_const(arch_name: str) -> ir.Value {
    cached = self._class_name_consts.get(arch_name);
    if cached is not None {
        return cached;
    }
    i32 = ir.IntType(32);
    (struct_type, struct_val) = self._static_str_struct_const(
        (arch_name + "\0").encode("utf8")
    );
    global_str = ir.GlobalVariable(
        self.llvm_module, struct_type, name=f".clsname.{self._str_count}"
    );
    self._str_count = self._str_count + 1;
    global_str.linkage = "private";
    global_str.global_constant = True;
    global_str.initializer = struct_val;

    ptr = global_str.gep(
        [ir.Constant(i32, 0), ir.Constant(i32, 2), ir.Constant(i32, 0)]
    );
    self._class_name_consts[arch_name] = ptr;
    return ptr;
}

impl NaIRGenVtable._emit_runtime_class_name_fn -> (ir.Function | None) {
    if self._nogc_headerless() {
        return None;
    }
    _cached = self?._runtime_class_name_fn;
    if _cached is not None {
        return _cached;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();

    fn = self._define_function("__jac_class_name", ir.FunctionType(i8_ptr, [i8_ptr]));
    fn.linkage = "private";
    fn.args[0].name = "obj";

    _entry = fn.append_basic_block("entry");
    _sentinel = fn.append_basic_block("check.sentinel");
    _magic = fn.append_basic_block("check.magic");
    _read = fn.append_basic_block("read");
    _none = fn.append_basic_block("none");
    _unknown = fn.append_basic_block("unknown");
    _done = fn.append_basic_block("done");

    b = ir.IRBuilder(_entry);
    _null = b.icmp_unsigned(
        "==", fn.args[0], ir.Constant(i8_ptr, None), name="cn.null"
    );
    b.cbranch(_null, _none, _sentinel);

    b = ir.IRBuilder(_sentinel);
    _rc_slot = b.gep(fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="cn.rc.slot");
    _rc_val = b.load(b.bitcast(_rc_slot, i64_ptr, name="cn.rc.p"), name="cn.rc");
    _is_stk = b.icmp_unsigned(
        "==", _rc_val, ir.Constant(i64, RC_SENTINEL), name="cn.stk"
    );
    b.cbranch(_is_stk, _read, _magic);

    b = ir.IRBuilder(_magic);
    b.cbranch(
        self._emit_magic_check(b, fn.args[0], name_prefix="cn.mc"), _read, _unknown
    );

    b = ir.IRBuilder(_read);
    _tag_slot = b.gep(fn.args[0], [ir.Constant(i64, HDR_TAG_OFF)], name="cn.tag.slot");
    _tag = b.load(
        b.bitcast(_tag_slot, i8_ptr.as_pointer(), name="cn.tag.pp"), name="cn.tag"
    );
    _tag_null = b.icmp_unsigned(
        "==", _tag, ir.Constant(i8_ptr, None), name="cn.tag.null"
    );
    b.cbranch(_tag_null, _unknown, _done);
    _read_end = b.block;

    _i32 = ir.IntType(32);
    b = ir.IRBuilder(_none);
    _none_name = b.gep(
        self._get_snprintf_fmt("NoneType"),
        [ir.Constant(_i32, 0), ir.Constant(_i32, 0)],
        name="cn.nonetype"
    );
    b.branch(_done);
    _none_end = b.block;

    b = ir.IRBuilder(_unknown);
    _empty = b.gep(
        self._get_snprintf_fmt(""),
        [ir.Constant(_i32, 0), ir.Constant(_i32, 0)],
        name="cn.empty"
    );
    b.branch(_done);
    _unknown_end = b.block;

    b = ir.IRBuilder(_done);
    _res = b.phi(i8_ptr, name="cn.name");
    _res.add_incoming(_tag, _read_end);
    _res.add_incoming(_none_name, _none_end);
    _res.add_incoming(_empty, _unknown_end);
    b.ret(_res);

    self._runtime_class_name_fn = fn;
    return fn;
}

impl NaIRGenVtable._codegen_runtime_class_name(obj_val: ir.Value) -> (ir.Value | None) {
    i8_ptr = ir.IntType(8).as_pointer();
    _headerless = self._nogc_headerless();
    if self._opt_payload_of(obj_val.type) is not None {
        if _headerless or self._opt_ptr_payload_of(obj_val.type) is None {
            return None;
        }
        _tag = self.builder.extract_value(obj_val, 0, name="clsname.opt.tag");
        _some = self.builder.icmp_signed(
            "!=", _tag, ir.Constant(ir.IntType(8), 0), name="clsname.opt.some"
        );
        _payload = self.builder.extract_value(obj_val, 1, name="clsname.opt.val");
        obj_val = self.builder.select(
            _some,
            self.builder.bitcast(_payload, i8_ptr, name="clsname.opt.i8"),
            ir.Constant(i8_ptr, None),
            name="clsname.opt.ptr"
        );
    }
    if not isinstance(obj_val.type, ir.PointerType)
        or isinstance(obj_val.type.pointee, ir.FunctionType) {
        return None;
    }
    _pointee_arch = self._struct_ptr_pointee_name(obj_val);
    if _pointee_arch is not None and self._arch_has_vtable(_pointee_arch) {
        return self._class_id_of_value(_pointee_arch, obj_val);
    }
    _fn = self._emit_runtime_class_name_fn();
    if _fn is None {
        return None;
    }
    return self.builder.call(
        _fn,
        [self.builder.bitcast(obj_val, i8_ptr, name="clsname.i8")],
        name="clsname.rt"
    );
}

impl NaIRGenVtable._codegen_class_name(nd: uni.AtomTrailer) -> (ir.Value | None) {
    if not (nd.is_attr and self._get_name(nd.right) == "__name__") {
        return None;
    }
    inner = nd.target;
    receiver: (uni.UniNode | None) = None;

    if isinstance(inner, uni.AtomTrailer)
        and inner.is_attr
        and self._get_name(inner.right) == "__class__" {
        receiver = inner.target;
    } elif isinstance(inner, uni.FuncCall)
        and self._get_name(inner.target) == "type"
        and inner.params
        and len(inner.params) == 1 {
        receiver = inner.params[0];
    }
    if receiver is None {
        return None;
    }
    return self._codegen_class_id(receiver);
}

impl NaIRGenVtable._codegen_class_id(receiver: uni.UniNode) -> (ir.Value | None) {
    arch_name = self._struct_name_of(receiver);

    if arch_name is not None and not self._arch_has_vtable(arch_name) {
        return self._emit_class_name_const(arch_name);
    }

    obj_val = self._codegen_expr(receiver);
    if obj_val is None {
        return None;
    }
    if arch_name is not None
        and isinstance(obj_val.type, ir.PointerType)
        and isinstance(obj_val.type.pointee, ir.IdentifiedStructType) {
        return self._class_id_of_value(arch_name, obj_val);
    }

    return self._codegen_runtime_class_name(obj_val);
}

impl NaIRGenVtable._class_id_of_value(arch_name: str, obj_val: ir.Value) -> ir.Value {
    if not self._arch_has_vtable(arch_name) {
        return self._emit_class_name_const(arch_name);
    }
    i32 = ir.IntType(32);
    vtable_ptr_ptr = self.builder.gep(
        obj_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="clsname.vt.ptr.ptr"
    );
    vtable_ptr = self.builder.load(vtable_ptr_ptr, name="clsname.vt.ptr");
    name_slot = self.builder.gep(
        vtable_ptr, [ir.Constant(i32, 0)], name="clsname.slot"
    );
    return self.builder.load(name_slot, name="clsname");
}

impl NaIRGenVtable._codegen_class_ref(nd: uni.Name) -> (ir.Value | None) {
    _np = nd.parent;
    if isinstance(_np, uni.AtomTrailer) and _np.target is nd {
        return None;
    }
    if isinstance(_np, uni.FuncCall) and _np.target is nd {
        return None;
    }

    if _np?.collection is nd {
        return None;
    }
    _arch = self._arch_alias_target(nd) or nd.value;
    if _arch not in self.struct_types or self._is_enum_arch(_arch) {
        return None;
    }
    return self._emit_class_name_const(_arch);
}

impl NaIRGenVtable._is_enum_arch(name: str) -> bool {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    if name in self.enum_types {
        return True;
    }
    _cands: list = [self.ir_in];
    for _fm in (self?._foreign_modules or []) {
        _cands.append(_fm);
    }
    for _cand in _cands {
        if get_layout_registry(_cand, self.prog).get_enum_layout(name) is not None {
            return True;
        }
    }
    return False;
}

impl NaIRGenVtable._emit_isa_fn -> ir.Function {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    if self._isa_fn is not None {
        return self._isa_fn;
    }
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();
    row_ty = ir.LiteralStructType([i8p, i8p]);

    reg = get_layout_registry(self.ir_in, self.prog);
    rows: list = [];
    for cls in sorted(reg.mro_order) {
        for anc in self._mro_of(cls) {
            if anc == cls {
                continue;
            }
            rows.append(
                ir.Constant(
                    row_ty,
                    [self._emit_class_name_const(cls), self._emit_class_name_const(anc)]
                )
            );
        }
    }
    rows.append(ir.Constant(row_ty, [ir.Constant(i8p, None), ir.Constant(i8p, None)]));
    tbl_ty = ir.ArrayType(row_ty, len(rows));
    tbl = ir.GlobalVariable(self.llvm_module, tbl_ty, name=".jac.isa.table");
    tbl.linkage = "private";
    tbl.global_constant = True;
    tbl.initializer = ir.Constant(tbl_ty, rows);

    strcmp = self._get_or_declare_extern("strcmp", i32, [i8p, i8p]);
    fn: any = self._define_function("__jac_isa", ir.FunctionType(i1, [i8p, i8p]));
    fn.linkage = "private";
    fn.args[0].name = "cls";
    fn.args[1].name = "tgt";
    _cls = fn.args[0];
    _tgt = fn.args[1];

    `entry = fn.append_basic_block("entry");
    scan = fn.append_basic_block("scan");
    row = fn.append_basic_block("row");
    anc_bb = fn.append_basic_block("anc");
    next_bb = fn.append_basic_block("next");
    yes = fn.append_basic_block("yes");
    no = fn.append_basic_block("no");

    be = ir.IRBuilder(`entry);
    idx = be.alloca(i64, name="i");
    be.store(ir.Constant(i64, 0), idx);

    _self_hit = be.icmp_signed(
        "==",
        be.call(strcmp, [_cls, _tgt], name="isa.self"),
        ir.Constant(i32, 0),
        name="isa.self.eq"
    );
    be.cbranch(_self_hit, yes, scan);

    bs = ir.IRBuilder(scan);
    _i = bs.load(idx, name="i");
    _cp = bs.gep(
        tbl, [ir.Constant(i32, 0), _i, ir.Constant(i32, 0)], name="isa.rowc.p"
    );
    _rc = bs.load(_cp, name="isa.rowc");
    bs.cbranch(
        bs.icmp_unsigned("==", _rc, ir.Constant(i8p, None), name="isa.end"), no, row
    );

    br = ir.IRBuilder(row);
    _c_eq = br.icmp_signed(
        "==",
        br.call(strcmp, [_rc, _cls], name="isa.cc"),
        ir.Constant(i32, 0),
        name="isa.cc.eq"
    );
    br.cbranch(_c_eq, anc_bb, next_bb);

    ba = ir.IRBuilder(anc_bb);
    _ap = ba.gep(
        tbl, [ir.Constant(i32, 0), _i, ir.Constant(i32, 1)], name="isa.rowa.p"
    );
    _ra = ba.load(_ap, name="isa.rowa");
    _a_eq = ba.icmp_signed(
        "==",
        ba.call(strcmp, [_ra, _tgt], name="isa.ac"),
        ir.Constant(i32, 0),
        name="isa.ac.eq"
    );
    ba.cbranch(_a_eq, yes, next_bb);

    bn = ir.IRBuilder(next_bb);
    bn.store(bn.add(_i, ir.Constant(i64, 1), name="isa.in"), idx);
    bn.branch(scan);

    ir.IRBuilder(yes).ret(ir.Constant(i1, 1));
    ir.IRBuilder(no).ret(ir.Constant(i1, 0));
    self._isa_fn = fn;
    return fn;
}

impl NaIRGenVtable._runtime_class_value(
    expr: (uni.UniNode | None)
) -> (ir.Value | None) {
    if not isinstance(expr, uni.Name) or expr.type is None {
        return None;
    }
    _nm = expr.value;
    if _nm not in self.local_vars and _nm not in self.global_vars {
        return None;
    }
    if _nm in self.struct_types or _nm in self.enum_types {
        return None;
    }
    _mk = self._mangled_of(expr.type);
    if _mk is None or not (_mk == "type" or _mk.startswith("type[")) {
        return None;
    }
    val = self._codegen_expr(expr);
    if val is None or val.type != ir.IntType(8).as_pointer() {
        return None;
    }
    return val;
}

impl NaIRGenVtable._is_runtime_class_tuple(t: any) -> bool {
    """Is this the type of a tuple whose every arm is a class handle?

    That is the shape `isinstance(x, types)` needs: the arms arrive as values,
    and each one has to be a `type[...]` so the compare has a class id to walk.
    An arity-less arm (the `UnknownType` a variadic tuple parks) is skipped, so
    both `tuple[type[T], type[T]]` and `tuple[type[T], ...]` qualify.
    """;
    try {
        import from jaclang.compiler.types.types { ClassType as _SeqClassType }
    } except ImportError {
        return False;
    }
    if not isinstance(t, _SeqClassType) or t._shared is None {
        return False;
    }
    if t.shared.class_name != "tuple" {
        return False;
    }
    saw_class = False;
    for a in (t.private.type_args or []) {
        am = self._mangled_of(a);
        if am is None {
            return False;
        }
        if am == "<unknown>" {
            continue;
        }
        if am != "type" and not am.startswith("type[") {
            return False;
        }
        saw_class = True;
    }
    return saw_class;
}

impl NaIRGenVtable._runtime_class_arms(expr: (uni.UniNode | None)) -> tuple {
    """The class handles an `isinstance` type argument carries as a value.

    `isinstance(x, types)` where `types` is a value is the same check as a
    literal tuple of arms, only the arms arrive at runtime. Returns them as
    `(unrolled, sequence)`: an arity the type states unrolls into one compare
    per arm, and a variadic tuple -- which lowers to a native sequence, so its
    arity is a runtime value -- comes back whole for the loop to walk. Both are
    `None` when the argument is not a runtime class handle at all.
    """;
    none_pair = (None, None, );
    one = self._runtime_class_value(expr);
    if one is not None {
        return ([one], None, );
    }
    if not isinstance(expr, uni.Expr) or not self._is_runtime_class_tuple(expr.type) {
        return none_pair;
    }
    val = self._codegen_expr(expr);
    if val is None {
        return none_pair;
    }
    i8p = ir.IntType(8).as_pointer();
    if "ptr" in self.list_types and val.type == self.list_types["ptr"].as_pointer() {
        return (None, val, );
    }
    st = self._tuple_struct_of_value(val);
    if st is None {
        return none_pair;
    }
    if isinstance(val.type, ir.PointerType) {
        val = self.builder.load(val, name="isa.tgts");
    }
    out: list[ir.Value] = [];
    for i in range(len(st.elements)) {
        if st.elements[i] != i8p {
            return none_pair;
        }
        out.append(self.builder.extract_value(val, i, name="isa.tgt"));
    }
    return (out, None, ) if out else none_pair;
}

impl NaIRGenVtable._emit_isa_seq_fn -> ir.Function {
    """`__jac_isa_seq(cls, seq)`: does any class handle in `seq` answer for `cls`?

    A variadic tuple of types arrives as a native pointer sequence, so its arity
    is a runtime value and the per-arm compare has to run in a loop rather than
    unroll. The body is the same `__jac_isa` walk each named arm performs.
    """;
    if self._isa_seq_fn is not None {
        return self._isa_seq_fn;
    }
    i1 = ir.IntType(1);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    self._emit_list_helpers("ptr", i8p);
    helpers = self.list_helpers["ptr"];
    seq_ty = self.list_types["ptr"].as_pointer();

    fn: any = self._define_function(
        "__jac_isa_seq", ir.FunctionType(i1, [i8p, seq_ty])
    );
    fn.linkage = "private";
    fn.args[0].name = "cls";
    fn.args[1].name = "seq";
    _cls = fn.args[0];
    _seq = fn.args[1];

    `entry = fn.append_basic_block("entry");
    head = fn.append_basic_block("head");
    body = fn.append_basic_block("body");
    yes = fn.append_basic_block("yes");
    no = fn.append_basic_block("no");

    be = ir.IRBuilder(`entry);
    idx = be.alloca(i64, name="i");
    be.store(ir.Constant(i64, 0), idx);
    _null = be.icmp_unsigned("==", _seq, ir.Constant(seq_ty, None), name="isaseq.null");
    be.cbranch(_null, no, head);

    bh = ir.IRBuilder(head);
    _n = bh.call(helpers["len"], [_seq], name="isaseq.len");
    _i = bh.load(idx, name="i");
    bh.cbranch(bh.icmp_signed("<", _i, _n, name="isaseq.more"), body, no);

    bb = ir.IRBuilder(body);
    _tgt = bb.call(helpers["get"], [_seq, _i], name="isaseq.tgt");
    _hit = bb.call(self._emit_isa_fn(), [_cls, _tgt], name="isaseq.hit");
    bb.store(bb.add(_i, ir.Constant(i64, 1), name="isaseq.in"), idx);
    bb.cbranch(_hit, yes, head);

    ir.IRBuilder(yes).ret(ir.Constant(i1, 1));
    ir.IRBuilder(no).ret(ir.Constant(i1, 0));
    self._isa_seq_fn = fn;
    return fn;
}

impl NaIRGenVtable._isinstance_operand_arch(
    nd: uni.FuncCall, operand: ir.Value
) -> (str | None) {
    """The archetype layout whose class id the operand's vtable slot holds.

    The declared type answers first; when a union or an `any` erases it, the
    pointee's own struct name still names the layout, which is what the class
    id is read through.
    """;
    named = self._struct_name_of(nd.params[0] if nd.params else None);
    if named is not None and named in self.struct_types {
        return named;
    }
    if isinstance(operand.type, ir.PointerType)
        and isinstance(operand.type.pointee, ir.IdentifiedStructType) {
        pointee = operand.type.pointee.name or "";
        if pointee in self.struct_types {
            return pointee;
        }
    }
    return None;
}

impl NaIRGenVtable._emit_isinstance_runtime(
    nd: uni.FuncCall, operand: ir.Value, type_arg: uni.UniNode
) -> (ir.Value | None) {
    if not isinstance(operand.type, ir.PointerType) {
        return None;
    }
    struct_name = self._isinstance_operand_arch(nd, operand);
    if struct_name is None {
        return None;
    }
    (tgts, tgt_seq) = self._runtime_class_arms(type_arg);
    if not tgts and tgt_seq is None {
        return None;
    }
    i1 = ir.IntType(1);
    pre_bb = self.builder.block;
    nonnull_bb = self.builder.append_basic_block(name="isa.nonnull");
    merge_bb = self.builder.append_basic_block(name="isa.merge");
    self.builder.cbranch(
        self.builder.icmp_unsigned(
            "==", operand, ir.Constant(operand.type, None), name="isa.null.chk"
        ),
        merge_bb,
        nonnull_bb
    );
    self.builder.position_at_end(nonnull_bb);
    cls_id = self._class_id_of_value(struct_name, operand);
    hit: (ir.Value | None) = None;
    if tgt_seq is not None {
        hit = self.builder.call(
            self._emit_isa_seq_fn(), [cls_id, tgt_seq], name="isa.seq.res"
        );
    } else {
        isa_fn = self._emit_isa_fn();
        for tgt in tgts {
            one = self.builder.call(isa_fn, [cls_id, tgt], name="isa.res");
            hit = one if hit is None else self.builder.or_(hit, one, name="isa.or");
        }
    }
    if self._is_owned(operand) {
        self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
    }
    end_nonnull = self.builder.block;
    self.builder.branch(merge_bb);
    self.builder.position_at_end(merge_bb);
    res = self.builder.phi(i1, name="isa.result");
    res.add_incoming(ir.Constant(i1, 0), pre_bb);
    res.add_incoming(hit, end_nonnull);
    return res;
}

impl NaIRGenVtable._generate_inherited_method_wrappers -> None {
    for child_name in self.arch_ast_map {
        mro = self._mro_of(child_name);
        child_struct = self.struct_types.get(child_name);
        if child_struct is None or len(mro) < 2 {
            continue;
        }

        seen_methods: set[str] = set();
        for ancestor_name in mro[1:] {
            ancestor_layout = self.vtable_layouts.get(ancestor_name, []);
            for method_name in ancestor_layout {
                if method_name in seen_methods {
                    continue;
                }
                seen_methods.add(method_name);
                child_full = f"{child_name}.{method_name}";

                if child_full in self.method_funcs {
                    continue;
                }

                impl_func = None;
                impl_class: (str | None) = None;
                for mro_class in mro[1:] {
                    parent_full = f"{mro_class}.{method_name}";
                    if parent_full in self.method_funcs {
                        impl_func = self.method_funcs[parent_full];
                        impl_class = mro_class;
                        break;
                    }
                }
                if impl_func is None {
                    continue;
                }

                orig_fn_type = impl_func.function_type;

                _has_self = False;
                if len(orig_fn_type.args) > 0
                    and isinstance(orig_fn_type.args[0], ir.PointerType) {
                    _p0_nm = getattr(orig_fn_type.args[0].pointee, "name", "") or "";
                    if _p0_nm == impl_class {
                        _has_self = True;
                    }
                }
                if not _has_self {
                    self.method_funcs[child_full] = impl_func;
                    self.func_symtab[child_full] = impl_func;
                    continue;
                }

                new_param_types: list[ir.Type] = [child_struct.as_pointer()];
                for i in range(1, len(orig_fn_type.args)) {
                    new_param_types.append(orig_fn_type.args[i]);
                }
                wrapper_fn_type = ir.FunctionType(
                    orig_fn_type.return_type, new_param_types
                );
                wrapper_fn = ir.Function(
                    self.llvm_module, wrapper_fn_type, name=self._symbol_for(child_full)
                );
                wrapper_fn.linkage = "internal";

                wrapper_fn.args[0].name = "self";
                for i in range(1, len(impl_func.args)) {
                    wrapper_fn.args[i].name = impl_func.args[i].name;
                }

                entry_block = wrapper_fn.append_basic_block(name="entry");
                builder = ir.IRBuilder(entry_block);

                impl_struct = self.struct_types.get(impl_class);
                if impl_struct is None {
                    args: list[ir.Value] = list(wrapper_fn.args);
                } else {
                    parent_self = builder.bitcast(
                        wrapper_fn.args[0], impl_struct.as_pointer(), name="parent.self"
                    );
                    args: list[ir.Value] = [parent_self];
                    for i in range(1, len(wrapper_fn.args)) {
                        args.append(wrapper_fn.args[i]);
                    }
                }

                _exp_types = impl_func.function_type.args;
                for _ai in range(len(args)) {
                    if _ai < len(_exp_types)
                        and args[_ai].type != _exp_types[_ai]
                        and isinstance(args[_ai].type, ir.PointerType)
                        and isinstance(_exp_types[_ai], ir.PointerType) {
                        args[_ai] = builder.bitcast(
                            args[_ai], _exp_types[_ai], name=f"inh.arg{_ai}"
                        );
                    }
                }
                result = builder.call(impl_func, args, name=f"inherited.{method_name}");

                if isinstance(orig_fn_type.return_type, ir.VoidType) {
                    builder.ret_void();
                } else {
                    builder.ret(result);
                }

                self.method_funcs[child_full] = wrapper_fn;
                self.func_symtab[child_full] = wrapper_fn;
            }
        }
    }
}
