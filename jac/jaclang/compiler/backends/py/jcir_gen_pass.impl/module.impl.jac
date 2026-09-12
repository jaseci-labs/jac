impl JcirGenPass.ir_bytes -> bytes {
    if self._module_root is None {
        raise RuntimeError(self.ice('JCIR emitter produced no module root'));
    }
    return module_container_bytes(self._module_path, self._module_root);
}

impl JcirGenPass.exit_sub_tag with SubTag exit {
    tag_node = here.tag;
    if isinstance(tag_node, UniNode) {
        self.set_out(here, self.outs(tag_node));
    }
}

impl JcirGenPass.exit_module with Module exit {
    import from jaclang.runtime.osp_tag { stable_osp_tag }
    _tag_names: dict[int, str] = {};
    for _stmt in (here.body or []) {
        if isinstance(_stmt, Archetype)
            and (_stmt.name is not None)
            and (_stmt.arch_kind is not None) {
            _an = _stmt.name.value;
            _t = stable_osp_tag(_an);
            _prior = _tag_names.get(_t);
            if (_prior is not None) and (_prior != _an) {
                self.emit(E5102, node_override=_stmt, name=_an, other=_prior);
            } else {
                _tag_names[_t] = _an;
            }
        }
    }
    mod_path = here.loc.mod_path;
    is_builtin_module = (
        (mod_path.endswith('builtin.jac') or mod_path.endswith('builtin.py'))
        and ('runtime' in mod_path)
    );
    if (self.builtin_imports and not is_builtin_module) {
        self.preamble.append(
            self.nod(
                'ImportFrom',
                ['module', 'names', 'level'],
                [
                    'jaclang.runtime.builtin',
                    [
                        self.nod(
                            'alias',
                            ['name', 'asname'],
                            [name, None],
                            jac_node=self.ir_out
                        ) for name in sorted(list(self.builtin_imports))
                    ],
                    0
                ],
                jac_node=self.ir_out
            )
        );
    }
    is_sized_module = mod_path.endswith('sized.jac') or mod_path.endswith('sized.py');
    if (self.sized_imports and not is_sized_module) {
        self.preamble.append(
            self.nod(
                'ImportFrom',
                ['module', 'names', 'level'],
                [
                    'jaclang.runtime.sized',
                    [
                        self.nod(
                            'alias',
                            ['name', 'asname'],
                            [name, None],
                            jac_node=self.ir_out
                        ) for name in sorted(list(self.sized_imports))
                    ],
                    0
                ],
                jac_node=self.ir_out
            )
        );
    }
    if self.typing_imports {
        self.preamble.append(
            self.nod(
                'ImportFrom',
                ['module', 'names', 'level'],
                [
                    'typing',
                    [
                        self.nod(
                            'alias',
                            ['name', 'asname'],
                            [name, None],
                            jac_node=self.ir_out
                        ) for name in sorted(list(self.typing_imports))
                    ],
                    0
                ],
                jac_node=self.ir_out
            )
        );
    }
    mod_path_norm = here.loc.mod_path.replace('\\', '/');
    is_jaclib_module = (
        mod_path_norm.endswith('/jaclang/lib.jac')
        or mod_path_norm.endswith('/jaclang/lib.py')
    );
    if ((self.jaclib_imports or self._runtime_aliases) and not is_jaclib_module) {
        self.preamble.append(
            self.nod(
                'ImportFrom',
                ['module', 'names', 'level'],
                [
                    'jaclang.lib.jaclib',
                    [
                        self.nod(
                            'alias',
                            ['name', 'asname'],
                            [name, None],
                            jac_node=self.ir_out
                        ) for name in sorted(list(self.jaclib_imports))
                    ]
                        + [
                            self.nod(
                                'alias',
                                ['name', 'asname'],
                                [name, self._runtime_aliases[name]],
                                jac_node=self.ir_out
                            ) for name in sorted(self._runtime_aliases)
                        ],
                    0
                ],
                jac_node=self.ir_out
            )
        );
    }
    merged_body = self._merge_module_bodies(here);
    body_items: list[CgItem] = [];
    if here.doc {
        body_items.append(
            self.nod('Expr', ['value'], [self.val(here.doc)], jac_node=here.doc)
        );
    }
    body_items.extend(self.preamble);
    body_items.extend(self._drain_module_hoists());
    stub_node = self._interop_stub_node;
    if stub_node is not None {
        self._gen_native_interop_stubs(stub_node);
    }
    reg_map = self._native_import_registration_map();
    emitted: set[str] = set();
    for item in merged_body {
        body_items.extend(self.outs(item));
        if not reg_map {
            continue;
        }
        for bound in self._top_level_bound_names(self.outs(item)) {
            if (bound in reg_map and bound not in emitted) {
                body_items.extend(reg_map[bound]);
                emitted.add(bound);
            }
        }
    }
    for (reg_name, stmts) in reg_map.items() {
        if reg_name not in emitted {
            body_items.extend(stmts);
        }
    }
    new_body = self._flatten_ast_list(body_items);
    module = self.nod('Module', ['body', 'type_ignores'], [new_body, []]);
    self.set_out(here, [module]);
    self._module_root = module;
    self._module_path = here.loc.mod_path;
    here.gen.jcir = module_container_bytes(self._module_path, module);
}

