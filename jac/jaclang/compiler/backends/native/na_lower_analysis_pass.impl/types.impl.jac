impl NativeLowering._type_key_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    return self._mangled_of(expr.type);
}

impl NativeLowering._enum_name_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    import from jaclang.compiler.types.types {
        ClassType as EnumClassType,
        EnumMemberType,
        TypeBase,
        UnionType
    }
    t = self._flow_narrowed_type_of(expr);
    if not isinstance(t, TypeBase) {
        return None;
    }
    pending: list[TypeBase] = [t];
    enum_class: EnumClassType | None = None;
    while pending {
        member = pending.pop();
        if isinstance(member, UnionType) {
            pending.extend(member.types);
            continue;
        }
        candidate = member.enum_class if isinstance(member, EnumMemberType) else member;
        if not isinstance(candidate, EnumClassType) or not candidate.is_enum_class() {
            return None;
        }
        if enum_class is not None and candidate.shared is not enum_class.shared {
            return None;
        }
        enum_class = candidate;
    }
    return enum_class.shared.class_name if enum_class is not None else None;
}

impl NativeLowering._spec_name_match(tk: str, names: tuple[str, ...]) -> bool {
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

impl NativeLowering._opt_sole_member(t: any) -> (TypeBase | None) {
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
    _all: list[TypeBase] = t.types or [];
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

impl NativeLowering._split_union_key(tk: str) -> list[str] {
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

impl NativeLowering._flow_narrowed_type_of(
    expr: (uni.UniNode | None)
) -> (TypeBase | None) {
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

impl NativeLowering._program_has_subclasses(arch_name: str) -> bool {
    if self._subclassed_arch_names is None {
        _names: set[str] = set();
        _mods: list[uni.Module] = list(self.prog.mod.hub.values());
        if self.module not in _mods {
            _mods.append(self.module);
        }
        for _mod in _mods {
            for _arch in _mod.get_all_sub_nodes(uni.Archetype) {
                for _base in (_arch.base_classes or []) {
                    _bn = self._arch_ref_key(_base) or self._get_name(_base);
                    if _bn is not None {
                        _names.add(_bn);
                    }
                }
            }
        }
        self._subclassed_arch_names = _names;
    }
    return arch_name in self._subclassed_arch_names;
}

impl NativeLowering._erased_decl(tb: any) -> bool {
    """Whether a declared slot type is spelled by a type parameter.

    This reads the declaration, not the instantiation: `T`, `T | None`, or a
    union of `T` with reference types. Such a slot is a pointer in the one
    layout every instantiation shares, so a by-value argument has to be boxed
    on the way in and unboxed on the way out; whether that happens is then
    decided by the physical slot and the access site's own type.
    """;
    try {
        import from jaclang.compiler.types.types {
            ClassType as _EdClassType,
            UnionType as _EdUnionType,
            TypeVarType as _EdTypeVarType
        }
    } except ImportError {
        return False;
    }
    if isinstance(tb, _EdTypeVarType) {
        return True;
    }
    if isinstance(tb, _EdUnionType) {
        for m in (tb.types or []) {
            if isinstance(m, _EdTypeVarType) {
                return True;
            }
        }
        return False;
    }
    if isinstance(tb, _EdClassType)
        and tb._shared is not None
        and tb.shared.class_name == "type" {
        _eargs: list[TypeBase] = tb.private.type_args or [];
        return len(_eargs) == 1 and self._erased_decl(_eargs[0]);
    }
    return False;
}

impl NativeLowering._erased_field(type_name: str, fname: str) -> bool {
    return fname in (self.struct_field_erased_tv.get(type_name) or {});
}

impl NativeLowering._erased_decl_names(tb: any) -> list[str] {
    try {
        import from jaclang.compiler.types.types {
            UnionType as _EnUnionType,
            TypeVarType as _EnTypeVarType
        }
    } except ImportError {
        return [];
    }
    if isinstance(tb, _EnTypeVarType) {
        return [tb.name];
    }
    out: list[str] = [];
    if isinstance(tb, _EnUnionType) {
        for m in (tb.types or []) {
            if isinstance(m, _EnTypeVarType) and m.name not in out {
                out.append(m.name);
            }
        }
    }
    return out;
}

impl NativeLowering._type_base_is_unknown(tb: any) -> bool {
    try {
        import from jaclang.compiler.types.types { UnknownType as _UnknownType }
        return isinstance(tb, _UnknownType);
    } except ImportError {
        return True;
    }
}

impl NativeLowering._get_name(nd: (uni.UniNode | None)) -> (str | None) {
    if nd is None {
        return None;
    }
    if isinstance(nd, uni.Name) {
        return nd.value;
    }
    if isinstance(nd, (uni.NameAtom, uni.AstSymbolNode)) {
        return nd.sym_name or None;
    }
    if isinstance(nd, uni.Token) {
        return nd.value or None;
    }
    return None;
}

impl NativeLowering._narrowed_flow_type(nd: uni.UniNode) -> (TypeBase | None) {
    return nd.type if isinstance(nd, uni.Expr) else None;
}

impl NativeLowering._narrowing_blocked_by_none_test(nd: uni.UniNode) -> bool {
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
        _s: uni.UniNode = _side.expr if isinstance(_side, uni.CfgExpr) else _side;
        if isinstance(_s, uni.AtomUnit) {
            _s = _s.value;
        }
        if isinstance(_s, uni.Null) {
            return True;
        }
    }
    return False;
}

impl NativeLowering._narrowing_stable_in_loops(nd: uni.UniNode, name: str) -> bool {
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

impl NativeLowering._loop_rebinds_name(loop: uni.UniNode, name: str) -> bool {
    _key = (id(loop), name);
    _hit = self._loop_rebind_memo.get(_key);
    if _hit is not None {
        return _hit;
    }
    _found = False;
    for _asn in loop.get_all_sub_nodes(uni.Assignment) {
        for _t in (_asn.target or []) {
            for _tn in self._target_bound_names(_t) {
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

impl NativeLowering._target_bound_names(target: uni.UniNode) -> list[uni.Name] {
    if isinstance(target, uni.Name) {
        return [target];
    }
    if isinstance(target, uni.UnaryExpr) {
        return self._target_bound_names(target.operand);
    }
    if isinstance(target, (uni.TupleVal, uni.ListVal)) {
        _bound: list[uni.Name] = [];
        for _item in (target.values or []) {
            _bound.extend(self._target_bound_names(_item));
        }
        return _bound;
    }
    return [];
}

impl NativeLowering._body_assigns_before(
    loop: uni.WhileStmt | uni.ForeverStmt | uni.InForStmt | uni.IterForStmt,
    child: (uni.UniNode | None),
    name: str
) -> bool {
    if isinstance(loop, uni.InForStmt) {
        for _tn in self._target_bound_names(loop.target) {
            if _tn.value == name {
                return True;
            }
        }
    }
    _body = loop.body;
    if child is None {
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
            if any(_tn.value == name for _tn in self._target_bound_names(_t)) {
                return True;
            }
        }
    }
    return False;
}

impl NativeLowering._cmp_static_type(
    left_node: uni.UniNode, right_node: uni.UniNode
) -> (TypeBase | None) {
    """The checked type both operands of a comparison share, or `None`.

    Containers keep nested containers, archetypes and tuples in erased pointer
    slots, so a value read out of one no longer says what it points at. The
    checked type does: it tells the comparison how to walk an element instead
    of comparing its address or its header bytes. Only a type the two sides
    agree on is returned; a comparison across types keeps its own lowering.
    """;
    _l = left_node.expr if isinstance(left_node, uni.CfgExpr) else left_node;
    _r = right_node.expr if isinstance(right_node, uni.CfgExpr) else right_node;
    if not isinstance(_l, uni.Expr) or not isinstance(_r, uni.Expr) {
        return None;
    }
    if _l.type is None or _r.type is None {
        return None;
    }
    _lt: TypeBase = self._opt_sole_member(_l.type) or _l.type;
    _rt: TypeBase = self._opt_sole_member(_r.type) or _r.type;
    _lk = self._mangled_of(_lt);
    if _lk is None or _lk != self._mangled_of(_rt) {
        return None;
    }
    return _lt;
}

impl NativeLowering._is_graph_type(ty: (TypeBase | None)) -> bool {
    import from jaclang.compiler.types.types { ClassType as _GtClassType }
    if ty is None or not isinstance(ty, _GtClassType) {
        return False;
    }
    import from jaclang.compiler.passes.layout_pass { class_type_native_name }
    _tn = class_type_native_name(ty);
    if _tn is None {
        return False;
    }
    _lay = self._arch_layout(_tn);
    if _lay is not None {
        return _lay.is_osp;
    }
    return _tn in ("Node", "Edge", "Walker", "Root", "GenericEdge");
}

impl NativeLowering._sort_key_return_type(nd: (uni.UniNode | None)) -> (TypeBase | None) {
    import from jaclang.compiler.types.types { FunctionType }
    while isinstance(nd, uni.CfgExpr) {
        nd = nd.expr;
    }
    if isinstance(nd, uni.LambdaExpr) {
        _ret = nd.tail_return_expr();
        return _ret.type if _ret is not None else None;
    }
    if isinstance(nd, uni.Expr) and isinstance(nd.type, FunctionType) {
        return nd.type.return_type;
    }
    return None;
}

impl NativeLowering._sort_key_orderable(ty: (TypeBase | None)) -> (bool | None) {
    import from jaclang.compiler.types.types { ClassType }
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    if ty is None {
        return None;
    }
    _name = primitive_type_name_of(ty);
    if _name == "str" or _name == "bytes" {
        return True;
    }
    if self._scalar_shape_named(_name) is not None {
        return True;
    }
    if not isinstance(ty, ClassType) {
        return None;
    }
    if _name is None {
        return False;
    }
    if _name not in ("list", "set", "frozenset", "tuple") {
        return False;
    }
    _args = ty.private.type_args or [];
    if _name == "tuple" {
        import from jaclang.compiler.types.types { UnknownType }
        _known = [
            a
            for a in _args
            if not isinstance(a, UnknownType)
        ];
        if _known and len(_known) < len(_args) {
            _args = _known;
        }
    }
    if not _args {
        return None;
    }
    _orderable: (bool | None) = True;
    for _arg in _args {
        _sub = self._sort_key_orderable(_arg);
        if _sub is False {
            return False;
        }
        if _sub is None {
            _orderable = None;
        }
    }
    return _orderable;
}

impl NativeLowering._sort_key_unsigned(nd: (uni.UniNode | None)) -> bool {
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    while isinstance(nd, uni.CfgExpr) {
        nd = nd.expr;
    }
    if isinstance(nd, uni.LambdaExpr) {
        return self._is_unsigned_node(nd.tail_return_expr());
    }
    _shape = self._scalar_shape_named(
        primitive_type_name_of(self._sort_key_return_type(nd))
    );
    return _shape is not None
        and _shape.sized
        and not _shape.is_float
        and not _shape.signed;
}

impl NativeLowering._agg_key_args(
    key_ret: (TypeBase | None), agg_name: str
) -> (list[TypeBase] | None) {
    import from jaclang.compiler.types.types { ClassType }
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    if not isinstance(key_ret, ClassType) {
        return None;
    }
    if self._container_class_name(key_ret) != agg_name {
        return None;
    }
    return list(key_ret.private.type_args or []);
}

impl NativeLowering._container_class_name(ty: (TypeBase | None)) -> (str | None) {
    """The builtin class a checked type instantiates: `list`, `dict`, `dict_keys`...

    `primitive_type_name_of` names the primitives; the dictionary views are
    plain builtin classes it does not cover, so their class name answers.
    """;
    import from jaclang.compiler.types.types { ClassType }
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    if ty is None {
        return None;
    }
    _name = primitive_type_name_of(ty);
    if _name is not None {
        return _name;
    }
    if isinstance(ty, ClassType)
        and ty.shared.class_name in ("dict_keys", "dict_values", "dict_items") {
        return ty.shared.class_name;
    }
    return None;
}

impl NativeLowering._key_elem_unsigned(et: (TypeBase | None)) -> bool {
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    _shape = self._scalar_shape_named(primitive_type_name_of(et));
    return _shape is not None
        and _shape.sized
        and not _shape.is_float
        and not _shape.signed;
}
