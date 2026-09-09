impl JcirGenPass._gen_native_interop_stubs(nd: UniNode) -> None {
    manifest = self.ir_in.gen.interop_manifest;
    parts: list[str] = [];
    names: list[str] = [];
    if (manifest and manifest.bindings) {
        import from jaclang.runtime.interop_bridge { JAC_TO_CTYPES_STR }
        for binding in manifest.native_exports {
            params = ', '.join(binding.param_names);
            ret_ct = JAC_TO_CTYPES_STR.get(binding.ret_type, 'ctypes.c_int64');
            arg_cts = ', '.join(
                JAC_TO_CTYPES_STR.get(pt, 'ctypes.c_int64')
                for pt in binding.param_types
            );
            parts.append(
                f"def {binding.name}({params}):\n"
                    + f"    import ctypes\n"
                    + f"    _addr = __jac_native_engine__"
                    + f".get_function_address('{binding.name}')\n"
                    + f"    _fn = ctypes.CFUNCTYPE({ret_ct}, {arg_cts})(_addr)\n"
                    + f"    return _fn({params})"
            );
            names.append(binding.name);
        }
    }
    if parts {
        self.set_out(nd, [CgSplice(src='\n'.join(parts), offset=0, bound_names=names)]);
    }
}

impl JcirGenPass._native_import_registration_map -> dict {
    manifest = self.ir_in.gen.interop_manifest;
    if not (manifest and manifest.bindings and manifest.native_imports) {
        return {};
    }
    reg_map: dict = {};
    for binding in manifest.native_imports {
        if binding.name in reg_map {
            continue;
        }
        src = (
            f"if '__jac_interop_py_funcs__' in globals() "
            + f"and '{binding.name}' in globals():\n"
            + f"    __jac_interop_py_funcs__['{binding.name}'] = {binding.name}"
        );
        reg_map[binding.name] = [CgSplice(src=src, offset=0)];
    }
    return reg_map;
}

impl JcirGenPass._top_level_bound_names(items: any) -> list {
    stmts = items if isinstance(items, list) else [items];
    names: list[str] = [];
    for stmt in stmts {
        if isinstance(stmt, list) {
            names.extend(self._top_level_bound_names(stmt));
        } elif isinstance(stmt, CgSplice) {
            names.extend(stmt.bound_names);
        } elif isinstance(stmt, CgNode) {
            if stmt.cls in ('FunctionDef', 'AsyncFunctionDef', 'ClassDef') {
                def_name = stmt.get('name');
                if isinstance(def_name, str) {
                    names.append(def_name);
                }
            } elif stmt.cls in ('Import', 'ImportFrom') {
                for alias in stmt.get('names') {
                    if isinstance(alias, CgNode) {
                        bound: str = '';
                        if alias.hasf('asname') {
                            asname = alias.get('asname');
                            if isinstance(asname, str) {
                                bound = asname;
                            }
                        }
                        if not bound {
                            plain = alias.get('name');
                            if isinstance(plain, str) {
                                bound = plain;
                            }
                        }
                        if bound {
                            names.append(bound);
                        }
                    }
                }
            } elif stmt.cls == 'Assign' {
                for target in stmt.get('targets') {
                    if (isinstance(target, CgNode) and (target.cls == 'Name')) {
                        target_id = target.get('id');
                        if isinstance(target_id, str) {
                            names.append(target_id);
                        }
                    }
                }
            }
        }
    }
    return names;
}

impl JcirGenPass._native_test_shim_stmts(nd: Test) -> list {
    import from jaclang.compiler.frontend.codeinfo {
        native_test_symbol,
        native_glob_init_name
    }
    test_name = nd.name.sym_name;
    line = nd.loc.first_line if nd.loc else 0;
    symbol = native_test_symbol(test_name, line);
    manifest = self.ir_in.gen.interop_manifest if self.ir_in?.gen else None;
    dep_sources = manifest.native_transitive_sources if manifest else [];
    init_syms: list[str] = [];
    for dep_src in (dep_sources or []) {
        if dep_src {
            dep_init = native_glob_init_name(dep_src, manifest);
            if dep_init not in init_syms {
                init_syms.append(dep_init);
            }
        }
    }
    init_syms.append("__jac_glob_init");
    init_list = "[" + ", ".join(f"'{sy}'" for sy in init_syms) + "]";
    src_lines = [
        "from jaclang.testing.test import invoke_native_test as _jac_invoke",
        "_jac_invoke(globals().get('__jac_native_engine__'), '"
            + symbol
            + "', '"
            + test_name
            + "', "
            + init_list
            + ")"
    ];
    return [CgSplice(src='\n'.join(src_lines), offset=0)];
}

