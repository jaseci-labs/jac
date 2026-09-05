import from jaclang.compiler.expr_keys { type_tag_borrows }
impl NaIRGenTypes._lower_type(t: any) -> (ir.Type | None) {
    if t is None {
        return None;
    }
    try {
        import from jaclang.compiler.types.types {
            ClassType as _ClassType,
            UnionType as _UnionType,
            FunctionType as _FunctionType,
            NeverType as _NeverType,
            AnyType as _AnyType,
            TypeVarType as _TypeVarType,
            EnumMemberType as _EnumMemberType
        }
    } except ImportError {
        return None;
    }
    if isinstance(t, _TypeVarType) {
        _sol = self._mono_solution;
        if _sol is not None and t.name in _sol {
            return self._lower_type(_sol[t.name]);
        }
        return None;
    }
    key = self._mangled_of(t);
    if key is not None and key in self._lowered_type_cache {
        return self._lowered_type_cache[key];
    }
    lowered: (ir.Type | None) = None;
    if isinstance(t, _NeverType) {
        lowered = ir.VoidType();
    } elif isinstance(t, _AnyType) {
        lowered = self.jacval_type;
    } elif isinstance(t, _EnumMemberType) {
        lowered = self._lower_type(t.enum_class) if t.enum_class is not None else None;
    } elif isinstance(t, _ClassType) {
        lowered = self._lower_class_type(t);
    } elif isinstance(t, _UnionType) {
        lowered = ir.VoidType();
        _members: list = [];
        for m in (t.types or []) {
            if isinstance(m, _ClassType)
                and m.shared.class_name in ("NoneType", "None") {
                continue;
            }
            _members.append(m);
        }
        _had_none = len(_members) < len(t.types or []);
        if _members {
            _mreprs: list = [];
            for _m in _members {
                _mr = self._lower_type(_m);
                if self._str_desc_ty is not None and _mr == self._str_desc_ty {
                    _mr = ir.IntType(8).as_pointer();
                }
                _mreprs.append(_mr);
            }
            _mlow = self._unify_repr_lowering(_mreprs);
            if (
                _had_none
                and len(_members) == 1
                and _mlow is not None
                and not isinstance(_mlow, ir.VoidType)
            ) {
                lowered = self._jac_optional_type(_mlow);
            } else {
                lowered = _mlow;
            }
        }
    } elif isinstance(t, _FunctionType) {
        lowered = self._lower_function_type(t);
    }
    if key is not None and lowered is not None {
        self._lowered_type_cache[key] = lowered;
    }
    return lowered;
}

impl NaIRGenTypes._unify_repr_lowering(reprs: list) -> (ir.Type | None) {
    """One representation for a set of lowerings that share a slot.

    Members that share a lowering keep it. An all-pointer set keeps the
    first member's layout only when every member is the same kind of
    pointer, or when every member is callable: a closure struct and a raw
    function pointer meet at one calling convention once the raw function
    is wrapped into a closure (`_coerce_type` does the wrapping), so the
    closure layout is the union's layout and boxing them would leave
    nothing callable behind. Any other mix, including two headered heap
    kinds such as `list | Expr` in the unitree, boxes to a tagged jacval so
    the payload is never reinterpreted through the wrong layout.
    """;
    if not reprs {
        return None;
    }
    _first = reprs[0];
    _rest = reprs[1:];
    if _first is None or not _rest {
        return _first;
    }
    _shared = True;
    _all_ptr = isinstance(_first, ir.PointerType);
    for _r in _rest {
        if _r is None {
            return _first;
        }
        if _r != _first {
            _shared = False;
        }
        if not isinstance(_r, ir.PointerType) {
            _all_ptr = False;
        }
    }
    if _shared or not self?.jacval_type {
        return _first;
    }
    if _all_ptr {
        _kinds = [self._ptr_box_kind(_first)];
        for _r in _rest {
            _kinds.append(self._ptr_box_kind(_r));
        }
        _same_kind = True;
        _all_callable = True;
        for _k in _kinds {
            if _k != _kinds[0] {
                _same_kind = False;
            }
            if _k != 7 {
                _all_callable = False;
            }
        }
        if _same_kind {
            return _first;
        }

        if _all_callable {
            for _r in reprs {
                if self._closure_struct_of(_r) is not None {
                    return _r;
                }
            }
            return _first;
        }
    }
    return self.jacval_type;
}

impl NaIRGenTypes._ptr_box_kind(rt: any) -> int {
    if isinstance(rt, ir.PointerType) and isinstance(rt.pointee, ir.FunctionType) {
        return 7;
    }
    if self._closure_struct_of(rt) is not None {
        return 7;
    }
    for (_, ltype) in self.list_types.items() {
        if rt == ltype.as_pointer() {
            return 3;
        }
    }
    for (_, dtype) in self.dict_types.items() {
        if rt == dtype.as_pointer() {
            return 4;
        }
    }
    for (_, stype) in self.set_types.items() {
        if rt == stype.as_pointer() {
            return 5;
        }
    }
    for (_, structt) in self.struct_types.items() {
        if rt == structt.as_pointer() {
            return 6;
        }
    }
    return 2;
}

impl NaIRGenTypes._type_key_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    return self._mangled_of(expr.type);
}

impl NaIRGenTypes._enum_name_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    try {
        import from jaclang.compiler.types.types { EnumMemberType as _EnumMemberType }
    } except ImportError {
        return None;
    }
    import from jaclang.compiler.passes.layout_pass {
        is_enum_class_type as _is_enum_type
    }
    t = expr.type;
    if isinstance(t, _EnumMemberType) and t.enum_class is not None {
        return t.enum_class.shared.class_name;
    }
    if _is_enum_type(t) {
        return t.shared.class_name;
    }
    return None;
}

impl NaIRGenTypes._tuple_key_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    tk = self._mangled_of(expr.type);
    if not tk.startswith("tuple[") {
        return None;
    }
    lowered = self._lower_type(expr.type);
    if lowered is None
        or not isinstance(lowered, ir.PointerType)
        or not isinstance(lowered.pointee, ir.LiteralStructType) {
        return None;
    }
    elems = lowered.pointee.elements;
    return f"Tuple.{len(elems)}." + ".".join([str(x) for x in elems]);
}

impl NaIRGenTypes._set_spec_of(expr: (uni.UniNode | None)) -> (str | None) {
    return self._spec_of(expr, ("set", "frozenset"), self.set_types);
}

impl NaIRGenTypes._dict_key_of(expr: (uni.UniNode | None)) -> (str | None) {
    return self._spec_of(expr, ("dict", ), self.dict_types);
}

impl NaIRGenTypes._list_spec_of(expr: (uni.UniNode | None)) -> (str | None) {
    return self._spec_of(expr, ("list", "bytearray", "Sequence"), self.list_types);
}

impl NaIRGenTypes._spec_of(
    expr: (uni.UniNode | None), names: tuple, registry: dict
) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    _t = expr.type;
    tk = self._mangled_of(_t);
    matched = self._spec_name_match(tk, names);
    if not matched {
        _sole = self._opt_sole_member(_t);
        if _sole is not None {
            _t = _sole;
            tk = self._mangled_of(_t);
            matched = self._spec_name_match(tk, names);
        }
    }
    if not matched {
        _agreed = self._spec_union_agreement(_t, names);
        if _agreed is not None {
            _t = _agreed;
            tk = self._mangled_of(_t);
            matched = True;
        }
    }
    if not matched {
        if self._na_debug_on() and ("Sequence" in tk or "UniNode" in tk) {
            import sys as _so_sys;
            _so_sys.stderr.write(f"SPECMISS {tk}\n");
        }
        return None;
    }
    lowered = self._lower_type(_t);
    if lowered is None {
        return None;
    }
    for (spec, st) in registry.items() {
        if lowered == st.as_pointer() {
            return spec;
        }
    }
    return None;
}

impl NaIRGenTypes._spec_name_match(tk: str, names: tuple) -> bool {
    if tk in names {
        return True;
    }
    for nm in names {
        if tk.startswith(nm + "[") {
            return True;
        }
    }
    return False;
}

impl NaIRGenTypes._opt_sole_member(t: any) -> (any | None) {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _OsClassType,
            UnionType as _OsUnionType
        }
    } except ImportError {
        return None;
    }
    if not isinstance(t, _OsUnionType) {
        return None;
    }
    _all = t.types or [];
    _members = [
        m
        for m in _all
        if not (
            isinstance(m, _OsClassType)
            and m._shared is not None
            and m.shared.class_name in ("NoneType", "None")
        )
    ];
    if len(_members) != 1 or len(_members) == len(_all) {
        return None;
    }
    return _members[0];
}

impl NaIRGenTypes._spec_union_agreement(t: any, names: tuple) -> (any | None) {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _SuClassType,
            UnionType as _SuUnionType
        }
    } except ImportError {
        return None;
    }
    if not isinstance(t, _SuUnionType) {
        return None;
    }
    _members = [
        m
        for m in (t.types or [])
        if not (
            isinstance(m, _SuClassType)
            and m._shared is not None
            and m.shared.class_name in ("NoneType", "None")
        )
    ];
    if len(_members) < 2 {
        return None;
    }
    _low: any = None;
    for m in _members {
        if not self._spec_name_match(self._mangled_of(m), names) {
            return None;
        }
        _ml = self._lower_type(m);
        if _ml is None {
            return None;
        }
        if _low is None {
            _low = _ml;
        } elif _ml != _low {
            return None;
        }
    }
    return _members[0];
}

impl NaIRGenTypes._struct_name_of(expr: (uni.UniNode | None)) -> (str | None) {
    """Which archetype layout a receiver's field access should address.

    Two questions have to be answered together: *which type* to ask about,
    and *which key* that type resolves through. The type is the narrow the
    analysis stamped for this occurrence when there is one, so a receiver
    guarded by `isinstance` addresses the class it was narrowed to. The key
    is then resolved by `_struct_name_for_key`, which sees through a
    parameterised or union-mangled name to the base archetype the layout was
    built for -- a narrow that produces `SubTag[Token]` still has to land on
    `SubTag`.
    """;
    _narrowed = self._struct_name_for_key(
        self._mangled_of(self._flow_narrowed_type_of(expr))
    );
    if (
        isinstance(expr, uni.Name)
        and expr.value == "self"
        and self._self_arch is not None
    ) {
        if _narrowed is not None
            and _narrowed != self._self_arch
            and self._self_arch in self._mro_of(_narrowed) {
            return _narrowed;
        }
        return self._self_arch;
    }
    return _narrowed;
}

impl NaIRGenTypes._struct_name_for_key(tk: (str | None)) -> (str | None) {
    if tk is None {
        return None;
    }
    if tk in self.struct_types {
        return tk;
    }
    _arch_parts = [
        part
        for part in self._split_union_key(tk)
        if part in self.struct_types
    ];
    if len(_arch_parts) == 1 {
        return _arch_parts[0];
    }
    if _arch_parts {
        for _anc in self._mro_of(_arch_parts[0]) {
            if _anc not in self.struct_types {
                continue;
            }
            _in_all = True;
            for _other in _arch_parts[1:] {
                if _anc not in self._mro_of(_other) {
                    _in_all = False;
                    break;
                }
            }
            if _in_all {
                return _anc;
            }
        }
        return None;
    }
    for part in self._split_union_key(tk) {
        _base = self._erased_arch_base(part);
        if _base is not None {
            return _base;
        }
    }
    return None;
}

impl NaIRGenTypes._erased_arch_base(tk: str) -> (str | None) {
    _open = tk.find("[");
    if _open <= 0 or not tk.endswith("]") {
        return None;
    }
    _base = tk[:_open];
    return _base if _base in self.struct_types else None;
}

impl NaIRGenTypes._split_union_key(tk: str) -> list[str] {
    if "|" not in tk {
        return [tk];
    }
    out: list[str] = [];
    depth = 0;
    start = 0;
    for i in range(len(tk)) {
        ch = tk[i];
        if ch == "[" {
            depth += 1;
        } elif ch == "]" {
            depth -= 1;
        } elif ch == "|" and depth == 0 {
            out.append(tk[start:i]);
            start = i + 1;
        }
    }
    out.append(tk[start:]);
    return out;
}

impl NaIRGenTypes._flow_narrowed_type_of(expr: (uni.UniNode | None)) -> (any | None) {
    """The narrow the analysis pipeline stamped on this occurrence.

    `Expr.type` records what the evaluator computed for the expression, and
    for a `Name` that is already the narrowed view -- the symbol's narrow is
    folded into the type that gets stored. A member or subscript reference is
    different: the evaluator stores the *member's* type there and hands the
    narrow to its caller, so `Expr.narrowed_type` is where that answer is
    kept. Reading it is a consumption of a central fact; the backend never
    asks analysis to compute one.
    """;
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    _nt = expr.narrowed_type;
    return _nt if _nt is not None else expr.type;
}

impl NaIRGenTypes._struct_ptr_pointee_name(val: ir.Value) -> (str | None) {
    _vt = val.type;
    if isinstance(_vt, ir.PointerType)
        and isinstance(_vt.pointee, ir.IdentifiedStructType) {
        _name = _vt.pointee.name;
        if _name in self.struct_types and self.struct_types[_name] == _vt.pointee {
            return _name;
        }
    }
    return None;
}

impl NaIRGenTypes._struct_array_elem_ptr(ptr: ir.Value, idx_val: ir.Value) -> ir.Value {
    _i64 = ir.IntType(64);
    _wide_idx = (
        idx_val
            if idx_val.type == _i64
            else self.builder.sext(idx_val, _i64, name="arr.idx.i64")
    );
    return self.builder.gep(ptr, [_wide_idx], name="ptr.elem.ptr");
}

impl NaIRGenTypes._list_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None) {
    return self._typed_elem_llvm_of(expr, "list[");
}

impl NaIRGenTypes._iter_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None) {
    return self._typed_elem_llvm_of(expr, "Iterator[");
}

impl NaIRGenTypes._typed_elem_llvm_of(
    expr: (uni.UniNode | None), prefix: str
) -> (ir.Type | None) {
    """Element storage for a container-typed expression.

    The type reaching here can be a union: a field read off a joined narrow
    (`isinstance(item, (TupleVal, ListVal))` then `item.values`) has one
    member type per narrowed class, and a union carries no `private` of its
    own. Members that agree on the container shape agree on its element type
    too, so the first matching member answers for all of them.

    An optional container (`list[T] | None`, the shape every `has` slot that
    defaults to `None` carries) is the same question asked of one member.
    Its mangle is the union's, so the prefix test has to be retried against
    the sole non-`None` member or the element type erases -- a comprehension
    or for-loop over `x.parts or []` would then walk elements it has no
    layout for. `_opt_sole_member` is the same unwrap `_list_spec_of` uses
    to recognise the container itself, so the two answers stay congruent.
    """;
    _ty = self._flow_narrowed_type_of(expr);
    if _ty is None {
        return None;
    }
    _mg = self._mangled_of(_ty);
    if _mg is None or not _mg.startswith(prefix) {
        _sole = self._opt_sole_member(_ty);
        _sole_mg = self._mangled_of(_sole) if _sole is not None else None;
        if _sole_mg is None or not _sole_mg.startswith(prefix) {
            return None;
        }
        _ty = _sole;
    }
    for _cand in (_ty?.types or [_ty]) {
        _priv = _cand?.private;
        if _priv is not None and (_priv?.type_args or []) {
            _ty = _cand;
            break;
        }
    }
    _priv = _ty?.private;
    args = (_priv?.type_args or []) if _priv is not None else [];
    if not args {
        return None;
    }
    lowered = self._elem_storage_llvm(args[0]);
    if lowered is not None and isinstance(lowered, ir.VoidType) {
        return ir.IntType(64);
    }
    return lowered;
}

impl NaIRGenTypes._elem_storage_llvm(t: any) -> (ir.Type | None) {
    if t is None {
        return None;
    }
    try {
        import from jaclang.compiler.types.types {
            ClassType as _EsClassType,
            UnionType as _EsUnionType
        }
    } except ImportError {
        return self._lower_type(t);
    }
    if not isinstance(t, _EsUnionType) {
        return self._lower_type(t);
    }
    _members = [
        m
        for m in (t.types or [])
        if not (
            isinstance(m, _EsClassType)
            and m._shared is not None
            and m.shared.class_name in ("NoneType", "None")
        )
    ];
    _had_none = len(_members) < len(t.types or []);
    if not _members {
        return self._lower_type(t);
    }
    _lowered: list = [];
    for m in _members {
        _ml = self._lower_type(m);
        if _ml is None {
            return self.jacval_type;
        }
        _lowered.append(_ml);
    }
    _first = _lowered[0];
    _all_same = True;
    _all_ptr = isinstance(_first, ir.PointerType);
    for _ml in _lowered[1:] {
        if _ml != _first {
            _all_same = False;
        }
        if not isinstance(_ml, ir.PointerType) {
            _all_ptr = False;
        }
    }
    if _all_ptr {
        if _all_same and not _had_none {
            return _first;
        }
        return _first if _all_same else ir.IntType(8).as_pointer();
    }
    if _had_none or not _all_same {
        return self.jacval_type;
    }
    return _first;
}

impl NaIRGenTypes._static_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None) {
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    _t = expr.type;
    if _t is None and isinstance(expr, uni.Name) and expr.sym is not None {
        _decl = expr.sym.decl;
        _t = _decl?.type;
        if _t is None and isinstance(_decl?.parent, (uni.ParamVar, uni.HasVar)) {
            _t = _decl.parent?.type;
        }
    }
    if _t is None {
        return None;
    }
    _names = ("list", "set", "frozenset", "Sequence");
    if not self._spec_name_match(self._mangled_of(_t) or "", _names) {
        _sole = self._opt_sole_member(_t);
        if _sole is None
            or not self._spec_name_match(self._mangled_of(_sole) or "", _names) {
            return None;
        }
        _t = _sole;
    }
    _args = _t.private.type_args or [];
    if not _args {
        return None;
    }
    _low = self._elem_storage_llvm(_args[0]);
    if _low is None or isinstance(_low, ir.VoidType) {
        return None;
    }
    if self?.jacval_type and _low == self.jacval_type {
        return None;
    }
    if self._str_desc_ty is not None and _low == self._str_desc_ty {
        return ir.IntType(8).as_pointer();
    }
    return _low;
}

impl NaIRGenTypes._elem_spec_of(expr: (uni.UniNode | None)) -> (str | None) {
    et = self._list_elem_llvm_of(expr);
    if et is None {
        return None;
    }
    if self._str_desc_ty is not None and et == self._str_desc_ty {
        return "ptr";
    }
    if isinstance(et, ir.DoubleType) {
        return "f64";
    }
    if isinstance(et, ir.PointerType) {
        return "ptr";
    }
    if self?.jacval_type and et == self.jacval_type {
        return "jacval";
    }
    return "i64";
}

impl NaIRGenTypes._lower_view_container(t: any) -> (ir.Type | None) {
    try {
        import from jaclang.compiler.types.types { ClassType as _VcClassType }
    } except ImportError {
        return None;
    }
    if not isinstance(t, _VcClassType) or t._shared is None {
        return None;
    }
    if t.shared.class_name not in ("list", "Sequence") {
        return None;
    }
    _args = t.private.type_args or [];
    if not _args {
        return None;
    }
    _elem = self._elem_storage_llvm(_args[0]);
    if _elem is None {
        return None;
    }
    return self._lower_list_for_elem(_elem);
}

impl NaIRGenTypes._lower_class_type(t: any) -> (ir.Type | None) {
    cname = t.shared.class_name;
    if cname in self.type_map {
        return self.type_map[cname];
    }
    if cname in ("NoneType", "None") {
        return ir.VoidType();
    }

