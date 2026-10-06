glob _NA_ABC_REDUCTIONS: dict[str, tuple[str, ...]] = {
         "Sequence": ("list", "tuple", "str", "bytes", "bytearray"),
         "MutableSequence": ("list", "bytearray"),
         "Mapping": ("dict", ),
         "MutableMapping": ("dict", ),
         "Set": ("set", "frozenset"),
         "AbstractSet": ("set", "frozenset"),
         "MutableSet": ("set", ),
         "ByteString": ("bytes", "bytearray")
     },
     _NA_ABC_OPAQUE: tuple[str, ...] = (
         "Iterable",
         "Iterator",
         "Reversible",
         "Generator",
         "Container",
         "Collection",
         "Sized",
         "Hashable",
         "Callable",
         "Awaitable",
         "Coroutine",
         "AsyncIterable",
         "AsyncIterator",
         "AsyncGenerator",
         "MappingView",
         "KeysView",
         "ItemsView",
         "ValuesView",
         "Buffer"
     );

impl NativeLowering._arch_alias_target(nd: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(nd, uni.NameAtom) {
        return None;
    }
    _arch_key = self._arch_ref_key(nd);
    if _arch_key is not None {
        return _arch_key;
    }
    sym = nd.sym;
    if sym is None {
        return None;
    }
    d = sym.decl;
    if d is None {
        return None;
    }
    nof = d.name_of;
    if isinstance(nof, uni.Archetype) and nof.name.value != self._get_name(nd) {
        return nof.name.value;
    }
    par = d.parent;
    if isinstance(par, uni.ModuleItem) and par.alias is d {
        return self._get_name(par.name);
    }
    return None;
}

impl NativeLowering._callee_ability_of(nd: uni.FuncCall) -> (uni.Ability | None) {
    import from jaclang.compiler.symbol_utils { resolved_callee }
    return resolved_callee(nd);
}

impl NativeLowering._arch_init_sig_of(type_name: str) -> (uni.FuncSignature | None) {
    for cls in self._mro_of(type_name) {
        arch = self.arch_ast_map.get(cls);
        if not isinstance(arch, uni.Archetype) or arch.body is None {
            continue;
        }
        for stmt in arch.body {
            if isinstance(stmt, uni.Ability)
                and stmt.name_ref is not None
                and stmt.name_ref.sym_name in ("init", "__init__")
                and isinstance(stmt.signature, uni.FuncSignature) {
                return stmt.signature;
            }
        }
    }
    return None;
}

impl NativeLowering._emit_pack_slot_refusal(nd: uni.FuncCall, star: str) -> None {
    """Refuse a call whose callee declares a pack it could not lay out.

    Binding the extras positionally into a slot that is not a pack is the one
    answer this site may never give: the callee reads that slot as its whole
    parameter pack, so the mismatch is a silent misread at run time rather
    than a missing feature.

    Reached only when the signature that declares the pack is the one the
    called function was built from. A bundled native module whose typeshed
    stub is variadic while its own definition is fixed-arity -- `os.path.join`
    is the standing example -- resolves a signature belonging to a different
    implementation, and positional binding against the real one is correct.
    """;
    _sink = "*args" if star == "*" else "**kwargs";
    self.emit(
        E5092,
        node_override=nd,
        kind="variadic call",
        name=star,
        help_text=(
            f"The callee declares a `{star}` pack, but its `{_sink}` slot did "
            f"not lay out as a native list or dict, so the arguments this "
            f"site would pack have nowhere to go. Annotate the pack with an "
            f"element type that lowers, or move the call to a @sv/Python "
            f"context."
        )
    );
}

impl NativeLowering._emit_unsupported_builtin_call(
    nd: uni.FuncCall, func_name: str
) -> None {
    self.emit(
        E5092,
        node_override=nd,
        kind="builtin call",
        name=func_name,
        help_text="This builtin is implemented for some argument types but could not be lowered for the argument(s) at this call site (for example `sum`/`min`/`max` over a `range` rather than a list). Restructure to a supported form, or move the code to a @sv/Python context."
    );
}

