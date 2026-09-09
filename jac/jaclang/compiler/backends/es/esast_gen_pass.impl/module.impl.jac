impl EsastGenPass.exit_test with uni.Test exit {
    params: list[es.Pattern] = [];
    body_stmts = self._collect_body_stmts(here.body);
    body_stmts = self._prepend_hoisted(here, body_stmts);
    block = self.sync_loc(es.BlockStatement(body=body_stmts), jac_node=here);
    func_id = self.sync_loc(es.Identifier(name=here.name.sym_name), jac_node=here.name);

    func_decl = self.sync_loc(
        es.FunctionDeclaration(id=func_id, params=params, body=block, async_=True),
        jac_node=here
    );
    here.gen.es_ast = func_decl;

    self.client_manifest.has_client = True;
    self.client_manifest.tests.append(
        {
            'name': here.name.sym_name,
            'description': here.description.lit_value
                if here.description
                else here.name.sym_name
        }
    );
}

impl EsastGenPass.exit_module_code with uni.ModuleCode exit {
    here.gen.es_ast = self._collect_body_stmts(here.body);
}

impl EsastGenPass.exit_global_vars with uni.GlobalVars exit {
    if here.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = here.access and (here.access.tag.name == Tok.KW_PUB);
        if is_pub or here.codespace_dual {
            for assignment in here.assignments {
                for target in assignment.target {
                    if (sym_name := target?.sym_name) {
                        self.client_manifest.globals.append(sym_name);
                        if (
                            assignment.value
                            and (
                                (lit_val := self._literal_value(assignment.value))
                                is not None
                            )
                        ) {
                            self.client_manifest.globals_values[sym_name] = lit_val;
                        }
                    }
                }
            }
        }
    }
    statements: list[(es.Statement | es.ModuleDeclaration)] = [];
    for assignment in here.assignments {
        if assignment.gen.es_ast {
            stmt = assignment.gen.es_ast;
            if (
                isinstance(stmt, es.VariableDeclaration)
                and here.is_frozen
                and (stmt.kind != 'const')
            ) {
                stmt.kind = 'const';
            }
            statements.append(cast(es.Statement, stmt));
        }
    }
    here.gen.es_ast = statements;
}

impl EsastGenPass.populate_client_manifest(nd: uni.Module) -> None {
    for (ename, eeffect) in nd.gen.interop_manifest.endpoint_effects.items() {
        self.client_manifest.endpoint_effects[ename] = eeffect;
    }
}

impl EsastGenPass._es_json_literal(value: any) -> any {
    if isinstance(value, list) {
        return es.ArrayExpression(elements=[self._es_json_literal(v) for v in value]);
    }
    if isinstance(value, dict) {
        return es.ObjectExpression(
            properties=[
                es.Property(
                    key=es.Literal(value=k), value=self._es_json_literal(v), kind='init'
                ) for (k, v) in value.items()
            ]
        );
    }
    return es.Literal(value=value);
}

impl EsastGenPass.exit_module with uni.Module exit {
    import from jaclang.compiler.symbol_utils { report_client_bare_import_uses }
    report_client_bare_import_uses(self, here);
    server_forwarders = self._bind_client_value_refs(here);
    if (self.scoped_styles is not None and self.scoped_styles.class_map) {
        import os;
        here.gen.css = self.scoped_styles.scoped_css;
        base = os.path.basename(self.scoped_styles.css_path);
        if base.endswith('.style.css') {
            base = base[:-len('.style.css')];
        }
        css_import = f"./{base}.css";
        css_source = self.sync_loc(
            es.Literal(value=css_import, raw=f'"{css_import}"'), jac_node=here
        );
        self.imports.insert(
            0,
            self.sync_loc(
                es.ImportDeclaration(specifiers=[], source=css_source), jac_node=here
            )
        );
    }
    body: list[(es.Statement | es.ModuleDeclaration)] = [];
    body.extend(self.imports);

    body.extend(self.sv_import_stubs);
    body.extend(self.na_import_stubs);

    body.extend(self._emit_boundary_type_stubs(here));
    body.extend(server_forwarders);
    scope = self.scope_map.get(here);
    if (scope and scope.hoisted) {
        hoisted = list(scope.hoisted);
        scope.hoisted.clear();
        body.extend(hoisted);
    }

