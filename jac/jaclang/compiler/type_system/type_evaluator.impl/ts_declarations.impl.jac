impl TypeEvaluator._get_ts_declared_item_type(
    from_loc: uni.ModulePath, item_name: str
) -> (TypeBase | None) {
    if not (
        from_loc.path
        and len(from_loc.path) == 1
        and isinstance(from_loc.path[0], uni.String)
    ) {
        return None;
    }
    if not from_loc.in_client_context() {
        return None;
    }
    mod_path = from_loc.loc.mod_path if from_loc.loc else None;
    if not mod_path {
        return None;
    }
    spec = from_loc.path[0].lit_value;
    if not isinstance(spec, str) or not spec {
        return None;
    }

    cache_key = spec + "\n" + mod_path;
    if cache_key in self._ts_decl_path_cache {
        dts_path = self._ts_decl_path_cache[cache_key];
    } else {
        import from jaclang.jac0core.modresolver {
            resolve_client_npm_declarations,
            sibling_declaration_file
        }
        dts_path: (str | None) = None;
        try {
            if spec.startswith('.') {
                js_path = from_loc.resolve_relative_path();
                if js_path {
                    dts_path = sibling_declaration_file(js_path);
                }
            } else {
                dts_path = resolve_client_npm_declarations(spec, mod_path);
            }
        } except Exception {
            dts_path = None;
        }
        self._ts_decl_path_cache[cache_key] = dts_path;
    }
    if dts_path is None {
        return None;
    }
    return self._ts_declared_type_from_file(dts_path, item_name);
}

impl TypeEvaluator._ts_declared_type_from_file(
    dts_path: str, item_name: str
) -> (TypeBase | None) {
    decls = self._load_ts_declarations(dts_path);
    if not decls {
        return None;
    }
    decl = decls.get(item_name);
    if decl is None {
        return None;
    }
    return self._map_ts_decl(decl, decls, item_name);
}

impl TypeEvaluator._load_ts_declarations(dts_path: str) -> (dict[str, TsDecl] | None) {
    if dts_path in self._ts_decl_cache {
        return self._ts_decl_cache[dts_path];
    }
    import from jaclang.compiler.type_system.ts_decl_parser { parse_dts }
    decls: (dict[str, TsDecl] | None) = None;
    try {
        with open(dts_path, 'r', encoding='utf-8', errors='replace') as f {
            source = f.read();
        }
        decls = parse_dts(source);
    } except Exception {
        decls = None;
    }
    self._ts_decl_cache[dts_path] = decls;
    return decls;
}

impl TypeEvaluator._map_ts_decl(
    decl: TsDecl, decls: dict[str, TsDecl], item_name: str
) -> (TypeBase | None) {
    if decl.kind == TsDeclKind.FUNCTION and decl.ty is not None {
        mapped = self._map_ts_type(decl.ty, decls);
        if isinstance(mapped, types.FunctionType) {
            mapped.func_name = item_name;
        }
        return mapped;
    }
    if (
        decl.kind in (TsDeclKind.CONST, TsDeclKind.TYPEALIAS) and decl.ty is not None
    ) {
        return self._map_ts_type(decl.ty, decls);
    }
    if decl.kind in (TsDeclKind.INTERFACE, TsDeclKind.CLASS) {
        synth = self._synthesize_ts_decl_class(decls, item_name);
        if synth is not None {
            return synth;
        }
    }
    return types.AnyType(is_foreign=True);
}