impl NativeLowering._skip_is_other_module(
    nd: uni.FuncCall, func_name: str, mod_qual: (str | None)
) -> bool {
    origins = self._native_skipped_import_origin.get(func_name);
    if origins is None {
        return False;
    }
    callee_path: (str | None) = None;
    declaration = self._callee_ability_of(nd);
    if declaration is not None and isinstance(declaration.parent_scope, uni.Module) {
        callee_path = os.path.realpath(declaration.parent_scope.source.file_path);
    } elif mod_qual is not None {
        import from jaclang.compiler.frontend.codeinfo { resolve_native_module }
        (_, source) = resolve_native_module(mod_qual, os.path.dirname(nd.loc.mod_path));
        if source is not None {
            callee_path = os.path.realpath(source);
        }
    }
    if callee_path is None {
        return False;
    }
    own_path = os.path.realpath(self.module.loc.mod_path) if self.module?.loc else None;
    return callee_path != own_path and callee_path not in origins;
}

impl NativeLowering._native_module_call_target(
    nd: uni.FuncCall
) -> tuple[str, str] | None {
    if isinstance(nd.target, uni.Name) and nd.target.sym is not None {
        import from jaclang.compiler.frontend.codeinfo { NATIVE_STDLIB_EXTENSIONS }
        scope = nd.target.sym.parent_tab;
        if isinstance(scope, uni.Module)
            and scope.stub_only
            and scope.name in NATIVE_STDLIB_EXTENSIONS {
            return (scope.name, nd.target.sym.name);
        }
    }
    trailer = nd.target;
    if not isinstance(trailer, uni.AtomTrailer) or not trailer.is_attr {
        return None;
    }

    import from jaclang.compiler.symbol_utils { imported_module_name }
    mod_name = imported_module_name(trailer.target);
    method_name = self._get_name(trailer.right);
    if mod_name is None or method_name is None {
        return None;
    }

    if (mod_name == "os.path" and method_name in NATIVE_OSPATH_FUNCS)
        or (mod_name == "os" and method_name in NATIVE_OS_FUNCS) {
        return None;
    }

    if mod_name == "os.path" and "os" in self._native_module_imports {
        return (mod_name, method_name);
    }

    if mod_name in self._native_module_imports {
        return (mod_name, method_name);
    }
    return None;
}

impl NativeLowering._stdlib_intercept_covers(module_name: str, func_name: str) -> bool {
    """Whether `module_name.func_name` lowers through a compiler intercept for an
    imported stdlib module (`os`, `random`, `struct`).""";
    if module_name not in self._native_stdlib_modules {
        return False;
    }
    return (module_name == "os" and func_name in NATIVE_OS_FUNCS)
        or (module_name == "random" and func_name in NATIVE_RANDOM_FUNCS)
        or (module_name == "struct" and func_name in NATIVE_STRUCT_FUNCS);
}

impl NativeLowering._from_imported_intercept(nd: uni.FuncCall) -> tuple[str, str] | None {
    """The intercepted (module, function) a bare call names when the name was bound
    by `import from <module> { function }`: `randint(1, 6)` lowers exactly like
    `random.randint(1, 6)`. The callee symbol lives in the module's stub, so a
    local or module definition that shadows the name never matches. The stub is
    named by its place in the stdlib tree, not its file stem: `os` is a package
    whose stub is `os/__init__.pyi`.""";
    import from jaclang.compiler.frontend.codeinfo { bundled_stdlib_module_of }
    if not isinstance(nd.target, uni.Name) or nd.target.sym is None {
        return None;
    }
    scope = nd.target.sym.parent_tab;
    if not isinstance(scope, uni.Module) or not scope.stub_only {
        return None;
    }
    module_name = bundled_stdlib_module_of(scope.loc.mod_path);
    if module_name is None
        or not self._stdlib_intercept_covers(module_name, nd.target.sym.name) {
        return None;
    }
    return (module_name, nd.target.sym.name);
}

impl NativeLowering._emit_intrinsic_misuse(
    nd: uni.FuncCall, intr: IntrinsicEntry, reason: str
) -> None {
    for e in self.ctx.errors_had {
        if (
            e.code is E5095
            and e.loc.mod_path == nd.loc.mod_path
            and e.loc.first_line == nd.loc.first_line
            and e.loc.col_start == nd.loc.col_start
        ) {
            return;
        }
    }
    self.emit(E5095, node_override=nd, name=intr.name, reason=reason);
}

