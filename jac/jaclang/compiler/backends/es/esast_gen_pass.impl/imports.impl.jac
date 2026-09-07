impl EsastGenPass._has_import(name: str) -> bool {
    for import_decl in self.imports {
        for spec in import_decl.specifiers {
            if isinstance(spec, es.ImportSpecifier) {
                if spec.local and spec.local.name == name {
                    return True;
                }
            }
        }
    }
    return False;
}

impl EsastGenPass._register_jac_virtual_import(module_id: str) -> None {
    import from jaclang.compiler.driver.modresolver { resolve_jac_virtual_module_path }
    if not self.client_manifest or module_id in self.client_manifest.imports {
        return;
    }
    source_path = resolve_jac_virtual_module_path(module_id);
    if source_path {
        self.client_manifest.imports[module_id] = source_path;
    }
}

impl EsastGenPass._register_jac_runtime_import -> None {
    self._ensure_backend();
    self._register_jac_virtual_import(self.backend.runtime_module());
}

impl EsastGenPass._inject_runtime_import(name: str, nd: uni.UniNode) -> None {
    import from jaclang.client.client_surface { runtime_import_source }
    self._ensure_backend();
    if name in self.injected_imports or self._has_import(name) {
        return;
    }
    src = runtime_import_source(name, self.backend);
    specifier = self.sync_loc(
        es.ImportSpecifier(
            imported=es.Identifier(name=name), local=es.Identifier(name=name)
        ),
        jac_node=nd
    );
    source = self.sync_loc(es.Literal(value=src, raw='"' + src + '"'), jac_node=nd);
    import_decl = self.sync_loc(
        es.ImportDeclaration(specifiers=[specifier], source=source), jac_node=nd
    );
    self.imports.append(import_decl);
    self.injected_imports.add(name);
    if src.startswith('@jac/') {
        self._register_jac_runtime_import();
    }
}

impl EsastGenPass.exit_import with uni.Import exit {
    if here.is_typed or here.is_comptime {
        here.gen.es_ast = None;
        return;
    }

    if self._is_service_bridge_import(here) {
        if (here.from_loc and here.items) {
            self._generate_sv_import_stubs(here);
            self._record_sv_backend(here);
        }
        return;
    }

    if self._is_client_native_import(here) {
        if (here.from_loc and here.items) {
            self._generate_na_import_binding(here);
        }
        here.gen.es_ast = None;
        return;
    }
    emit_items: list = list(here.items);
    if (here.from_loc and here.items) {
        resolved_path = here.from_loc.resolve_relative_path();
        partition = self._partition_client_import_items(here);
        if partition is not None {
            (emit_items, bridged_items) = partition;
            if bridged_items {
                self._generate_sv_import_stubs(here, bridged_items);
                self._record_sv_backend(here);
            }
            if not emit_items {
                here.gen.es_ast = None;
                return;
            }
        }
        import_key = here.from_loc.dot_path_str;
        self.client_manifest.imports[import_key] = resolved_path;
        self.client_manifest.has_client = True;

        import_path = here.from_loc.dot_path_str;
        is_jac_runtime = here.is_virtual_jac;
        if resolved_path.endswith('.jac')
            and not import_path.startswith('.')
            and not is_jac_runtime {
            js_import_path = relative_js_specifier(
                resolved_path, self.ir_in.loc.mod_path or here.loc.mod_path
            );
        } else {
            js_import_path = convert_to_js_import_path(import_path);
        }
    } elif (not here.from_loc and here.items) {
        self.client_manifest.has_client = True;
        first_item = here.items[0];
        if (isinstance(first_item, uni.ModulePath) and first_item.path) {
            path_elem = first_item.path[0];
            import_key = path_elem.lit_value
                if isinstance(path_elem, uni.String)
                else path_elem.value;
        } else {
            import_key = '';
        }
        resolved_path = resolve_relative_path(
            import_key,
            here.loc.mod_path,
            string_spec=isinstance(first_item, uni.ModulePath)
                and first_item.string_path_value is not None
        );
        self.client_manifest.imports[import_key] = resolved_path;
        import_path = import_key;
        if resolved_path.endswith('.jac') and not import_path.startswith('.') {
            js_import_path = relative_js_specifier(
                resolved_path, self.ir_in.loc.mod_path or here.loc.mod_path
            );
        } else {
            js_import_path = convert_to_js_import_path(import_path);
        }
    } else {
        return;
    }
    if resolved_path.endswith(".jac") {
        self.module_import_paths[js_import_path] = resolved_path;
    }
    source = self.sync_loc(es.Literal(value=js_import_path), jac_node=here.from_loc);
    specifiers:
        list[
            es.ImportSpecifier | es.ImportDefaultSpecifier | es.ImportNamespaceSpecifier
        ] = [];
    for item in emit_items {
        if isinstance(item, uni.ModuleItem) {
            if isinstance(item.name, uni.Name) {
                imported = self.sync_loc(
                    es.Identifier(name=item.name.sym_name), jac_node=item.name
                );
                local = self.sync_loc(
                    es.Identifier(
                        name=item.alias.sym_name if item.alias else item.name.sym_name
                    ),
                    jac_node=item.alias or item.name
                );
                specifiers.append(
                    self.sync_loc(
                        es.ImportSpecifier(imported=imported, local=local),
                        jac_node=item
                    )
                );
            } elif isinstance(item.name, uni.Token) {
                if (item.name.value == 'default') {
                    if not item.alias {
                        continue;
                    }
                    local = self.sync_loc(
                        es.Identifier(name=item.alias.sym_name), jac_node=item.alias
                    );
                    specifiers.append(
                        self.sync_loc(
                            es.ImportDefaultSpecifier(local=local), jac_node=item
                        )
                    );
                } elif (item.name.value == '*') {
                    if not item.alias {
                        continue;
                    }
                    local = self.sync_loc(
                        es.Identifier(name=item.alias.sym_name), jac_node=item.alias
                    );
                    specifiers.append(
                        self.sync_loc(
                            es.ImportNamespaceSpecifier(local=local), jac_node=item
                        )
                    );
                }
            }
        }
    }
    import_decl = self.sync_loc(
        es.ImportDeclaration(specifiers=specifiers, source=source), jac_node=here
    );
    self.imports.append(import_decl);
    here.gen.es_ast = None;
}