impl JcirGenPass.exit_type_param with TypeParam exit {
    if here.is_comptime {
        self.set_out(here, []);
        return;
    }
    bound_ast = self.val(here.bound) if here.bound else None;
    self.set_out(
        here, [self.nod('TypeVar', ['name', 'bound'], [here.name.value, bound_ast])]
    );
}

impl JcirGenPass.exit_type_alias with TypeAlias exit {
    type_param_asts: list[CgNode] = [];
    for tp in here.type_params {
        if self.outs(tp) {
            type_param_asts.append(self.val(tp));
        }
    }
    value_ast = self.val(here.value);
    if here.is_distinct {
        assign = self.nod(
            'Assign',
            ['targets', 'value'],
            [
                [
                    self.nod(
                        'Name',
                        ['id', 'ctx'],
                        [here.name.sym_name, self.nod('Store', [], [])]
                    )
                ],
                value_ast
            ]
        );
        self.set_out(here, [assign]);
        return;
    }
    type_alias = self.nod(
        'TypeAlias',
        ['name', 'type_params', 'value'],
        [
            self.nod(
                'Name', ['id', 'ctx'], [here.name.sym_name, self.nod('Store', [], [])]
            ),
            type_param_asts,
            value_ast
        ]
    );
    self.set_out(here, [type_alias]);
}

impl JcirGenPass.exit_global_vars with GlobalVars exit {
    assigns_ast = self._flatten_ast_list([self.outs(a) for a in here.assignments]);
    if here.doc {
        doc = self.nod('Expr', ['value'], [self.val(here.doc)], jac_node=here.doc);
        self.set_out(here, [doc] + assigns_ast);
    } else {
        self.set_out(here, assigns_ast);
    }
}

impl JcirGenPass.enter_test with Test entry {
    self._push_hoist_frame();
}

impl JcirGenPass.exit_test with Test exit {
    test_name = here.name.sym_name;
    if here.code_context == CodeContext.NATIVE {
        body_stmts = self._native_test_shim_stmts(here);
    } else {
        body_stmts = self.resolve_stmt_block(here.body, doc=here.doc);
    }
    test_directives = self.scope_directive_stmts([here]);
    if test_directives {
        insert_at = self._docstring_offset(body_stmts);
        body_stmts = [
            *body_stmts[:insert_at],
            *test_directives,
            *body_stmts[insert_at:]
        ];
    }
    scope_frame = self._hoist_frames.pop() if self._hoist_frames else [];
    if not self._hoist_frames {
        self._hoist_frames = [[]];
    }
    test_sig_roots: list[UniNode] = [];
    if here.decorators {
        for d in here.decorators {
            if d {
                test_sig_roots.append(d);
            }
        }
    }
    (test_body_hoists, test_enclosing_hoists) = self._split_scope_hoists(
        scope_frame, test_sig_roots
    );
    if test_enclosing_hoists {
        self._hoist_frames[-1].extend(test_enclosing_hoists);
    }
    if test_body_hoists {
        body_stmts = [*test_body_hoists, *body_stmts];
    }
    func = self.nod(
        'FunctionDef',
        [
            'name',
            'args',
            'body',
            'decorator_list',
            'returns',
            'type_comment',
            'type_params'
        ],
        [
            test_name,
            self.nod(
                'arguments',
                [
                    'posonlyargs',
                    'args',
                    'kwonlyargs',
                    'vararg',
                    'kwarg',
                    'kw_defaults',
                    'defaults'
                ],
                [[], [], [], None, None, [], []]
            ),
            body_stmts,
            [self.val(i) for i in here.decorators] if here.decorators else [],
            self.const_of(None),
            None,
            []
        ]
    );
    jac_test_keywords: list[CgNode] = [];
    if here.description {
        jac_test_keywords.append(
            self.nod(
                'keyword',
                ['arg', 'value'],
                ['description', self.const_of(here.description.lit_value)]
            )
        );
    }
    func.get('decorator_list').append(
        self.call_node(self.jaclib_obj('jac_test'), [], jac_test_keywords)
    );
    if jcir_is_test_path(here.loc.mod_path) {
        func.get('decorator_list').append(
            self.call_node(
                self.jaclib_obj('impl_patch_filename'),
                [],
                [
                    self.nod(
                        'keyword',
                        ['arg', 'value'],
                        ['file_loc', self.const_of(here.loc.mod_path)]
                    )
                ]
            )
        );
    }
    self.set_out(here, [func]);
}

impl JcirGenPass.exit_module_code with ModuleCode exit {
    stmts = self.resolve_stmt_block(here.body, doc=here.doc);
    if here.name {
        stmts = [
            self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [
                    self.nod(
                        'Compare',
                        ['left', 'ops', 'comparators'],
                        [
                            self.name_load('__name__'),
                            [self.nod('Eq', [], [])],
                            [self.const_of(here.name.sym_name)]
                        ]
                    ),
                    stmts,
                    []
                ]
            )
        ];
    }
    self.set_out(here, stmts);
}