impl NativeLowering._jacval_tags_for_type(name: str) -> list[int] {
    if name == "int" {
        return [0, 7];
    }
    if name == "bool" {
        return [7];
    }
    if name == "float" {
        return [1];
    }
    if name == "str" {
        return [2];
    }
    if name == "list" {
        return [3];
    }
    if name == "dict" {
        return [4];
    }
    if name == "set" or name == "frozenset" {
        return [5];
    }
    if name == "NoneType" {
        return [8];
    }
    if name in ("ellipsis", "EllipsisType") {
        return [JACVAL_ELLIPSIS_TAG];
    }
    return [];
}

impl NativeLowering._isinstance_type_name(nd: uni.UniNode) -> (str | None) {
    if (
        isinstance(nd, uni.FuncCall)
        and self._get_name(nd.target) == "type"
        and nd.params
        and len(nd.params) == 1
        and isinstance(nd.params[0], (uni.Null, uni.Ellipsis))
    ) {
        import from jaclang.compiler.symbol_utils { classify_call, CallKind }
        if classify_call(nd) == CallKind.BUILTIN {
            return "NoneType" if isinstance(nd.params[0], uni.Null) else "ellipsis";
        }
        return None;
    }
    _mn_nd = nd;
    while isinstance(_mn_nd, uni.AtomUnit) and _mn_nd.value is not None {
        _mn_nd = _mn_nd.value;
    }
    if self._mono_mangle_map
        and isinstance(_mn_nd, uni.Name)
        and _mn_nd.sym is not None {
        nd = _mn_nd;
        _mn_sym = _mn_nd.sym;
        assert _mn_sym is not None;
        _mn_decl = _mn_sym.decl.name_of if _mn_sym.decl is not None else None;
        if isinstance(_mn_decl, uni.ParamVar) and _mn_decl.type_tag is not None {
            _mn_tag: uni.UniNode = _mn_decl.type_tag.tag;
            while isinstance(_mn_tag, uni.AtomUnit) and _mn_tag.value is not None {
                _mn_tag = _mn_tag.value;
            }
            if (
                isinstance(_mn_tag, uni.AtomTrailer)
                and isinstance(_mn_tag.target, uni.Name)
                and _mn_tag.target.value == "type"
                and isinstance(_mn_tag.right, uni.IndexSlice)
                and len(_mn_tag.right.slices) == 1
            ) {
                _mn_inner = _mn_tag.right.slices[0].start;
                if isinstance(_mn_inner, uni.Name)
                    and _mn_inner.value in self._mono_mangle_map {
                    return self._mono_mangle_map[_mn_inner.value];
                }
            }
        }
    }
    _alias_nm = self._arch_alias_target(nd);
    if _alias_nm is not None {
        return _alias_nm;
    }
    return self._get_name(nd) or self._module_class_name(nd);
}

impl NativeLowering._enum_union_tags(
    operand_expr: uni.UniNode, names: list[str]
) -> tuple[list[int], list[str]] {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _EnClassType,
            EnumMemberType as _EnMemberType,
            UnionType as _EnUnionType
        }
    } except ImportError {
        return ([], names, );
    }
    t = operand_expr.type if isinstance(operand_expr, uni.Expr) else None;
    members: list[TypeBase] = [];
    if isinstance(t, _EnUnionType) {
        members = list(t.types or []);
    } elif t is not None {
        members = [t];
    }
    if not members {
        return ([], names, );
    }
    member_rows: list[tuple[str, bool, list[int]]] = [];
    for m in members {
        cls = m.enum_class if isinstance(m, _EnMemberType) else m;
        if not isinstance(cls, _EnClassType) or cls._shared is None {
            return ([], names, );
        }
        cn = cls.shared.class_name;
        if cls.is_enum_class() {
            member_rows.append((cn, True, [0], ));
        } elif cn in ("NoneType", "None") {
            member_rows.append((cn, False, [8], ));
        } elif cn == "bool" {
            member_rows.append((cn, False, [7], ));
        } elif cn == "int" {
            member_rows.append((cn, False, [0, 7], ));
        } elif cn == "float" {
            member_rows.append((cn, False, [1], ));
        } elif cn == "str" {
            member_rows.append((cn, False, [2], ));
        } elif cn in ("list", "dict", "set", "tuple") {
            member_rows.append((cn, False, [3, 4, 5], ));
        } else {
            member_rows.append((cn, False, [6], ));
        }
    }
    resolved: list[int] = [];
    still: list[str] = [];
    for nm in names {
        hit = False;
        for row in member_rows {
            if row[0] == nm and row[1] {
                clash = False;
                for other in member_rows {
                    if other[0] != nm and (0 in other[2]) {
                        clash = True;
                        break;
                    }
                }
                hit = not clash;
                break;
            }
        }
        if hit {
            if 0 not in resolved {
                resolved.append(0);
            }
        } else {
            still.append(nm);
        }
    }
    return (resolved, still, );
}