impl JcirGenPass._generate_sv_to_sv_stubs(nd: Import) -> bool {
    manifest = self.ir_in.gen.interop_manifest;
    if (not manifest) {
        return False;
    }
    if (not nd.from_loc or not nd.from_loc.path) {
        return False;
    }
    module_name = nd.from_loc.base_module_name;
    if not module_name {
        return False;
    }
    sv_to_sv_names: set[str] = set();
    for b in manifest.server_exports_to_server {
        if b.source_module == module_name {
            sv_to_sv_names.add(b.name);
        }
    }
    import from jaclang.compiler.driver.boundary_classify {
        import_crosses_apps,
        import_provider_app,
        import_provider_route
    }
    mirrored_names: set[str] = set();
    if import_crosses_apps(nd) {
        for item in nd.items {
            if isinstance(item, ModuleItem) {
                mirrored = getattr(item.name, 'value', str(item.name));
                if mirrored in manifest.boundary_types {
                    mirrored_names.add(mirrored);
                }
            }
        }
    }
    if not sv_to_sv_names and not mirrored_names {
        return False;
    }
    provider_app = import_provider_app(nd) or module_name;
    provider_route = manifest.provider_routes.get(provider_app, '')
        or import_provider_route(nd);
    boundary_types = manifest.boundary_types;
    parts: list = [
        "from jaclang.server import sv_client as __jac_sv_client",
        "__jac_sv_client._declare_consumer_provider("
            + self._sv_consumer_app_expr()
            + ", '"
            + provider_app
            + "', '"
            + provider_route
            + "')"
    ];
    names: list = ['__jac_sv_client'];
    for item in nd.items {
        if not isinstance(item, ModuleItem) {
            continue;
        }
        item_name = getattr(item.name, 'value', str(item.name));
        local_name = item.alias.sym_name if item.alias else item_name;
        if item_name in boundary_types {
            info = boundary_types[item_name];
            parts.append(self._gen_py_boundary_stub_class(local_name, info));
            names.append(local_name);
            continue;
        }
        if item_name not in sv_to_sv_names {
            continue;
        }
        binding = None;
        for b in manifest.server_exports_to_server {
            if (b.name == item_name and b.source_module == module_name) {
                binding = b;
                break;
            }
        }
        if not isinstance(binding, InteropBinding) {
            continue;
        }
        if binding.kind == 'walker' {
            parts.append(
                self._gen_py_sv_walker_stub(
                    local_name, item_name, provider_app, binding, boundary_types
                )
            );
            names.append(local_name);
            continue;
        }
        parts.append(
            self._gen_py_sv_func_stub(
                local_name, item_name, provider_app, binding, boundary_types
            )
        );
        names.append(local_name);
    }
    if (len(parts) <= 1) {
        return False;
    }
    self.set_out(nd, [CgSplice(src='\n\n'.join(parts), offset=0, bound_names=names)]);
    return True;
}

impl JcirGenPass._sv_wire_args_dict(
    names: list[str], types: list[str], boundary_types: dict
) -> str {
    args_kvs: list[str] = [];
    for i in range(len(names)) {
        pname = names[i];
        ptype = types[i] if i < len(types) else '';
        if (ptype in boundary_types and boundary_types[ptype].kind != "enum") {
            args_kvs.append(
                "'"
                    + pname
                    + "': ("
                    + pname
                    + "._to_wire() if hasattr("
                    + pname
                    + ", '_to_wire') else "
                    + pname
                    + ")"
            );
        } else {
            args_kvs.append("'" + pname + "': " + pname);
        }
    }
    return '{' + ', '.join(args_kvs) + '}';
}