    if self.needs_osp_graph or self.needs_osp_kernel {
        self.needs_jac_runtime = True;
    }
    if self.needs_jac_runtime {
        import from jaclang.compiler.backends.es.jac_runtime_js { build_jac_runtime_js }
        jac_rt_decl = es.VariableDeclaration(
            declarations=[
                es.VariableDeclarator(
                    id=es.Identifier(name='_jac'),
                    init=es.RawCode(code=build_jac_runtime_js())
                )
            ],
            kind='const'
        );
        body.append(jac_rt_decl);
    }
    merged_body = self._merge_module_bodies(here);
    client_items: list[es.Statement | list[es.Statement] | None] = [];
    fallback_items: list[es.Statement | list[es.Statement] | None] = [];
    for stmt in merged_body {
        if stmt.gen.es_ast {
            is_shared_arch = (
                isinstance(stmt, uni.Archetype)
                and (stmt.name is not None)
                and (stmt.name.value in self.shared_arch_names)
            );
            if (getattr(stmt, 'code_context', CodeContext.CLIENT) == CodeContext.CLIENT)
                or is_shared_arch {
                client_items.append(cast(es.Statement, stmt.gen.es_ast));
            } else {}
        }
    }
    target_body = client_items or fallback_items;
    body.extend(self._flatten_ast_list(target_body));

    if self.needs_osp_graph or self.needs_osp_kernel {
        import from jaclang.compiler.backends.es.jac_runtime_js {
            build_osp_core_js,
            build_osp_driver_js
        }
        body.append(
            self.sync_loc(
                es.ExpressionStatement(expression=es.RawCode(code=build_osp_core_js())),
                jac_node=here
            )
        );
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.RawCode(code=build_osp_driver_js())
                ),
                jac_node=here
            )
        );
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.RawCode(code=self._build_osp_tags_js())
                ),
                jac_node=here
            )
        );
    }
    if self.needs_osp_kernel {
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.RawCode(code=self._build_osp_setup_js())
                ),
                jac_node=here
            )
        );
    }
    body.extend(self.exports);
    self.populate_client_manifest(here);
    self.client_manifest.exports.sort();
    self.client_manifest.globals.sort();
    module_export_names = sorted(
        set(self.client_manifest.exports + self.client_manifest.globals)
    );
    if module_export_names {
        export_specifiers: list[es.ExportSpecifier] = [];
        for name in module_export_names {
            export_specifiers.append(
                es.ExportSpecifier(
                    exported=es.Identifier(name=name), local=es.Identifier(name=name)
                )
            );
        }

        if (
            not self.client_manifest.globals
            and all(name in self.component_export_names for name in module_export_names)
        ) {
            body.append(
                self.sync_loc(
                    es.ExpressionStatement(
                        expression=es.Identifier(name='/*jac:refresh-boundary*/')
                    ),
                    jac_node=here
                )
            );
        }
        comprehensive_export = es.ExportNamedDeclaration(
            declaration=None, specifiers=export_specifiers, source=None
        );
        body.append(comprehensive_export);
    }

    if self.client_manifest.endpoint_effects {
        import json as _json;
        effects_json = _json.dumps(self.client_manifest.endpoint_effects);
        register_code = (
            'if (typeof globalThis !== "undefined") {'
            ' if (!globalThis.__jacEndpointEffects__) globalThis.__jacEndpointEffects__ = {};'
            f' Object.assign(globalThis.__jacEndpointEffects__, {effects_json});'
            ' }'
        );
        body.append(
            es.ExpressionStatement(expression=es.Identifier(name=register_code))
        );
    }
    program = self.sync_loc(es.Program(body=body), jac_node=here);
    self._finalize_runtime_imports(program);
    here.gen.es_ast = program;
    here.gen.js = es_to_js(here.gen.es_ast);
    here.gen.client_manifest = self.client_manifest;
    self._audit_free_identifiers(here, program);
}

impl EsastGenPass.get_main_mod -> uni.Module {
    main_mod_path = self.ir_in.annexable_by or self.ir_in.loc.mod_path;
    mod = self.prog.mod.hub.get(main_mod_path);
    if not isinstance(mod, uni.Module) {
        self.emit(E5012);
    }
    return mod;
}