impl NativeLowering._source_may_hold_bytes(source_type: (TypeBase | None)) -> bool {
    members = source_type.types
        if isinstance(source_type, UnionType)
        else [source_type];
    for member in members {
        if not isinstance(member, ClassType) {
            return True;
        }
        if member.shared.class_name in ("bytes", "object", "any", "Any") {
            return True;
        }
    }
    return False;
}

impl NativeLowering._flow_future_licensed(nd: uni.ConcurrentExpr) -> (uni.Name | None) {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    asgn = nd.parent;
    if not (
        isinstance(asgn, uni.Assignment)
        and asgn.value is nd
        and asgn.aug_op is None
        and len(asgn.target) == 1
        and isinstance(asgn.target[0], uni.Name)
    ) {
        return None;
    }
    h = asgn.target[0];
    if h.sym is None {
        return None;
    }
    _fn = asgn.find_parent_of_type(uni.Ability);
    _scope = _fn if _fn is not None else asgn.find_parent_of_type(uni.ModuleCode);
    if _scope is None {
        return None;
    }
    _spawn_loop = (
        asgn.find_parent_of_type(uni.InForStmt)
        or asgn.find_parent_of_type(uni.WhileStmt)
        or asgn.find_parent_of_type(uni.IterForStmt)
    );
    _waits = 0;
    for use in _scope.get_all_sub_nodes(uni.Name) {
        if use.sym is not h.sym or use is h {
            continue;
        }
        _p = use.parent;
        _use_loop = (
            use.find_parent_of_type(uni.InForStmt)
            or use.find_parent_of_type(uni.WhileStmt)
            or use.find_parent_of_type(uni.IterForStmt)
        );
        if isinstance(_p, uni.ConcurrentExpr)
            and _p.target is use
            and _p.tok is not None
            and _p.tok.name == Tok.KW_WAIT
            and _use_loop is _spawn_loop {
            _waits += 1;
            continue;
        }
        return None;
    }
    if _waits != 1 {
        return None;
    }
    return h;
}

impl NativeLowering._empty_ctor_args_of(nd: uni.FuncCall) -> list[TypeBase] {
    _own = self._container_type_args(nd?.type);
    if _own {
        return _own;
    }
    _cur: (uni.UniNode | None) = nd;
    _par = _cur?.parent;
    while isinstance(_par, uni.CfgExpr) {
        _cur = _par;
        _par = _par.parent;
    }
    if isinstance(_par, uni.IfElseExpr) {
        _sib = _par.else_value if _par.value is _cur else _par.value;
        if _sib is not _cur {
            return self._container_type_args(self._unwrap_cfg_expr(_sib)?.type);
        }
    }
    return [];
}

impl NativeLowering._unwrap_cfg_expr(e: any) -> any {
    _cur = e;
    while isinstance(_cur, uni.CfgExpr) {
        _cur = _cur.expr;
    }
    return _cur;
}

impl NativeLowering._container_type_args(t: any) -> list[TypeBase] {
    if t is None {
        return [];
    }
    for _cand in (t?.types or [t]) {
        _priv = _cand?.private;
        if _priv is not None and (_priv?.type_args or []) {
            return list(_priv.type_args);
        }
    }
    return [];
}

impl NativeLowering._emit_kw_spread_refusal(nd: uni.FuncCall) -> None {
    self.emit(
        E5092,
        node_override=nd,
        kind="call argument unpacking",
        name="**",
        help_text="A `**` spread binds against the callee's declared parameters, so the callee's signature must be statically known and its `*args`/`**kwargs` packs must lay out natively. Call a declared function, or pass the arguments explicitly."
    );
}