impl EsastGenPass._partition_client_import_items(
    nd: uni.Import
) -> (tuple[list, list] | None) {
    import from jaclang.compiler.symbol_utils {
        ClientImportVerdict,
        classify_client_import_item,
        decl_has_access,
        import_target_pinned_server,
        is_client_boundary_import,
        report_dead_client_import
    }
    if not is_client_boundary_import(nd) {
        return None;
    }
    import from jaclang.compiler.driver.boundary_classify { import_crosses_apps }
    pinned_server = import_target_pinned_server(nd);
    cross_app = import_crosses_apps(nd);
    source_mod = self._resolve_source_module(nd);
    if source_mod is None {
        return ([], list(nd.items)) if pinned_server else None;
    }
    kept: list = [];
    bridged: list = [];
    for item in nd.items {
        verdict = classify_client_import_item(source_mod, item);
        if pinned_server and verdict != ClientImportVerdict.DEAD {
            bridged.append(item);
            continue;
        }
        if pinned_server
            and verdict == ClientImportVerdict.DEAD
            and decl_has_access(source_mod, item) {
            bridged.append(item);
            continue;
        }
        if verdict == ClientImportVerdict.BRIDGED {
            bridged.append(item);
        } elif verdict == ClientImportVerdict.DEAD {
            if not cross_app {
                report_dead_client_import(self, nd, item);
            }
        } else {
            kept.append(item);
        }
    }
    return (kept, bridged);
}