    if cname in ("any", "Any", "object") {
        return self.jacval_type;
    }

    if cname == "File" {
        return self._get_file_struct_type().as_pointer();
    }

    if cname == "BinaryFile" {
        return self._get_binary_file_struct_type().as_pointer();
    }

    if cname == "bytes" {
        return self._get_bytes_struct_type().as_pointer();
    }

    if cname == "bytearray" {
        return self._ensure_bytearray_type();
    }

    _enum_ty = self._ensure_enum_lowered(t);
    if _enum_ty is not None {
        return _enum_ty;
    }
    if cname in self.struct_types {
        return self.struct_types[cname].as_pointer();
    }
    type_args = t.private.type_args or [];

    if cname in ("Iterator", "Iterable") {
        self._ensure_iter_types();
        return self._jac_iter_type.as_pointer();
    }

    if cname in ("list", "Sequence") {
        elem_llvm: ir.Type = ir.IntType(64);
        if type_args {
            _aos_t = self._aos_elem_name(type_args[0]);
            if _aos_t is not None {
                return self._emit_aos_list_helpers(_aos_t).as_pointer();
            }
            _e = self._elem_storage_llvm(type_args[0]);
            if _e is None {
                return None;
            }
            elem_llvm = _e;
        }
        return self._lower_list_for_elem(elem_llvm);
    }

    if cname == "dict" {
        k_llvm: ir.Type = ir.IntType(64);
        v_llvm: ir.Type = ir.IntType(64);
        if len(type_args) >= 2 {
            _k = self._elem_storage_llvm(type_args[0]);
            _v = self._elem_storage_llvm(type_args[1]);
            if _k is None or _v is None {
                return None;
            }
            if self?.jacval_type and _k == self.jacval_type {
                return None;
            }
            k_llvm = _k;
            v_llvm = _v;
        }
        if self._str_desc_ty is not None {
            if k_llvm == self._str_desc_ty {
                k_llvm = ir.IntType(8).as_pointer();
            }
            if v_llvm == self._str_desc_ty {
                v_llvm = ir.IntType(8).as_pointer();
            }
        }

        (k_spec, k_size) = self._dict_key_spec(k_llvm);
        v_spec = self._dict_val_spec(v_llvm);
        self._emit_dict_helpers(k_spec, v_spec, k_llvm, v_llvm, k_size);
        return self.dict_types[f"{k_spec}:{v_spec}"].as_pointer();
    }

    if cname in ("set", "frozenset") {
        elem_llvm: ir.Type = ir.IntType(64);
        if type_args {
            _e = self._elem_storage_llvm(type_args[0]);
            if _e is None {
                return None;
            }
            if self?.jacval_type and _e == self.jacval_type {
                return None;
            }
            elem_llvm = _e;
        }
        if self._str_desc_ty is not None and elem_llvm == self._str_desc_ty {
            elem_llvm = ir.IntType(8).as_pointer();
        }
        spec = "i64";
        esize = 0;
        if isinstance(elem_llvm, ir.DoubleType) {
            spec = "f64";
        } elif isinstance(elem_llvm, ir.PointerType) {
            spec = "ptr";
            if isinstance(elem_llvm.pointee, ir.LiteralStructType) {
                esize = self._get_struct_size(elem_llvm.pointee);
                spec = self._tuple_spec_name(elem_llvm.pointee);
            }
        }
        self._emit_set_helpers(spec, elem_llvm, esize);
        return self.set_types[spec].as_pointer();
    }

    if cname == "tuple" {
        if not type_args {
            return None;
        }
        _var_seq = self._variadic_tuple_seq_type(type_args);
        if _var_seq is not None {
            return _var_seq;
        }
        elem_types: list[ir.Type] = [];
        for a in type_args {
            _et = self._lower_type(a);
            if _et is None {
                return None;
            }
            if self._str_desc_ty is not None and _et == self._str_desc_ty {
                _et = ir.IntType(8).as_pointer();
            }
            elem_types.append(_et);
        }
        return self._tuple_struct_of(elem_types).as_pointer();
    }
    return None;
}

impl NaIRGenTypes._lower_function_type(t: any) -> ir.Type {
    raw = self._lower_function_type_raw(t);
    (_sig_name, sig_st, _fnty_env) = self._closure_sig_struct(raw.pointee);
    return sig_st.as_pointer();
}

impl NaIRGenTypes._lower_function_type_raw(t: any) -> ir.Type {
    ret_type: ir.Type = ir.VoidType();
    if t.return_type is not None {
        _r = self._lower_type(t.return_type);
        if _r is not None {
            ret_type = _r;
        }
    }
    param_types: list[ir.Type] = [];
    for p in (t.parameters or []) {
        _p = self._lower_type(p.param_type);
        if _p is None {
            param_types.append(ir.IntType(64));
        } else {
            param_types.append(_p);
        }
    }
    return ir.FunctionType(ret_type, param_types).as_pointer();
}

impl NaIRGenTypes._aos_elem_of(type_expr: (uni.UniNode | None)) -> (str | None) {
    nd = type_expr;
    if isinstance(nd, uni.ParamVar) {
        nd = nd.type_tag;
    }
    if isinstance(nd, uni.SubTag) {
        nd = nd.tag;
    }
    if isinstance(nd, uni.UnaryExpr) {
        nd = nd.operand;
    }
    _t = nd?.type if isinstance(nd, uni.Expr) else None;
    if _t is None {
        return None;
    }
    _sole = self._opt_sole_member(_t);
    if _sole is not None {
        _t = _sole;
    }
    _priv = _t?.private;
    _args = (_priv?.type_args or []) if _priv is not None else [];
    _shared = _t?.shared;
    if _shared is None or _shared.class_name != "list" or not _args {
        return None;
    }
    return self._aos_elem_name(_args[0]);
}

impl NaIRGenTypes._aos_elem_name(t: any) -> (str | None) {
    if t is None or not self._nogc_owned_world() {
        return None;
    }
    try {
        import from jaclang.compiler.types.types {
            ClassType as _AeClassType,
            TypeVarType as _AeTypeVarType
        }
    } except ImportError {
        return None;
    }
    if isinstance(t, _AeTypeVarType) {
        _sol = self._mono_solution;
        if _sol is None or t.name not in _sol {
            return None;
        }
        return self._aos_elem_name(_sol[t.name]);
    }
    if not isinstance(t, _AeClassType) or t._shared is None {
        return None;
    }
    _tn = t.shared.class_name;
    if _tn not in self.struct_types {
        return None;
    }
    _lay = self._arch_layout(_tn);
    if _lay is None or _lay.is_osp or _lay.arch_type == "walker" {
        return None;
    }
    if self._program_has_subclasses(_tn) {
        return None;
    }
    _fields = self.struct_field_types.get(_tn) or {};
    for (_fname, _fty) in _fields.items() {
        if isinstance(_fty, ir.PointerType) or self._opt_payload_of(_fty) is not None {
            return None;
        }
    }
    return _tn;
}

impl NaIRGenTypes._program_has_subclasses(arch_name: str) -> bool {
    if self._subclassed_arch_names is None {
        _cached = getattr(self.prog, "_na_subclassed_arch_names", None);
        if isinstance(_cached, set) {
            self._subclassed_arch_names = _cached;
            return arch_name in _cached;
        }
        _names: set[str] = set();
        _mods: list = [];
        try {
            _mods = list(self.prog.mod.hub.values());
        } except Exception {
            _mods = [];
        }
        if self.ir_in not in _mods {
            _mods.append(self.ir_in);
        }
        for _mod in _mods {
            for _arch in _mod.get_all_sub_nodes(uni.Archetype) {
                for _base in (_arch.base_classes or []) {
                    _bn = self._get_name(_base);
                    if _bn is not None {
                        _names.add(_bn);
                    }
                }
            }
        }
        self._subclassed_arch_names = _names;
        try {
            self.prog._na_subclassed_arch_names = _names;
        } except Exception {}
    }
    return arch_name in self._subclassed_arch_names;
}

impl NaIRGenTypes._resolve_sig_type(type_expr: (uni.UniNode | None)) -> ir.Type {
    _ptb = type_expr?.type;
    if _ptb is not None {
        lowered = self._lower_type(_ptb);
        if lowered is not None {
            if self._str_desc_ty is not None and lowered == self._str_desc_ty {
                lowered = ir.IntType(8).as_pointer();
            }
            return lowered;
        }
        if self._foreign_optional_field(_ptb) {
            return ir.IntType(8).as_pointer();
        }
        if self._typevar_optional_field(_ptb) {
            return ir.IntType(8).as_pointer();
        }
        _sig_seq = self._erased_seq_type(_ptb);
        if _sig_seq is not None {
            return _sig_seq;
        }
        if not self._type_base_is_unknown(_ptb) {
            _sig_shared = _ptb?.shared;
            _sig_cn = _sig_shared.class_name if _sig_shared is not None else None;
            if _sig_cn in ("tuple", "list", "dict", "set", "type") {
                _sig_lmark = len(self.errors_had);
                _sig_res = self._resolve_jac_type(type_expr);
                if len(self.errors_had) == _sig_lmark {
                    return _sig_res;
                }
                del self.errors_had[_sig_lmark:];
            }
            return ir.IntType(8).as_pointer();
        }
    }

    _sig_out = self._resolve_jac_type(type_expr);
    if self._str_desc_ty is not None and _sig_out == self._str_desc_ty {
        return ir.IntType(8).as_pointer();
    }
    return _sig_out;
}

impl NaIRGenTypes._resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type {
    if type_expr is None {
        return ir.IntType(64);
    }

    if isinstance(type_expr, uni.SubTag) and type_expr?.tag is not None {
        return self._resolve_jac_type(type_expr.tag);
    }

    _ptb = type_expr?.type;
    if _ptb is not None and not isinstance(type_expr, uni.Expr) {
        lowered = self._lower_type(_ptb);
        if lowered is not None {
            return lowered;
        }
        return self._emit_unlowerable_type(type_expr, _ptb);
    }
    if isinstance(type_expr, uni.Expr) {
        if type_expr.type is None {
            _structural = self._lower_untyped_annotation(type_expr);
            if _structural is not None {
                return _structural;
            }
            return self._emit_unlowerable_type(type_expr, None);
        }
        if type_tag_borrows(type_expr) {
            _view = self._lower_view_container(type_expr.type);
            if _view is not None {
                return _view;
            }
        }
        lowered = self._lower_type(type_expr.type);
        if lowered is not None {
            return lowered;
        }
        return self._emit_unlowerable_type(type_expr, type_expr.type);
    }

    if isinstance(type_expr, (uni.HasVar, uni.ParamVar))
        and type_expr.type_tag is not None {
        return self._resolve_jac_type(type_expr.type_tag.tag);
    }
    return ir.IntType(64);
}

impl NaIRGenTypes._resolve_decl_type(
    type_expr: (uni.UniNode | None), value: (uni.UniNode | None)
) -> ir.Type {
    if self._quiet_glob_type(type_expr) is None {
        widened = self._widened_tuple_decl_type(type_expr, value);
        if widened is not None {
            return widened;
        }
    }
    return self._resolve_jac_type(type_expr);
}

impl NaIRGenTypes._widened_tuple_decl_type(
    type_expr: (uni.UniNode | None), value: (uni.UniNode | None)
) -> (ir.Type | None) {
    if value is None or type_expr is None {
        return None;
    }
    nd = type_expr;
    if isinstance(nd, uni.SubTag) {
        nd = nd.tag;
    }
    _tb = nd?.type;
    if _tb is None {
        if not (isinstance(nd, uni.Name) and nd.value == "tuple") {
            return None;
        }
    } else {
        try {
            import from jaclang.compiler.types.types { ClassType as _WdClassType }
        } except ImportError {
            return None;
        }
        if not isinstance(_tb, _WdClassType)
            or _tb.shared.class_name != "tuple"
            or (_tb.private.type_args or []) {
            return None;
        }
    }
    if isinstance(value, uni.TupleVal) and not value.values {
        return self._tuple_struct_of([]).as_pointer();
    }
    return self._infer_global_init_type(value);
}

impl NaIRGenTypes._tuple_struct_of(elem_types: list) -> ir.Type {
    tuple_key = f"Tuple.{len(elem_types)}." + ".".join([str(x) for x in elem_types]);
    if tuple_key not in self.tuple_types {
        self.tuple_types[tuple_key] = ir.LiteralStructType(elem_types);
    }
    return self.tuple_types[tuple_key];
}

impl NaIRGenTypes._resolve_field_type(var: uni.UniNode) -> ir.Type {
    _ptb = var?.type;
    if _ptb is not None {
        try {
            import from jaclang.compiler.types.types { FunctionType as _FieldFnType }
            if isinstance(_ptb, _FieldFnType) {
                return self._lower_function_type_raw(_ptb);
            }
        } except ImportError {}
        lowered = self._lower_type(_ptb);
        if lowered is not None {
            if self._str_desc_ty is not None and lowered == self._str_desc_ty {
                lowered = ir.IntType(8).as_pointer();
            }
            return lowered;
        }
        if self._foreign_optional_field(_ptb) {
            return ir.IntType(8).as_pointer();
        }
        if self._typevar_optional_field(_ptb) {
            return ir.IntType(8).as_pointer();
        }
        try {
            import from jaclang.compiler.types.types { TypeVarType as _RfTypeVarType }
            if isinstance(_ptb, _RfTypeVarType) {
                return ir.IntType(8).as_pointer();
            }
        } except ImportError {}
        if not self._type_base_is_unknown(_ptb) {
            return self._emit_unlowerable_type(var, _ptb);
        }
    }

    _hv_tag = (
        var.type_tag.tag
            if isinstance(var, (uni.HasVar, uni.ParamVar)) and var.type_tag is not None
            else None
    );
    if _hv_tag is not None and _hv_tag?.type is None {
        _structural = self._lower_untyped_annotation(_hv_tag);
        if _structural is not None {
            if self._str_desc_ty is not None and _structural == self._str_desc_ty {
                _structural = ir.IntType(8).as_pointer();
            }
            return _structural;
        }

        _hv_opt = False;
        _hv_scan: list[uni.UniNode] = [_hv_tag];
        while _hv_scan {
            _hv_cur = _hv_scan.pop();
            if isinstance(_hv_cur, uni.AtomUnit) and _hv_cur.value is not None {
                _hv_cur = _hv_cur.value;
            }
            if isinstance(_hv_cur, uni.BinaryExpr)
                and isinstance(_hv_cur.op, uni.Token)
                and _hv_cur.op.value == "|" {
                _hv_scan.append(_hv_cur.left);
                _hv_scan.append(_hv_cur.right);
            } elif isinstance(_hv_cur, uni.Null)
                or (
                    isinstance(_hv_cur, uni.Name)
                    and _hv_cur.value in ("None", "NoneType")
                ) {
                _hv_opt = True;
            }
        }
        if _hv_opt {
            return ir.IntType(8).as_pointer();
        }
        return ir.IntType(64);
    }
    _rf_out = self._resolve_jac_type(var);
    if self._str_desc_ty is not None and _rf_out == self._str_desc_ty {
        return ir.IntType(8).as_pointer();
    }
    return _rf_out;
}

impl NaIRGenTypes._foreign_optional_field(tb: any) -> bool {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _FofClassType,
            UnionType as _FofUnionType,
            UnknownType as _FofUnknownType
        }
    } except ImportError {
        return False;
    }
    if not isinstance(tb, _FofUnionType) {
        return False;
    }
    _members = tb.types or [];
    _non_none = [
        m
        for m in _members
        if not (
            isinstance(m, _FofClassType)
            and m._shared is not None
            and m.shared.class_name in ("NoneType", "None")
        )
    ];
    if len(_non_none) == len(_members) or not _non_none {
        return False;
    }
    try {
        import from jaclang.compiler.types.types { TypeVarType as _FofTypeVarType }
    } except ImportError {
        return False;
    }
    for m in _non_none {
        if isinstance(m, _FofUnknownType) {
            continue;
        }
        if isinstance(m, _FofTypeVarType) {
            return False;
        }
        if isinstance(m, _FofClassType) and self._lower_type(m) is None {
            continue;
        }
        return False;
    }
    return True;
}

impl NaIRGenTypes._erased_typevar_names(tb: any) -> list[str] {
    try {
        import from jaclang.compiler.types.types { TypeVarType as _EtvTypeVarType }
    } except ImportError {
        return [];
    }
    if isinstance(tb, _EtvTypeVarType) and self._lower_type(tb) is None {
        return [tb.name];
    }
    if not self._typevar_optional_field(tb) {
        return [];
    }
    out: list[str] = [];
    for m in (tb.types or []) {
        if isinstance(m, _EtvTypeVarType) and m.name not in out {
            out.append(m.name);
        }
    }
    return out;
}

impl NaIRGenTypes._typevar_optional_field(tb: any) -> bool {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _TvoClassType,
            UnionType as _TvoUnionType,
            TypeVarType as _TvoTypeVarType
        }
    } except ImportError {
        return False;
    }
    if not isinstance(tb, _TvoUnionType) {
        return False;
    }
    _members = tb.types or [];
    _non_none = [
        m
        for m in _members
        if not (
            isinstance(m, _TvoClassType)
            and m._shared is not None
            and m.shared.class_name in ("NoneType", "None")
        )
    ];
    if len(_non_none) == len(_members) or not _non_none {
        return False;
    }
    for m in _non_none {
        if not isinstance(m, _TvoTypeVarType) or self._lower_type(m) is not None {
            return False;
        }
    }
    return True;
}

impl NaIRGenTypes._erased_seq_type(tb: any) -> (ir.Type | None) {
    """The pointer-element native list a `list[T]` signature slot erases to.

    A generic archetype is laid out once and its `T` slots are raw pointers,
    so a sequence *of* `T` is the pointer-flavoured list -- the same storage
    every erased reference already uses. Answering `None` here leaves the
    slot to the ordinary refusal path, which is what a sequence of anything
    else that fails to lower deserves.
    """;
    try {
        import from jaclang.compiler.types.types { ClassType as _EsqClassType }
    } except ImportError {
        return None;
    }
    if not isinstance(tb, _EsqClassType) or tb._shared is None {
        return None;
    }
    if tb.shared.class_name not in ("list", "Sequence") {
        return None;
    }
    _args = tb.private.type_args or [];
    if len(_args) != 1 or not self._erased_typevar_names(_args[0]) {
        return None;
    }
    self._emit_list_helpers("ptr", ir.IntType(8).as_pointer());
    return self.list_types["ptr"].as_pointer();
}

impl NaIRGenTypes._type_base_is_unknown(tb: any) -> bool {
    try {
        import from jaclang.compiler.types.types { UnknownType as _UnknownType }
        return isinstance(tb, _UnknownType);
    } except ImportError {
        return True;
    }
}

impl NaIRGenTypes._emit_unlowerable_type(type_expr: uni.UniNode, tb: any) -> ir.Type {
    if isinstance(type_expr, uni.Expr) {
        import from jaclang.compiler.tools.unparse_pass { unparse_node }
        _label = unparse_node(type_expr);
    } else {
        _tag = type_expr?.type_tag;
        _label = self._get_name(_tag?.tag) or str(tb);
    }
    self.emit(
        E5092, node_override=type_expr, kind=self._sig_decl_kind or "type", name=_label
    );

    import logging as _logging;
    _logging.getLogger("jaclang.native").debug(
        "[NaIRGenPass] _resolve_jac_type: unresolved type %r (type=%s) — "
        "defaulting to i64; consider adding an explicit type annotation",
        type_expr,
        type(type_expr).__name__,
    );
    return ir.IntType(64);
}