impl NativeLowering._bound_args_sig_shape(
    callee_sig: uni.FuncSignature, self_offset: int
) -> tuple[list[uni.ParamVar], int, bool] {
    sig_params = callee_sig.get_parameters();
    _self_skip = 0;
    if (
        self_offset > 0
        and sig_params
        and sig_params[0].name
        and sig_params[0].name.value == "self"
    ) {
        sig_params = sig_params[1:];
        _self_skip = 1;
    }
    _has_pack = (callee_sig.varargs is not None) or (callee_sig.kwargs is not None);
    return (sig_params, _self_skip, _has_pack);
}

impl NativeLowering._bound_args_bind_path(
    has_pack: bool, kw_spreads: list[uni.Expr], callee_sig: uni.FuncSignature
) -> bool {
    return has_pack
        or (
            bool(kw_spreads)
            and callee_sig.varargs is None
            and callee_sig.kwargs is None
        );
}

impl NativeLowering._bound_args_fixed_params(
    callee_sig: uni.FuncSignature, self_skip: int
) -> tuple[list[uni.ParamVar], int] {
    _fixed = list(callee_sig.posonly_params or []) + list(callee_sig.params or []);
    _n_posonly = len(callee_sig.posonly_params or []);
    if self_skip and _fixed {
        _fixed = _fixed[1:];
        _n_posonly = _n_posonly - 1 if _n_posonly > 0 else 0;
    }
    return (_fixed, _n_posonly);
}

impl NativeLowering._bound_args_param_default(sp: uni.ParamVar) -> (uni.Expr | None) {
    chosen = sp.value;
    if isinstance(chosen, (uni.Null, uni.Ellipsis))
        and str(chosen.loc.mod_path).endswith(".pyi") {
        chosen = None;
    }
    return chosen;
}

impl NativeLowering._new_params(
    nd: uni.FuncCall
) -> (list[uni.Expr | uni.KWPair] | None) {
    params_l: list[uni.Expr | uni.KWPair] = list(nd.params or []);
    if not params_l or any([isinstance(p, uni.KWPair) for p in params_l]) {
        self.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name="new",
            help_text="new() takes a class followed by positional constructor arguments only."
        );
        return None;
    }
    return params_l;
}

impl NativeLowering._intrinsic_positional(
    nd: uni.FuncCall, intr: IntrinsicEntry
) -> (list[uni.Expr] | None) {
    positional: list[uni.Expr] = [];
    _has_kw = False;
    for p in (nd.params or []) {
        if isinstance(p, uni.KWPair) {
            _has_kw = True;
        } else {
            positional.append(p);
        }
    }
    if _has_kw {
        self._emit_intrinsic_misuse(nd, intr, "keyword arguments are not accepted");
        return None;
    }
    if len(positional) != intr.arity() {
        self._emit_intrinsic_misuse(
            nd, intr, f"expected {intr.arity()} argument(s), got {len(positional)}"
        );
        return None;
    }
    return positional;
}

impl NativeLowering._call_contextmanager_refusal_name(nd: uni.FuncCall) -> (str | None) {
    import from jaclang.compiler.erased_imports { contextmanager_ability }
    _cm_callee = self._callee_ability_of(nd);
    if contextmanager_ability(_cm_callee) {
        _cm_name = _cm_callee.name_ref.sym_name
            if _cm_callee is not None and _cm_callee.name_ref
            else "contextmanager";
        return f"@contextmanager {_cm_name}";
    }
    return None;
}

impl NativeLowering._call_field_marker(
    nd: uni.FuncCall
) -> (tuple[uni.HasVar, uni.Expr | None, uni.Expr | None] | None) {
    import from jaclang.compiler.field_semantics {
        field_initialization,
        is_field_marker
    }
    if is_field_marker(nd) {
        owner = nd.parent;
        assert isinstance(owner, uni.HasVar);
        initialization = field_initialization(owner);
        factory = initialization.factory_expr;
        return (owner, factory, initialization.default_expr);
    }
    return None;
}

impl NativeLowering._call_intrinsic_entry(func_name: str) -> (IntrinsicEntry | None) {
    import from jaclang.compiler.intrinsic_registry { INTRINSIC_REGISTRY }
    return INTRINSIC_REGISTRY.get(func_name);
}