impl JcirGenPass.exit_py_inline_code with PyInlineCode exit {
    if here.doc {
        doc = self.nod('Expr', ['value'], [self.val(here.doc)], jac_node=here.doc);
        shift = here.loc.first_line;
        inner = doc.get('value');
        doc.l1 = doc.l1 + shift;
        doc.l2 = doc.l2 + shift;
        if isinstance(inner, CgNode) {
            inner.l1 = inner.l1 + shift;
            inner.l2 = inner.l2 + shift;
        }
        self.set_out(here, [doc, CgSplice(src=here.code.value, offset=shift)]);
    } else {
        self.set_out(
            here,
            [CgSplice(src=textwrap.dedent(here.code.value), offset=here.loc.first_line)]
        );
    }
}

impl JcirGenPass.exit_import with Import exit {
    import from jaclang.compiler.driver.boundary_classify {
        CrossAppKind,
        classify_cross_app_import,
        import_binds_client_native
    }
    if (
        import_binds_client_native(here, self.ir_in.gen.interop_manifest)
        or here.native_only_drop
    ) {
        self.set_out(here, []);
        return;
    }
    if (here.from_loc and here.from_loc.path) {
        module_parts = [
            p.value
            for p in here.from_loc.path
            if p?.value
        ];
        if (module_parts == ['__future__']) {
            self.set_out(here, []);
            return;
        }
    }
    if (
        here.from_loc
        and here.items
        and classify_cross_app_import(here, self.ir_in.gen.interop_manifest)
            == CrossAppKind.SERVICE_BRIDGE
        and self._generate_sv_to_sv_stubs(here)
    ) {
        return;
    }
    py_nodes: list[CgItem] = [];
    if here.doc {
        py_nodes.append(
            self.nod('Expr', ['value'], [self.val(here.doc)], jac_node=here.doc)
        );
    }
    if here.is_absorb {
        source = here.items[0];
        if not isinstance(source, ModulePath) {
            raise RuntimeError(self.ice());
        }
        module_name_parts = [p.value for p in source.path] if source.path else [];
        module_name = '.'.join(module_name_parts) if module_name_parts else None;
        py_nodes.append(
            self.nod(
                'ImportFrom',
                ['module', 'names', 'level'],
                [
                    module_name,
                    [self.nod('alias', ['name'], ['*'], jac_node=here)],
                    source.level
                ],
                jac_node=here
            )
        );
    } elif not here.from_loc {
        mod_paths = [
            k
            for k in here.kid
            if isinstance(k, ModulePath)
        ];
        names_list = [x for p in mod_paths for x in self.outs(p)]
            if mod_paths
            else [x for item in here.items for x in self.outs(item)];
        py_nodes.append(self.nod('Import', ['names'], [names_list]));
    } else {
        module_name_parts = [p.value for p in here.from_loc.path]
            if here.from_loc.path
            else [];
        module_name = '.'.join(module_name_parts) if module_name_parts else None;
        py_nodes.append(
            self.nod(
                'ImportFrom',
                ['module', 'names', 'level'],
                [
                    module_name,
                    [i for item in here.items for i in self.outs(item)],
                    here.from_loc.level
                ]
            )
        );
    }
    if here.is_typed {
        self.typing_imports.add('TYPE_CHECKING');
        body_stmts = [
            stmt
            for stmt in py_nodes
            if isinstance(stmt, CgNode) and stmt.cls in ('Import', 'ImportFrom', 'Expr')
        ];
        if body_stmts {
            wrapped = self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [self.name_load('TYPE_CHECKING'), body_stmts, []]
            );
            py_nodes = [];
            py_nodes.append(wrapped);
        }
    }
    self.set_out(here, py_nodes);
}

impl JcirGenPass.exit_module_path with ModulePath exit {
    if here.string_path_value is not None {
        import_node = here.parent_of_type(Import);
        if (import_node and (import_node.code_context != CodeContext.CLIENT)) {
            self.emit(E5001, node_override=here, path=str(here.string_path_value));
        }
    }
    self.set_out(
        here,
        [
            self.nod(
                'alias',
                ['name', 'asname'],
                [str(here.dot_path_str), here.alias.sym_name if here.alias else None]
            )
        ]
    );
}

impl JcirGenPass.exit_module_item with ModuleItem exit {
    if (isinstance(here.name, Token) and (here.name.value in ['default', '*'])) {
        import_node = here.from_parent;
        if (import_node.code_context != CodeContext.CLIENT) {
            import_type = 'Default' if (here.name.value == 'default') else 'Namespace';
            self.emit(
                E5002,
                node_override=here,
                import_type=import_type,
                name=str(here.name.value)
            );
            self.set_out(here, []);
            return;
        }
    }
    self.set_out(
        here,
        [
            self.nod(
                'alias',
                ['name', 'asname'],
                [
                    (
                        here.name.sym_name
                            if isinstance(here.name, Name)
                            else here.name.value
                    ),
                    here.alias.sym_name if here.alias else None
                ]
            )
        ]
    );
}