impl NaIRGenTypes._resolve_clib_type(type_expr: (uni.UniNode | None)) -> ir.Type {
    if type_expr is None {
        return ir.VoidType();
    }

    type_name: (str | None) = None;
    if isinstance(type_expr, uni.Name) and type_expr.value == "str" {
        return ir.IntType(8).as_pointer();
    }
    if isinstance(type_expr, uni.Name) {
        type_name = type_expr.value;
    } elif type_expr?.value and isinstance(type_expr?.value, str) {
        type_name = type_expr.value;
    }
    if type_name is not None and type_name in self.clib_struct_names {
        if type_name in self.clib_struct_abi_types {
            return self.clib_struct_abi_types[type_name];
        }
        return self.struct_types[type_name];
    }

    if type_name == "bytes" or type_name == "bytearray" {
        return ir.IntType(8).as_pointer();
    }

    try {
        import from jaclang.compiler.types.types { FunctionType as _ClibSigFnType }
        if isinstance(type_expr?.type, _ClibSigFnType) {
            return self._lower_function_type_raw(type_expr.type);
        }
    } except ImportError {}

    return self._resolve_jac_type(type_expr);
}

impl NaIRGenTypes._get_name(nd: (uni.UniNode | None)) -> (str | None) {
    if nd is None {
        return None;
    }
    if isinstance(nd, uni.Name) {
        return nd.value;
    }
    if nd?.sym_name {
        return nd.sym_name;
    }
    if nd?.value and isinstance(getattr(nd, "value"), str) {
        return nd.value;
    }
    return None;
}

impl NaIRGenTypes._entry_alloca(var_type: ir.Type, name: str) -> ir.Value {
    func = self.builder.function;

    _gc = self._gen_ctx;
    if _gc is not None and func is _gc["resume_fn"] {
        i64 = ir.IntType(64);
        size = self._abi_sizeof(var_type);
        offset = (_gc["cursor"] + 7) // 8 * 8;
        _gc["cursor"] = offset + size;
        _gc["slots"].append((name, offset, var_type));
        cur_block = self.builder.block;
        entry_block = func.entry_basic_block;
        if entry_block.instructions {
            self.builder.position_before(entry_block.instructions[0]);
        } else {
            self.builder.position_at_start(entry_block);
        }
        raw = self.builder.gep(
            _gc["frame_i8"], [ir.Constant(i64, offset)], name=f"{name}.slot"
        );
        slot = self.builder.bitcast(raw, var_type.as_pointer(), name=f"{name}.frame");
        self.builder.position_at_end(cur_block);
        return slot;
    }

    entry_block = func.entry_basic_block;

    cur_block = self.builder.block;

    if entry_block.instructions {
        self.builder.position_before(entry_block.instructions[0]);
    } else {
        self.builder.position_at_start(entry_block);
    }
    alloca = self.builder.alloca(var_type, name=name);

    self.builder.store(self._zero_const(var_type), alloca);

    self.builder.position_at_end(cur_block);
    return alloca;
}

impl NaIRGenTypes._stack_entry_alloca(var_type: ir.Type, name: str) -> ir.Value {
    func = self.builder.function;
    entry_block = func.entry_basic_block;
    cur_block = self.builder.block;
    if entry_block.instructions {
        self.builder.position_before(entry_block.instructions[0]);
    } else {
        self.builder.position_at_start(entry_block);
    }
    alloca = self.builder.alloca(var_type, name=name);
    self.builder.position_at_end(cur_block);
    return alloca;
}

impl NaIRGenTypes._abi_sizeof(t: ir.Type) -> int {
    if isinstance(t, (ir.IntType, ir.DoubleType, ir.PointerType, ir.FloatType)) {
        return 8;
    }
    if isinstance(t, ir.ArrayType) {
        return t.count * ((self._abi_sizeof(t.element) + 7) // 8 * 8);
    }
    elems = t?.elements;
    if elems {
        total = 0;
        for e in elems {
            total += (self._abi_sizeof(e) + 7) // 8 * 8;
        }
        return total;
    }
    raise RuntimeError(
        f"native codegen internal error: _abi_sizeof has no layout for {t!r}. "
        f"A generator-frame slot of unknown size would silently corrupt "
        f"adjacent slots; teach _abi_sizeof this type instead."
    );
}

impl NaIRGenTypes._to_bool(val: ir.Value) -> ir.Value {
    if self._str_desc_ty is not None and val.type == self._str_desc_ty {
        return self.builder.icmp_signed(
            "!=",
            self.builder.extract_value(
                val, len(list(self._str_desc_ty.elements)) - 1, name="s.tlen"
            ),
            ir.Constant(ir.IntType(64), 0),
            name="s.truthy"
        );
    }
    if isinstance(val.type, ir.IntType) and val.type.width == 1 {
        return val;
    }
    if self?.jacval_type and val.type == self.jacval_type {
        return self._jacval_truthy(val);
    }
    _tb_opt = self._opt_payload_of(val.type);
    if _tb_opt is not None {
        _tb_tag = self.builder.extract_value(val, 0, name="tobool.opt.tag");
        _tb_set = self.builder.icmp_signed(
            "!=", _tb_tag, ir.Constant(ir.IntType(8), 0), name="tobool.opt.set"
        );
        _tb_func = self.builder.basic_block.function;
        _tb_entry = self.builder.basic_block;
        _tb_pay_bb = _tb_func.append_basic_block(name="tobool.opt.payload");
        _tb_merge_bb = _tb_func.append_basic_block(name="tobool.opt.done");
        self.builder.cbranch(_tb_set, _tb_pay_bb, _tb_merge_bb);
        self.builder.position_at_start(_tb_pay_bb);
        _tb_pv = self.builder.extract_value(val, 1, name="tobool.opt.pv");
        _tb_t = self._to_bool(_tb_pv);
        _tb_pay_end = self.builder.basic_block;
        self.builder.branch(_tb_merge_bb);
        self.builder.position_at_start(_tb_merge_bb);
        _tb_phi = self.builder.phi(ir.IntType(1), name="tobool.opt");
        _tb_phi.add_incoming(ir.Constant(ir.IntType(1), 0), _tb_entry);
        _tb_phi.add_incoming(_tb_t, _tb_pay_end);
        return _tb_phi;
    }
    if isinstance(val.type, ir.IntType) {
        return self.builder.icmp_unsigned(
            "!=", val, ir.Constant(val.type, 0), name="tobool"
        );
    }
    if isinstance(val.type, (ir.DoubleType, ir.FloatType)) {
        return self.builder.fcmp_unordered(
            "!=", val, ir.Constant(val.type, 0.0), name="tobool"
        );
    }
    if isinstance(val.type, ir.PointerType) {
        _is_container = False;
        for (_, _lt) in self.list_types.items() {
            if val.type == _lt.as_pointer() {
                _is_container = True;
                break;
            }
        }
        if not _is_container {
            for (_, _dt) in self.dict_types.items() {
                if val.type == _dt.as_pointer() {
                    _is_container = True;
                    break;
                }
            }
        }
        if not _is_container {
            for (_, _st) in self.set_types.items() {
                if val.type == _st.as_pointer() {
                    _is_container = True;
                    break;
                }
            }
        }
        if _is_container {
            _i32 = ir.IntType(32);
            _tc_null = self.builder.icmp_unsigned(
                "==", val, ir.Constant(val.type, None), name="tobool.cont.null"
            );
            _tc_func = self.builder.basic_block.function;
            _tc_entry = self.builder.basic_block;
            _tc_len_bb = _tc_func.append_basic_block(name="tobool.cont.len");
            _tc_end_bb = _tc_func.append_basic_block(name="tobool.cont.end");
            self.builder.cbranch(_tc_null, _tc_end_bb, _tc_len_bb);
            self.builder.position_at_start(_tc_len_bb);
            _len_ptr = self.builder.gep(
                val, [ir.Constant(_i32, 0), ir.Constant(_i32, 0)], name="tobool.len.ptr"
            );
            _len = self.builder.load(_len_ptr, name="tobool.len");
            _tc_nonempty = self.builder.icmp_unsigned(
                "!=", _len, ir.Constant(ir.IntType(64), 0), name="tobool.cont.nonempty"
            );
            _tc_len_end = self.builder.basic_block;
            self.builder.branch(_tc_end_bb);
            self.builder.position_at_start(_tc_end_bb);
            _tc_phi = self.builder.phi(ir.IntType(1), name="tobool");
            _tc_phi.add_incoming(ir.Constant(ir.IntType(1), 0), _tc_entry);
            _tc_phi.add_incoming(_tc_nonempty, _tc_len_end);
            return _tc_phi;
        }

        if self._is_bytes_value(val) {
            return self._emit_bytes_truthy(val);
        }

        if val.type == ir.IntType(8).as_pointer() {
            return self._call_str_truthy(self.builder, val, name="tobool.str");
        }

        null_ptr = ir.Constant(val.type, None);
        return self.builder.icmp_unsigned("!=", val, null_ptr, name="tobool");
    }
    return val;
}


impl NaIRGenTypes._jacval_truthy(jv: ir.Value) -> ir.Value {
    b = self.builder;
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    tag = b.extract_value(jv, 0, name="jv.truthy.tag");
    payload = b.extract_value(jv, 1, name="jv.truthy.payload");
    func = b.function;
    str_bb = func.append_basic_block(name="jv.truthy.str");
    cont_chk_bb = func.append_basic_block(name="jv.truthy.cont.chk");
    cont_len_bb = func.append_basic_block(name="jv.truthy.cont.len");
    scalar_bb = func.append_basic_block(name="jv.truthy.scalar");
    merge_bb = func.append_basic_block(name="jv.truthy.end");

    is_str = b.icmp_unsigned("==", tag, ir.Constant(i8, 2), name="jv.truthy.isstr");
    str_nn = b.icmp_unsigned(
        "!=", payload, ir.Constant(i64, 0), name="jv.truthy.str.nn"
    );
    do_str = b.and_(is_str, str_nn, name="jv.truthy.dostr");
    b.cbranch(do_str, str_bb, cont_chk_bb);

    b.position_at_end(str_bb);
    str_ptr = b.inttoptr(payload, i8.as_pointer(), name="jv.truthy.strp");
    _slen = self._call_str_len(b, str_ptr, name="jv.truthy.slen");
    str_res = b.icmp_unsigned("!=", _slen, ir.Constant(i64, 0), name="jv.truthy.snz");
    str_exit_bb = b.block;
    b.branch(merge_bb);

    b.position_at_end(cont_chk_bb);
    is_list = b.icmp_unsigned("==", tag, ir.Constant(i8, 3), name="jv.truthy.islist");
    is_dict = b.icmp_unsigned("==", tag, ir.Constant(i8, 4), name="jv.truthy.isdict");
    is_set = b.icmp_unsigned("==", tag, ir.Constant(i8, 5), name="jv.truthy.isset");
    is_cont = b.or_(
        b.or_(is_list, is_dict, name="jv.truthy.ld"), is_set, name="jv.truthy.iscont"
    );
    cont_nonnull = b.icmp_unsigned(
        "!=", payload, ir.Constant(i64, 0), name="jv.truthy.cont.nn"
    );
    read_len = b.and_(is_cont, cont_nonnull, name="jv.truthy.readlen");
    b.cbranch(read_len, cont_len_bb, scalar_bb);

    b.position_at_end(cont_len_bb);
    len_ptr = b.inttoptr(payload, i64.as_pointer(), name="jv.truthy.lenp");
    cont_len = b.load(len_ptr, name="jv.truthy.len");
    len_res = b.icmp_unsigned(
        "!=", cont_len, ir.Constant(i64, 0), name="jv.truthy.lennz"
    );
    b.branch(merge_bb);

    b.position_at_end(scalar_bb);
    is_none = b.icmp_unsigned("==", tag, ir.Constant(i8, 8), name="jv.truthy.isnone");
    is_float = b.icmp_unsigned("==", tag, ir.Constant(i8, 1), name="jv.truthy.isfloat");
    as_f64 = b.bitcast(payload, ir.DoubleType(), name="jv.truthy.f64");
    f_nz = b.fcmp_unordered(
        "!=", as_f64, ir.Constant(ir.DoubleType(), 0.0), name="jv.truthy.fnz"
    );
    p_nz = b.icmp_unsigned("!=", payload, ir.Constant(i64, 0), name="jv.truthy.pnz");
    num_res = b.select(is_float, f_nz, p_nz, name="jv.truthy.num");
    scalar_res = b.select(
        is_none, ir.Constant(i1, 0), num_res, name="jv.truthy.scalar"
    );
    b.branch(merge_bb);

    b.position_at_end(merge_bb);
    phi = b.phi(i1, name="jv.truthy");
    phi.add_incoming(str_res, str_exit_bb);
    phi.add_incoming(len_res, cont_len_bb);
    phi.add_incoming(scalar_res, scalar_bb);
    return phi;
}

impl NaIRGenTypes._jacval_is_none(jv: ir.Value, negate: bool) -> ir.Value {
    i8 = ir.IntType(8);
    tag = self.builder.extract_value(jv, 0, name="jv.nonetest.tag");
    cmp_op = "!=" if negate else "==";
    return self.builder.icmp_unsigned(
        cmp_op, tag, ir.Constant(i8, 8), name="jv.nonetest"
    );
}

impl NaIRGenTypes._zero_const(ty: ir.Type) -> ir.Constant {
    if isinstance(ty, (ir.PointerType, ir.Aggregate)) {
        return ir.Constant(ty, None);
    }
    return ir.Constant(ty, 0);
}

impl NaIRGenTypes._coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value {
    _was_owned = self._is_owned(val);
    _result = self._coerce_type_inner(val, target_type);
    if _was_owned and _result is not val {
        self._mark_owned(_result);
    }
    return _result;
}

impl NaIRGenTypes._jac_optional_type(payload: ir.Type) -> ir.Type {
    key = str(payload);
    _existing = self._opt_struct_types.get(key);
    if _existing is not None {
        return _existing;
    }
    n = len(self._opt_struct_types) + 1;
    st = self.llvm_module.context.get_identified_type(f"JacOpt.{n}");
    st.set_body(ir.IntType(8), payload);
    self._opt_struct_types[key] = st;
    return st;
}

impl NaIRGenTypes._opt_payload_of(t: ir.Type) -> (ir.Type | None) {
    _nm: any = t?.name;
    if isinstance(_nm, str) and _nm.startswith("JacOpt.") {
        return t.elements[1];
    }
    return None;
}

impl NaIRGenTypes._narrowed_flow_type(nd: uni.UniNode) -> (any | None) {
    return nd.type if isinstance(nd, uni.Expr) else None;
}

impl NaIRGenTypes._narrowing_blocked_by_none_test(nd: uni.UniNode) -> bool {
    _p = nd.parent;
    while isinstance(_p, (uni.AtomUnit, uni.CfgExpr)) {
        _p = _p.parent;
    }
    if not isinstance(_p, uni.CompareExpr) {
        return False;
    }
    _has_id_op = False;
    for _op in (_p.ops or []) {
        if isinstance(_op, uni.Token)
            and _op.name in (Tok.KW_IS, Tok.KW_ISN, Tok.EE, Tok.NE) {
            _has_id_op = True;
            break;
        }
    }
    if not _has_id_op {
        return False;
    }
    for _side in [_p.left, *(_p.rights or [])] {
        _s = _side.expr if isinstance(_side, uni.CfgExpr) else _side;
        if isinstance(_s, uni.AtomUnit) {
            _s = _s.value;
        }
        if isinstance(_s, uni.Null) {
            return True;
        }
    }
    return False;
}

impl NaIRGenTypes._narrowing_stable_in_loops(nd: uni.UniNode, name: str) -> bool {
    _cur: (uni.UniNode | None) = nd;
    _child: (uni.UniNode | None) = None;
    while _cur is not None {
        if isinstance(_cur, (uni.Ability, uni.Module, uni.LambdaExpr)) {
            return True;
        }
        if isinstance(
            _cur, (uni.WhileStmt, uni.ForeverStmt, uni.InForStmt, uni.IterForStmt)
        )
            and self._loop_rebinds_name(_cur, name)
            and not self._body_assigns_before(_cur, _child, name) {
            return False;
        }
        _child = _cur;
        _cur = _cur.parent;
    }
    return True;
}

impl NaIRGenTypes._loop_rebinds_name(loop: uni.UniNode, name: str) -> bool {
    _key = (id(loop), name);
    _hit = self._loop_rebind_memo.get(_key);
    if _hit is not None {
        return _hit;
    }
    _found = False;
    for _asn in loop.get_all_sub_nodes(uni.Assignment) {
        for _t in (_asn.target or []) {
            for _tn in (
                [_t] if isinstance(_t, uni.Name) else _t.get_all_sub_nodes(uni.Name)
            ) {
                if _tn.value == name {
                    _found = True;
                    break;
                }
            }
            if _found {
                break;
            }
        }
        if _found {
            break;
        }
    }
    if not _found {
        for _b in loop.get_all_sub_nodes(uni.BinaryExpr) {
            if isinstance(_b.op, uni.Token)
                and _b.op.name == Tok.WALRUS_EQ
                and isinstance(_b.left, uni.Name)
                and _b.left.value == name {
                _found = True;
                break;
            }
        }
    }
    self._loop_rebind_memo[_key] = _found;
    return _found;
}

impl NaIRGenTypes._body_assigns_before(
    loop: uni.UniNode, child: (uni.UniNode | None), name: str
) -> bool {
    if isinstance(loop, (uni.InForStmt, uni.IterForStmt)) {
        for _tn in (loop.target.get_all_sub_nodes(uni.Name) if loop?.target else []) {
            if _tn.value == name {
                return True;
            }
        }
    }
    _body = loop?.body;
    if child is None or not isinstance(_body, (list, tuple)) {
        return False;
    }
    _idx = -1;
    for (_i, _stmt) in enumerate(_body) {
        if _stmt is child {
            _idx = _i;
            break;
        }
    }
    if _idx < 0 {
        return False;
    }
    for _stmt in _body[:_idx] {
        if not isinstance(_stmt, uni.Assignment) {
            continue;
        }
        for _t in (_stmt.target or []) {
            if isinstance(_t, uni.Name) and _t.value == name {
                return True;
            }
        }
    }
    return False;
}

impl NaIRGenTypes._apply_flow_narrowing(nd: uni.UniNode, val: ir.Value) -> ir.Value {
    """Retype a read to what the checker narrowed this occurrence to.

    Three storages can arrive here. A `JacOpt` unwraps to its payload and a
    boxed `jacval` unboxes, both of which this has always done. A union whose
    members are all pointers keeps the *first* member's pointer layout rather
    than boxing, so its narrow is a bitcast -- gated below on the analysis
    having actually stamped a narrow for this occurrence, because a bare
    `dict` or `list` annotation lowers to a default flavour that is not the
    one the value already carries, and re-typing to it would hand a jacval
    container the helpers of an integer one.

    Only a `Name` is retyped. A member reference is narrowed by an
    intra-procedural walk that cannot see a callee rebinding the attribute,
    so consuming its narrow here would replace a checked unwrap with a blind
    payload read -- `optional_narrowing.jac`'s `callee_rebinds_attr` is
    exactly that hole. Class resolution off such a narrow is still fine and
    happens in `_struct_name_of`; what is refused here is dropping the tag.
    """;
    _src_opt = self._opt_payload_of(val.type);
    _is_jv = bool(self?.jacval_type) and val.type == self.jacval_type;
    _is_ptr = _src_opt is None and not _is_jv and isinstance(val.type, ir.PointerType);
    if _src_opt is None and not _is_jv and not _is_ptr {
        return val;
    }
    if not isinstance(nd, uni.Name) {
        if _is_jv and isinstance(nd, uni.AtomTrailer) {
            return self._unbox_narrowed_member(nd, val);
        }
        return val;
    }
    _nm = nd.value;
    if _nm not in self.local_vars or _nm in self.closure_cell_vars {
        return val;
    }
    if not self._narrowing_stable_in_loops(nd, _nm) {
        return val;
    }
    if self._narrowing_blocked_by_none_test(nd) {
        return val;
    }
    _nt = self._narrowed_flow_type(nd);
    if _nt is None {
        return val;
    }
    try {
        import from jaclang.compiler.types.types { ClassType as _ClassType }
    } except ImportError {
        return val;
    }
    if not isinstance(_nt, _ClassType)
        or _nt.shared.class_name in ("NoneType", "None") {
        return val;
    }
    _want = self._lower_type(_nt);
    _nt_bare = False;
    if _nt.shared.class_name in ("list", "Sequence") {
        _nt_args = _nt.private.type_args or [];
        _nt_bare = not _nt_args;
        if not _nt_bare and len(_nt_args) == 1 {
            _a0 = _nt_args[0];
            _nt_bare = (
                isinstance(_a0, _ClassType)
                and _a0.shared.class_name in ("any", "Any", "object")
            );
        }
        if _nt_bare and not _is_ptr and self?.jacval_type {
            self._emit_list_helpers("jacval", self.jacval_type);
            _want = self.list_types["jacval"].as_pointer();
        }
    }
    if _want is None or isinstance(_want, ir.VoidType) or _want == val.type {
        return val;
    }
    if _is_ptr {
        if not (isinstance(nd, uni.Expr) and nd.narrowed_type is not None) {
            return val;
        }
        if not (_nt.private.type_args or [])
            or _nt.shared.class_name
                not in ("list", "Sequence", "dict", "set", "frozenset", "tuple")
            or not isinstance(_want, ir.PointerType) {
            return val;
        }
        return self.builder.bitcast(val, _want, name="ptr.narrowed");
    }
    if _src_opt is not None {
        return self.builder.extract_value(val, 1, name="opt.narrowed");
    }
    _ub_want = _want;
    if self._str_desc_ty is not None and _want == self._str_desc_ty {
        _ub_want = ir.IntType(8).as_pointer();
    }
    if not isinstance(
        _ub_want, (ir.IntType, ir.DoubleType, ir.FloatType, ir.PointerType)
    ) {
        return val;
    }
    _ub = self._unbox_from_jacval(val, _ub_want);
    if _ub_want != _want {
        return self._coerce_type(_ub, _want);
    }
    return _ub;
}

impl NaIRGenTypes._unbox_narrowed_member(
    nd: uni.AtomTrailer, val: ir.Value
) -> ir.Value {
    """Unbox a member read the checker narrowed to one heap kind.

    A member typed as a mix of heap kinds (`list[Item] | Item`) is stored
    boxed, and the analysis pipeline stamps `narrowed_type` on an occurrence
    it has narrowed (`src.body` after `isinstance(src.body, list)`). Before
    unions boxed, every pointer union carried its first member's layout and
    the narrow was a free reinterpretation; the box needs an explicit unbox
    or the consumer sees a jacval where the checker promised a list, and
    `list(src.body)` refuses to lower. Only a class or container narrow
    unboxes here: an Optional payload read stays a Name-only retype, because
    a callee can rebind an attribute to None between the test and the use
    (`optional_narrowing.jac`'s `callee_rebinds_attr`), and that unwrap must
    keep its tag check.
    """;
    if not isinstance(nd, uni.Expr) or nd.narrowed_type is None {
        return val;
    }
    if self._narrowing_blocked_by_none_test(nd) {
        return val;
    }
    _nt = nd.narrowed_type;
    try {
        import from jaclang.compiler.types.types { ClassType as _ClassType }
    } except ImportError {
        return val;
    }
    if not isinstance(_nt, _ClassType)
        or _nt.shared.class_name in ("NoneType", "None") {
        return val;
    }
    _want = self._lower_type(_nt);
    if _want is None
        or isinstance(_want, ir.VoidType)
        or _want == val.type
        or self._opt_payload_of(_want) is not None
        or not isinstance(_want, ir.PointerType)
        or isinstance(_want.pointee, ir.FunctionType) {
        return val;
    }
    return self._unbox_from_jacval(val, _want);
}

impl NaIRGenTypes._opt_ptr_payload_of(t: ir.Type) -> (ir.Type | None) {
    _pt = self._opt_payload_of(t);
    if (
        _pt is not None
        and isinstance(_pt, ir.PointerType)
        and not isinstance(_pt.pointee, ir.FunctionType)
    ) {
        return _pt;
    }
    return None;
}

impl NaIRGenTypes._coerce_type_inner(val: ir.Value, target_type: ir.Type) -> ir.Value {
    if val.type == target_type {
        return val;
    }