impl NativeLowering._call_distinct_callee_type(nd: uni.FuncCall) -> (ClassType | None) {
    _callee_t = nd.target?.type;
    if isinstance(_callee_t, ClassType)
        and _callee_t.private.distinct_key is not None {
        return _callee_t;
    }
    return None;
}

impl NativeLowering._call_declared_fn_key(
    declaration: (uni.Ability | None)
) -> (tuple[str, str] | None) {
    if declaration is not None and declaration.name_ref is not None {
        declaring_module = declaration.parent_scope;
        if isinstance(declaring_module, uni.Module) {
            return (
                os.path.realpath(declaring_module.source.file_path),
                declaration.name_ref.sym_name
            );
        }
    }
    return None;
}

impl NativeLowering._call_declaration_body(
    declaration: uni.Ability
) -> (Sequence[uni.UniNode] | None) {
    return ModuleFacts.unwrap_body(declaration);
}

impl NativeLowering._call_module_fn_key(
    nd: uni.FuncCall, mod_qual: str, func_name: str
) -> (tuple[str, str] | None) {
    import from jaclang.compiler.frontend.codeinfo { resolve_native_module }
    (_, source) = resolve_native_module(mod_qual, os.path.dirname(nd.loc.mod_path));
    if source is not None {
        return (os.path.realpath(source), func_name);
    }
    return None;
}

impl NativeLowering._call_extern_symbol(
    func_name: str, source_context: str, src_ab: (uni.Ability | None)
) -> str {
    _extern_sym = func_name;
    if source_context == "native" and src_ab is not None {
        _extern_sym = self._symbol_for(
            func_name,
            src_ab.find_parent_of_type(uni.Module),
            bool(src_ab.access and src_ab.access.tag.name == Tok.KW_PUB)
        );
    }
    return _extern_sym;
}

impl NativeLowering._call_clib_sig_strs(
    clib_sig: uni.FuncSignature
) -> tuple[set[int], str] {
    import from jaclang.compiler.backends.native.foreign { declared_type_name }
    _clib_str_args: set[int] = set();
    for (_ci, _cp) in enumerate(clib_sig.get_parameters()) {
        if _cp.type_tag is not None
            and declared_type_name(_cp.type_tag.tag) == "str" {
            _clib_str_args.add(_ci);
        }
    }
    _clib_ret_name = declared_type_name(clib_sig.return_type) or "";
    return (_clib_str_args, _clib_ret_name);
}

impl NativeLowering._call_foreign_struct_result(func_name: str) -> (str | None) {
    foreign_decl = self._foreign_fns().get(func_name);
    result_name = foreign_decl["ret"] if foreign_decl is not None else None;
    if isinstance(result_name, str) and result_name in self.clib_struct_names {
        return result_name;
    }
    return None;
}

impl NativeLowering._isinstance_core_known_string(
    source_type: (TypeBase | None)
) -> bool {
    source_members = source_type.types
        if isinstance(source_type, UnionType)
        else [source_type];
    present_members = [
        member
        for member in source_members
        if not (
            isinstance(member, ClassType)
            and member.shared.class_name in ("None", "NoneType")
        )
    ];
    known_string = len(present_members) == 1
        and isinstance(present_members[0], ClassType)
        and present_members[0].shared.class_name == "str";
    return known_string;
}

impl NativeLowering._try_flow_future_par_ok(nogc_enforced: bool, rc_debug: bool) -> bool {
    _par_ok = (nogc_enforced and self._gc_mode() == "none")
        or (self._gc_mode() == "rc" and not rc_debug);
    return _par_ok;
}

impl NativeLowering._consume_kw_spreads_callee(nd: uni.FuncCall) -> str {
    callee = self._get_name(nd.target) or "function";
    if isinstance(nd.target, uni.AtomTrailer)
        and isinstance(nd.target.right, uni.Name) {
        callee = nd.target.right.sym_name;
    }
    return callee;
}

impl NativeLowering._sized_builtin_call_wrap_owner(
    target: uni.AtomTrailer
) -> (str | None) {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    _owner = self._get_name(target.target);
    _attr = self._get_name(target.right);
    if _owner is not None and _attr == "wrap" and JAC_TYPE_REGISTRY.is_sized(_owner) {
        return _owner;
    }
    return None;
}