impl JcirGenPass._gen_py_sv_func_stub(
    local_name: str,
    func_name: str,
    provider_app: str,
    binding: InteropBinding,
    boundary_types: dict[(str, BoundaryTypeInfo)]
) -> str {
    params = ', '.join(binding.param_names) if binding.param_names else '';
    args_dict = self._sv_wire_args_dict(
        binding.param_names, binding.param_types, boundary_types
    );
    ret_type = binding.ret_type;
    effects = self._sv_endpoint_effects(binding, 'func:' + func_name);
    raw_call = (
        "await __jac_sv_client.call('"
        + provider_app
        + "', '"
        + func_name
        + "', "
        + args_dict
        + ", effects="
        + repr(effects)
        + ", contract="
        + repr(binding.endpoint_id)
        + ")"
    );
    if (ret_type in boundary_types and boundary_types[ret_type].kind != "enum") {
        ret_expr = ret_type + '._from_wire(' + raw_call + ')';
    } else {
        ret_expr = raw_call;
    }
    return 'async def ' + local_name + '(' + params + '):\n    return ' + ret_expr;
}

impl JcirGenPass._gen_py_sv_walker_stub(
    local_name: str,
    walker_name: str,
    provider_app: str,
    binding: InteropBinding,
    boundary_types: dict[(str, BoundaryTypeInfo)]
) -> str {
    field_names = list(binding.param_names);
    field_types = list(binding.param_types);
    fields_repr_pieces: list[str] = [];
    for fname in field_names {
        fields_repr_pieces.append("'" + fname + "'");
    }
    fields_repr = '[' + ', '.join(fields_repr_pieces) + ']';
    boundary_pairs: list[str] = [];
    for i in range(len(field_names)) {
        ptype = field_types[i] if i < len(field_types) else '';
        if (ptype in boundary_types and boundary_types[ptype].kind != "enum") {
            boundary_pairs.append("'" + field_names[i] + "': " + ptype);
        }
    }
    boundary_map = '{' + ', '.join(boundary_pairs) + '}';
    args_dict = self._sv_wire_args_dict(field_names, field_types, boundary_types);
    init_params = ', '.join(
        ['cls'] + [field_names[i] + '=None' for i in range(len(field_names))]
    );
    lines: list[str] = [];
    lines.append('class ' + local_name + ':');
    lines.append('    __jac_fields__ = ' + fields_repr);
    lines.append('    __jac_walker_name__ = ' + "'" + walker_name + "'");
    lines.append('    __jac_provider_app__ = ' + "'" + provider_app + "'");
    lines.append('    __jac_boundary_types__ = ' + boundary_map);
    lines.append('    def __new__(' + init_params + '):');
    lines.append('        kwargs = ' + args_dict);
    if field_names {
        lines.append(
            '        kwargs = {k: v for k, v in kwargs.items() if v is not None}'
        );
    }
    lines.append(
        '        return globals()["__jac_sv_client"].spawn_walker('
            + "'"
            + provider_app
            + "', '"
            + walker_name
            + "', kwargs, cls)"
    );
    lines.append('    def __init__(self, *args, **kwargs):');
    lines.append('        pass');
    lines.append('    @classmethod');
    lines.append('    def _deferred(cls, **kwargs):');
    lines.append(
        '        kwargs = {k: (v._to_wire() if hasattr(v, "_to_wire") else v)'
    );
    lines.append('                  for k, v in kwargs.items() if v is not None}');
    lines.append(
        '        return globals()["__jac_sv_client"].spawn_deferred('
            + "'"
            + provider_app
            + "', '"
            + walker_name
            + "', kwargs)"
    );
    lines.append('    def _to_wire(self):');
    lines.append(
        '        return {f: getattr(self, f, None) for f in self.__jac_fields__}'
    );
    lines.append('    @classmethod');
    lines.append('    def _from_wire(cls, d):');
    lines.append('        if d is None:');
    lines.append('            return None');
    lines.append('        if isinstance(d, list):');
    lines.append('            return [cls._from_wire(i) for i in d]');
    lines.append('        if not isinstance(d, dict):');
    lines.append('            return d');
    lines.append('        inst = object.__new__(cls)');
    lines.append('        for k, v in d.items():');
    lines.append('            if k in cls.__jac_boundary_types__ and v is not None:');
    lines.append('                v = cls.__jac_boundary_types__[k]._from_wire(v)');
    lines.append('            setattr(inst, k, v)');
    lines.append('        if not hasattr(inst, "reports"):');
    lines.append('            inst.reports = []');
    lines.append('        return inst');
    return '\n'.join(lines);
}