    if isinstance(val.type, ir.PointerType)
        and isinstance(target_type, ir.PointerType) {
        _src_nm = getattr(val.type.pointee, "name", "") or "";
        _tgt_nm = getattr(target_type.pointee, "name", "") or "";
        if _src_nm in self.struct_types and _tgt_nm in self.struct_types {
            if _tgt_nm in self._mro_of(_src_nm) or _src_nm in self._mro_of(_tgt_nm) {
                return self.builder.bitcast(val, target_type, name="hier.cast");
            }
        }
    }

    _tseq = self._tuple_seq_coerce(val, target_type);
    if _tseq is not None {
        return _tseq;
    }

    _sd = self._str_desc_ty;
    if _sd is not None {
        _i8p_sd = ir.IntType(8).as_pointer();
        if target_type == _sd and val.type == _i8p_sd {
            if self.str_unwrap_fn is None {
                self._emit_str_desc_helpers();
            }

            return self.builder.call(self.str_wrap_raw_fn, [val], name="s.desc");
        }
        if val.type == _sd and target_type == _i8p_sd {
            if self.str_unwrap_fn is None {
                self._emit_str_desc_helpers();
            }
            return self.builder.call(self.str_unwrap_fn, [val], name="s.raw");
        }
        if target_type == _sd and self?.jacval_type and val.type == self.jacval_type {
            if self.str_unwrap_fn is None {
                self._emit_str_desc_helpers();
            }
            return self.builder.call(
                self.str_wrap_raw_fn,
                [self._unbox_from_jacval(val, _i8p_sd)],
                name="s.desc"
            );
        }
        if target_type == _sd
            and isinstance(val.type, ir.IntType)
            and val.type.width == 64 {
            if self.str_unwrap_fn is None {
                self._emit_str_desc_helpers();
            }
            return self.builder.call(
                self.str_wrap_raw_fn,
                [self.builder.inttoptr(val, _i8p_sd, name="s.unbox")],
                name="s.desc"
            );
        }
        if val.type == _sd
            and isinstance(target_type, ir.IntType)
            and target_type.width == 64 {
            if self.str_unwrap_fn is None {
                self._emit_str_desc_helpers();
            }
            return self.builder.ptrtoint(
                self.builder.call(self.str_unwrap_fn, [val], name="s.raw"),
                target_type,
                name="s.box"
            );
        }
    }

    _opt_tgt = self._opt_payload_of(target_type);
    if _opt_tgt is not None {
        _tgt_is_ptr = isinstance(_opt_tgt, ir.PointerType);
        _val_is_none = isinstance(val.type, ir.VoidType)
            or (
                isinstance(val, ir.Constant)
                and isinstance(val.type, ir.PointerType)
                and val.constant is None
            )
            or (isinstance(val.type, ir.PointerType) and not _tgt_is_ptr);
        if _val_is_none {
            return ir.Constant(target_type, None);
        }
        if self?.jacval_type
            and val.type == self.jacval_type
            and _opt_tgt != self.jacval_type {
            _jv_tag = self.builder.extract_value(val, 0, name="opt.jv.tag");
            _jv_is_none = self.builder.icmp_unsigned(
                "==", _jv_tag, ir.Constant(ir.IntType(8), 8), name="opt.jv.isnone"
            );
            _jv_pl = self._unbox_from_jacval(val, _opt_tgt);
            _jv_ov = self.builder.insert_value(
                ir.Constant(target_type, None),
                ir.Constant(ir.IntType(8), 1),
                0,
                name="opt.jv.tagset"
            );
            _jv_ov = self.builder.insert_value(_jv_ov, _jv_pl, 1, name="opt.jv.wrap");
            return self.builder.select(
                _jv_is_none, ir.Constant(target_type, None), _jv_ov, name="opt.jv.sel"
            );
        }
        _pv = self._coerce_type_inner(val, _opt_tgt);
        _ov = self.builder.insert_value(
            ir.Constant(target_type, None),
            ir.Constant(ir.IntType(8), 1),
            0,
            name="opt.tag"
        );
        _ov = self.builder.insert_value(_ov, _pv, 1, name="opt.wrap");
        if _tgt_is_ptr {
            _pv_nn = self.builder.icmp_unsigned(
                "!=", _pv, ir.Constant(_opt_tgt, None), name="opt.wrap.nn"
            );
            return self.builder.select(
                _pv_nn, _ov, ir.Constant(target_type, None), name="opt.wrap.sel"
            );
        }
        return _ov;
    }
    _opt_src = self._opt_payload_of(val.type);
    if _opt_src is not None {
        _tag = self.builder.extract_value(val, 0, name="opt.tag.rd");
        _tag_set = self.builder.icmp_signed(
            "!=", _tag, ir.Constant(ir.IntType(8), 0), name="opt.has"
        );
        if isinstance(target_type, ir.IntType) and target_type.width == 1 {
            _pl_t = self.builder.extract_value(val, 1, name="opt.payload.t");
            _pl_b = self._coerce_type_inner(_pl_t, target_type);
            return self.builder.and_(_tag_set, _pl_b, name="opt.truthy");
        }
        _pl = self.builder.extract_value(val, 1, name="opt.payload");
        if self?.jacval_type and target_type == self.jacval_type {
            _boxed = self._box_to_jacval(_pl);
            _none_jv = self.builder.insert_value(
                ir.Constant(self.jacval_type, None),
                ir.Constant(ir.IntType(8), 8),
                0,
                name="opt.none.jv"
            );
            return self.builder.select(_tag_set, _boxed, _none_jv, name="opt.tojv");
        }

        if isinstance(target_type, ir.PointerType)
            and isinstance(_pl.type, ir.PointerType) {
            _pl_c = self._coerce_type_inner(_pl, target_type);
            return self.builder.select(
                _tag_set, _pl_c, ir.Constant(target_type, None), name="opt.ornull"
            );
        }
        _is_none = self.builder.icmp_signed(
            "==", _tag, ir.Constant(ir.IntType(8), 0), name="opt.isnone"
        );
        self._emit_runtime_raise(
            _is_none, "TypeError", "value is None where a value is required"
        );
        return self._coerce_type_inner(_pl, target_type);
    }

    if self?.jacval_type {
        if target_type == self.jacval_type and val.type != self.jacval_type {
            return self._box_to_jacval(val);
        }
        if val.type == self.jacval_type and target_type != self.jacval_type {
            return self._unbox_from_jacval(val, target_type);
        }
    }

    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.DoubleType) {
        return self.builder.sitofp(val, target_type, name="cast");
    }

    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.FloatType) {
        return self.builder.sitofp(val, target_type, name="cast.f32");
    }

    if isinstance(val.type, ir.DoubleType) and isinstance(target_type, ir.IntType) {
        return self.builder.fptosi(val, target_type, name="cast");
    }

    if isinstance(val.type, ir.FloatType) and isinstance(target_type, ir.IntType) {
        return self.builder.fptosi(val, target_type, name="cast.i");
    }

    if isinstance(val.type, ir.DoubleType) and isinstance(target_type, ir.FloatType) {
        return self.builder.fptrunc(val, target_type, name="fptrunc");
    }

    if isinstance(val.type, ir.FloatType) and isinstance(target_type, ir.DoubleType) {
        return self.builder.fpext(val, target_type, name="fpext");
    }

    _clos_tgt = self._closure_struct_of(target_type);
    if _clos_tgt is not None {
        _src_is_fn = isinstance(val.type, ir.FunctionType)
            or (
                isinstance(val.type, ir.PointerType)
                and isinstance(val.type.pointee, ir.FunctionType)
            );
        if _src_is_fn {
            if self._pending_lambda_captures is not None {
                self._pending_lambda_captures = None;
                self.emit(
                    E5092,
                    kind="expression",
                    name="capturing lambda used as a value",
                    help_text="This lambda captures enclosing locals that could not be promoted to shared heap cells in this frame, so it cannot escape as a value here. Bind the lambda's inputs through parameters, or use a named nested function."
                );
                return ir.Constant(target_type, None);
            }
            if self.rc_alloc_fn is None {
                self._emit_rc_helpers();
            }
            _wi32 = ir.IntType(32);
            _wi64 = ir.IntType(64);
            _wi8p = ir.IntType(8).as_pointer();
            _wfn = val;
            if isinstance(_wfn.type, ir.FunctionType) {
                _wfn = self.builder.bitcast(
                    _wfn, _wfn.type.as_pointer(), name="clos.wrap.fnp"
                );
            }
            _wclos = self._alloc_iter_struct(_clos_tgt);
            _wfn_slot = self.builder.gep(
                _wclos,
                [ir.Constant(_wi32, 0), ir.Constant(_wi32, 0)],
                name="clos.wrap.fn.slot"
            );
            self.builder.store(
                self.builder.ptrtoint(_wfn, _wi64, name="clos.wrap.fn.i64"), _wfn_slot
            );
            _wenv_slot = self.builder.gep(
                _wclos,
                [ir.Constant(_wi32, 0), ir.Constant(_wi32, 1)],
                name="clos.wrap.env.slot"
            );
            self.builder.store(ir.Constant(_wi8p, None), _wenv_slot);
            self._mark_owned(_wclos);
            return _wclos;
        }
    }

    if isinstance(val.type, ir.PointerType)
        and isinstance(target_type, ir.PointerType) {
        _lc_src = self._spec_from_list_slot_type(val.type);
        _lc_dst = self._spec_from_list_slot_type(target_type);
        if (
            _lc_src is not None
            and _lc_dst is not None
            and _lc_src != _lc_dst
            and (_lc_src == "jacval") != (_lc_dst == "jacval")
        ) {
            _lc_re = self._reflavor_list(val, _lc_src, _lc_dst);
            if _lc_re is not None {
                return _lc_re;
            }
            self.emit(
                E5092,
                node_override=self.ir_in,
                kind="coercion",
                name=f"list[{_lc_src}] -> list[{_lc_dst}]",
                help_text=(
                    "These list layouts store elements at different slot "
                    "widths, so a cast would corrupt the elements; construct "
                    "the list with the destination's element flavor instead."
                )
            );
            return val;
        }
        return self.builder.bitcast(val, target_type, name="ptrcast");
    }

    if isinstance(val.type, ir.FunctionType)
        and isinstance(target_type, ir.PointerType) {
        return self.builder.bitcast(val, target_type, name="fn.cast");
    }

    if isinstance(val.type, ir.FunctionType) and isinstance(target_type, ir.IntType) {
        fn_ptr = self.builder.bitcast(val, val.type.as_pointer(), name="fn.ptr");
        return self.builder.ptrtoint(fn_ptr, target_type, name="fn.ptrtoint");
    }

    if isinstance(val.type, ir.PointerType)
        and isinstance(val.type.pointee, ir.FunctionType)
        and isinstance(target_type, ir.IntType) {
        return self.builder.ptrtoint(val, target_type, name="fn.ptrtoint");
    }

    if isinstance(val.type, ir.PointerType)
        and not isinstance(target_type, ir.PointerType) {
        if val.type?.pointee and val.type.pointee == target_type {
            return self.builder.load(val, name="struct.unbox");
        }

        if isinstance(target_type, ir.IntType) and val.type?.pointee {
            for (sname, abi_type) in self.clib_struct_abi_types.items() {
                if val.type.pointee == self.struct_types.get(sname)
                    and abi_type == target_type {
                    int_ptr = self.builder.bitcast(
                        val, target_type.as_pointer(), name="struct.abi.cast"
                    );
                    return self.builder.load(int_ptr, name="struct.abi.unbox");
                }
            }
        }

        if isinstance(target_type, ir.IntType) and isinstance(val, ir.Constant) {
            return ir.Constant(target_type, -1);
        }

        if isinstance(target_type, ir.IntType) {
            return self.builder.ptrtoint(val, target_type, name="ptr.toint");
        }
    }

    if not isinstance(val.type, ir.PointerType)
        and isinstance(target_type, ir.PointerType) {
        if isinstance(val.type, ir.LiteralStructType)
            and target_type?.pointee
            and isinstance(target_type.pointee, ir.LiteralStructType)
            and val.type != target_type.pointee
            and len(val.type.elements) == len(target_type.pointee.elements) {
            val = self._coerce_tuple_to_struct(val, target_type.pointee);
        }
        if target_type?.pointee and target_type.pointee == val.type {
            if isinstance(val.type, ir.LiteralStructType) {
                return self._box_value_tuple(val);
            }
            null_ptr = ir.Constant(target_type, None);
            size_gep = self.builder.gep(
                null_ptr, [ir.Constant(ir.IntType(32), 1)], name="clib.sizeof.gep"
            );
            size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="clib.sizeof");

            _clib_loc = getattr(val, 'jac_loc', '');
            raw_ptr = self._rc_call_with_ctx(
                self.rc_alloc_fn, [size], op="box", loc=_clib_loc, name="clib.box.raw"
            );
            typed_ptr = self.builder.bitcast(raw_ptr, target_type, name="clib.box.ptr");
            self.builder.store(val, typed_ptr);

            self._mark_owned(typed_ptr);

            self._emit_set_type_tag(self.builder, raw_ptr, "tuple");
            return typed_ptr;
        }

        if isinstance(val.type, ir.IntType) and target_type?.pointee {
            for (sname, abi_type) in self.clib_struct_abi_types.items() {
                if target_type.pointee == self.struct_types.get(sname)
                    and abi_type == val.type {
                    null_ptr = ir.Constant(target_type, None);
                    size_gep = self.builder.gep(
                        null_ptr,
                        [ir.Constant(ir.IntType(32), 1)],
                        name="clib.sizeof.gep"
                    );
                    size = self.builder.ptrtoint(
                        size_gep, ir.IntType(64), name="clib.sizeof"
                    );
                    raw_ptr = self._rc_call_with_ctx(
                        self.rc_alloc_fn, [size], op="box", name="clib.box.raw"
                    );
                    int_ptr = self.builder.bitcast(
                        raw_ptr, val.type.as_pointer(), name="clib.abi.cast"
                    );
                    self.builder.store(val, int_ptr);
                    typed_ptr = self.builder.bitcast(
                        raw_ptr, target_type, name="clib.box.ptr"
                    );

                    self._mark_owned(typed_ptr);

                    self._emit_set_type_tag(self.builder, raw_ptr, sname);
                    return typed_ptr;
                }
            }
        }
    }

    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.PointerType) {
        return self.builder.inttoptr(val, target_type, name="int.toptr");
    }

    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.IntType) {
        if val.type.width < target_type.width {
            if val?.jac_signed {
                return self.builder.sext(val, target_type, name="sext");
            }
            return self.builder.zext(val, target_type, name="zext");
        } elif val.type.width > target_type.width {
            if target_type.width == 1 {
                return self.builder.icmp_signed(
                    "!=", val, ir.Constant(val.type, 0), name="int.truth"
                );
            }
            if isinstance(val, ir.Constant) and isinstance(val.constant, int) {
                _w = target_type.width;
                if -(1 << (_w - 1)) <= val.constant < (1 << _w) {
                    return ir.Constant(target_type, val.constant);
                }
            }
            self.emit(
                E5092,
                node_override=self.cur_node,
                kind="silent narrowing",
                name=f"{val.type} into {target_type}"
            );
            return val;
        }
    }

    if isinstance(val.type, ir.LiteralStructType)
        and val.type != target_type
        and len(val.type.elements) >= 2 {
        _all_prim = True;
        for _el in val.type.elements {
            if not isinstance(
                _el, (ir.IntType, ir.DoubleType, ir.FloatType, ir.PointerType)
            ) {
                _all_prim = False;
                break;
            }
        }
        if _all_prim {
            boxed = self._box_value_tuple(val);
            if boxed.type == target_type {
                return boxed;
            }

            if isinstance(boxed.type, ir.PointerType)
                and isinstance(target_type, ir.PointerType) {
                _cast = self.builder.bitcast(boxed, target_type, name="tuple.box.cast");

                self._mark_owned(_cast);
                return _cast;
            }
        }
    }
    return val;
}