impl NativeLowering._sized_builtin_call_kind(func_name: str) -> (str | None) {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if JAC_TYPE_REGISTRY.is_sized(func_name) {
        return "cast";
    }
    if func_name.startswith("wrapping_") and JAC_TYPE_REGISTRY.is_builtin(func_name) {
        return "wrapping";
    }
    return None;
}

impl NativeLowering._take_place(nd: uni.FuncCall) -> (uni.Expr | uni.KWPair | None) {
    params_l = list(nd.params or []);
    if len(params_l) != 1 or isinstance(params_l[0], uni.KWPair) {
        self.emit(E5092, node_override=nd, kind="take() call", name="take");
        return None;
    }
    return params_l[0];
}

impl NativeLowering._swap_params(
    nd: uni.FuncCall
) -> (list[uni.Expr | uni.KWPair] | None) {
    params_l = list(nd.params or []);
    if len(params_l) != 2 or any([isinstance(_p, uni.KWPair) for _p in params_l]) {
        self.emit(E5092, node_override=nd, kind="swap() call", name="swap");
        return None;
    }
    return params_l;
}

impl NativeLowering._transfer_own_args_is_ctor(nd: uni.FuncCall) -> bool {
    return isinstance(nd.target, uni.Name)
        and (
            nd.target.sym_name in self.arch_ast_map
            or self._arch_alias_target(nd.target) in self.arch_ast_map
        );
}

impl NativeLowering._transfer_own_args_owned(
    is_ctor: bool, sig: (uni.FuncSignature | None), offset: int, n_release: int
) -> (tuple[set, dict[str, int]] | None) {
    _sig_params = sig.get_parameters() if sig is not None else [];
    _own_idx: set = set();
    if is_ctor {
        for _oi in range(n_release) {
            _own_idx.add(_oi);
        }
    } elif sig is not None and len(_sig_params) + offset == n_release {
        for (_oi, _op) in enumerate(_sig_params) {
            if _op.type_tag is not None
                and _op.type_tag.ownership == OwnershipKind.OWN {
                _own_idx.add(_oi + offset);
            }
        }
    }
    if not _own_idx {
        return None;
    }
    _param_idx: dict[str, int] = {};
    for (_pi2, _p2) in enumerate(_sig_params) {
        _param_idx[_p2.name.sym_name] = _pi2 + offset;
    }
    return (_own_idx, _param_idx);
}

impl NativeLowering._transfer_own_args_moved(
    nd: uni.FuncCall,
    is_ctor: bool,
    own_idx: set,
    param_idx: dict[str, int],
    offset: int
) -> list[tuple[int, uni.Name]] {
    _moved: list[tuple[int, uni.Name]] = [];
    _pos = offset;
    for _pa in (nd.params or []) {
        _aidx = -1;
        _anode: (uni.Expr | None) = None;
        if isinstance(_pa, uni.KWPair) {
            _anode = _pa.value;
            _k = _pa.key.sym_name if _pa.key is not None else None;
            if _k is not None and _k in param_idx {
                _aidx = param_idx[_k];
            }
        } else {
            _anode = _pa;
            _aidx = _pos;
            _pos += 1;
        }
        if not (is_ctor or _aidx in own_idx) or not isinstance(_anode, uni.Name) {
            continue;
        }
        _moved.append((_aidx, _anode));
    }
    return _moved;
}

impl NativeLowering._isinstance_abc_reduction_shapes(
    type_expr: uni.UniNode
) -> (list[str] | None) {
    try {
        import from jaclang.compiler.types.types { ClassType as _AbcClassType }
    } except ImportError {
        return None;
    }
    t = type_expr.type if isinstance(type_expr, uni.Expr) else None;
    if not isinstance(t, _AbcClassType) or t._shared is None {
        return None;
    }
    if not t.shared.is_from_stdlib_stub {
        return None;
    }
    cn = t.shared.class_name;
    if cn in _NA_ABC_REDUCTIONS {
        return list(_NA_ABC_REDUCTIONS[cn]);
    }
    if cn in _NA_ABC_OPAQUE {
        return [];
    }
    return None;
}
