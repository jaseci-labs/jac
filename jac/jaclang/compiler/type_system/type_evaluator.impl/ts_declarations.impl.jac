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

impl TypeEvaluator._load_ts_declarations(dts_path: str) -> (dict | None) {
    if dts_path in self._ts_decl_cache {
        return self._ts_decl_cache[dts_path];
    }
    import from jaclang.compiler.type_system.ts_decl_parser { parse_dts }
    decls: (dict | None) = None;
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
    decl: object, decls: dict, item_name: str
) -> (TypeBase | None) {
    if decl.kind == 'function' and decl.ty is not None {
        mapped = self._map_ts_type(decl.ty, decls);
        if isinstance(mapped, types.FunctionType) {
            mapped.func_name = item_name;
        }
        return mapped;
    }
    if (decl.kind in ('const', 'typealias') and decl.ty is not None) {
        return self._map_ts_type(decl.ty, decls);
    }
    if decl.kind in ('interface', 'class') {
        synth = self._synthesize_ts_interface(decls, item_name);
        if synth is not None {
            return synth;
        }
    }
    return types.AnyType(is_foreign=True);
}

impl TypeEvaluator._map_ts_type(
    ts: object, decls: dict, seen: (set[str] | None) = None
) -> TypeBase {
    foreign_any = types.AnyType(is_foreign=True);
    if ts is None or self.prefetch is None {
        return foreign_any;
    }
    k = ts.kind;
    if k == 'never' {
        return types.NeverType();
    }
    if k == 'void' {
        return self._convert_to_instance(self.get_none_type());
    }
    if k == 'prim' {
        prim_cls = {
            'string': self.prefetch.str_class,
            'number': self.prefetch.float_class,
            'boolean': self.prefetch.bool_class,
            'object': self.prefetch.object_class
        }.get(
            ts.name
        );
        if prim_cls is None {
            return foreign_any;
        }
        return self._convert_to_instance(prim_cls);
    }
    if (k == 'literal-str' and self.prefetch.str_class) {
        return self._convert_to_instance(
            self.prefetch.str_class.clone_with_literal(ts.name)
        );
    }
    if k == 'literal-num' {
        try {
            int_val = int(ts.name);
        } except ValueError {
            int_val = None;
        }
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
    if (k == 'literal-bool' and self.prefetch.bool_class) {
        return self._convert_to_instance(
            self.prefetch.bool_class.clone_with_literal(ts.name == 'true')
        );
    }
    if k == 'union' {
        return types.UnionType(
            types=[self._map_ts_type(m, decls, seen) for m in ts.args]
        );
    }
    if (k in ('array', 'tuple') and self.prefetch.list_class) {
        elem: TypeBase = foreign_any;
        if k == 'array' and ts.args {
            elem = self._map_ts_type(ts.args[0], decls, seen);
        } elif (k == 'tuple' and ts.args) {
            mapped = [self._map_ts_type(a, decls, seen) for a in ts.args];
            elem = mapped[0] if len(mapped) == 1 else types.UnionType(types=mapped);
        }
        lst = self.prefetch.list_class.clone_as_instance();
        lst.private.type_args = [elem];
        return lst;
    }
    if k == 'func' {
        parameters: list[types.Parameter] = [];
        for (idx, p) in enumerate(ts.params) {
            if p.rest {
                elem_ty: TypeBase = types.AnyType(is_foreign=True);
                if (p.ty is not None and p.ty.kind == 'array' and p.ty.args) {
                    elem_ty = self._map_ts_type(p.ty.args[0], decls, seen);
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
                    param_type=self._map_ts_type(p.ty, decls, seen)
                        if p.ty is not None
                        else types.AnyType(is_foreign=True),
                    has_default=p.optional,
                )
            );
        }
        ret: TypeBase = types.AnyType(is_foreign=True);
        if ts.ret is not None {
            ret = self._map_ts_type(ts.ret, decls, seen);
        }
        return types.FunctionType(func_name='', return_type=ret, parameters=parameters);
    }
    if k == 'ref' {
        if seen is None {
            seen = set();
        }
        if ts.name in seen {
            return foreign_any;
        }
        target = decls.get(ts.name);
        if (
            target is not None and target.kind == 'typealias' and target.ty is not None
        ) {
            seen.add(ts.name);
            return self._map_ts_type(target.ty, decls, seen);
        }
        if target is not None and target.kind in ('interface', 'class') {
            synth = self._synthesize_ts_interface(decls, ts.name);
            if synth is not None {
                return self._convert_to_instance(synth);
            }
        }
        return foreign_any;
    }
    return foreign_any;
}

impl TypeEvaluator._ts_type_to_pyannot(ts: object, decls: dict) -> str {
    if ts is None {
        return "object";
    }
    k = ts.kind;
    if k == 'any' {
        return "Any";
    }
    if k == 'prim' {
        return {
            'string': 'str',
            'number': 'float',
            'boolean': 'bool',
            'object': 'object',
            'symbol': 'object',
            'bigint': 'int',

        }.get(
            ts.name, 'object'
        );
    }
    if k == 'void' {
        return 'None';
    }
    if k == 'literal-str' {
        return 'str';
    }
    if k == 'literal-num' {
        return 'float';
    }
    if k == 'literal-bool' {
        return 'bool';
    }
    if k in ('array', 'tuple') {
        if ts.args {
            return f"list[{self._ts_type_to_pyannot(ts.args[0], decls)}]";
        }
        return 'list';
    }
    if k == 'union' {
        ordered: list[str] = [];
        for a in ts.args {
            p = self._ts_type_to_pyannot(a, decls);
            if p not in ordered {
                ordered.append(p);
            }
        }
        return " | ".join(ordered) if ordered else 'object';
    }
    if k == 'ref' {
        target = decls.get(ts.name);
        if target is not None and target.kind in ('interface', 'class') {
            return ts.name;
        }
        return 'object';
    }
    return 'object';
}

impl TypeEvaluator._ts_synthetic_module(decls: dict) -> (uni.Module | None) {
    key = id(decls);
    if key in self._ts_synthetic_mod_cache {
        return self._ts_synthetic_mod_cache[key];
    }

    self._ts_synthetic_mod_cache[key] = None;
    lines: list[str] = [];
    for (name, decl) in decls.items() {
        if decl.kind not in ('interface', 'class') {
            continue;
        }
        if not name.isidentifier() {
            continue;
        }
        bases = [
            b
            for b in decl.heritage
            if decls.get(b) is not None
            and decls.get(b).kind in ('interface', 'class')
            and b.isidentifier()
        ];
        lines.append(
            f"class {name}(" + ", ".join(bases) + "):" if bases else f"class {name}:"
        );
        body: list[str] = [];
        for m in decl.members {
            if not m.name or m.is_method or not m.name.isidentifier() {
                continue;
            }
            annot = self._ts_type_to_pyannot(m.ty, decls);

            if m.optional and annot != "Any" {
                annot = f"{annot} | None";
            }
            body.append(f"    {m.name}: {annot}");
        }
        if not body {
            body.append("    pass");
        }
        lines.extend(body);
        lines.append("");
    }
    if not lines {
        return None;
    }

    source = "from typing import Any\n" + "\n".join(lines) + "\n";
    mod: (uni.Module | None) = None;
    try {
        uni_source = uni.Source(source, f"<ts-synthetic-{key}>");
        mod = PyastBuildPass(
            ir_in=uni.PythonModuleAst(py_ast.parse(source), orig_src=uni_source),
            prog=self.program,
        ).ir_out;
        SymTabBuildPass(ir_in=mod, prog=self.program);

        for nm in mod.get_all_sub_nodes(uni.Name) {
            if nm.value == "Any" and isinstance(nm.parent, uni.SubTag) {
                nm.type = types.AnyType(is_foreign=True);
            }
        }
    } except Exception {
        mod = None;
    }
    self._ts_synthetic_mod_cache[key] = mod;
    return mod;
}

impl TypeEvaluator._synthesize_ts_interface(
    decls: dict, item_name: str
) -> (TypeBase | None) {
    mod = self._ts_synthetic_module(decls);
    if mod is None {
        return None;
    }
    sym = mod.names_in_scope.get(item_name);
    if sym is None {
        return None;
    }
    cls_type = self.get_type_of_symbol(sym);
    if not isinstance(cls_type, types.ClassType) {
        return None;
    }

    cls_type.shared.is_ts_synthetic = True;

    return cls_type;
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
