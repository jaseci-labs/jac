impl NaIRGenPass._copy_call_kind(nd: uni.FuncCall) -> (str | None) {
    if "copy" not in self._native_stdlib_modules {
        return None;
    }
    target = nd.target;
    if isinstance(target, uni.AtomTrailer) and target.is_attr {
        import from jaclang.compiler.symbol_utils { imported_module_name }
        if imported_module_name(target.target) != "copy" {
            return None;
        }
        name = self._get_name(target.right);
        return name if name in NATIVE_COPY_FUNCS else None;
    }
    if not isinstance(target, uni.Name) or target.sym is None {
        return None;
    }
    scope = target.sym.parent_tab;
    if isinstance(scope, uni.Module)
        and scope.stub_only
        and scope.name == "copy"
        and target.sym.name in NATIVE_COPY_FUNCS {
        return target.sym.name;
    }
    return None;
}

impl NaIRGenPass._emit_copy_refusal(nd: uni.UniNode, kind: str, why: str) -> None {
    self.emit(
        E5092,
        node_override=nd,
        kind="copy call",
        name=f"copy.{kind} of {why}",
        help_text=(
            f"`copy.{kind}` lowers natively for scalars, strings, bytes, tuples, "
            "lists, dicts, sets and obj/class archetypes composed of them. Copy "
            f"the value explicitly, or call `copy.{kind}` from a @sv/Python context."
        )
    );
}

impl NaIRGenPass._emit_copy_call(kind: str, nd: uni.FuncCall) -> (ir.Value | None) {
    params: list[uni.Expr | uni.KWPair] = list(nd.params or []);
    deep = kind == "deepcopy";
    if len(params) != 1 or isinstance(params[0], uni.KWPair) {
        self._emit_copy_refusal(
            nd, kind, "a call with other than one positional argument (a `memo` dict)"
        );
        return None;
    }
    if self._nogc_headerless() {
        self._emit_copy_refusal(
            nd,
            kind,
            "a module under the nogc memory profile, whose headerless objects carry no runtime class"
        );
        return None;
    }
    arg = params[0];
    val = self._codegen_expr(arg);
    if val is None {
        return None;
    }
    hint = arg.type if isinstance(arg, uni.Expr) else None;
    why = self._copy_refusal(val.type, hint, deep, set(), True);
    if why is not None {
        self._emit_copy_refusal(nd, kind, why);
        return None;
    }
    if self._copy_is_atomic(val.type, hint, deep) {
        if isinstance(val.type, ir.LiteralStructType) {
            return val;
        }
        if not self._is_owned(val) {
            self._emit_take_ref(val, op="copy_identity");
        }
        return self._mark_reference_owned(val);
    }
    memo: (ir.Value | None) = None;
    if deep {
        memo = self.builder.call(
            self._copy_memo_helpers()["new"], [], name="copy.memo"
        );
    }
    result = self._copy_value(val, hint, deep, memo, nd, kind);
    if memo is not None {
        self._emit_rc_release_simple(memo, op="copy_memo");
    }
    self._release_owned_args([val], op="copy_arg");
    return self._mark_reference_owned(result);
}

impl NaIRGenPass._copy_memo_helpers -> dict[str, any] {
    i64 = ir.IntType(64);
    self._emit_dict_helpers("i64", "i64", i64, i64);
    return self.dict_helpers["i64:i64"];
}

impl NaIRGenPass._copy_hint_name(hint: (TypeBase | None)) -> str {
    if isinstance(hint, ClassType) and hint._shared is not None {
        return hint.shared.class_name;
    }
    return "";
}

impl NaIRGenPass._copy_concrete(ty: ir.Type, hint: (TypeBase | None)) -> ir.Type {
    i8p = ir.IntType(8).as_pointer();
    if ty != i8p or hint is None {
        return ty;
    }
    lowered = self._lower_type(hint);
    if isinstance(lowered, ir.PointerType) and lowered != i8p {
        return lowered;
    }
    return ty;
}