impl TypeEvaluator._map_ts_type(
    ts: (TsType | None),
    decls: dict[str, TsDecl],
    seen: (set[str] | None) = None,
    shells: (dict[str, types.ClassType] | None) = None
) -> TypeBase {
    foreign_any = types.AnyType(is_foreign=True);
    if ts is None or self.prefetch is None {
        return foreign_any;
    }
    k = ts.kind;
    if k == TsTypeKind.ANY {
        return foreign_any;
    }
    if k == TsTypeKind.NEVER {
        return types.NeverType();
    }
    if k == TsTypeKind.VOID {
        return self._convert_to_instance(self.get_none_type());
    }
    if k == TsTypeKind.PRIM {
        prim_cls = {
            'string': self.prefetch.str_class,
            'number': self.prefetch.float_class,
            'boolean': self.prefetch.bool_class,
            'object': self.prefetch.object_class,
            'symbol': self.prefetch.object_class,
            'bigint': self.prefetch.int_class,

        }.get(
            ts.name
        );
        if prim_cls is None {
            return foreign_any;
        }
        return self._convert_to_instance(prim_cls);
    }
    if (k == TsTypeKind.LITERAL_STR and self.prefetch.str_class) {
        return self._convert_to_instance(
            self.prefetch.str_class.clone_with_literal(ts.name)
        );
    }
    if k == TsTypeKind.LITERAL_NUM {
        int_val: (int | None) = None;
        try {
            int_val = int(ts.name);
        } except ValueError { }
        if (int_val is not None and self.prefetch.int_class) {
            return self._convert_to_instance(
                self.prefetch.int_class.clone_with_literal(int_val)
            );
        }
        if self.prefetch.float_class {
            return self._convert_to_instance(self.prefetch.float_class);
        }
        return foreign_any;
    }
    if (k == TsTypeKind.LITERAL_BOOL and self.prefetch.bool_class) {
        return self._convert_to_instance(
            self.prefetch.bool_class.clone_with_literal(ts.name == 'true')
        );
    }
    if k == TsTypeKind.UNION {
        return types.UnionType(
            types=[self._map_ts_type(m, decls, seen, shells) for m in ts.args]
        );
    }
    if (k in (TsTypeKind.ARRAY, TsTypeKind.TUPLE) and self.prefetch.list_class) {
        elem: TypeBase = foreign_any;
        if k == TsTypeKind.ARRAY and ts.args {
            elem = self._map_ts_type(ts.args[0], decls, seen, shells);
        } elif (k == TsTypeKind.TUPLE and ts.args) {
            mapped = [self._map_ts_type(a, decls, seen, shells) for a in ts.args];
            elem = mapped[0] if len(mapped) == 1 else types.UnionType(types=mapped);
        }
        lst = self.prefetch.list_class.clone_as_instance();
        lst.private.type_args = [elem];
        return lst;
    }
    if k == TsTypeKind.FUNC {
        parameters: list[types.Parameter] = [];
        for (idx, p) in enumerate(ts.params) {
            if p.rest {
                elem_ty: TypeBase = types.AnyType(is_foreign=True);
                if (p.ty is not None and p.ty.kind == TsTypeKind.ARRAY and p.ty.args) {
                    elem_ty = self._map_ts_type(p.ty.args[0], decls, seen, shells);
                }
                parameters.append(
                    types.Parameter(
                        name=p.name or f"p{idx}",
                        category=types.ParameterCategory.ArgsList,
                        param_type=elem_ty,
                        param_kind=types.ParamKind.VARARG,
                    )
                );
                continue;
            }
            parameters.append(
                types.Parameter(
                    name=p.name or f"p{idx}",
                    category=types.ParameterCategory.Positional,
                    param_type=self._map_ts_type(p.ty, decls, seen, shells)
                        if p.ty is not None
                        else types.AnyType(is_foreign=True),
                    has_default=p.optional,
                )
            );
        }
        ret: TypeBase = types.AnyType(is_foreign=True);
        if ts.ret is not None {
            ret = self._map_ts_type(ts.ret, decls, seen, shells);
        }
        return types.FunctionType(func_name='', return_type=ret, parameters=parameters);
    }
    if k == TsTypeKind.REF {
        if seen is None {
            seen = set();
        }
        if ts.name in seen {
            return foreign_any;
        }
        target = decls.get(ts.name);
        if (
            target is not None
            and target.kind == TsDeclKind.TYPEALIAS
            and target.ty is not None
        ) {
            seen.add(ts.name);
            return self._map_ts_type(target.ty, decls, seen, shells);
        }
        if target is not None
        and target.kind in (TsDeclKind.INTERFACE, TsDeclKind.CLASS) {
            if shells is not None and ts.name in shells {
                return self._convert_to_instance(shells[ts.name]);
            }
            synth = self._synthesize_ts_decl_class(decls, ts.name);
            if synth is not None {
                return self._convert_to_instance(synth);
            }
        }
        return foreign_any;
    }
    return foreign_any;
}

