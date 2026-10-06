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