impl NaIRGenPass._copy_shape(ty: ir.Type, hint: (TypeBase | None)) -> tuple[str, any] {
    ty = self._copy_concrete(ty, hint);
    if isinstance(ty, (ir.IntType, ir.DoubleType)) {
        return ("atomic", None);
    }
    if self._str_desc_ty is not None and ty == self._str_desc_ty {
        return ("atomic", None);
    }
    if self?.jacval_type and ty == self.jacval_type {
        return ("any", None);
    }
    _payload = self._opt_payload_of(ty);
    if _payload is not None {
        return ("opt", _payload);
    }
    if isinstance(ty, ir.LiteralStructType) {
        return ("tuple", ty);
    }
    if not isinstance(ty, ir.PointerType) or isinstance(ty.pointee, ir.FunctionType) {
        return ("unknown", None);
    }
    if self._is_bytes_type(ty)
        or (
            self._complex_struct_type is not None
            and ty == self._complex_struct_type.as_pointer()
        ) {
        return ("atomic", None);
    }
    _pointee = ty.pointee;
    if isinstance(_pointee, ir.LiteralStructType) {
        return ("tuple", _pointee);
    }
    if self._copy_hint_name(hint) == "frozenset" {
        return ("atomic", None);
    }
    for (spec, lt) in self.list_types.items() {
        if lt.as_pointer() == ty {
            return ("list", spec);
        }
    }
    for (spec, st) in self.set_types.items() {
        if st.as_pointer() == ty {
            return ("set", spec);
        }
    }
    for (spec, dt) in self.dict_types.items() {
        if dt.as_pointer() == ty {
            return ("dict", spec);
        }
    }
    if isinstance(_pointee, ir.IdentifiedStructType)
        and _pointee.name in self.struct_types
        and self.struct_types[_pointee.name] == _pointee {
        if self._is_enum_arch(_pointee.name) {
            return ("atomic", None);
        }
        return ("arch", _pointee.name);
    }
    if self._copy_hint_name(hint) in ("str", "bytes") {
        return ("atomic", None);
    }
    return ("unknown", None);
}

impl NaIRGenPass._copy_is_atomic(
    ty: ir.Type, hint: (TypeBase | None), deep: bool
) -> bool {
    (shape, info) = self._copy_shape(ty, hint);
    if shape == "atomic" {
        return True;
    }
    if shape == "opt" {
        return self._copy_is_atomic(info, _jc_optional_payload(hint), deep);
    }
    if shape != "tuple" {
        return False;
    }
    if not deep {
        return True;
    }
    _args = self._container_type_args(hint);
    for (i, elem) in enumerate(info.elements) {
        if not self._copy_is_atomic(elem, _args[i] if i < len(_args) else None, True) {
            return False;
        }
    }
    return True;
}

impl NaIRGenPass._copy_type_label(ty: ir.Type, hint: (TypeBase | None)) -> str {
    if hint is not None {
        return f"`{hint}`";
    }
    return f"a value lowered as `{ty}`";
}

