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

impl NativeLowering._lower_type_union_members(
    t: UnionType
) -> tuple[list[TypeBase], bool] {
    _members: list[TypeBase] = [];
    for m in (t.types or []) {
        if isinstance(m, ClassType)
            and m.shared.class_name in ("NoneType", "None") {
            continue;
        }
        _members.append(m);
    }
    _had_none = len(_members) < len(t.types or []);
    return (_members, _had_none);
}

impl NativeLowering._typevar_bound_struct_class(
    t: (TypeBase | None)
) -> (ClassType | None) {
    import from jaclang.compiler.types.types { TypeVarType }
    if isinstance(t, UnionType) {
        members = [
            m
            for m in (t.types or [])
            if not (
                isinstance(m, ClassType)
                and m._shared is not None
                and m.shared.class_name in ("NoneType", "None")
            )
        ];
        t = members[0] if len(members) == 1 else None;
    }
    if isinstance(t, TypeVarType) and isinstance(t.bound, ClassType) {
        return t.bound;
    }
    return None;
}

impl NativeLowering._typed_elem_llvm_of_arg(
    expr: (uni.UniNode | None), prefix: str, arg_index: int
) -> (TypeBase | None) {
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
    candidates = _ty.types if isinstance(_ty, UnionType) else [_ty];
    for _cand in candidates {
        if isinstance(_cand, ClassType) and _cand.private.type_args {
            _ty = _cand;
            break;
        }
    }
    if not isinstance(_ty, ClassType) {
        return None;
    }
    args = _ty.private.type_args;
    if not args or arg_index >= len(args) {
        return None;
    }
    return args[arg_index];
}

impl NativeLowering._static_elem_llvm_of_arg(
    expr: (uni.UniNode | None)
) -> (TypeBase | None) {
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
    if not isinstance(_t, ClassType) {
        return None;
    }
    _args = _t.private.type_args;
    if not _args {
        return None;
    }
    return _args[0];
}

impl NativeLowering._aos_elem_of_list_arg(
    type_expr: (uni.UniNode | None)
) -> (TypeBase | None) {
    if not self._nogc_headerless() {
        return None;
    }
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
    if not isinstance(_t, ClassType) or _t.shared.class_name != "list" {
        return None;
    }
    _args = _t.private.type_args;
    if not _args {
        return None;
    }
    return _args[0];
}

impl NativeLowering._resolve_sig_type_is_container(ptb: TypeBase) -> bool {
    _sig_cn = ptb.shared.class_name if isinstance(ptb, ClassType) else None;
    return _sig_cn in ("tuple", "list", "dict", "set", "type");
}

impl NativeLowering._unlowerable_type_refuse(
    type_expr: uni.UniNode, tb: any, decl_kind: str
) -> None {
    if isinstance(type_expr, uni.Expr) {
        import from jaclang.compiler.frontend.unparse { unparse_node }
        _label = unparse_node(type_expr);
    } else {
        _tag = type_expr?.type_tag;
        _label = self._get_name(_tag?.tag) or str(tb);
    }
    self.emit(E5092, node_override=type_expr, kind=decl_kind, name=_label);
}

impl NativeLowering._bare_any_container_type_kind(nt: ClassType) -> (str | None) {
    _cn = nt.shared.class_name;
    _args: list[TypeBase] = nt.private.type_args or [];
    if _cn in ("list", "Sequence") {
        _a0 = _args[0] if len(_args) == 1 else None;
        if _args
            and not (
                isinstance(_a0, ClassType)
                and _a0.shared.class_name in ("any", "Any", "object")
            ) {
            return None;
        }
        return "list";
    }
    if _cn == "dict" and not _args {
        return "dict";
    }
    return None;
}

impl NativeLowering._lower_untyped_annotation_union_members(
    nd: uni.BinaryExpr
) -> tuple[list[uni.UniNode], bool] {
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
    return (_live, _had_none);
}

impl NativeLowering._lower_untyped_annotation_tuple_elems(
    idx: uni.IndexSlice
) -> (list[uni.UniNode] | None) {
    _tslices = idx.slices;
    if _tslices and _tslices[0].start is not None {
        _tvals: uni.UniNode = _tslices[0].start;
        if isinstance(_tvals, uni.AtomUnit) and _tvals.value is not None {
            _tvals = _tvals.value;
        }
        _telems = (
            list(_tvals.values)
                if isinstance(_tvals, uni.TupleVal)
                else [_tvals]
        );
        return _telems;
    }
    return None;
}