impl NaIRGenTypes._promote_to_float(
    left: ir.Value, right: ir.Value, unsigned: bool = False
) -> tuple[(ir.Value, ir.Value)] {
    target: ir.Type = (
        ir.FloatType()
            if isinstance(left.type, ir.FloatType)
                and isinstance(right.type, ir.FloatType)
            else ir.DoubleType()
    );
    return (
        self._to_float_type(left, target, unsigned),
        self._to_float_type(right, target, unsigned)
    );
}

impl NaIRGenTypes._to_float_type(
    val: ir.Value, target: ir.Type, unsigned: bool
) -> ir.Value {
    if val.type == target {
        return val;
    }
    if isinstance(val.type, ir.IntType) {
        if unsigned or val.type.width == 1 {
            return self.builder.uitofp(val, target, name="u2f");
        }
        return self.builder.sitofp(val, target, name="s2f");
    }
    if isinstance(val.type, ir.FloatType) and isinstance(target, ir.DoubleType) {
        return self.builder.fpext(val, target, name="fpext");
    }
    if isinstance(val.type, ir.DoubleType) and isinstance(target, ir.FloatType) {
        return self.builder.fptrunc(val, target, name="fptrunc");
    }
    return val;
}

impl NaIRGenTypes._unify_int_widths(
    left: ir.Value, right: ir.Value
) -> tuple[(ir.Value, ir.Value)] {
    if left.type.width == 1 and right.type.width > 1 {
        left = self.builder.zext(left, right.type, name="bool.widen");
    } elif right.type.width == 1 and left.type.width > 1 {
        right = self.builder.zext(right, left.type, name="bool.widen");
    }
    return (left, right);
}

impl NaIRGenTypes._codegen_int_floor_divmod(
    left: ir.Value, right: ir.Value
) -> tuple[(ir.Value, ir.Value)] {
    int_ty = left.type;
    q = self.builder.sdiv(left, right, name="floordiv.quot");
    r = self.builder.srem(left, right, name="floordiv.rem");
    izero = ir.Constant(int_ty, 0);
    rone = ir.Constant(int_ty, 1);
    r_ne_zero = self.builder.icmp_signed("!=", r, izero, name="floordiv.r.nz");
    r_neg = self.builder.icmp_signed("<", r, izero, name="floordiv.r.neg");
    b_neg = self.builder.icmp_signed("<", right, izero, name="floordiv.b.neg");
    sign_diff = self.builder.icmp_unsigned("!=", r_neg, b_neg, name="floordiv.sdiff");
    need_adj = self.builder.and_(r_ne_zero, sign_diff, name="floordiv.adj");
    q_one_less = self.builder.sub(q, rone, name="floordiv.q.dec");
    q_final = self.builder.select(need_adj, q_one_less, q, name="floordiv.q");
    r_plus_b = self.builder.add(r, right, name="floordiv.r.fix");
    r_final = self.builder.select(need_adj, r_plus_b, r, name="floordiv.r");
    return (q_final, r_final);
}

impl NaIRGenTypes._codegen_float_floor_div(
    left: ir.Value, right: ir.Value
) -> ir.Value {
    raw = self.builder.fdiv(left, right, name="ffloordiv.raw");
    floor_fn = self._get_or_declare_extern("floor", ir.DoubleType(), [ir.DoubleType()]);
    return self.builder.call(floor_fn, [raw], name="ffloordiv");
}

impl NaIRGenTypes._codegen_float_floor_mod(
    left: ir.Value, right: ir.Value
) -> ir.Value {
    floored = self._codegen_float_floor_div(left, right);
    prod = self.builder.fmul(right, floored, name="fmod.prod");
    return self.builder.fsub(left, prod, name="fmod");
}

impl NaIRGenTypes._emit_binary_op(
    op: str,
    left: ir.Value,
    right: ir.Value,
    unsigned: bool = False,
    checked: bool = False
) -> (ir.Value | None) {
    left = self._str_norm(left);
    right = self._str_norm(right);
    if isinstance(left.type, ir.PointerType)
        or isinstance(right.type, ir.PointerType) {
        _dunder_res = self._emit_arch_dunder_binop(op, left, right);
        if _dunder_res is not None {
            return _dunder_res;
        }
    }

    if self._opt_payload_of(left.type) is not None {
        left = self._coerce_type(left, self._opt_payload_of(left.type));
    }
    if self._opt_payload_of(right.type) is not None {
        right = self._coerce_type(right, self._opt_payload_of(right.type));
    }
    i8p_type = ir.IntType(8).as_pointer();
    if op == Tok.PLUS and left.type == i8p_type and right.type == i8p_type {
        _i8p_cc = ir.IntType(8).as_pointer();
        _i64_cc = ir.IntType(64);
        memcpy_cc = self._get_or_declare_extern(
            "memcpy", _i8p_cc, [_i8p_cc, _i8p_cc, _i64_cc]
        );
        len1 = self._call_str_len(self.builder, left, name="len1");
        len2 = self._call_str_len(self.builder, right, name="len2");
        total = self.builder.add(len1, len2, name="total_len");
        buf_size = self.builder.add(
            total, ir.Constant(ir.IntType(64), 1), name="buf_size"
        );
        _concat_loc = getattr(left, 'jac_loc', getattr(right, 'jac_loc', ''));
        self._set_rc_ctx("str_concat", _concat_loc);
        buf = self._str_alloc(self.builder, buf_size, name="concat.buf");
        self._clear_rc_ctx();
        self.builder.call(memcpy_cc, [buf, left, len1]);
        _cc_dst2 = self.builder.gep(buf, [len1], name="concat.dst2");
        self.builder.call(memcpy_cc, [_cc_dst2, right, len2]);
        self._str_finish(self.builder, buf, total);

        self._mark_owned(buf);
        return buf;
    }

    if op == Tok.PLUS and self._is_bytes_value(left) and self._is_bytes_value(right) {
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        llen = self._bytes_len_val(left);
        rlen = self._bytes_len_val(right);
        total = self.builder.add(llen, rlen, name="by.cat.total");
        result = self._bytes_alloc(total);
        dst = self._bytes_data_ptr(result);
        memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        self.builder.call(memcpy_fn, [dst, self._bytes_data_ptr(left), llen]);
        rdst = self.builder.gep(dst, [llen], name="by.cat.rdst");
        self.builder.call(memcpy_fn, [rdst, self._bytes_data_ptr(right), rlen]);
        return result;
    }

    if op == Tok.STAR_MUL {
        by_val: (ir.Value | None) = None;
        rep_val: (ir.Value | None) = None;
        if self._is_bytes_value(left) and isinstance(right.type, ir.IntType) {
            by_val = left;
            rep_val = right;
        } elif self._is_bytes_value(right) and isinstance(left.type, ir.IntType) {
            by_val = right;
            rep_val = left;
        }
        if by_val is not None and rep_val is not None {
            return self._emit_bytes_repeat(by_val, rep_val);
        }
    }

    if op == Tok.STAR_MUL {
        str_val: (ir.Value | None) = None;
        int_val: (ir.Value | None) = None;
        if left.type == i8p_type and isinstance(right.type, ir.IntType) {
            str_val = left;
            int_val = right;
        } elif right.type == i8p_type and isinstance(left.type, ir.IntType) {
            str_val = right;
            int_val = left;
        }
        if str_val is not None and int_val is not None {
            i8 = ir.IntType(8);
            i8p = i8.as_pointer();
            i64 = ir.IntType(64);
            memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
            slen = self._call_str_len(self.builder, str_val, name="rep.slen");

            _rep_neg = self.builder.icmp_signed(
                "<", int_val, ir.Constant(i64, 0), name="rep.neg"
            );
            int_val = self.builder.select(
                _rep_neg, ir.Constant(i64, 0), int_val, name="rep.n"
            );
            total = self.builder.mul(slen, int_val, name="rep.total");
            alloc = self.builder.add(total, ir.Constant(i64, 1), name="rep.alloc");
            self._set_rc_ctx("str_repeat", "");
            buf = self._str_alloc(self.builder, alloc, name="rep.buf");
            self._clear_rc_ctx();
            func = self.builder.basic_block.function;
            entry_bb = self.builder.basic_block;
            loop_bb = func.append_basic_block(name="rep.loop");
            body_bb = func.append_basic_block(name="rep.body");
            done_bb = func.append_basic_block(name="rep.done");
            self.builder.branch(loop_bb);
            self.builder.position_at_start(loop_bb);
            offset = self.builder.phi(i64, name="rep.off");
            count = self.builder.phi(i64, name="rep.cnt");
            offset.add_incoming(ir.Constant(i64, 0), entry_bb);
            count.add_incoming(ir.Constant(i64, 0), entry_bb);
            at_end = self.builder.icmp_unsigned(">=", count, int_val, name="rep.atend");
            self.builder.cbranch(at_end, done_bb, body_bb);
            self.builder.position_at_start(body_bb);
            dst = self.builder.gep(buf, [offset], name="rep.dst");
            self.builder.call(memcpy_fn, [dst, str_val, slen]);
            new_off = self.builder.add(offset, slen, name="rep.newoff");
            new_cnt = self.builder.add(count, ir.Constant(i64, 1), name="rep.newcnt");
            offset.add_incoming(new_off, body_bb);
            count.add_incoming(new_cnt, body_bb);
            self.builder.branch(loop_bb);
            self.builder.position_at_start(done_bb);
            self._str_finish(self.builder, buf, total);
            return buf;
        }
    }

    if op == Tok.STAR_MUL {
        for (lmul_key, lmul_helpers) in self.list_helpers.items() {
            lmul_type = self.list_types.get(lmul_key);
            if lmul_type is None {
                continue;
            }
            lmul_list: (ir.Value | None) = None;
            lmul_int: (ir.Value | None) = None;
            if left.type == lmul_type.as_pointer()
                and isinstance(right.type, ir.IntType) {
                lmul_list = left;
                lmul_int = right;
            } elif right.type == lmul_type.as_pointer()
                and isinstance(left.type, ir.IntType) {
                lmul_list = right;
                lmul_int = left;
            }
            if lmul_list is not None and lmul_int is not None {
                i64 = ir.IntType(64);
                lmul_new = self.builder.call(lmul_helpers["new"], [], name="lmul.new");
                lmul_len = self.builder.call(
                    lmul_helpers["len"], [lmul_list], name="lmul.len"
                );
                func = self.builder.basic_block.function;
                lmul_entry_bb = self.builder.basic_block;
                lmul_outer_bb = func.append_basic_block(name="lmul.outer");
                lmul_iinit_bb = func.append_basic_block(name="lmul.iinit");
                lmul_inner_bb = func.append_basic_block(name="lmul.inner");
                lmul_ibody_bb = func.append_basic_block(name="lmul.ibody");
                lmul_onext_bb = func.append_basic_block(name="lmul.onext");
                lmul_done_bb = func.append_basic_block(name="lmul.done");
                self.builder.branch(lmul_outer_bb);
                self.builder.position_at_start(lmul_outer_bb);
                lmul_rep = self.builder.phi(i64, name="lmul.rep");
                lmul_rep.add_incoming(ir.Constant(i64, 0), lmul_entry_bb);
                lmul_rend = self.builder.icmp_signed(
                    ">=", lmul_rep, lmul_int, name="lmul.rend"
                );
                self.builder.cbranch(lmul_rend, lmul_done_bb, lmul_iinit_bb);
                self.builder.position_at_start(lmul_iinit_bb);
                self.builder.branch(lmul_inner_bb);
                self.builder.position_at_start(lmul_inner_bb);
                lmul_ei = self.builder.phi(i64, name="lmul.ei");
                lmul_ei.add_incoming(ir.Constant(i64, 0), lmul_iinit_bb);
                lmul_eend = self.builder.icmp_unsigned(
                    ">=", lmul_ei, lmul_len, name="lmul.eend"
                );
                self.builder.cbranch(lmul_eend, lmul_onext_bb, lmul_ibody_bb);
                self.builder.position_at_start(lmul_ibody_bb);
                lmul_elem = self.builder.call(
                    lmul_helpers["get"], [lmul_list, lmul_ei], name="lmul.elem"
                );
                self._rc_call_with_ctx(
                    lmul_helpers["append"], [lmul_new, lmul_elem], op="list_mul"
                );
                lmul_ne = self.builder.add(
                    lmul_ei, ir.Constant(i64, 1), name="lmul.ne"
                );
                lmul_ei.add_incoming(lmul_ne, lmul_ibody_bb);
                self.builder.branch(lmul_inner_bb);
                self.builder.position_at_start(lmul_onext_bb);
                lmul_nr = self.builder.add(
                    lmul_rep, ir.Constant(i64, 1), name="lmul.nr"
                );
                lmul_rep.add_incoming(lmul_nr, lmul_onext_bb);
                self.builder.branch(lmul_outer_bb);
                self.builder.position_at_start(lmul_done_bb);
                return self._mark_owned(lmul_new);
            }
        }
    }

    if op == Tok.PLUS {
        for (list_key, helpers) in self.list_helpers.items() {
            list_type = self.list_types.get(list_key);
            if list_type is not None
                and left.type == list_type.as_pointer()
                and right.type == list_type.as_pointer() {
                i64 = ir.IntType(64);
                new_list = self.builder.call(helpers["new"], [], name="lcat.new");

                left_len = self.builder.call(helpers["len"], [left], name="lcat.llen");
                func = self.builder.basic_block.function;
                entry_bb = self.builder.basic_block;
                loop1_bb = func.append_basic_block(name="lcat.l1");
                body1_bb = func.append_basic_block(name="lcat.b1");
                mid_bb = func.append_basic_block(name="lcat.mid");
                loop2_bb = func.append_basic_block(name="lcat.l2");
                body2_bb = func.append_basic_block(name="lcat.b2");
                done_bb = func.append_basic_block(name="lcat.done");
                self.builder.branch(loop1_bb);
                self.builder.position_at_start(loop1_bb);
                i1 = self.builder.phi(i64, name="lcat.i1");
                i1.add_incoming(ir.Constant(i64, 0), entry_bb);
                end1 = self.builder.icmp_unsigned(">=", i1, left_len, name="lcat.end1");
                self.builder.cbranch(end1, mid_bb, body1_bb);
                self.builder.position_at_start(body1_bb);
                e1 = self.builder.call(helpers["get"], [left, i1], name="lcat.e1");
                self._rc_call_with_ctx(
                    helpers["append"], [new_list, e1], op="list_cat"
                );
                n1 = self.builder.add(i1, ir.Constant(i64, 1), name="lcat.n1");
                i1.add_incoming(n1, body1_bb);
                self.builder.branch(loop1_bb);

                self.builder.position_at_start(mid_bb);
                right_len = self.builder.call(
                    helpers["len"], [right], name="lcat.rlen"
                );
                self.builder.branch(loop2_bb);
                self.builder.position_at_start(loop2_bb);
                i2 = self.builder.phi(i64, name="lcat.i2");
                i2.add_incoming(ir.Constant(i64, 0), mid_bb);
                end2 = self.builder.icmp_unsigned(
                    ">=", i2, right_len, name="lcat.end2"
                );
                self.builder.cbranch(end2, done_bb, body2_bb);
                self.builder.position_at_start(body2_bb);
                e2 = self.builder.call(helpers["get"], [right, i2], name="lcat.e2");
                self._rc_call_with_ctx(
                    helpers["append"], [new_list, e2], op="list_cat"
                );
                n2 = self.builder.add(i2, ir.Constant(i64, 1), name="lcat.n2");
                i2.add_incoming(n2, body2_bb);
                self.builder.branch(loop2_bb);
                self.builder.position_at_start(done_bb);
                return self._mark_owned(new_list);
            }
        }
    }

    for (sk, st) in self.set_types.items() {
        if left.type == st.as_pointer() and right.type == st.as_pointer() {
            self._ensure_emitters();
            _ctx = self._native_emit_ctx_class(pass_ref=self, type_key=sk);
            _se = self._native_emitters.get("set");
            if _se is not None {
                if op == Tok.BW_OR {
                    return _se.emit_union(_ctx, left, [right]);
                }
                if op == Tok.BW_AND {
                    return _se.emit_intersection(_ctx, left, [right]);
                }
                if op == Tok.MINUS {
                    return _se.emit_difference(_ctx, left, [right]);
                }
                if op == Tok.BW_XOR {
                    return _se.emit_symmetric_difference(_ctx, left, [right]);
                }
            }
            break;
        }
    }

    ctype_ptr = self.complex_struct_type.as_pointer();
    if left.type == ctype_ptr and right.type == ctype_ptr {
        f64 = ir.DoubleType();
        i64 = ir.IntType(64);
        i32 = ir.IntType(32);
        z0 = ir.Constant(i32, 0);
        z1 = ir.Constant(i32, 1);
        ar = self.builder.load(
            self.builder.gep(left, [z0, z0], name="c.ar.p"), name="c.ar"
        );
        ai = self.builder.load(
            self.builder.gep(left, [z0, z1], name="c.ai.p"), name="c.ai"
        );
        br = self.builder.load(
            self.builder.gep(right, [z0, z0], name="c.br.p"), name="c.br"
        );
        bi = self.builder.load(
            self.builder.gep(right, [z0, z1], name="c.bi.p"), name="c.bi"
        );
        rr: (ir.Value | None) = None;
        ri: (ir.Value | None) = None;
        if op == Tok.PLUS {
            rr = self.builder.fadd(ar, br, name="c.add.r");
            ri = self.builder.fadd(ai, bi, name="c.add.i");
        } elif op == Tok.MINUS {
            rr = self.builder.fsub(ar, br, name="c.sub.r");
            ri = self.builder.fsub(ai, bi, name="c.sub.i");
        } elif op == Tok.STAR_MUL {
            rr = self.builder.fsub(
                self.builder.fmul(ar, br, name="c.m1"),
                self.builder.fmul(ai, bi, name="c.m2"),
                name="c.mul.r"
            );
            ri = self.builder.fadd(
                self.builder.fmul(ar, bi, name="c.m3"),
                self.builder.fmul(ai, br, name="c.m4"),
                name="c.mul.i"
            );
        } elif op == Tok.DIV {
            denom = self.builder.fadd(
                self.builder.fmul(br, br, name="c.d1"),
                self.builder.fmul(bi, bi, name="c.d2"),
                name="c.denom"
            );
            rr = self.builder.fdiv(
                self.builder.fadd(
                    self.builder.fmul(ar, br, name="c.d3"),
                    self.builder.fmul(ai, bi, name="c.d4"),
                    name="c.div.rn"
                ),
                denom,
                name="c.div.r"
            );
            ri = self.builder.fdiv(
                self.builder.fsub(
                    self.builder.fmul(ai, br, name="c.d5"),
                    self.builder.fmul(ar, bi, name="c.d6"),
                    name="c.div.in"
                ),
                denom,
                name="c.div.i"
            );
        }
        if rr is not None and ri is not None {
            raw = self.builder.call(
                self.rc_alloc_fn, [ir.Constant(i64, 16)], name="c.res.raw"
            );
            ptr = self.builder.bitcast(raw, ctype_ptr, name="c.res.ptr");
            self.builder.store(rr, self.builder.gep(ptr, [z0, z0], name="c.res.rp"));
            self.builder.store(ri, self.builder.gep(ptr, [z0, z1], name="c.res.ip"));
            return ptr;
        }
    }

    if self?.jacval_type
        and (left.type == self.jacval_type or right.type == self.jacval_type) {
        self.emit(
            E5092,
            node_override=self.cur_node,
            kind="binary operator",
            name=f"{op} on a tagged `any` operand"
        );
        return None;
    }

    is_float = isinstance(left.type, (ir.DoubleType, ir.FloatType))
        or isinstance(right.type, (ir.DoubleType, ir.FloatType))
        or op == Tok.DIV;
    if is_float {
        (left, right) = self._promote_to_float(left, right, unsigned=unsigned);
    }
    if is_float {
        if op == Tok.PLUS {
            return self.builder.fadd(left, right, name="fadd");
        } elif op == Tok.MINUS {
            return self.builder.fsub(left, right, name="fsub");
        } elif op == Tok.STAR_MUL {
            return self.builder.fmul(left, right, name="fmul");
        } elif op == Tok.DIV {
            fzero = ir.Constant(right.type, 0.0);
            is_zero = self.builder.fcmp_ordered(
                "==", right, fzero, name="fdiv.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "float division by zero"
            );
            return self.builder.fdiv(left, right, name="fdiv");
        } elif op == Tok.MOD {
            fzero = ir.Constant(right.type, 0.0);
            is_zero = self.builder.fcmp_ordered(
                "==", right, fzero, name="fmod.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "float modulo by zero"
            );
            return self._codegen_float_floor_mod(left, right);
        } elif op == Tok.FLOOR_DIV {
            fzero = ir.Constant(right.type, 0.0);
            is_zero = self.builder.fcmp_ordered(
                "==", right, fzero, name="ffloordiv.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "float floor division by zero"
            );
            return self._codegen_float_floor_div(left, right);
        }
    } else {
        if not isinstance(left.type, ir.IntType)
            or not isinstance(right.type, ir.IntType) {
            self.emit(
                E5092,
                node_override=self.cur_node,
                kind="integer operator layout",
                name=f"{op} on {left.type} vs {right.type}"
            );
            return None;
        }
        (left, right) = self._unify_int_widths(left, right);
        if op == Tok.LSHIFT {
            if checked {
                return self._emit_checked_shl(left, right, unsigned);
            }
            return self.builder.shl(left, right, name="shl");
        } elif op == Tok.RSHIFT {
            if checked {
                return self._emit_shr(left, right, unsigned);
            }
            return self.builder.ashr(left, right, name="ashr");
        }
        if left.type != right.type {
            self.emit(
                E5092,
                node_override=self.cur_node,
                kind="integer operator layout",
                name=f"{op} on {left.type} vs {right.type}"
            );
            return None;
        }
        int_ty = left.type;
        if op == Tok.PLUS {
            return self._emit_overflow_op("add", left, right, unsigned);
        } elif op == Tok.MINUS {
            return self._emit_overflow_op("sub", left, right, unsigned);
        } elif op == Tok.STAR_MUL {
            return self._emit_overflow_op("mul", left, right, unsigned);
        } elif op == Tok.FLOOR_DIV {
            izero = ir.Constant(int_ty, 0);
            is_zero = self.builder.icmp_signed(
                "==", right, izero, name="floordiv.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "integer division or modulo by zero"
            );
            (q, _) = self._emit_int_divmod(left, right, unsigned);
            return q;
        } elif op == Tok.MOD {
            izero = ir.Constant(int_ty, 0);
            is_zero = self.builder.icmp_signed("==", right, izero, name="mod.zero.chk");
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "integer division or modulo by zero"
            );
            (_, r) = self._emit_int_divmod(left, right, unsigned, trap_min=False);
            return r;
        }
    }

    if op == Tok.BW_AND {
        return self.builder.and_(left, right, name="bwand");
    }
    if op == Tok.BW_OR {
        return self.builder.or_(left, right, name="bwor");
    }
    if op == Tok.BW_XOR {
        return self.builder.xor(left, right, name="bwxor");
    }

    if op == Tok.KW_AND {
        return self.builder.and_(left, right, name="and");
    }
    if op == Tok.KW_OR {
        return self.builder.or_(left, right, name="or");
    }

    self.emit(E5092, node_override=self.cur_node, kind="binary operator", name=op);
    return None;
}