impl NaIRGenPass._copy_refusal(
    ty: ir.Type, hint: (TypeBase | None), deep: bool, seen: set[str], top: bool
) -> (str | None) {
    (shape, info) = self._copy_shape(ty, hint);
    if shape == "atomic" {
        return None;
    }
    if shape == "tuple" {
        if self._copy_is_atomic(ty, hint, deep) {
            return None;
        }
        return f"{self._copy_type_label(ty, hint)}, a tuple holding mutable values";
    }
    if shape == "any" {
        if not deep and not top {
            return None;
        }
        return f"{self._copy_type_label(
            ty, hint
        )}, whose runtime type the native copy cannot dispatch on";
    }
    if shape == "unknown" {
        if not deep and not top {
            return None;
        }
        return self._copy_type_label(ty, hint);
    }
    if shape == "opt" {
        return self._copy_refusal(info, _jc_optional_payload(hint), deep, seen, top);
    }
    if shape == "arch" {
        return self._copy_class_refusal(info, deep, seen);
    }
    if not deep {
        return None;
    }
    _args = self._container_type_args(hint);
    if shape == "list" {
        _elem = self.list_helpers[info]["elem_type"];
        _why = self._copy_refusal(
            _elem, _args[0] if _args else None, True, seen, False
        );
        return None
            if _why is None
            else f"{self._copy_type_label(ty, hint)}, whose elements are {_why}";
    }
    if shape == "set" {
        _elem = self.set_helpers[info]["elem_type"];
        if self._copy_is_atomic(_elem, _args[0] if _args else None, True) {
            return None;
        }
        return f"{self._copy_type_label(ty, hint)}, a set of mutable objects";
    }
    _helpers = self.dict_helpers[info];
    _khint = _args[0] if _args else None;
    if not self._copy_is_atomic(_helpers["key_type"], _khint, True) {
        return f"{self._copy_type_label(ty, hint)}, a dict keyed by mutable objects";
    }
    _why = self._copy_refusal(
        _helpers["val_type"], _args[1] if len(_args) > 1 else None, True, seen, False
    );
    return None
        if _why is None
        else f"{self._copy_type_label(ty, hint)}, whose values are {_why}";
}

impl NaIRGenPass._copy_candidates(arch: str) -> list[str] {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    out: list[str] = [arch];
    for cand in get_layout_registry(self.module, self.prog).mro_order {
        if cand != arch and cand in self.struct_types and arch in self._mro_of(cand) {
            out.append(cand);
        }
    }
    return out;
}

impl NaIRGenPass._copy_field_hints(arch: str) -> dict[str, (TypeBase | None)] {
    out: dict[str, (TypeBase | None)] = {};
    lay = self._arch_layout(arch);
    if lay is None {
        return out;
    }
    for finfo in lay.fields {
        var = finfo.decl_node;
        out[finfo.name] = var.type if isinstance(var, uni.HasVar) else None;
    }
    return out;
}