impl NativeLowering._lower_untyped_annotation_callable_parts(
    idx: uni.IndexSlice
) -> (tuple[uni.UniNode, uni.UniNode] | None) {
    _fnslices = idx.slices;
    _fnparams_nd: (uni.UniNode | None) = None;
    _fnret_nd: (uni.UniNode | None) = None;
    if len(_fnslices) == 2
        and _fnslices[0].start is not None
        and _fnslices[1].start is not None {
        _fnparams_nd = _fnslices[0].start;
        _fnret_nd = _fnslices[1].start;
    } elif _fnslices and _fnslices[0].start is not None {
        _fnargs: uni.UniNode = _fnslices[0].start;
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
        return (_fnparams_nd, _fnret_nd);
    }
    return None;
}

impl NativeLowering._lower_untyped_annotation_dict_kv(
    idx: uni.IndexSlice
) -> (tuple[uni.UniNode, uni.UniNode] | None) {
    _dslices = idx.slices;
    if _dslices and _dslices[0].start is not None {
        _dkv: uni.UniNode = _dslices[0].start;
        if isinstance(_dkv, uni.AtomUnit) and _dkv.value is not None {
            _dkv = _dkv.value;
        }
        if isinstance(_dkv, uni.TupleVal) and len(_dkv.values) == 2 {
            return (_dkv.values[0], _dkv.values[1]);
        }
    }
    return None;
}

impl NativeLowering._lower_untyped_annotation_decl(
    nd: uni.UniNode
) -> tuple[str | None, uni.ModuleItem | None, str | None] {
    if isinstance(nd, uni.Name) and nd.sym is not None and nd.sym.decl is not None {
        _decl_of = nd.sym.decl.name_of;
        if isinstance(_decl_of, uni.Enum) {
            return ("enum", None, None);
        }
        if isinstance(_decl_of, uni.TypeParam)
            or (_decl_of is not None and isinstance(_decl_of.parent, uni.TypeParam)) {
            return ("typeparam", None, None);
        }
        if _decl_of is not None and isinstance(_decl_of.parent, uni.ModuleItem) {
            _item = _decl_of.parent;
            _orig = _item.name.value if isinstance(_item.name, uni.Name) else None;
            return ("item", _item, _orig);
        }
    }
    return (None, None, None);
}

impl NativeLowering._lower_untyped_annotation_import_tail(
    item: uni.ModuleItem
) -> (str | None) {
    _imp_node = item.find_parent_of_type(uni.Import);
    _imp_from = _imp_node.from_loc if _imp_node is not None else None;
    _imp_tail = (
        _imp_from.dot_path_str.split(".")[-1]
            if _imp_from is not None
            else None
    );
    return _imp_tail;
}

impl NativeLowering._is_object_union_key_members(t: any) -> (list[TypeBase] | None) {
    if not isinstance(t, UnionType) or not t.types {
        return None;
    }
    return t.types;
}

impl NativeLowering._is_object_union_key_member_kind(member: TypeBase) -> str {
    if not isinstance(member, ClassType) or member._shared is None {
        return "other";
    }
    if member.shared.class_name in ("NoneType", "None") {
        return "none";
    }
    return "class";
}

impl NativeLowering._spec_union_agreement_members(t: any) -> (list[TypeBase] | None) {
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
    return _members;
}

impl NativeLowering._elem_storage_llvm_members(
    t: any
) -> (tuple[list[TypeBase], bool] | None) {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _EsClassType,
            UnionType as _EsUnionType
        }
    } except ImportError {
        return None;
    }
    if not isinstance(t, _EsUnionType) {
        return None;
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
        return None;
    }
    return (_members, _had_none);
}

impl NativeLowering._lower_view_container_elem(t: any) -> (TypeBase | None) {
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
    _args: list[TypeBase] = t.private.type_args or [];
    if not _args {
        return None;
    }
    return _args[0];
}

impl NativeLowering._aos_elem_name_native(t: any) -> (str | None) {
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
        return self._aos_elem_name_native(_sol[t.name]);
    }
    if not isinstance(t, _AeClassType) or t._shared is None {
        return None;
    }
    import from jaclang.compiler.passes.layout_pass { class_type_native_name }
    return class_type_native_name(t);
}

impl NativeLowering._aos_elem_name_inline_layout(tn: str) -> bool {
    _lay = self._arch_layout(tn);
    if _lay is None or _lay.is_osp or _lay.arch_type == "walker" {
        return False;
    }
    if self._program_has_subclasses(tn) {
        return False;
    }
    return True;
}

impl NativeLowering._widened_tuple_decl_type_bare(type_expr: uni.UniNode) -> bool {
    nd = type_expr;
    if isinstance(nd, uni.SubTag) {
        nd = nd.tag;
    }
    _tb = nd?.type;
    if _tb is None {
        if not (isinstance(nd, uni.Name) and nd.value == "tuple") {
            return False;
        }
    } else {
        try {
            import from jaclang.compiler.types.types { ClassType as _WdClassType }
        } except ImportError {
            return False;
        }
        if not isinstance(_tb, _WdClassType)
            or _tb.shared.class_name != "tuple"
            or (_tb.private.type_args or []) {
            return False;
        }
    }
    return True;
}