impl TypeEvaluator._ts_synth_class_types(
    decls: dict[str, TsDecl]
) -> (dict[str, types.ClassType] | None) {
    key = id(decls);
    if key in self._ts_synth_class_cache {
        return self._ts_synth_class_cache[key];
    }
    self._ts_synth_class_cache[key] = None;

    synth_src = uni.Source('', '<ts-synth>');

    shells: dict[str, types.ClassType] = {};
    for (name, decl) in decls.items() {
        if (
            decl.kind not in (TsDeclKind.INTERFACE, TsDeclKind.CLASS)
            or not name.isidentifier()
        ) {
            continue;
        }
        shells[name] = types.ClassType(
            _shared=types.ClassType.ClassDetailsShared(
                class_name=name, symbol_table=uni.Module.make_stub(inject_name=name),
            ),
            flags=types.TypeFlags.Instantiable,
        );
    }
    if not shells {
        return None;
    }

    direct_bases: dict[str, list[str]] = {};
    for (name, decl) in decls.items() {
        if name not in shells {
            continue;
        }
        picked: list[str] = [];
        seen: set[str] = set();
        for b in decl.heritage {
            if b != name and b in shells and b not in seen {
                seen.add(b);
                picked.append(b);
            }
        }
        direct_bases[name] = picked;
    }
    WHITE = 0;
    GRAY = 1;
    BLACK = 2;
    color: dict[str, int] = {n: WHITE for n in shells};
    back_edges: set[tuple[(str, str)]] = set();
    for start in shells {
        if color[start] != WHITE {
            continue;
        }
        color[start] = GRAY;
        stack: list[tuple[(str, int)]] = [(start, 0)];
        while stack {
            top = stack[-1];
            cur = top[0];
            idx = top[1];
            nbrs = direct_bases.get(cur, []);
            if idx < len(nbrs) {
                stack[-1] = (cur, idx + 1);
                v = nbrs[idx];
                cv = color[v];
                if cv == GRAY {
                    back_edges.add((cur, v));
                } elif cv == WHITE {
                    color[v] = GRAY;
                    stack.append((v, 0));
                }
            } else {
                stack.pop();
                color[cur] = BLACK;
            }
        }
    }

    for (name, decl) in decls.items() {
        cls_type = shells.get(name);
        if cls_type is None {
            continue;
        }
        scope = cls_type.shared.symbol_table;

        kept_by_name: dict[str, list[TsMember]] = {};
        for m in decl.members {
            if (not m.name or not m.name.isidentifier()) {
                continue;
            }
            if m.is_static or m.access in (TsAccess.PRIVATE, TsAccess.PROTECTED) {
                continue;
            }
            kept_by_name.setdefault(m.name, []).append(m);
        }
        for (mname, group) in kept_by_name.items() {
            if len(group) > 1 {
                member_type = types.AnyType(is_foreign=True);
            } else {
                m = group[0];
                member_type = self._map_ts_type(m.ty, decls, None, shells);
                if m.optional {
                    member_type = types.UnionType(
                        types=[
                            member_type,
                            self._convert_to_instance(self.get_none_type())
                        ]
                    );
                }
            }
            self._install_synth_member(scope, synth_src, mname, member_type);
        }
        if decl.call_sig is not None {
            self._install_synth_member(
                scope,
                synth_src,
                "__call__",
                self._map_ts_type(decl.call_sig, decls, None, shells)
            );
        }
        base_classes: list[types.TypeBase] = [];
        for b in direct_bases.get(name, []) {
            if (name, b) in back_edges {
                continue;
            }
            base = shells.get(b);
            if base is not None {
                base_classes.append(base);
            }
        }
        if not base_classes and self.prefetch and self.prefetch.object_class {
            base_classes.append(self.prefetch.object_class);
        }
        cls_type.shared.base_classes = base_classes;
    }

    for cls_type in shells.values() {
        type_utils.compute_mro_linearization(cls_type);
    }

    self._ts_synth_class_cache[key] = shells;
    return shells;
}

impl TypeEvaluator._install_synth_member(
    scope: uni.UniScopeNode, synth_src: uni.Source, mname: str, member_type: TypeBase
) -> None {
    field_node = uni.Name(
        orig_src=synth_src,
        name=Tok.NAME.value,
        value=mname,
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0,
    );
    field_node.type = member_type;
    scope.names_in_scope[mname] = uni.Symbol(
        defn=field_node, access=SymbolAccess.PUBLIC, parent_tab=scope
    );
}

impl TypeEvaluator._synthesize_ts_decl_class(
    decls: dict[str, TsDecl], item_name: str
) -> (TypeBase | None) {
    classes = self._ts_synth_class_types(decls);
    if classes is None {
        return None;
    }
    return classes.get(item_name);
}

impl TypeEvaluator._emit_untyped_external(
    name_node: uni.Name, name: str, module: str
) -> None {
    if self._untyped_external_is_error(name_node) {
        self.emit_diag(E1120, name_node, name=name, module=module);
    } else {
        self.emit_diag(W1102, name_node, name=name, module=module);
    }
}

impl TypeEvaluator._untyped_external_is_error(node_: uni.UniNode) -> bool {
    mod_path = node_.loc.mod_path if node_.loc else None;
    if not mod_path {
        return False;
    }
    import from jaclang.jac0core.modresolver { find_jac_project_root }
    proj_root = find_jac_project_root(mod_path);
    if not proj_root {
        return False;
    }
    if proj_root in self._untyped_external_cfg_cache {
        return self._untyped_external_cfg_cache[proj_root];
    }
    import os;
    result = False;
    try {
        import from jaclang.jac0core.helpers { read_toml_with_encoding }
        data = read_toml_with_encoding(os.path.join(proj_root, 'jac.toml'));
        check_cfg = data.get('check', {}) if isinstance(data, dict) else {};
        result = (
            isinstance(check_cfg, dict) and check_cfg.get('untyped-external') == 'error'
        );
    } except Exception {
        result = False;
    }
    self._untyped_external_cfg_cache[proj_root] = result;
    return result;
}