impl NaIRGenPass._copy_class_refusal(
    arch: str, deep: bool, seen: set[str]
) -> (str | None) {
    if arch in seen {
        return None;
    }
    seen.add(arch);
    _dunder = "__deepcopy__" if deep else "__copy__";
    for cand in self._copy_candidates(arch) {
        _label = f"`{self._arch_display(cand)}`"
            if cand == arch
            else f"`{self._arch_display(cand)}` (a subclass of `{self._arch_display(
                arch
            )}`)";
        if cand not in self.struct_field_types {
            return f"{_label}, whose field layout is not visible to this module";
        }
        _lay = self._arch_layout(cand);
        if _lay is not None and _lay.is_osp {
            _what = _lay.arch_type;
            return (
                f"{_label}, a {_what} archetype: a copy would share (copy.copy) or "
                "recursively duplicate (copy.deepcopy) the graph anchor of the original, "
                "which the Python runtime does not handle either; construct a new "
                f"{_what} explicitly"
            );
        }
        if self._pyb_base_of(cand) is not None {
            return f"{_label}, which extends a Python-side base";
        }
        if cand in self.clib_struct_names or cand in self.clib_vtable_structs {
            return f"{_label}, a C-library struct";
        }
        if self._resolve_method(cand, _dunder) is not None
            or self._resolve_method_owner(cand, _dunder) is not None {
            return f"{_label}, which defines its own `{_dunder}`";
        }
        _foreign = self.struct_field_foreign.get(cand, set());
        _hints = self._copy_field_hints(cand);
        for finfo in (_lay.fields if _lay is not None else []) {
            if finfo.decl_node is not None and self._hasvar_is_own(finfo.decl_node) {
                return f"{_label}, whose field `{finfo.name}` is `own`: a copy would alias the uniquely-owned value";
            }
            if finfo.name in _foreign {
                return f"{_label}, whose field `{finfo.name}` has no native representation";
            }
        }
        if not deep {
            continue;
        }
        if "wasm" in str(self.llvm_module.triple or "") {
            return f"{_label} on a wasm target, where the class dispatch of a deep copy cannot raise";
        }
        for (fname, ftype) in self.struct_field_types[cand].items() {
            if self._copy_is_atomic(ftype, _hints.get(fname), True) {
                continue;
            }
            _why = self._copy_refusal(ftype, _hints.get(fname), True, seen, False);
            if _why is not None {
                return f"{_label}, whose field `{fname}` is {_why}";
            }
        }
    }
    return None;
}

impl NaIRGenPass._copy_retain(ty: ir.Type, val: ir.Value) -> None {
    if self._elem_kind(ty) != "raw" {
        self._emit_elem_retain(self.builder, ty, val);
        return;
    }
    if self._opt_ptr_payload_of(ty) is not None {
        _payload = self.builder.extract_value(val, 1, name="copy.opt.pv");
        self._emit_elem_retain(self.builder, _payload.type, _payload);
    }
}

impl NaIRGenPass._copy_release(ty: ir.Type, val: ir.Value) -> None {
    if self._elem_kind(ty) != "raw" {
        self._emit_elem_release(self.builder, ty, val);
        return;
    }
    if self._opt_ptr_payload_of(ty) is not None {
        _payload = self.builder.extract_value(val, 1, name="copy.opt.pv");
        self._emit_elem_release(self.builder, _payload.type, _payload);
    }
}

impl NaIRGenPass._copy_value(
    val: ir.Value,
    hint: (TypeBase | None),
    deep: bool,
    memo: (ir.Value | None),
    nd: uni.UniNode,
    kind: str
) -> ir.Value {
    ty = val.type;
    concrete = self._copy_concrete(ty, hint);
    if concrete != ty {
        return self.builder.bitcast(
            self._copy_value(
                self.builder.bitcast(val, concrete), hint, deep, memo, nd, kind
            ),
            ty
        );
    }
    if self._copy_is_atomic(ty, hint, deep) {
        self._copy_retain(ty, val);
        return val;
    }
    (shape, info) = self._copy_shape(ty, hint);
    if shape == "opt" {
        return self._copy_optional(val, info, hint, deep, memo, nd, kind);
    }
    if shape == "arch" {
        if deep {
            return self.builder.call(
                self._deepcopy_fn(ty, hint, nd), [val, memo], name="deepcopy"
            );
        }
        return self._emit_copy_dispatch(val, info, False, None, nd, kind);
    }
    if deep {
        return self.builder.call(
            self._deepcopy_fn(ty, hint, nd), [val, memo], name="deepcopy"
        );
    }
    _copied = self._dispatch_primitive_method(shape, "copy", val, [], info);
    assert _copied is not None , f"native {shape}.copy() is emitted for spec {info}";
    return _copied;
}

impl NaIRGenPass._copy_optional(
    val: ir.Value,
    payload_ty: ir.Type,
    hint: (TypeBase | None),
    deep: bool,
    memo: (ir.Value | None),
    nd: uni.UniNode,
    kind: str
) -> ir.Value {
    fn = self.builder.function;
    some_bb = fn.append_basic_block("copy.opt.some");
    done_bb = fn.append_basic_block("copy.opt.done");
    entry_bb = self.builder.block;
    tag = self.builder.extract_value(val, 0, name="copy.opt.tag");
    self.builder.cbranch(
        self.builder.icmp_unsigned(
            "!=", tag, ir.Constant(tag.type, 0), name="copy.opt.set"
        ),
        some_bb,
        done_bb
    );
    self.builder.position_at_end(some_bb);
    _payload = self.builder.extract_value(val, 1, name="copy.opt.payload");
    _copied = self._copy_value(
        _payload, _jc_optional_payload(hint), deep, memo, nd, kind
    );
    _rebuilt = self.builder.insert_value(
        val, self._coerce_type(_copied, payload_ty), 1, name="copy.opt.new"
    );
    some_end = self.builder.block;
    self.builder.branch(done_bb);
    self.builder.position_at_end(done_bb);
    phi = self.builder.phi(val.type, name="copy.opt");
    phi.add_incoming(val, entry_bb);
    phi.add_incoming(_rebuilt, some_end);
    return phi;
}

impl NaIRGenPass._emit_copy_dispatch(
    val: ir.Value,
    arch: str,
    deep: bool,
    memo: (ir.Value | None),
    nd: uni.UniNode,
    kind: str
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    sptr = self.struct_types[arch].as_pointer();
    val = self.builder.bitcast(val, sptr, name="copy.src");
    cls = self._codegen_runtime_class_name(val);
    assert cls is not None , "a headered archetype carries its runtime class";
    strcmp = self._get_or_declare_extern("strcmp", i32, [i8p, i8p]);
    fn = self.builder.function;
    done_bb = fn.append_basic_block(f"copy.{arch}.done");
    incoming: list[tuple[ir.Value, ir.Block]] = [];
    for cand in self._copy_candidates(arch) {
        hit_bb = fn.append_basic_block(f"copy.{cand}");
        miss_bb = fn.append_basic_block(f"copy.not.{cand}");
        self._emit_isa_name_match(
            self.builder,
            None,
            self._emit_class_name_const(cand),
            cls,
            strcmp,
            hit_bb,
            miss_bb
        );
        self.builder.position_at_end(hit_bb);
        body = self._copy_body_fn(cand, deep, nd);
        _args: list[ir.Value] = [
            self.builder.bitcast(val, self.struct_types[cand].as_pointer())
        ];
        if memo is not None {
            _args.append(memo);
        }
        _res = self.builder.call(body, _args, name=f"copy.{cand}.new");
        incoming.append((self.builder.bitcast(_res, sptr), self.builder.block));
        self.builder.branch(done_bb);
        self.builder.position_at_end(miss_bb);
    }
    self._emit_runtime_raise(
        ir.Constant(ir.IntType(1), 1),
        "TypeError",
        f"copy.{kind}: this native unit has no copy for the runtime class of a '{self._arch_display(
            arch
        )}' value (a subclass defined in a module it does not import)"
    );
    incoming.append((ir.Constant(sptr, None), self.builder.block));
    self.builder.branch(done_bb);
    self.builder.position_at_end(done_bb);
    phi = self.builder.phi(sptr, name=f"copy.{arch}");
    for (_v, _b) in incoming {
        phi.add_incoming(_v, _b);
    }
    return phi;
}

impl NaIRGenPass._copy_body_fn(arch: str, deep: bool, nd: uni.UniNode) -> ir.Function {
    _key = f"{'deep' if deep else 'shallow'}:{arch}";
    cached = self._copy_fns.get(_key);
    if cached is not None {
        return cached;
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    sptr = self.struct_types[arch].as_pointer();
    _params: list[ir.Type] = [sptr];
    if deep {
        _params.append(self.dict_types["i64:i64"].as_pointer());
    }
    fn = self._define_function(
        f"__jac_{'deepcopy' if deep else 'copy'}.{arch}", ir.FunctionType(sptr, _params)
    );
    fn.linkage = "private";
    self._copy_fns[_key] = fn;
    state = self._enter_function(fn);
    try {
        src = fn.args[0];
        size = self.builder.ptrtoint(
            self.builder.gep(ir.Constant(sptr, None), [ir.Constant(i32, 1)]),
            i64,
            name="copy.size"
        );
        raw = self._emit_heap_object_alloc(nd, arch, size, False);
        self.builder.call(
            self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]),
            [raw, self.builder.bitcast(src, i8p), size]
        );
        dst = self.builder.bitcast(raw, sptr, name="copy.dst");
        _hints = self._copy_field_hints(arch);
        _indices = self.struct_field_indices.get(arch, {});
        _deferred: list[tuple[str, ir.Type, int, ir.Value]] = [];
        for (fname, ftype) in self.struct_field_types[arch].items() {
            idx = _indices.get(fname, -1);
            if idx < 0 or not self._is_reference_type(ftype) {
                continue;
            }
            _v = self.builder.load(
                self.builder.gep(
                    src,
                    [ir.Constant(i32, 0), ir.Constant(i32, idx)],
                    name=f"copy.{fname}.src"
                ),
                name=f"copy.{fname}"
            );
            if deep and not self._copy_is_atomic(ftype, _hints.get(fname), True) {
                _dst_slot = self.builder.gep(
                    dst,
                    [ir.Constant(i32, 0), ir.Constant(i32, idx)],
                    name=f"copy.{fname}.dst"
                );
                self.builder.store(ir.Constant(ftype, None), _dst_slot);
                _deferred.append((fname, ftype, idx, _v));
            } else {
                self._copy_retain(ftype, _v);
            }
        }
        if deep {
            self._copy_memo_record(fn.args[1], src, dst);
        }
        for (fname, ftype, idx, _v) in _deferred {
            _nv = self._copy_value(
                _v, _hints.get(fname), True, fn.args[1], nd, "deepcopy"
            );
            self.builder.store(
                self._coerce_type(_nv, ftype),
                self.builder.gep(
                    dst,
                    [ir.Constant(i32, 0), ir.Constant(i32, idx)],
                    name=f"copy.{fname}.dst"
                )
            );
        }
        self.builder.ret(dst);
    } finally {
        self._leave_function(state);
    }
    return fn;
}

impl NaIRGenPass._copy_memo_record(
    memo: ir.Value, src: ir.Value, dst: ir.Value
) -> None {
    i64 = ir.IntType(64);
    self.builder.call(
        self._copy_memo_helpers()["set"],
        [
            memo,
            self.builder.ptrtoint(src, i64, name="memo.key"),
            self.builder.ptrtoint(dst, i64, name="memo.val")
        ]
    );
}

impl NaIRGenPass._deepcopy_fn(
    ty: ir.Type, hint: (TypeBase | None), nd: uni.UniNode
) -> ir.Function {
    _key = f"deepfn:{ty}:{hint}";
    cached = self._copy_fns.get(_key);
    if cached is not None {
        return cached;
    }
    i64 = ir.IntType(64);
    memo_helpers = self._copy_memo_helpers();
    memo_ty = self.dict_types["i64:i64"].as_pointer();
    (shape, info) = self._copy_shape(ty, hint);
    fn = self._define_function(
        f"__jac_deepcopy.{shape}.{len(self._copy_fns)}",
        ir.FunctionType(ty, [ty, memo_ty])
    );
    fn.linkage = "private";
    self._copy_fns[_key] = fn;
    state = self._enter_function(fn);
    try {
        src = fn.args[0];
        memo = fn.args[1];
        null_bb = fn.append_basic_block("deep.null");
        probe_bb = fn.append_basic_block("deep.probe");
        hit_bb = fn.append_basic_block("deep.hit");
        fresh_bb = fn.append_basic_block("deep.fresh");
        self.builder.cbranch(
            self.builder.icmp_unsigned(
                "==", src, ir.Constant(ty, None), name="deep.isnull"
            ),
            null_bb,
            probe_bb
        );
        self.builder.position_at_end(null_bb);
        self.builder.ret(ir.Constant(ty, None));
        self.builder.position_at_end(probe_bb);
        slot = self.builder.call(
            memo_helpers["lookup"],
            [memo, self.builder.ptrtoint(src, i64, name="memo.key")],
            name="memo.slot"
        );
        self.builder.cbranch(
            self.builder.icmp_unsigned(
                "!=", slot, ir.Constant(slot.type, None), name="memo.seen"
            ),
            hit_bb,
            fresh_bb
        );
        self.builder.position_at_end(hit_bb);
        _prior = self.builder.inttoptr(
            self.builder.load(slot, name="memo.dst"), ty, name="memo.prior"
        );
        self._copy_retain(ty, _prior);
        self.builder.ret(_prior);
        self.builder.position_at_end(fresh_bb);
        if shape == "arch" {
            self.builder.ret(
                self._emit_copy_dispatch(src, info, True, memo, nd, "deepcopy")
            );
        } else {
            _args = self._container_type_args(hint);
            self.builder.ret(
                self._deepcopy_container(shape, info, src, memo, _args, nd)
            );
        }
    } finally {
        self._leave_function(state);
    }
    return fn;
}

impl NaIRGenPass._deepcopy_container(
    shape: str,
    spec: str,
    src: ir.Value,
    memo: ir.Value,
    type_args: list[TypeBase],
    nd: uni.UniNode
) -> ir.Value {
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    if shape == "set" {
        _new_set = self._dispatch_primitive_method("set", "copy", src, [], spec);
        assert _new_set is not None , f"native set.copy() is emitted for spec {spec}";
        self._copy_memo_record(memo, src, _new_set);
        return _new_set;
    }
    helpers = self.list_helpers[spec] if shape == "list" else self.dict_helpers[spec];
    dst = self.builder.call(helpers["new"], [], name=f"deep.{shape}.new");
    self._copy_memo_record(memo, src, dst);
    count = self.builder.load(
        self.builder.gep(src, [ir.Constant(i32, 0), ir.Constant(i32, 0)]),
        name=f"deep.{shape}.len"
    );
    fn = self.builder.function;
    entry_bb = self.builder.block;
    loop_bb = fn.append_basic_block(f"deep.{shape}.loop");
    body_bb = fn.append_basic_block(f"deep.{shape}.body");
    done_bb = fn.append_basic_block(f"deep.{shape}.done");
    self.builder.branch(loop_bb);
    self.builder.position_at_end(loop_bb);
    idx = self.builder.phi(i64, name=f"deep.{shape}.i");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    self.builder.cbranch(
        self.builder.icmp_signed("<", idx, count, name=f"deep.{shape}.more"),
        body_bb,
        done_bb
    );
    self.builder.position_at_end(body_bb);
    if shape == "list" {
        _elem_ty = helpers["elem_type"];
        _elem_hint = type_args[0] if type_args else None;
        _elem = self.builder.call(helpers["get"], [src, idx], name="deep.elem");
        if self._copy_is_atomic(_elem_ty, _elem_hint, True) {
            self.builder.call(helpers["append"], [dst, _elem]);
        } else {
            _new = self._copy_value(_elem, _elem_hint, True, memo, nd, "deepcopy");
            _new = self._coerce_type(_new, _elem_ty);
            self.builder.call(helpers["append"], [dst, _new]);
            self._copy_release(_elem_ty, _new);
        }
    } else {
        _val_ty = helpers["val_type"];
        _val_hint = type_args[1] if len(type_args) > 1 else None;
        _key = self.builder.call(helpers["get_key"], [src, idx], name="deep.key");
        _val = self.builder.call(helpers["get_val"], [src, idx], name="deep.val");
        if self._copy_is_atomic(_val_ty, _val_hint, True) {
            self.builder.call(helpers["set"], [dst, _key, _val]);
        } else {
            _new = self._copy_value(_val, _val_hint, True, memo, nd, "deepcopy");
            _new = self._coerce_type(_new, _val_ty);
            self.builder.call(helpers["set"], [dst, _key, _new]);
            self._copy_release(_val_ty, _new);
        }
    }
    idx.add_incoming(
        self.builder.add(idx, ir.Constant(i64, 1), name=f"deep.{shape}.next"),
        self.builder.block
    );
    self.builder.branch(loop_bb);
    self.builder.position_at_end(done_bb);
    return dst;
}