impl NaIRGenTypes._emit_arch_dunder_binop(
    op: str, left: ir.Value, right: ir.Value
) -> (ir.Value | None) {
    import from jaclang.compiler.types.operations { BINARY_OPERATOR_MAP }
    _pair = BINARY_OPERATOR_MAP.get(op);
    if _pair is None {
        return None;
    }
    (magic, rmagic) = _pair;

    def _try_dispatch(
        pass_ref: NaIRGenState, recv: ir.Value, arg: ir.Value, mname: str
    ) -> (ir.Value | None) {
        if not isinstance(recv.type, ir.PointerType) {
            return None;
        }
        arch = pass_ref._infer_type_name(recv);
        if arch is None {
            return None;
        }
        mfn = pass_ref._resolve_method(arch, mname);
        if mfn is None or len(mfn.args) != 2 {
            return None;
        }
        _dargs = [
            pass_ref._coerce_type(recv, mfn.args[0].type),
            pass_ref._coerce_type(arg, mfn.args[1].type)
        ];
        _dres = pass_ref.builder.call(mfn, _dargs, name=f"dunder.{mname}");
        pass_ref._release_owned_args(_dargs, op="call_arg");
        return _dres;
    }

    _res = _try_dispatch(self, left, right, magic);
    if _res is not None {
        return _res;
    }
    return _try_dispatch(self, right, left, rmagic);
}

impl NaIRGenTypes._opt_membership_operand(left: ir.Value, slot_type: ir.Type) -> tuple {
    _pt = self._opt_payload_of(left.type);
    if _pt is None or (self?.jacval_type and slot_type == self.jacval_type) {
        return (self._coerce_type(left, slot_type), None);
    }
    i8p = ir.IntType(8).as_pointer();
    _tag = self.builder.extract_value(left, 0, name="opt.in.tag");
    _tag_set = self.builder.icmp_signed(
        "!=", _tag, ir.Constant(ir.IntType(8), 0), name="opt.in.has"
    );
    _pv = self.builder.extract_value(left, 1, name="opt.in.pv");
    if _pv.type == i8p and slot_type == i8p {
        _pv = self.builder.select(
            _tag_set,
            _pv,
            self.builder.bitcast(
                self._make_global_string(""), i8p, name="opt.in.empty"
            ),
            name="opt.in.safe"
        );
    }
    return (self._coerce_type(_pv, slot_type), _tag_set);
}

impl NaIRGenTypes._emit_jacval_eq(left: ir.Value, right: ir.Value) -> ir.Value {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i8p = ir.IntType(8).as_pointer();
    ltag = self.builder.extract_value(left, 0, name="jv.eq.ltag");
    rtag = self.builder.extract_value(right, 0, name="jv.eq.rtag");
    lpay = self.builder.extract_value(left, 1, name="jv.eq.lpay");
    rpay = self.builder.extract_value(right, 1, name="jv.eq.rpay");
    tag_eq = self.builder.icmp_signed("==", ltag, rtag, name="jv.eq.tag");
    both_str = self.builder.and_(
        self.builder.icmp_signed("==", ltag, ir.Constant(i8, 2), name="jv.eq.lstr"),
        self.builder.icmp_signed("==", rtag, ir.Constant(i8, 2), name="jv.eq.rstr"),
        name="jv.eq.bothstr"
    );
    func = self.builder.basic_block.function;
    entry_bb = self.builder.basic_block;
    str_bb = func.append_basic_block(name="jv.eq.str");
    bits_bb = func.append_basic_block(name="jv.eq.bits");
    merge_bb = func.append_basic_block(name="jv.eq.done");
    self.builder.cbranch(both_str, str_bb, bits_bb);
    self.builder.position_at_start(str_bb);
    strcmp_fn = self._get_or_declare_extern("strcmp", ir.IntType(32), [i8p, i8p]);
    sres = self.builder.call(
        strcmp_fn,
        [
            self.builder.inttoptr(lpay, i8p, name="jv.eq.lsp"),
            self.builder.inttoptr(rpay, i8p, name="jv.eq.rsp")
        ],
        name="jv.eq.strcmp"
    );
    str_eq = self.builder.icmp_signed(
        "==", sres, ir.Constant(ir.IntType(32), 0), name="jv.eq.streq"
    );
    self.builder.branch(merge_bb);
    self.builder.position_at_start(bits_bb);
    pay_eq = self.builder.icmp_signed("==", lpay, rpay, name="jv.eq.pay");
    bits_eq = self.builder.and_(tag_eq, pay_eq, name="jv.eq.bitseq");
    self.builder.branch(merge_bb);
    self.builder.position_at_start(merge_bb);
    res = self.builder.phi(i1, name="jv.eq");
    res.add_incoming(str_eq, str_bb);
    res.add_incoming(bits_eq, bits_bb);
    return res;
}

impl NaIRGenTypes._emit_optional_eq(
    op: str, left: ir.Value, right: ir.Value, is_float: bool
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    _lp = self._opt_payload_of(left.type);
    _rp = self._opt_payload_of(right.type);
    func = self.builder.basic_block.function;
    if _lp is not None and _rp is not None {
        if str(_lp) != str(_rp) {
            return None;
        }
        ltag = self.builder.extract_value(left, 0, name="opt.eq.ltag");
        rtag = self.builder.extract_value(right, 0, name="opt.eq.rtag");
        lset = self.builder.icmp_signed(
            "!=", ltag, ir.Constant(i8, 0), name="opt.eq.lset"
        );
        rset = self.builder.icmp_signed(
            "!=", rtag, ir.Constant(i8, 0), name="opt.eq.rset"
        );
        both_set = self.builder.and_(lset, rset, name="opt.eq.bothset");
        both_none = self.builder.and_(
            self.builder.not_(lset, name="opt.eq.lnone"),
            self.builder.not_(rset, name="opt.eq.rnone"),
            name="opt.eq.bothnone"
        );
        entry_bb = self.builder.basic_block;
        pay_bb = func.append_basic_block(name="opt.eq.payload");
        merge_bb = func.append_basic_block(name="opt.eq.done");
        self.builder.cbranch(both_set, pay_bb, merge_bb);
        self.builder.position_at_start(pay_bb);
        pl = self.builder.extract_value(left, 1, name="opt.eq.lpayload");
        pr = self.builder.extract_value(right, 1, name="opt.eq.rpayload");
        pcmp = self._emit_comparison(Tok.EE, pl, pr, is_float);
        if pcmp is None {
            return None;
        }
        pcmp = self._to_bool(pcmp);
        pay_end = self.builder.basic_block;
        self.builder.branch(merge_bb);
        self.builder.position_at_start(merge_bb);
        res = self.builder.phi(i1, name="opt.eq.res");
        res.add_incoming(both_none, entry_bb);
        res.add_incoming(pcmp, pay_end);
        if op == Tok.NE {
            return self.builder.not_(res, name="opt.eq.ne");
        }
        return res;
    }
    opt_v = left if _lp is not None else right;
    pt = _lp if _lp is not None else _rp;
    other = right if _lp is not None else left;
    tag = self.builder.extract_value(opt_v, 0, name="opt.eq.tag");
    tag_set = self.builder.icmp_signed(
        "!=", tag, ir.Constant(i8, 0), name="opt.eq.set"
    );
    if isinstance(other, ir.Constant)
        and isinstance(other.type, ir.PointerType)
        and other.constant is None {
        if op == Tok.NE {
            return tag_set;
        }
        return self.builder.not_(tag_set, name="opt.eq.isnone");
    }
    entry_bb = self.builder.basic_block;
    pay_bb = func.append_basic_block(name="opt.eq.payload");
    merge_bb = func.append_basic_block(name="opt.eq.done");
    self.builder.cbranch(tag_set, pay_bb, merge_bb);
    self.builder.position_at_start(pay_bb);
    pv = self.builder.extract_value(opt_v, 1, name="opt.eq.payloadval");
    ov = self._coerce_type(other, pt);
    pcmp = self._emit_comparison(Tok.EE, pv, ov, is_float);
    if pcmp is None {
        return None;
    }
    pcmp = self._to_bool(pcmp);
    pay_end = self.builder.basic_block;
    self.builder.branch(merge_bb);
    self.builder.position_at_start(merge_bb);
    res = self.builder.phi(i1, name="opt.eq.res");
    res.add_incoming(ir.Constant(i1, 0), entry_bb);
    res.add_incoming(pcmp, pay_end);
    if op == Tok.NE {
        return self.builder.not_(res, name="opt.eq.ne");
    }
    return res;
}

impl NaIRGenTypes._is_jacval_ty(t: ir.Type) -> bool {
    if not self?.jacval_type {
        return False;
    }
    return isinstance(t, ir.IdentifiedStructType) and t.name == self.jacval_type.name;
}

impl NaIRGenTypes._is_jacval_boxable(t: ir.Type) -> bool {
    if self._is_jacval_ty(t) {
        return True;
    }
    if isinstance(t, (ir.IntType, ir.DoubleType, ir.PointerType)) {
        return True;
    }
    _sd = self._str_desc_ty;
    return (
        _sd is not None
        and isinstance(t, ir.IdentifiedStructType)
        and t.name == _sd.name
    );
}

impl NaIRGenTypes._emit_jacval_ordering(
    op: str, jv: ir.Value, peer: ir.Value, jv_on_left: bool
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    _dbl = ir.DoubleType();
    _sym = {Tok.LT: "<", Tok.GT: ">", Tok.LTE: "<=", Tok.GTE: ">="}.get(op, "<");
    _tag = self.builder.extract_value(jv, 0, name="jv.ord.tag");
    _pay = self.builder.extract_value(jv, 1, name="jv.ord.pay");
    _is_flt = self.builder.icmp_signed(
        "==", _tag, ir.Constant(i8, 1), name="jv.ord.isflt"
    );
    _is_int = self.builder.icmp_signed(
        "==", _tag, ir.Constant(i8, 0), name="jv.ord.isint"
    );
    _is_bool = self.builder.icmp_signed(
        "==", _tag, ir.Constant(i8, 7), name="jv.ord.isbool"
    );
    _numeric = self.builder.or_(
        _is_flt,
        self.builder.or_(_is_int, _is_bool, name="jv.ord.intish"),
        name="jv.ord.num"
    );
    self._emit_runtime_raise(
        self.builder.not_(_numeric, name="jv.ord.bad"),
        "TypeError",
        f"'{_sym}' not supported between these operand types"
    );
    _jv_f = self.builder.select(
        _is_flt,
        self.builder.bitcast(_pay, _dbl, name="jv.ord.f.bits"),
        self.builder.sitofp(_pay, _dbl, name="jv.ord.f.conv"),
        name="jv.ord.f"
    );
    if isinstance(peer.type, ir.DoubleType) {
        _fl = _jv_f if jv_on_left else peer;
        _fr = peer if jv_on_left else _jv_f;
        return self._emit_comparison(op, _fl, _fr, True);
    }
    _peer_i = self._coerce_type(peer, i64);
    _peer_f = self.builder.sitofp(_peer_i, _dbl, name="jv.ord.peer.f");
    _il = _pay if jv_on_left else _peer_i;
    _ir_ = _peer_i if jv_on_left else _pay;
    _int_res = self._emit_comparison(op, _il, _ir_, False);
    _ml = _jv_f if jv_on_left else _peer_f;
    _mr = _peer_f if jv_on_left else _jv_f;
    _flt_res = self._emit_comparison(op, _ml, _mr, True);
    if _int_res is None or _flt_res is None {
        return None;
    }
    return self.builder.select(_is_flt, _flt_res, _int_res, name="jv.ord.res");
}

impl NaIRGenTypes._emit_mixed_jacval_comparison(
    op: str, left: ir.Value, right: ir.Value
) -> (ir.Value | None) {
    _left_boxed = self._is_jacval_ty(left.type);
    _peer = right.type if _left_boxed else left.type;
    if op in (Tok.EE, Tok.NE) and self._is_jacval_boxable(_peer) {
        if _left_boxed {
            right = self._coerce_type(right, self.jacval_type);
        } else {
            left = self._coerce_type(left, self.jacval_type);
        }
        _mx_res = self._emit_jacval_eq(left, right);
        if op == Tok.NE {
            return self.builder.not_(_mx_res, name="jv.mixed.ne");
        }
        return _mx_res;
    }
    if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE)
        and isinstance(_peer, (ir.IntType, ir.DoubleType)) {
        return self._emit_jacval_ordering(
            op,
            left if _left_boxed else right,
            right if _left_boxed else left,
            _left_boxed
        );
    }
    self.emit(
        E5090,
        kind="comparison",
        name=f"tagged `any` value against {_peer}",
        help_text="The element type of this container could not be inferred, so its values are stored as tagged `any`. Annotate the container (for example `list[int]`) so both sides of the comparison lower to the same representation."
    );
    return None;
}