impl EsastGenPass._generate_sv_import_stubs(
    nd: uni.Import, items: (Sequence[uni.ModuleItem] | None) = None
) -> None {
    manifest = self.ir_in.gen.interop_manifest;
    boundary_types = manifest.boundary_types;
    stubs: list[es.Statement] = [];
    for item in (items if items is not None else nd.items) {
        if not isinstance(item, uni.ModuleItem)
            or not isinstance(item.name, uni.Name) {
            continue;
        }

        if self._sv_import_item_is_type(nd, item) {
            continue;
        }
        func_name = item.name.sym_name;
        local_name = item.alias.sym_name if item.alias else func_name;

        binding = manifest.bindings.get(local_name);
        if binding is not None and binding.kind != 'function' {
            continue;
        }
        param_names: list[str] = [];
        param_type_map: dict[str, str] = {};
        ret_type_name: str = '';
        effect_key: str = '';
        if binding is not None {
            param_names = list(binding.param_names);
            for i in range(len(param_names)) {
                if i < len(binding.param_types) {
                    param_type_map[param_names[i]] = binding.param_types[i];
                }
            }
            ret_type_name = binding.ret_type;
            _src_mod = binding.ast_node.find_parent_of_type(uni.Module)
                if binding.ast_node is not None
                else None;
            if _src_mod is not None {
                import from jaclang.compiler.frontend.codeinfo { endpoint_key }
                effect_key = endpoint_key(_src_mod, "func", func_name);
                src_effect = _src_mod.gen.interop_manifest.endpoint_effects.get(
                    effect_key
                );
                if src_effect is not None {
                    self.client_manifest.endpoint_effects[effect_key] = src_effect;
                }
            }
        }

        js_params: list[es.Pattern] = [];
        for pname in param_names {
            js_params.append(self.sync_loc(es.Identifier(name=pname), jac_node=nd));
        }

        props: list[es.Property | es.SpreadElement] = [];
        for pname in param_names {
            key = self.sync_loc(es.Literal(value=pname), jac_node=nd);
            value: es.Expression = self._wrap_to_wire_if_boundary(
                self.sync_loc(es.Identifier(name=pname), jac_node=nd),
                param_type_map.get(pname, ''),
                boundary_types,
                nd
            );
            props.append(
                self.sync_loc(
                    es.Property(
                        key=key,
                        value=value,
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    ),
                    jac_node=nd
                )
            );
        }
        args_obj = self.sync_loc(es.ObjectExpression(properties=props), jac_node=nd);

        call_args: list[es.Expression] = [
            self.sync_loc(es.Literal(value=func_name), jac_node=nd),
            args_obj
        ];
        provider_opts = self._sv_provider_options(nd);
        if provider_opts is None {
            provider_opts = es.ObjectExpression(properties=[]);
        }
        if effect_key and isinstance(provider_opts, es.ObjectExpression) {
            provider_opts.properties.append(
                es.Property(
                    key=es.Literal(value="contract"),
                    value=es.Literal(value=effect_key),
                    kind="init",
                    method=False,
                    shorthand=False,
                    computed=False
                )
            );
        }
        call_args.append(provider_opts);
        call_expr = self.sync_loc(
            es.CallExpression(
                callee=self.sync_loc(
                    es.Identifier(name='__jacCallFunction'), jac_node=nd
                ),
                arguments=call_args
            ),
            jac_node=nd
        );
        await_expr: es.Expression = self.sync_loc(
            es.AwaitExpression(argument=call_expr), jac_node=nd
        );
        await_expr = self._wrap_return_with_boundary(
            await_expr, ret_type_name, boundary_types, nd, pre_awaited=True
        );
        return_stmt = self.sync_loc(
            es.ReturnStatement(argument=await_expr), jac_node=nd
        );
        body = self.sync_loc(es.BlockStatement(body=[return_stmt]), jac_node=nd);
        func_id = self.sync_loc(es.Identifier(name=local_name), jac_node=nd);
        func_decl = self.sync_loc(
            es.FunctionDeclaration(
                id=func_id, params=js_params, body=body, generator=False, async_=True
            ),
            jac_node=nd
        );
        stubs.append(func_decl);
    }
    if stubs {
        self._inject_runtime_import('__jacCallFunction', nd);

        self.sv_import_stubs.extend(stubs);
    }
}

impl EsastGenPass._is_client_native_import(nd: uni.Import) -> bool {
    import from jaclang.compiler.driver.boundary_classify { import_binds_client_native }
    return import_binds_client_native(nd, self.ir_in.gen.interop_manifest);
}

impl EsastGenPass._generate_na_import_binding(nd: uni.Import) -> None {
    import from jaclang.compiler.frontend.codeinfo { native_wasm_stem }
    import json;
    contracts: dict = {};
    host_imports: dict = {};
    resolved_path = nd.from_loc.resolve_relative_path();
    stem = native_wasm_stem(resolved_path);

    if self.client_manifest {
        self.client_manifest.has_client = True;
    }

    bind_local = '__jac_na_bind';
    if bind_local not in self.injected_imports {
        host_module = '@jac/wasm_host';
        specifier = self.sync_loc(
            es.ImportSpecifier(
                imported=es.Identifier(name='__na_bind'),
                local=es.Identifier(name=bind_local)
            ),
            jac_node=nd
        );
        source = self.sync_loc(
            es.Literal(value=host_module, raw=f'"{host_module}"'), jac_node=nd
        );
        self.imports.append(
            self.sync_loc(
                es.ImportDeclaration(specifiers=[specifier], source=source), jac_node=nd
            )
        );
        self.injected_imports.add(bind_local);
        self._register_jac_virtual_import(host_module);
    }