impl JcirGenPass._gen_py_boundary_stub_class(
    class_name: str, info: BoundaryTypeInfo
) -> str {
    field_names: list = [];
    for f in info.fields {
        field_names.append(f[0]);
    }
    fields_pieces: list[str] = [];
    for fname in field_names {
        fields_pieces.append("'" + fname + "'");
    }
    fields_repr = '[' + ', '.join(fields_pieces) + ']';
    lines: list[str] = [];
    lines.append('class ' + class_name + ':');
    lines.append('    __jac_fields__ = ' + fields_repr);
    lines.append('    def __init__(self, **kw):');
    lines.append('        for k, v in kw.items():');
    lines.append('            setattr(self, k, v)');
    lines.append('    def _to_wire(self):');
    lines.append(
        '        return {f: getattr(self, f, None) for f in self.__jac_fields__}'
    );
    lines.append('    @classmethod');
    lines.append('    def _from_wire(cls, d):');
    lines.append('        if d is None:');
    lines.append('            return None');
    lines.append('        if isinstance(d, list):');
    lines.append('            return [cls._from_wire(i) for i in d]');
    lines.append('        if not isinstance(d, dict):');
    lines.append('            return d');
    lines.append('        inst = cls.__new__(cls)');
    lines.append('        for k, v in d.items():');
    lines.append('            setattr(inst, k, v)');
    lines.append('        return inst');
    return '\n'.join(lines);
}

impl JcirGenPass._sv_endpoint_effects(binding: InteropBinding, key: str) -> list[str] {
    src_mod = (
        binding.ast_node.find_parent_of_type(Module)
            if binding.ast_node is not None
            else None
    );
    if src_mod is None or not src_mod.gen.interop_manifest {
        return ['*'];
    }
    import from jaclang.compiler.frontend.codeinfo { endpoint_key }
    (kind, name) = key.split(":", 1);
    effect = src_mod.gen.interop_manifest.endpoint_effects.get(
        endpoint_key(src_mod, kind, name)
    );
    if not isinstance(effect, dict) or effect.get('unknown') {
        return ['*'];
    }
    return [str(t) for t in effect['writes']];
}

impl JcirGenPass._sv_consumer_app_expr -> str {
    import from jaclang.compiler.driver.boundary_classify { consumer_owner_app }
    consumer = consumer_owner_app(self.ir_in);
    if consumer {
        return "'" + consumer + "'";
    }
    return '__name__';
}

impl JcirGenPass._sv_bridge_walker_call(expr: Expr) -> (FuncCall | None) {
    import from jaclang.compiler.driver.boundary_classify {
        CrossAppKind,
        classify_cross_app_import
    }
    if isinstance(expr, BinaryExpr) and expr.op?.name == Tok.KW_SPAWN {
        for side in (expr.right, expr.left) {
            found = self._sv_bridge_walker_call(side);
            if found is not None {
                return found;
            }
        }
        return None;
    }
    if not isinstance(expr, FuncCall) or not isinstance(expr.target, Name) {
        return None;
    }
    target = expr.target;
    item: (ModuleItem | None) = None;
    for imp_nd in self.ir_in.get_all_sub_nodes(Import) {
        for cand in imp_nd.items {
            if (
                isinstance(cand, ModuleItem)
                and isinstance(cand.name, Name)
                and cand.name.sym_name == target.sym_name
            ) {
                item = cand;
                break;
            }
        }
        if item is not None {
            break;
        }
    }
    if item is None {
        return None;
    }
    imp = item.from_parent;
    if (
        classify_cross_app_import(imp, self.ir_in.gen.interop_manifest)
        != CrossAppKind.SERVICE_BRIDGE
    ) {
        return None;
    }
    facts = imp.boundary_facts;
    item_name = getattr(item.name, 'value', str(item.name));
    in_walkers = facts is not None and item_name in facts.sv_walkers;
    if not in_walkers {
        binding = self.ir_in.gen.interop_manifest.bindings.get(target.sym_name);
        if binding is None or binding.kind != 'walker' {
            return None;
        }
    }
    return expr;
}