impl NativeLowering._resolve_field_type_is_typevar(ptb: TypeBase) -> bool {
    try {
        import from jaclang.compiler.types.types { TypeVarType as _RfTypeVarType }
        if isinstance(ptb, _RfTypeVarType) {
            return True;
        }
    } except ImportError {}
    return False;
}

impl NativeLowering._resolve_field_type_tag_optional(tag: uni.UniNode) -> bool {
    _hv_opt = False;
    _hv_scan: list[uni.UniNode] = [tag];
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
    return _hv_opt;
}

impl NativeLowering._foreign_optional_field_members(
    tb: any
) -> (list[tuple[str, TypeBase]] | None) {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _FofClassType,
            UnionType as _FofUnionType,
            UnknownType as _FofUnknownType
        }
    } except ImportError {
        return None;
    }
    if not isinstance(tb, _FofUnionType) {
        return None;
    }
    _members: list[TypeBase] = tb.types or [];
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
        return None;
    }
    try {
        import from jaclang.compiler.types.types { TypeVarType as _FofTypeVarType }
    } except ImportError {
        return None;
    }
    _kinds: list[tuple[str, TypeBase]] = [];
    for m in _non_none {
        if isinstance(m, _FofUnknownType) {
            _kinds.append(("unknown", m));
        } elif isinstance(m, _FofTypeVarType) {
            _kinds.append(("typevar", m));
        } elif isinstance(m, _FofClassType) {
            _kinds.append(("class", m));
        } else {
            _kinds.append(("other", m));
        }
    }
    return _kinds;
}

impl NativeLowering._erased_typevar_names_own(tb: any) -> (list[str] | None) {
    try {
        import from jaclang.compiler.types.types { TypeVarType as _EtvTypeVarType }
    } except ImportError {
        return None;
    }
    if isinstance(tb, _EtvTypeVarType) {
        return [tb.name];
    }
    return None;
}

impl NativeLowering._erased_typevar_names_members(tb: any) -> list[str] {
    try {
        import from jaclang.compiler.types.types { TypeVarType as _EtvTypeVarType }
    } except ImportError {
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

impl NativeLowering._typevar_optional_field_members(
    tb: any
) -> (tuple[list[tuple[bool, TypeBase]], bool] | None) {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _TvoClassType,
            UnionType as _TvoUnionType,
            TypeVarType as _TvoTypeVarType
        }
    } except ImportError {
        return None;
    }
    if not isinstance(tb, _TvoUnionType) {
        return None;
    }
    _members: list[TypeBase] = tb.types or [];
    _non_none = [
        m
        for m in _members
        if not (
            isinstance(m, _TvoClassType)
            and m._shared is not None
            and m.shared.class_name in ("NoneType", "None")
        )
    ];
    if not _non_none {
        return None;
    }
    _tagged: list[tuple[bool, TypeBase]] = [];
    for m in _non_none {
        _tagged.append((isinstance(m, _TvoTypeVarType), m));
    }
    return (_tagged, len(_non_none) < len(_members));
}

impl NativeLowering._erased_seq_type_arg(tb: any) -> (TypeBase | None) {
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
    _args: list[TypeBase] = tb.private.type_args or [];
    if len(_args) != 1 {
        return None;
    }
    return _args[0];
}

impl NativeLowering._apply_flow_narrowing_class(
    nd: uni.Name, nm: str
) -> (ClassType | None) {
    if not self._narrowing_stable_in_loops(nd, nm) {
        return None;
    }
    if self._narrowing_blocked_by_none_test(nd) {
        return None;
    }
    _nt = self._narrowed_flow_type(nd);
    if _nt is None {
        return None;
    }
    try {
        import from jaclang.compiler.types.types { ClassType as _ClassType }
    } except ImportError {
        return None;
    }
    if not isinstance(_nt, _ClassType)
        or _nt.shared.class_name in ("NoneType", "None") {
        return None;
    }
    return _nt;
}

impl NativeLowering._apply_flow_narrowing_not_typed_container(nt: ClassType) -> bool {
    return not (nt.private.type_args or [])
        or nt.shared.class_name
            not in ("list", "Sequence", "dict", "set", "frozenset", "tuple");
}

impl NativeLowering._unbox_narrowed_member_class(
    nd: uni.AtomTrailer
) -> (ClassType | None) {
    if not isinstance(nd, uni.Expr) or nd.narrowed_type is None {
        return None;
    }
    if self._narrowing_blocked_by_none_test(nd) {
        return None;
    }
    _nt = nd.narrowed_type;
    try {
        import from jaclang.compiler.types.types { ClassType as _ClassType }
    } except ImportError {
        return None;
    }
    if not isinstance(_nt, _ClassType)
        or _nt.shared.class_name in ("NoneType", "None") {
        return None;
    }
    return _nt;
}