    props: list[(es.AssignmentProperty | es.RestElement)] = [];
    for item in nd.items {
        if not isinstance(item, uni.ModuleItem)
            or not isinstance(item.name, uni.Name) {
            continue;
        }
        if self._sv_import_item_is_type(nd, item) {
            continue;
        }
        export_name = item.name.sym_name;
        local_name = item.alias.sym_name if item.alias else export_name;
        binding = self.ir_in.gen.interop_manifest.bindings.get(local_name);
        if binding is None or not binding.native_contract {
            raise ValueError(f"Missing native contract for '{export_name}'");
        }
        contracts[export_name] = binding.native_contract;
        host_imports = self.ir_in.gen.interop_manifest.native_host_imports[stem];
        props.append(
            self.sync_loc(
                es.AssignmentProperty(
                    key=es.Identifier(name=export_name),
                    value=es.Identifier(name=local_name),
                    shorthand=(export_name == local_name)
                ),
                jac_node=item
            )
        );
    }
    if not props {
        return;
    }

    bind_call = self.sync_loc(
        es.CallExpression(
            callee=es.Identifier(name=bind_local),
            arguments=[
                self.sync_loc(es.Literal(value=stem, raw=f'"{stem}"'), jac_node=nd),
                self.sync_loc(
                    es.Literal(
                        value=json.dumps(
                            {"exports": contracts, "imports": host_imports}
                        )
                    ),
                    jac_node=nd
                ),

            ]
        ),
        jac_node=nd
    );
    self.na_import_stubs.append(
        self.sync_loc(
            es.VariableDeclaration(
                kind='const',
                declarations=[
                    self.sync_loc(
                        es.VariableDeclarator(
                            id=self.sync_loc(
                                es.ObjectPattern(properties=props), jac_node=nd
                            ),
                            init=bind_call
                        ),
                        jac_node=nd
                    )
                ]
            ),
            jac_node=nd
        )
    );
}

impl EsastGenPass._sv_import_item_is_type(
    nd: uni.Import, item: uni.ModuleItem
) -> bool {
    sym = item.name.sym;
    if sym and sym.binding_kind.denotes_type() {
        return True;
    }
    return item.name.sym_name in self.ir_in.gen.interop_manifest.boundary_types;
}

impl EsastGenPass.exit_sub_tag with uni.SubTag exit {
    if here.tag.gen.es_ast {
        here.gen.es_ast = here.tag.gen.es_ast;
    }
}

impl EsastGenPass._import_item_named(name: str) -> (uni.ModuleItem | None) {
    for imp in self.ir_in.get_all_sub_nodes(uni.Import) {
        if imp.from_loc is None {
            continue;
        }
        for item in imp.items {
            if not isinstance(item, uni.ModuleItem) {
                continue;
            }
            local = item.alias.value if item.alias is not None else item.name.value;
            if local == name {
                return item;
            }
        }
    }
    return None;
}

impl EsastGenPass._finalize_runtime_imports(program: es.Program) -> None {
    if not self.module_import_paths {
        return;
    }
    manifest = self.client_manifest;
    assert manifest is not None;
    value_body = es.Program(
        body=[
            stmt
            for stmt in program.body
            if not isinstance(stmt, es.ImportDeclaration)
        ]
    );

    import re;
    referenced: set[str] = set();
    pending: list[any] = [value_body];
    while pending {
        value = pending.pop();
        if isinstance(value, (es.Identifier, es.JsxIdentifier)) {
            referenced.update(re.findall(r"[A-Za-z_$][A-Za-z0-9_$]*", value.name));
        } elif isinstance(value, es.RawCode) {
            referenced.update(re.findall(r"[A-Za-z_$][A-Za-z0-9_$]*", value.code));
        } elif isinstance(value, es.Node) {
            pending.extend(
                child
                for (key, child) in vars(value).items()
                if key not in ("loc", "type")
            );
        } elif isinstance(value, (list, tuple)) {
            pending.extend(value);
        }
    }
    for stmt in program.body {
        if not isinstance(stmt, es.ImportDeclaration) {
            continue;
        }
        source = stmt.source;
        assert source is not None;
        source_path = self.module_import_paths.get(str(source.value));
        if source_path is None {
            continue;
        }
        stmt.specifiers = [
            spec
            for spec in stmt.specifiers
            if spec.local is not None and spec.local.name in referenced
        ];
        names: list[str] = [];
        for spec in stmt.specifiers {
            if isinstance(spec, es.ImportSpecifier) {
                imported = spec.imported;
                assert imported is not None;
                names.append(imported.name);
            } elif isinstance(spec, es.ImportDefaultSpecifier) {
                names.append("default");
            }
        }
        manifest.runtime_imports.setdefault(source_path, []).extend(names);
    }
}