impl NaIRGenTypes._emit_comparison(
    op: str, left: ir.Value, right: ir.Value, is_float: bool, unsigned: bool = False
) -> (ir.Value | None) {
    if self?.jacval_type
        and left.type == self.jacval_type
        and right.type == self.jacval_type
        and op in (Tok.EE, Tok.NE) {
        _jv_res = self._emit_jacval_eq(left, right);
        if op == Tok.NE {
            return self.builder.not_(_jv_res, name="jv.ne");
        }
        return _jv_res;
    }
    if self?.jacval_type
        and self._is_jacval_ty(left.type) != self._is_jacval_ty(right.type)
        and self._opt_payload_of(left.type) is None
        and self._opt_payload_of(right.type) is None {
        return self._emit_mixed_jacval_comparison(op, left, right);
    }
    _l_opt = self._opt_payload_of(left.type);
    _r_opt = self._opt_payload_of(right.type);
    if _l_opt is not None or _r_opt is not None {
        if op in (Tok.EE, Tok.NE) {
            return self._emit_optional_eq(op, left, right, is_float);
        }
        if _l_opt is not None {
            left = self._coerce_type(left, _l_opt);
        }
        if _r_opt is not None {
            right = self._coerce_type(right, _r_opt);
        }
        return self._emit_comparison(op, left, right, is_float);
    }
    _dty = self._str_desc_ty;
    if _dty is not None
        and (left.type == _dty or right.type == _dty)
        and op in (Tok.EE, Tok.NE, Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) {
        _lp = self._str_cmp_parts_of(left);
        _rp = self._str_cmp_parts_of(right);
        if _lp is not None and _rp is not None {
            _sc3 = self._call_str_cmp3(self.builder, _lp[0], _lp[1], _rp[0], _rp[1]);
            _z32c = ir.Constant(ir.IntType(32), 0);
            _cmp_op = {
                Tok.EE: "==",
                Tok.NE: "!=",
                Tok.LT: "<",
                Tok.GT: ">",
                Tok.LTE: "<=",
                Tok.GTE: ">="
            }[op];
            return self.builder.icmp_signed(_cmp_op, _sc3, _z32c, name="scmp3");
        }
    }
    left = self._str_norm(left);
    right = self._str_norm(right);
    _l_is_tval = isinstance(left.type, ir.LiteralStructType);
    _r_is_tval = isinstance(right.type, ir.LiteralStructType);
    _l_is_tptr = isinstance(left.type, ir.PointerType)
        and isinstance(left.type.pointee, ir.LiteralStructType);
    _r_is_tptr = isinstance(right.type, ir.PointerType)
        and isinstance(right.type.pointee, ir.LiteralStructType);
    if _l_is_tval or _r_is_tval or _l_is_tptr or _r_is_tptr {
        tcmp_struct: (ir.LiteralStructType | None) = None;
        tcmp_left_val: (ir.Value | None) = None;
        tcmp_right_val: (ir.Value | None) = None;
        if _l_is_tval and _r_is_tval and str(left.type) == str(right.type) {
            tcmp_struct = left.type;
            tcmp_left_val = left;
            tcmp_right_val = right;
        } elif _l_is_tptr
            and _r_is_tptr
            and str(left.type.pointee) == str(right.type.pointee) {
            tcmp_struct = left.type.pointee;
            tcmp_left_val = self.builder.load(left, name="tcmp.l.val");
            tcmp_right_val = self.builder.load(right, name="tcmp.r.val");
        } elif _l_is_tval
            and _r_is_tptr
            and str(left.type) == str(right.type.pointee) {
            tcmp_struct = left.type;
            tcmp_left_val = left;
            tcmp_right_val = self.builder.load(right, name="tcmp.r.val");
        } elif _r_is_tval
            and _l_is_tptr
            and str(right.type) == str(left.type.pointee) {
            tcmp_struct = right.type;
            tcmp_left_val = self.builder.load(left, name="tcmp.l.val");
            tcmp_right_val = right;
        }
        if tcmp_struct is not None
            and tcmp_left_val is not None
            and tcmp_right_val is not None {
            n = len(tcmp_struct.elements);
            i1_t = ir.IntType(1);
            if op == Tok.EE or op == Tok.NE {
                result = ir.Constant(i1_t, 1);
                for i in range(n) {
                    ea = self.builder.extract_value(
                        tcmp_left_val, i, name=f"tcmp.ea.{i}"
                    );
                    eb = self.builder.extract_value(
                        tcmp_right_val, i, name=f"tcmp.eb.{i}"
                    );
                    if isinstance(ea.type, ir.IntType) {
                        eq_i = self.builder.icmp_signed(
                            "==", ea, eb, name=f"tcmp.eq.{i}"
                        );
                    } elif isinstance(ea.type, ir.DoubleType) {
                        eq_i = self.builder.fcmp_ordered(
                            "==", ea, eb, name=f"tcmp.eq.{i}"
                        );
                    } else {
                        tcmp_sc = self._call_str_cmp(
                            self.builder, ea, eb, name=f"tcmp.sc.{i}"
                        );
                        eq_i = self.builder.icmp_signed(
                            "==",
                            tcmp_sc,
                            ir.Constant(ir.IntType(32), 0),
                            name=f"tcmp.eq.{i}"
                        );
                    }
                    result = self.builder.and_(result, eq_i, name=f"tcmp.all.{i}");
                }
                if op == Tok.NE {
                    return self.builder.not_(result, name="tcmp.ne");
                }
                return result;
            }
            if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) and n > 0 {
                func = self.builder.basic_block.function;
                tcmp_true_bb = func.append_basic_block(name="tcmp.lex.true");
                tcmp_false_bb = func.append_basic_block(name="tcmp.lex.false");
                tcmp_done_bb = func.append_basic_block(name="tcmp.lex.done");
                for i in range(n) {
                    ea = self.builder.extract_value(
                        tcmp_left_val, i, name=f"tcmp.lex.ea.{i}"
                    );
                    eb = self.builder.extract_value(
                        tcmp_right_val, i, name=f"tcmp.lex.eb.{i}"
                    );
                    if isinstance(ea.type, ir.IntType) {
                        lt_i = self.builder.icmp_signed(
                            "<", ea, eb, name=f"tcmp.lt.{i}"
                        );
                        gt_i = self.builder.icmp_signed(
                            ">", ea, eb, name=f"tcmp.gt.{i}"
                        );
                    } elif isinstance(ea.type, ir.DoubleType) {
                        lt_i = self.builder.fcmp_ordered(
                            "<", ea, eb, name=f"tcmp.lt.{i}"
                        );
                        gt_i = self.builder.fcmp_ordered(
                            ">", ea, eb, name=f"tcmp.gt.{i}"
                        );
                    } else {
                        tcmp_sc2 = self._call_str_cmp(
                            self.builder, ea, eb, name=f"tcmp.lex.sc.{i}"
                        );
                        tcmp_z32 = ir.Constant(ir.IntType(32), 0);
                        lt_i = self.builder.icmp_signed(
                            "<", tcmp_sc2, tcmp_z32, name=f"tcmp.lt.{i}"
                        );
                        gt_i = self.builder.icmp_signed(
                            ">", tcmp_sc2, tcmp_z32, name=f"tcmp.gt.{i}"
                        );
                    }
                    next_bb = func.append_basic_block(name=f"tcmp.lex.next.{i}");
                    if op == Tok.LT or op == Tok.LTE {
                        self.builder.cbranch(lt_i, tcmp_true_bb, next_bb);
                        self.builder.position_at_start(next_bb);
                        next2_bb = func.append_basic_block(name=f"tcmp.lex.eq.{i}");
                        self.builder.cbranch(gt_i, tcmp_false_bb, next2_bb);
                        self.builder.position_at_start(next2_bb);
                    } else {
                        self.builder.cbranch(gt_i, tcmp_true_bb, next_bb);
                        self.builder.position_at_start(next_bb);
                        next2_bb = func.append_basic_block(name=f"tcmp.lex.eq.{i}");
                        self.builder.cbranch(lt_i, tcmp_false_bb, next2_bb);
                        self.builder.position_at_start(next2_bb);
                    }
                }
                if op == Tok.LTE or op == Tok.GTE {
                    self.builder.branch(tcmp_true_bb);
                } else {
                    self.builder.branch(tcmp_false_bb);
                }
                self.builder.position_at_start(tcmp_true_bb);
                self.builder.branch(tcmp_done_bb);
                self.builder.position_at_start(tcmp_false_bb);
                self.builder.branch(tcmp_done_bb);
                self.builder.position_at_start(tcmp_done_bb);
                tcmp_res = self.builder.phi(i1_t, name="tcmp.lex.res");
                tcmp_res.add_incoming(ir.Constant(i1_t, 1), tcmp_true_bb);
                tcmp_res.add_incoming(ir.Constant(i1_t, 0), tcmp_false_bb);
                return tcmp_res;
            }
        }
    }

    if isinstance(left.type, ir.PointerType)
        and isinstance(right.type, ir.PointerType) {
        i8_ptr = ir.IntType(8).as_pointer();

        if self._is_bytes_value(left) and self._is_bytes_value(right) {
            if op == Tok.EE or op == Tok.NE {
                return self._emit_bytes_eq(left, right, negate=op == Tok.NE);
            }
            if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) {
                _sym = "<"
                    if op == Tok.LT
                    else (">" if op == Tok.GT else ("<=" if op == Tok.LTE else ">="));
                _ord = self._emit_bytes_cmp(left, right, _sym);
                _zero = ir.Constant(ir.IntType(32), 0);
                if op == Tok.LT {
                    return self.builder.icmp_signed("<", _ord, _zero, name="by.lt");
                }
                if op == Tok.GT {
                    return self.builder.icmp_signed(">", _ord, _zero, name="by.gt");
                }
                if op == Tok.LTE {
                    return self.builder.icmp_signed("<=", _ord, _zero, name="by.lte");
                }
                return self.builder.icmp_signed(">=", _ord, _zero, name="by.gte");
            }
        }

        if left.type == i8_ptr and right.type == i8_ptr {
            cmp_result = self._call_str_cmp(self.builder, left, right, name="strcmp");
            zero = ir.Constant(ir.IntType(32), 0);
            if op == Tok.EE or op == Tok.NE {
                _sym = "==" if op == Tok.EE else "!=";
                _nm = "streq" if op == Tok.EE else "strne";
                return self.builder.icmp_signed(_sym, cmp_result, zero, name=_nm);
            }
            if op == Tok.LT {
                return self.builder.icmp_signed("<", cmp_result, zero, name="strlt");
            } elif op == Tok.GT {
                return self.builder.icmp_signed(">", cmp_result, zero, name="strgt");
            } elif op == Tok.LTE {
                return self.builder.icmp_signed("<=", cmp_result, zero, name="strle");
            } elif op == Tok.GTE {
                return self.builder.icmp_signed(">=", cmp_result, zero, name="strge");
            }
            return None;
        }

        for (lcmp_key, lcmp_type) in self.list_types.items() {
            if left.type == lcmp_type.as_pointer()
                and right.type == lcmp_type.as_pointer() {
                lcmp_h = self.list_helpers.get(lcmp_key);
                if lcmp_h is None {
                    break;
                }
                i64 = ir.IntType(64);
                i1_t = ir.IntType(1);
                lcmp_la = self.builder.call(lcmp_h["len"], [left], name="lcmp.la");
                lcmp_lb = self.builder.call(lcmp_h["len"], [right], name="lcmp.lb");
                func = self.builder.basic_block.function;
                lcmp_entry_bb = self.builder.basic_block;
                lcmp_et = lcmp_h["elem_type"];
                if op == Tok.EE or op == Tok.NE {
                    lcmp_len_eq = self.builder.icmp_unsigned(
                        "==", lcmp_la, lcmp_lb, name="lcmp.leq"
                    );
                    lcmp_chk_bb = func.append_basic_block(name="lcmp.eq.chk");
                    lcmp_false_bb = func.append_basic_block(name="lcmp.eq.false");
                    lcmp_loop_bb = func.append_basic_block(name="lcmp.eq.loop");
                    lcmp_body_bb = func.append_basic_block(name="lcmp.eq.body");
                    lcmp_ne_bb = func.append_basic_block(name="lcmp.eq.ne");
                    lcmp_next_bb = func.append_basic_block(name="lcmp.eq.next");
                    lcmp_done_bb = func.append_basic_block(name="lcmp.eq.done");
                    self.builder.cbranch(lcmp_len_eq, lcmp_chk_bb, lcmp_false_bb);
                    self.builder.position_at_start(lcmp_chk_bb);
                    self.builder.branch(lcmp_loop_bb);
                    self.builder.position_at_start(lcmp_loop_bb);
                    lcmp_i = self.builder.phi(i64, name="lcmp.eq.i");
                    lcmp_i.add_incoming(ir.Constant(i64, 0), lcmp_chk_bb);
                    lcmp_iend = self.builder.icmp_unsigned(
                        ">=", lcmp_i, lcmp_la, name="lcmp.eq.iend"
                    );
                    self.builder.cbranch(lcmp_iend, lcmp_done_bb, lcmp_body_bb);
                    self.builder.position_at_start(lcmp_body_bb);
                    lcmp_ea = self.builder.call(
                        lcmp_h["get"], [left, lcmp_i], name="lcmp.ea"
                    );
                    lcmp_eb = self.builder.call(
                        lcmp_h["get"], [right, lcmp_i], name="lcmp.eb"
                    );
                    if isinstance(lcmp_et, ir.IntType) {
                        lcmp_elem_ne = self.builder.icmp_signed(
                            "!=", lcmp_ea, lcmp_eb, name="lcmp.ene"
                        );
                    } elif isinstance(lcmp_et, ir.DoubleType) {
                        lcmp_elem_ne = self.builder.fcmp_ordered(
                            "!=", lcmp_ea, lcmp_eb, name="lcmp.ene"
                        );
                    } elif self?.jacval_type and lcmp_et == self.jacval_type {
                        lcmp_elem_ne = self.builder.not_(
                            self._emit_jacval_eq(lcmp_ea, lcmp_eb), name="lcmp.ene"
                        );
                    } else {
                        lcmp_scmp = self._call_str_cmp(
                            self.builder, lcmp_ea, lcmp_eb, name="lcmp.scmp"
                        );
                        lcmp_elem_ne = self.builder.icmp_signed(
                            "!=",
                            lcmp_scmp,
                            ir.Constant(ir.IntType(32), 0),
                            name="lcmp.ene"
                        );
                    }
                    self.builder.cbranch(lcmp_elem_ne, lcmp_ne_bb, lcmp_next_bb);
                    self.builder.position_at_start(lcmp_ne_bb);
                    self.builder.branch(lcmp_false_bb);
                    self.builder.position_at_start(lcmp_next_bb);
                    lcmp_ni = self.builder.add(
                        lcmp_i, ir.Constant(i64, 1), name="lcmp.ni"
                    );
                    lcmp_i.add_incoming(lcmp_ni, lcmp_next_bb);
                    self.builder.branch(lcmp_loop_bb);
                    self.builder.position_at_start(lcmp_false_bb);
                    self.builder.branch(lcmp_done_bb);
                    self.builder.position_at_start(lcmp_done_bb);
                    lcmp_result = self.builder.phi(i1_t, name="lcmp.eq.result");
                    lcmp_result.add_incoming(ir.Constant(i1_t, 1), lcmp_loop_bb);
                    lcmp_result.add_incoming(ir.Constant(i1_t, 0), lcmp_false_bb);
                    if op == Tok.NE {
                        return self.builder.not_(lcmp_result, name="lcmp.ne");
                    }
                    return lcmp_result;
                }

                if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) {
                    if self?.jacval_type and lcmp_et == self.jacval_type {
                        self.emit(
                            E5092,
                            kind="comparison",
                            name="ordering on tagged-element lists"
                        );
                        return None;
                    }
                    lcmp_lt_len = self.builder.icmp_unsigned(
                        "<", lcmp_la, lcmp_lb, name="lcmp.lex.ltl"
                    );
                    lcmp_min = self.builder.select(
                        lcmp_lt_len, lcmp_la, lcmp_lb, name="lcmp.min"
                    );
                    lcmp_lex_loop = func.append_basic_block(name="lcmp.lex.loop");
                    lcmp_lex_body = func.append_basic_block(name="lcmp.lex.body");
                    lcmp_lex_lbody = func.append_basic_block(name="lcmp.lex.lbody");
                    lcmp_lex_next = func.append_basic_block(name="lcmp.lex.next");
                    lcmp_lex_after = func.append_basic_block(name="lcmp.lex.after");
                    lcmp_lex_true = func.append_basic_block(name="lcmp.lex.true");
                    lcmp_lex_false = func.append_basic_block(name="lcmp.lex.false");
                    lcmp_lex_done = func.append_basic_block(name="lcmp.lex.done");
                    self.builder.branch(lcmp_lex_loop);
                    self.builder.position_at_start(lcmp_lex_loop);
                    lcmp_li = self.builder.phi(i64, name="lcmp.lex.i");
                    lcmp_li.add_incoming(ir.Constant(i64, 0), lcmp_entry_bb);
                    lcmp_lend = self.builder.icmp_unsigned(
                        ">=", lcmp_li, lcmp_min, name="lcmp.lex.lend"
                    );
                    self.builder.cbranch(lcmp_lend, lcmp_lex_after, lcmp_lex_body);
                    self.builder.position_at_start(lcmp_lex_body);
                    lcmp_lea = self.builder.call(
                        lcmp_h["get"], [left, lcmp_li], name="lcmp.lex.ea"
                    );
                    lcmp_leb = self.builder.call(
                        lcmp_h["get"], [right, lcmp_li], name="lcmp.lex.eb"
                    );
                    if isinstance(lcmp_et, ir.IntType) {
                        lcmp_lex_lt = self.builder.icmp_signed(
                            "<", lcmp_lea, lcmp_leb, name="lcmp.lex.lt"
                        );
                        lcmp_lex_gt = self.builder.icmp_signed(
                            ">", lcmp_lea, lcmp_leb, name="lcmp.lex.gt"
                        );
                    } elif isinstance(lcmp_et, ir.DoubleType) {
                        lcmp_lex_lt = self.builder.fcmp_ordered(
                            "<", lcmp_lea, lcmp_leb, name="lcmp.lex.lt"
                        );
                        lcmp_lex_gt = self.builder.fcmp_ordered(
                            ">", lcmp_lea, lcmp_leb, name="lcmp.lex.gt"
                        );
                    } else {
                        lcmp_scmp2 = self._call_str_cmp(
                            self.builder, lcmp_lea, lcmp_leb, name="lcmp.lex.sc"
                        );
                        lcmp_zero32 = ir.Constant(ir.IntType(32), 0);
                        lcmp_lex_lt = self.builder.icmp_signed(
                            "<", lcmp_scmp2, lcmp_zero32, name="lcmp.lex.lt"
                        );
                        lcmp_lex_gt = self.builder.icmp_signed(
                            ">", lcmp_scmp2, lcmp_zero32, name="lcmp.lex.gt"
                        );
                    }

                    if op == Tok.LT or op == Tok.LTE {
                        self.builder.cbranch(
                            lcmp_lex_lt, lcmp_lex_true, lcmp_lex_lbody
                        );
                        self.builder.position_at_start(lcmp_lex_lbody);
                        self.builder.cbranch(
                            lcmp_lex_gt, lcmp_lex_false, lcmp_lex_next
                        );
                    } else {
                        self.builder.cbranch(
                            lcmp_lex_gt, lcmp_lex_true, lcmp_lex_lbody
                        );
                        self.builder.position_at_start(lcmp_lex_lbody);
                        self.builder.cbranch(
                            lcmp_lex_lt, lcmp_lex_false, lcmp_lex_next
                        );
                    }
                    self.builder.position_at_start(lcmp_lex_next);
                    lcmp_lni = self.builder.add(
                        lcmp_li, ir.Constant(i64, 1), name="lcmp.lni"
                    );
                    lcmp_li.add_incoming(lcmp_lni, lcmp_lex_next);
                    self.builder.branch(lcmp_lex_loop);
                    self.builder.position_at_start(lcmp_lex_after);

                    if op == Tok.LT {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            "<", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    } elif op == Tok.GT {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            ">", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    } elif op == Tok.LTE {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            "<=", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    } else {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            ">=", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    }
                    self.builder.cbranch(lcmp_len_res, lcmp_lex_true, lcmp_lex_false);
                    self.builder.position_at_start(lcmp_lex_true);
                    self.builder.branch(lcmp_lex_done);
                    self.builder.position_at_start(lcmp_lex_false);
                    self.builder.branch(lcmp_lex_done);
                    self.builder.position_at_start(lcmp_lex_done);
                    lcmp_lex_res = self.builder.phi(i1_t, name="lcmp.lex.res");
                    lcmp_lex_res.add_incoming(ir.Constant(i1_t, 1), lcmp_lex_true);
                    lcmp_lex_res.add_incoming(ir.Constant(i1_t, 0), lcmp_lex_false);
                    return lcmp_lex_res;
                }
                break;
            }
        }

        for (sk, st) in self.set_types.items() {
            if left.type == st.as_pointer() and right.type == st.as_pointer() {
                shelpers = self.set_helpers.get(sk);
                if shelpers is not None {
                    self._ensure_emitters();
                    _ctx = self._native_emit_ctx_class(pass_ref=self, type_key=sk);
                    _se = self._native_emitters.get("set");
                    if _se is not None {
                        i64 = ir.IntType(64);
                        i1_t = ir.IntType(1);
                        if op == Tok.LTE {
                            sub_val = _se.emit_issubset(_ctx, left, [right]);
                            return self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="sle"
                            );
                        }
                        if op == Tok.GTE {
                            sub_val = _se.emit_issubset(_ctx, right, [left]);
                            return self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="sge"
                            );
                        }

                        len_a = self.builder.call(
                            shelpers["len"], [left], name="scmp.la"
                        );
                        len_b = self.builder.call(
                            shelpers["len"], [right], name="scmp.lb"
                        );
                        if op == Tok.EE or op == Tok.NE {
                            len_eq = self.builder.icmp_unsigned(
                                "==", len_a, len_b, name="scmp.leq"
                            );
                            func = self.builder.basic_block.function;
                            check_bb = func.append_basic_block(name="scmp.check");
                            false_bb = func.append_basic_block(name="scmp.false");
                            done_bb = func.append_basic_block(name="scmp.done");
                            self.builder.cbranch(len_eq, check_bb, false_bb);
                            self.builder.position_at_start(check_bb);
                            sub_val = _se.emit_issubset(_ctx, left, [right]);
                            after_bb = self.builder.basic_block;
                            is_sub = self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="scmp.issub"
                            );
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(false_bb);
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(done_bb);
                            result = self.builder.phi(i1_t, name="scmp.result");
                            result.add_incoming(is_sub, after_bb);
                            result.add_incoming(ir.Constant(i1_t, 0), false_bb);
                            if op == Tok.NE {
                                return self.builder.not_(result, name="scmp.ne");
                            }
                            return result;
                        }
                        if op == Tok.LT {
                            len_lt = self.builder.icmp_unsigned(
                                "<", len_a, len_b, name="slt.lcmp"
                            );
                            func = self.builder.basic_block.function;
                            check_bb = func.append_basic_block(name="slt.check");
                            false_bb = func.append_basic_block(name="slt.false");
                            done_bb = func.append_basic_block(name="slt.done");
                            self.builder.cbranch(len_lt, check_bb, false_bb);
                            self.builder.position_at_start(check_bb);
                            sub_val = _se.emit_issubset(_ctx, left, [right]);
                            after_bb = self.builder.basic_block;
                            is_sub = self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="slt.issub"
                            );
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(false_bb);
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(done_bb);
                            result = self.builder.phi(i1_t, name="slt.result");
                            result.add_incoming(is_sub, after_bb);
                            result.add_incoming(ir.Constant(i1_t, 0), false_bb);
                            return result;
                        }
                        if op == Tok.GT {
                            len_gt = self.builder.icmp_unsigned(
                                "<", len_b, len_a, name="sgt.lcmp"
                            );
                            func = self.builder.basic_block.function;
                            check_bb = func.append_basic_block(name="sgt.check");
                            false_bb = func.append_basic_block(name="sgt.false");
                            done_bb = func.append_basic_block(name="sgt.done");
                            self.builder.cbranch(len_gt, check_bb, false_bb);
                            self.builder.position_at_start(check_bb);
                            sub_val = _se.emit_issubset(_ctx, right, [left]);
                            after_bb = self.builder.basic_block;
                            is_sub = self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="sgt.issub"
                            );
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(false_bb);
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(done_bb);
                            result = self.builder.phi(i1_t, name="sgt.result");
                            result.add_incoming(is_sub, after_bb);
                            result.add_incoming(ir.Constant(i1_t, 0), false_bb);
                            return result;
                        }
                    }
                }
                break;
            }
        }

        rtype_ptr = self.range_struct_type.as_pointer();
        if left.type == rtype_ptr
            and right.type == rtype_ptr
            and (op == Tok.EE or op == Tok.NE) {
            i1_t = ir.IntType(1);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);

            as_ = self.builder.load(
                self.builder.gep(left, [z0, ir.Constant(i32, 0)], name="rcmp.as.p"),
                name="rcmp.as"
            );
            bs_ = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 0)], name="rcmp.bs.p"),
                name="rcmp.bs"
            );
            ae = self.builder.load(
                self.builder.gep(left, [z0, ir.Constant(i32, 1)], name="rcmp.ae.p"),
                name="rcmp.ae"
            );
            be = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 1)], name="rcmp.be.p"),
                name="rcmp.be"
            );
            at = self.builder.load(
                self.builder.gep(left, [z0, ir.Constant(i32, 2)], name="rcmp.at.p"),
                name="rcmp.at"
            );
            bt = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 2)], name="rcmp.bt.p"),
                name="rcmp.bt"
            );
            seq = self.builder.icmp_signed("==", as_, bs_, name="rcmp.seq");
            eeq = self.builder.icmp_signed("==", ae, be, name="rcmp.eeq");
            teq = self.builder.icmp_signed("==", at, bt, name="rcmp.teq");
            result = self.builder.and_(
                seq, self.builder.and_(eeq, teq, name="rcmp.et"), name="rcmp.all"
            );
            if op == Tok.NE {
                return self.builder.not_(result, name="rcmp.ne");
            }
            return result;
        }

        ctype_ptr = self.complex_struct_type.as_pointer();
        if left.type == ctype_ptr and right.type == ctype_ptr {
            i1_t = ir.IntType(1);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);
            z1 = ir.Constant(i32, 1);
            ar = self.builder.load(
                self.builder.gep(left, [z0, z0], name="ceq.ar.p"), name="ceq.ar"
            );
            ai = self.builder.load(
                self.builder.gep(left, [z0, z1], name="ceq.ai.p"), name="ceq.ai"
            );
            br = self.builder.load(
                self.builder.gep(right, [z0, z0], name="ceq.br.p"), name="ceq.br"
            );
            bi = self.builder.load(
                self.builder.gep(right, [z0, z1], name="ceq.bi.p"), name="ceq.bi"
            );
            req = self.builder.fcmp_ordered("==", ar, br, name="ceq.r");
            ieq = self.builder.fcmp_ordered("==", ai, bi, name="ceq.i");
            result = self.builder.and_(req, ieq, name="ceq.both");
            if op == Tok.EE {
                return result;
            } elif op == Tok.NE {
                return self.builder.not_(result, name="ceq.ne");
            }
        }

        if op == Tok.EE {
            return self.builder.icmp_unsigned("==", left, right, name="ptreq");
        } elif op == Tok.NE {
            return self.builder.icmp_unsigned("!=", left, right, name="ptrne");
        }
        return None;
    }
    if is_float {
        if op == Tok.NE {
            return self.builder.fcmp_unordered("!=", left, right, name="fcmp");
        }
        fcmp_map: dict[(str, str)] = {
            Tok.EE: "==",
            Tok.LT: "<",
            Tok.GT: ">",
            Tok.LTE: "<=",
            Tok.GTE: ">="
        };
        if op in fcmp_map {
            return self.builder.fcmp_ordered(fcmp_map[op], left, right, name="fcmp");
        }
    } else {
        icmp_map: dict[(str, str)] = {
            Tok.EE: "==",
            Tok.NE: "!=",
            Tok.LT: "<",
            Tok.GT: ">",
            Tok.LTE: "<=",
            Tok.GTE: ">="
        };
        if op in icmp_map {
            if not isinstance(left.type, ir.IntType)
                or not isinstance(right.type, ir.IntType) {
                self.emit(
                    E5090,
                    kind="comparison",
                    name=f"{left.type} against {right.type}",
                    help_text="The two sides of this comparison lower to different native representations, so no integer comparison is well formed. Annotate the values (or the container they came from) so both sides agree."
                );
                return None;
            }
            (left, right) = self._unify_int_widths(left, right);
            if left.type != right.type {
                self.emit(
                    E5090,
                    kind="comparison",
                    name=f"{left.type} against {right.type}",
                    help_text="The two sides of this comparison lower to different integer widths. The checker unifies fixed-width operands, so a mismatch here is a lowering bug."
                );
                return None;
            }
            if unsigned {
                return self.builder.icmp_unsigned(
                    icmp_map[op], left, right, name="icmp"
                );
            }
            return self.builder.icmp_signed(icmp_map[op], left, right, name="icmp");
        }
    }
    return None;
}

impl NaIRGenTypes._infer_type_name(val: ir.Value) -> (str | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (sname, stype) in self.struct_types.items() {
        if val.type == stype.as_pointer() {
            return sname;
        }
    }
    return None;
}

impl NaIRGenTypes._infer_list_elem_type(val: ir.Value) -> (str | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (ename, ltype) in self.list_types.items() {
        if val.type == ltype.as_pointer() {
            return ename;
        }
    }
    return None;
}

impl NaIRGenTypes._infer_compr_elem_struct(compr: object) -> (str | None) {
    _coll_tk = self._type_key_of(compr.collection);
    if _coll_tk is not None
        and _coll_tk.startswith("list[")
        and _coll_tk.endswith("]") {
        _inner_tk = _coll_tk[5:-1];
        if _inner_tk in self.struct_types {
            return _inner_tk;
        }
        for part in _inner_tk.split("|") {
            if part in self.struct_types {
                return part;
            }
        }
    }
    return None;
}

impl NaIRGenTypes._lower_type_by_name(name: (str | None)) -> (ir.Type | None) {
    if name is None {
        return None;
    }
    if name in self.type_map {
        return self.type_map[name];
    }
    if name in ("None", "NoneType") {
        return ir.VoidType();
    }
    if name in ("any", "Any", "object") {
        return self.jacval_type;
    }
    return None;
}

impl NaIRGenTypes._lower_untyped_annotation(nd: uni.UniNode) -> (ir.Type | None) {
    if isinstance(nd, uni.Null) {
        return ir.VoidType();
    }
    if isinstance(nd, uni.AtomUnit) and nd.value is not None {
        return self._lower_untyped_annotation(nd.value);
    }
    if isinstance(nd, uni.BinaryExpr)
        and isinstance(nd.op, uni.Token)
        and nd.op.value == "|" {
        _leaves: list[uni.UniNode] = [];
        _stack: list[uni.UniNode] = [nd];
        while _stack {
            _cur = _stack.pop();
            if isinstance(_cur, uni.AtomUnit) and _cur.value is not None {
                _cur = _cur.value;
            }
            if isinstance(_cur, uni.BinaryExpr)
                and isinstance(_cur.op, uni.Token)
                and _cur.op.value == "|" {
                _stack.append(_cur.left);
                _stack.append(_cur.right);
            } else {
                _leaves.append(_cur);
            }
        }
        _live: list[uni.UniNode] = [];
        _had_none = False;
        for _side in _leaves {
            if isinstance(_side, uni.Null) {
                _had_none = True;
                continue;
            }
            if isinstance(_side, uni.Name) and _side.value in ("None", "NoneType") {
                _had_none = True;
                continue;
            }
            _live.append(_side);
        }
        if not _live {
            return None;
        }
        _lreprs: list = [];
        for _lv in _live {
            _lr = self._lower_untyped_annotation(_lv);
            if _lr is None {
                return None;
            }
            if self._str_desc_ty is not None and _lr == self._str_desc_ty {
                _lr = ir.IntType(8).as_pointer();
            }
            _lreprs.append(_lr);
        }
        _ulow = self._unify_repr_lowering(_lreprs);
        if _ulow is None {
            return None;
        }
        if _had_none and len(_live) == 1 and not isinstance(_ulow, ir.VoidType) {
            return self._jac_optional_type(_ulow);
        }
        return _ulow;
    }
    if isinstance(nd, uni.AtomTrailer) and isinstance(nd.right, uni.IndexSlice) {
        _base = self._get_name(nd.target);
        if _base in ("list", "Sequence") {
            _elem_ty: ir.Type = ir.IntType(64);
            _slices = nd.right.slices;
            if _slices and _slices[0].start is not None {
                _lowered_elem = self._lower_untyped_annotation(_slices[0].start);
                if _lowered_elem is None {
                    return None;
                }
                _elem_ty = _lowered_elem;
            }
            return self._lower_list_for_elem(_elem_ty);
        }
        if _base == "tuple" {
            _tslices = nd.right.slices;
            if _tslices and _tslices[0].start is not None {
                _tvals = _tslices[0].start;
                if isinstance(_tvals, uni.AtomUnit) and _tvals.value is not None {
                    _tvals = _tvals.value;
                }
                _telems = (
                    list(_tvals.values)
                        if isinstance(_tvals, uni.TupleVal)
                        else [_tvals]
                );
                _tlow: list = [];
                _tok = True;
                for _tv in _telems {
                    _lt = self._lower_untyped_annotation(_tv);
                    if _lt is None {
                        _tok = False;
                        break;
                    }
                    if self._str_desc_ty is not None and _lt == self._str_desc_ty {
                        _lt = ir.IntType(8).as_pointer();
                    }
                    _tlow.append(_lt);
                }
                if _tok and _tlow {
                    return self._tuple_struct_of(_tlow).as_pointer();
                }
            }
            return None;
        }
        if _base == "Callable" {
            _fnslices = nd.right.slices;
            _fnparams_nd: (uni.UniNode | None) = None;
            _fnret_nd: (uni.UniNode | None) = None;
            if len(_fnslices) == 2
                and _fnslices[0].start is not None
                and _fnslices[1].start is not None {
                _fnparams_nd = _fnslices[0].start;
                _fnret_nd = _fnslices[1].start;
            } elif _fnslices and _fnslices[0].start is not None {
                _fnargs = _fnslices[0].start;
                if isinstance(_fnargs, uni.AtomUnit) and _fnargs.value is not None {
                    _fnargs = _fnargs.value;
                }
                if isinstance(_fnargs, uni.TupleVal) and len(_fnargs.values) == 2 {
                    _fnparams_nd = _fnargs.values[0];
                    _fnret_nd = _fnargs.values[1];
                }
            }
            if _fnparams_nd is not None and _fnret_nd is not None {
                if isinstance(_fnparams_nd, uni.AtomUnit)
                    and _fnparams_nd.value is not None {
                    _fnparams_nd = _fnparams_nd.value;
                }
                _fnret = self._lower_untyped_annotation(_fnret_nd);
                if _fnret is None {
                    _fnret = ir.VoidType();
                }
                _fnparams: list[ir.Type] = [];
                if isinstance(_fnparams_nd, uni.ListVal) {
                    for _fp in _fnparams_nd.values {
                        _fpl = self._lower_untyped_annotation(_fp);
                        _fnparams.append(_fpl if _fpl is not None else ir.IntType(64));
                    }
                    return ir.FunctionType(_fnret, _fnparams).as_pointer();
                }
            }
            return None;
        }
        if _base == "dict" {
            _dslices = nd.right.slices;
            if _dslices and _dslices[0].start is not None {
                _dkv = _dslices[0].start;
                if isinstance(_dkv, uni.AtomUnit) and _dkv.value is not None {
                    _dkv = _dkv.value;
                }
                if isinstance(_dkv, uni.TupleVal) and len(_dkv.values) == 2 {
                    _dk = self._lower_untyped_annotation(_dkv.values[0]);
                    _dv = self._lower_untyped_annotation(_dkv.values[1]);
                    if _dk is not None and _dv is not None {
                        if self._str_desc_ty is not None {
                            if _dk == self._str_desc_ty {
                                _dk = ir.IntType(8).as_pointer();
                            }
                            if _dv == self._str_desc_ty {
                                _dv = ir.IntType(8).as_pointer();
                            }
                        }
                        (_dk_spec, _dk_size) = self._dict_key_spec(_dk);
                        _dv_spec = self._dict_val_spec(_dv);
                        self._emit_dict_helpers(_dk_spec, _dv_spec, _dk, _dv, _dk_size);
                        _dict_ty = self.dict_types.get(f"{_dk_spec}:{_dv_spec}");
                        if _dict_ty is not None {
                            return _dict_ty.as_pointer();
                        }
                    }
                }
            }
            return None;
        }
        if _base in ("set", "frozenset") {
            _sslices = nd.right.slices;
            if _sslices and _sslices[0].start is not None {
                _set_elem = self._lower_untyped_annotation(_sslices[0].start);
                if _set_elem is not None {
                    _set_spec = "i64";
                    if isinstance(_set_elem, ir.DoubleType) {
                        _set_spec = "f64";
                    } elif isinstance(_set_elem, ir.PointerType) {
                        _set_spec = "ptr";
                    }
                    if self._str_desc_ty is not None
                        and _set_elem == self._str_desc_ty {
                        _set_elem = ir.IntType(8).as_pointer();
                        _set_spec = "ptr";
                    }
                    self._emit_set_helpers(_set_spec, _set_elem);
                    _set_ty = self.set_types.get(_set_spec);
                    if _set_ty is not None {
                        return _set_ty.as_pointer();
                    }
                }
            }
            return None;
        }
        return self._lower_untyped_annotation(nd.target);
    }
    _nm = self._get_name(nd);

    if isinstance(nd, uni.Name) and nd.sym is not None and nd.sym.decl is not None {
        _decl_of = nd.sym.decl.name_of;
        if isinstance(_decl_of, uni.Enum) {
            return ir.IntType(64);
        }
        if isinstance(_decl_of, uni.Archetype) {
            _decl_anm = _decl_of.name.value if _decl_of.name else None;
            if _decl_anm is not None and _decl_anm in self.struct_types {
                return self.struct_types[_decl_anm].as_pointer();
            }
        }
        if isinstance(_decl_of, uni.TypeParam)
            or (_decl_of is not None and isinstance(_decl_of.parent, uni.TypeParam)) {
            return ir.IntType(8).as_pointer();
        }
        if _decl_of is not None and isinstance(_decl_of.parent, uni.ModuleItem) {
            _item = _decl_of.parent;
            _orig = _item.name.value if isinstance(_item.name, uni.Name) else None;
            if _orig is not None and _orig != _nm {
                if _orig in self.struct_types {
                    return self.struct_types[_orig].as_pointer();
                }
                _by_name = self._lower_type_by_name(_orig);
                if _by_name is not None {
                    return _by_name;
                }
            }

            if _orig is not None {
                _imp_node = _item.find_parent_of_type(uni.Import);
                _imp_from = _imp_node.from_loc if _imp_node is not None else None;
                _imp_tail = (
                    _imp_from.dot_path_str.split(".")[-1]
                        if _imp_from is not None
                        else None
                );
                if _imp_tail is not None {
                    if self._enum_source_name.get(_orig) == _imp_tail {
                        return ir.IntType(64);
                    }
                    if self._struct_source_name.get(_orig) == _imp_tail {
                        _osrc_st = self.struct_types.get(_orig);
                        if _osrc_st is not None {
                            return _osrc_st.as_pointer();
                        }
                    }
                }
                if _orig in self.struct_types {
                    return self.struct_types[_orig].as_pointer();
                }
                if _orig in self.enum_types {
                    return self.enum_types[_orig];
                }
            }
        }
    }
    _nm_enum = _nm is not None and _nm in self.enum_types;
    _nm_struct = _nm is not None and _nm in self.struct_types;
    if _nm_enum and not _nm_struct {
        return self.enum_types[_nm];
    }
    if _nm_struct and not _nm_enum {
        return self.struct_types[_nm].as_pointer();
    }
    if _nm == "bytes" {
        return self._get_bytes_struct_type().as_pointer();
    }
    if _nm == "list" {
        return self._lower_list_for_elem(ir.IntType(64));
    }
    return self._lower_type_by_name(_nm);
}

impl NaIRGenTypes._lower_list_for_elem(elem_llvm: ir.Type) -> ir.Type {
    _elem = elem_llvm;
    if self._str_desc_ty is not None and _elem == self._str_desc_ty {
        _elem = ir.IntType(8).as_pointer();
    }
    spec = "i64";
    if isinstance(_elem, ir.DoubleType) {
        spec = "f64";
    } elif isinstance(_elem, ir.PointerType) {
        spec = "ptr";
    } elif self?.jacval_type and _elem == self.jacval_type {
        spec = "jacval";
    }
    self._emit_list_helpers(spec, _elem);
    return self.list_types[spec].as_pointer();
}
