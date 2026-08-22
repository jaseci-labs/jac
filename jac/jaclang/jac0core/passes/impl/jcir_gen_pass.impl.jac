impl JcirGenPass._get_builtin_names -> set[str] {
    return set(JCIR_BUILTIN_NAMES);
}

impl JcirGenPass._get_ambient_typing_names -> set[str] {
    return set(JCIR_AMBIENT_TYPING_NAMES);
}

impl JcirGenPass.postinit -> None {
    _jaclib: set[str] = set();
    _builtins: set[str] = set();
    _typing: set[str] = set();
    self.jaclib_imports = _jaclib;
    self.builtin_imports = _builtins;
    self.typing_imports = _typing;
    self._hoist_frames = [[]];
    self._sink = {};
    self.preamble = [
        self.nod(
            'ImportFrom',
            ['module', 'names', 'level'],
            [
                '__future__',
                [
                    self.nod(
                        'alias',
                        ['name', 'asname'],
                        ['annotations', None],
                        jac_node=self.ir_in
                    )
                ],
                0
            ],
            jac_node=self.ir_in
        )
    ];
    super.postinit();
}

impl JcirGenPass._is_native_ext_module -> bool {
    return self.ir_in is not None and self.ir_in.decided_codespace == 'native';
}

impl JcirGenPass._refuse(nd: (UniNode | None), construct: str) -> None {
    target = nd if nd is not None else self.cur_node;
    where = '';
    if (target is not None and target.loc is not None) {
        where = (
            f" at {target.loc.mod_path}:"
            f"{target.loc.first_line}:{target.loc.col_start}"
        );
    }
    raise NotImplementedError(
        f"JCIR emitter phase 1 does not lower {construct}{where}; "
        "this construct is outside the phase 1 scope"
    );
}

impl JcirGenPass.enter_node(nd: UniNode) -> None {
    if (isinstance(nd, Module) and (nd is not self.ir_in)) {
        self.prune();
        return;
    }
    if (
        isinstance(nd, ContextAwareNode)
        and (nd.code_context == CodeContext.NATIVE)
        and ((nd.parent is None) or isinstance(nd.parent, Module))
        and not isinstance(nd, (Import, Test))
        and not self._is_native_ext_module()
    ) {
        first_native = True;
        for sib in self.ir_in.body {
            if sib is nd {
                break;
            }
            if (
                isinstance(sib, ContextAwareNode)
                and sib.code_context == CodeContext.NATIVE
                and not isinstance(sib, Import)
            ) {
                first_native = False;
                break;
            }
        }
        if first_native {
            self._interop_stub_node = nd;
        }
        self.prune();
        return;
    }
    if (
        isinstance(nd, ContextAwareNode)
        and (nd.code_context == CodeContext.CLIENT)
        and not nd.codespace_dual
        and ((nd.parent is None) or isinstance(nd.parent, Module))
    ) {
        self.prune();
        return;
    }
    if (
        isinstance(nd, Import)
        and nd.code_context == CodeContext.NATIVE
        and (not nd.items)
    ) {
        self.prune();
        return;
    }
    super.enter_node(nd);
}

impl JcirGenPass.exit_node(nd: UniNode) -> None {
    if (isinstance(nd, Module) and (nd is not self.ir_in)) {
        return;
    }
    if (
        isinstance(nd, ContextAwareNode)
        and (nd.code_context == CodeContext.CLIENT)
        and not nd.codespace_dual
        and ((nd.parent is None) or isinstance(nd.parent, Module))
    ) {
        return;
    }
    if (
        isinstance(nd, ContextAwareNode)
        and (nd.code_context == CodeContext.NATIVE)
        and ((nd.parent is None) or isinstance(nd.parent, Module))
        and not isinstance(nd, (Import, Test))
        and not self._is_native_ext_module()
    ) {
        return;
    }
    if (
        isinstance(nd, Import)
        and nd.code_context == CodeContext.NATIVE
        and (not nd.items)
    ) {
        return;
    }
    super.exit_node(nd);
}

impl JcirGenPass.nod(
    cls_name: str, keys: list[str], vals: list, jac_node: (UniNode | None) = None
) -> CgNode {
    src = jac_node if jac_node is not None else self.cur_node;
    loc = src.loc;
    l2 = loc.last_line
        if (loc.last_line and (loc.last_line > loc.first_line))
        else loc.first_line;
    c2 = loc.col_end
        if (loc.col_end and (loc.col_end > loc.col_start))
        else loc.col_start;
    return CgNode(
        cls=cls_name,
        keys=keys,
        vals=vals,
        l1=loc.first_line,
        c1=loc.col_start,
        l2=l2,
        c2=c2,
        jac_src=src
    );
}

impl JcirGenPass.nod_loc(
    cls_name: str, keys: list[str], vals: list, l1: int, c1: int, l2: int, c2: int
) -> CgNode {
    return CgNode(cls=cls_name, keys=keys, vals=vals, l1=l1, c1=c1, l2=l2, c2=c2);
}

impl JcirGenPass._flatten_ast_list(
    items: list[CgItem | list[CgItem] | None]
) -> list[CgItem] {
    flattened: list[CgItem] = [];
    for item in items {
        if isinstance(item, `list) {
            flattened.extend(item);
        } elif (item is not None) {
            flattened.append(item);
        }
    }
    return flattened;
}

impl JcirGenPass.outs(nd: UniNode) -> list[CgItem] {
    if nd in self._sink {
        return self._sink[nd];
    }
    return [];
}

impl JcirGenPass.set_out(nd: UniNode, items: list[CgItem]) -> None {
    self._sink[nd] = items;
}

impl JcirGenPass.val(nd: UniNode) -> CgNode {
    got: list[CgItem] = self._sink[nd] if nd in self._sink else [];
    if not got {
        loc = nd.loc;
        raise RuntimeError(
            self.ice(
                f"Empty JCIR recipe on {type(nd).__name__} "
                f"at {loc.mod_path}:{loc.first_line}:{loc.col_start}"
            )
        );
    }
    first = got[0];
    if not isinstance(first, CgNode) {
        loc = nd.loc;
        raise RuntimeError(
            self.ice(
                f"JCIR recipe on {type(nd).__name__} is a splice, not a value "
                f"at {loc.mod_path}:{loc.first_line}:{loc.col_start}"
            )
        );
    }
    return first;
}

impl JcirGenPass.const_of(value: any, jac_node: (UniNode | None) = None) -> CgNode {
    return self.nod('Constant', ['value'], [value], jac_node=jac_node);
}

impl JcirGenPass.name_load(name_id: str, jac_node: (UniNode | None) = None) -> CgNode {
    return self.nod(
        'Name',
        ['id', 'ctx'],
        [name_id, self.nod('Load', [], [], jac_node=jac_node)],
        jac_node=jac_node
    );
}

impl JcirGenPass._with_ctx(cgn: CgNode, ctx_cls: str) -> CgNode {
    twin = CgNode(
        cls=cgn.cls,
        keys=list(cgn.keys),
        vals=list(cgn.vals),
        l1=cgn.l1,
        c1=cgn.c1,
        l2=cgn.l2,
        c2=cgn.c2,
        jac_src=cgn.jac_src
    );
    twin.setf('ctx', self.nod_loc(ctx_cls, [], [], cgn.l1, cgn.c1, cgn.l2, cgn.c2));
    return twin;
}

impl JcirGenPass.jaclib_obj(obj_name: str) -> CgNode {
    self.jaclib_imports.add(obj_name);
    return self.name_load(obj_name);
}

impl JcirGenPass.builtin_name(name: str) -> CgNode {
    if (name not in ['Enum', 'IntEnum', 'StrEnum']) {
        self.builtin_imports.add(name);
    }
    return self.name_load(name);
}

impl JcirGenPass._add_preamble_once(key: str, cgn: CgNode) -> None {
    if (key in self.already_added) {
        return;
    }
    self.preamble.append(cgn);
    self.already_added.append(key);
}

impl JcirGenPass.needs_enum_kind(kind: str) -> None {
    self._add_preamble_once(
        f"needs_enum_kind:{kind}",
        self.nod(
            'ImportFrom',
            ['module', 'names', 'level'],
            [
                'enum',
                [
                    self.nod('alias', ['name', 'asname'], [kind, None]),
                    self.nod('alias', ['name', 'asname'], ['auto', None])
                ],
                0
            ],
            jac_node=self.ir_out
        )
    );
}

impl JcirGenPass._py_name(nd: AstSymbolNode) -> str {
    if (isinstance(nd, SpecialVarRef) and (nd.name == Tok.KW_INIT)) {
        return '__init__';
    }
    if (isinstance(nd, Name) and (nd.name == Tok.KW_INIT)) {
        return '__init__';
    }
    return nd.sym_name;
}

impl JcirGenPass.py_ctx(nd: AstSymbolNode) -> CgNode {
    if (nd.expr_ctx == ExprCtx.STORE) {
        return self.nod('Store', [], []);
    }
    if (nd.expr_ctx == ExprCtx.DEL) {
        return self.nod('Del', [], []);
    }
    return self.nod('Load', [], []);
}

impl JcirGenPass._next_lambda_name -> str {
    self._lambda_counter += 1;
    return f"_jac_lambda_{self._lambda_counter}";
}

impl JcirGenPass._push_hoist_frame -> None {
    self._hoist_frames.append([]);
}

impl JcirGenPass._hoist_lambda(func_def: CgNode) -> None {
    if not self._hoist_frames {
        self._hoist_frames = [[]];
    }
    self._hoist_frames[-1].append(func_def);
}

impl JcirGenPass._ancestor_is_one_of(
    nd: (UniNode | None), roots: list[UniNode]
) -> bool {
    cur: (UniNode | None) = nd;
    seen: set[UniNode] = set();
    while cur {
        if cur in seen {
            return False;
        }
        seen.add(cur);
        for cand_root in roots {
            if cur is cand_root {
                return True;
            }
        }
        cur = cur.parent;
    }
    return False;
}

impl JcirGenPass._split_scope_hoists(
    hoists: list[CgNode], sig_roots: list[UniNode]
) -> tuple[(list[CgNode], list[CgNode])] {
    body_hoists: list[CgNode] = [];
    enclosing_hoists: list[CgNode] = [];
    for func_def in hoists {
        lam = func_def.jac_src;
        if (lam is not None and self._ancestor_is_one_of(lam, sig_roots)) {
            enclosing_hoists.append(func_def);
        } else {
            body_hoists.append(func_def);
        }
    }
    return (body_hoists, enclosing_hoists);
}

impl JcirGenPass._docstring_offset(body: list[CgItem]) -> int {
    if not body {
        return 0;
    }
    head = body[0];
    if (not isinstance(head, CgNode)) or (head.cls != 'Expr') {
        return 0;
    }
    inner = head.get('value');
    if (not isinstance(inner, CgNode)) or (inner.cls != 'Constant') {
        return 0;
    }
    return 1 if isinstance(inner.get('value'), str) else 0;
}

impl JcirGenPass._drain_module_hoists -> list[CgNode] {
    if not self._hoist_frames {
        self._hoist_frames = [[]];
    }
    if len(self._hoist_frames) > 1 {
        self._report_leaked_hoisted_lambdas();
    }
    hoists = self._hoist_frames[0][:];
    self._hoist_frames = [[]];
    return hoists;
}

impl JcirGenPass._report_leaked_hoisted_lambdas -> None {
    leftover: list[CgNode] = [];
    for frame in self._hoist_frames[1:] {
        leftover.extend(frame);
    }
    for func_def in leftover {
        jac_node: UniNode = self.ir_out;
        if func_def.jac_src is not None {
            jac_node = func_def.jac_src;
        }
        leaked_name = func_def.get('name');
        self.emit(
            E5098,
            node_override=jac_node,
            name=leaked_name if isinstance(leaked_name, str) else ''
        );
    }
}

impl JcirGenPass._function_expr_from_def(
    func_def: CgNode, jac_node: UniNode
) -> CgNode {
    self._hoist_lambda(func_def);
    return self.nod(
        'Name',
        ['id', 'ctx'],
        [func_def.get('name'), self.nod('Load', [], [], jac_node=jac_node)],
        jac_node=jac_node
    );
}

impl JcirGenPass._get_sem_decorator(nd: UniNode) -> (CgNode | None) {
    semstr: str = '';
    inner_semstr: dict[(str, str)] = {};
    if isinstance(nd, Archetype) {
        semstr = nd.semstr;
        arch_ast_body: list[UniNode] = [];
        if isinstance(nd.body, list) {
            arch_ast_body = list(nd.body);
        } elif (isinstance(nd.body, ImplDef) and isinstance(nd.body.body, list)) {
            arch_ast_body = list(nd.body.body);
        }
        for stmt in arch_ast_body {
            if isinstance(stmt, ArchHas) {
                for has_var in stmt.vars {
                    if has_var.semstr {
                        inner_semstr[has_var.sym_name] = has_var.semstr;
                    }
                }
            }
        }
    } elif isinstance(nd, Enum) {
        semstr = nd.semstr;
        enum_ast_body: list[UniNode] = [];
        if isinstance(nd.body, list) {
            enum_ast_body = list(nd.body);
        } elif (isinstance(nd.body, ImplDef) and isinstance(nd.body.body, list)) {
            enum_ast_body = list(nd.body.body);
        }
        for stmt in enum_ast_body {
            if (
                isinstance(stmt, Assignment)
                and isinstance(stmt.target[0], AstSymbolNode)
            ) {
                inner_semstr[stmt.target[0].sym_name] = stmt.target[0].semstr;
            }
        }
    } elif isinstance(nd, Ability) {
        semstr = nd.semstr;
        if isinstance(nd.signature, FuncSignature) and nd.signature.params {
            for param in nd.signature.params {
                if isinstance(param, ParamVar) and param.semstr {
                    inner_semstr[param.sym_name] = param.semstr;
                }
            }
        }
    }
    has_inner = False;
    for k in inner_semstr {
        if inner_semstr[k] {
            has_inner = True;
        }
    }
    if (not semstr and not has_inner) {
        return None;
    }
    return self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [
            self.jaclib_obj('sem'),
            [
                self.const_of(semstr),
                self.nod(
                    'Dict',
                    ['keys', 'values'],
                    [
                        [self.const_of(k) for k in inner_semstr],
                        [self.const_of(inner_semstr[k]) for k in inner_semstr]
                    ]
                )
            ],
            []
        ]
    );
}

impl JcirGenPass.resolve_switch_pattern(pattern: MatchPattern, target: Expr) -> CgNode {
    if isinstance(pattern, MatchValue) {
        return self.nod(
            'Compare',
            ['left', 'ops', 'comparators'],
            [self.val(target), [self.nod('Eq', [], [])], [self.val(pattern.value)]]
        );
    } elif isinstance(pattern, MatchOr) {
        return self.nod(
            'BoolOp',
            ['op', 'values'],
            [
                self.nod('Or', [], []),
                [self.resolve_switch_pattern(pat, target) for pat in pattern.patterns]
            ]
        );
    } elif isinstance(pattern, MatchSingleton) {
        return self.nod(
            'Compare',
            ['left', 'ops', 'comparators'],
            [self.val(target), [self.nod('Is', [], [])], [self.val(pattern.value)]]
        );
    } else {
        raise RuntimeError(self.ice('Unsupported switch pattern type'));
    }
}

impl JcirGenPass.resolve_switch_stmt(nd: SwitchStmt) -> list[CgItem] {
    var_executed = self.nod(
        'Name', ['id', 'ctx'], ['__executed', self.nod('Store', [], [])]
    );
    assign_var = self.nod(
        'Assign', ['targets', 'value'], [[var_executed], self.const_of(False)]
    );
    ast_nodes: list[CgItem] = [];
    executed_assign = self.nod(
        'Assign', ['targets', 'value'], [[var_executed], self.const_of(True)]
    );
    for cs in nd.cases {
        if (cs.pattern is None) {
            ast_nodes.extend((self.resolve_stmt_block(cs.body) + [executed_assign]));
        } else {
            test_expr = self.nod(
                'BoolOp',
                ['op', 'values'],
                [
                    self.nod('Or', [], []),
                    [
                        self.resolve_switch_pattern(cs.pattern, nd.target),
                        self.name_load('__executed')
                    ]
                ]
            );
            if_stmt = self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [test_expr, (self.resolve_stmt_block(cs.body) + [executed_assign]), []]
            );
            ast_nodes.append(if_stmt);
        }
    }
    while_cond = self.nod(
        'UnaryOp',
        ['op', 'operand'],
        [self.nod('Not', [], []), self.name_load('__executed')]
    );
    return [
        assign_var,
        self.nod('While', ['test', 'body', 'orelse'], [while_cond, ast_nodes, []])
    ];
}

impl JcirGenPass.resolve_stmt_block(
    nd: Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | None,
    doc: (String | None) = None
) -> list[CgItem] {
    items = list(nd) if nd else [];
    valid_stmts = [
        i
        for i in items
        if not isinstance(i, Semi)
    ];
    ret: list[CgItem] = [self.nod('Pass', [], [])]
        if (isinstance(nd, Sequence) and not valid_stmts)
        else self._flatten_ast_list(
            [
                self.outs(x)
                    if not isinstance(x, SwitchStmt)
                    else self.resolve_switch_stmt(x)
                for x in valid_stmts
                if not isinstance(x, ImplDef)
            ]
        )
            if (nd is not None)
            else [self.nod('Pass', [], [])];
    if doc {
        ret = [self.nod('Expr', ['value'], [self.val(doc)], jac_node=doc), *ret];
    }
    return ret;
}

impl JcirGenPass.scope_directive_stmts(
    scopes: list[UniScopeNode | None]
) -> list[CgNode] {
    global_names: list[str] = [];
    nonlocal_names: list[str] = [];
    seen: set[str] = set();
    for scope in scopes {
        if scope is None {
            continue;
        }
        for name in scope.implicit_rebinds {
            if name in seen {
                continue;
            }
            seen.add(name);
            sym = scope.implicit_rebinds[name];
            if isinstance(sym.parent_tab, Module) {
                global_names.append(name);
            } else {
                nonlocal_names.append(name);
            }
        }
    }
    stmts: list[CgNode] = [];
    if global_names {
        stmts.append(self.nod('Global', ['names'], [sorted(global_names)]));
    }
    if nonlocal_names {
        stmts.append(self.nod('Nonlocal', ['names'], [sorted(nonlocal_names)]));
    }
    return stmts;
}

impl JcirGenPass.ir_bytes -> bytes {
    if self._module_root is None {
        raise RuntimeError(self.ice('JCIR emitter produced no module root'));
    }
    return module_container_bytes(self._module_path, self._module_root);
}

impl JcirGenPass.exit_sub_tag(nd: SubTag) -> None {
    tag_node = nd.tag;
    if isinstance(tag_node, UniNode) {
        self.set_out(nd, self.outs(tag_node));
    }
}

impl JcirGenPass.exit_module(nd: Module) -> None {
    mod_path = nd.loc.mod_path;
    is_builtin_module = (
        (mod_path.endswith('builtin.jac') or mod_path.endswith('builtin.py'))
        and ('runtimelib' in mod_path)
    );
    if (self.builtin_imports and not is_builtin_module) {
        self.preamble.append(
            self.nod(
                'ImportFrom',
                ['module', 'names', 'level'],
                [
                    'jaclang.runtimelib.builtin',
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
    mod_path_norm = nd.loc.mod_path.replace('\\', '/');
    is_jaclib_module = (
        mod_path_norm.endswith('/jaclang/lib.jac')
        or mod_path_norm.endswith('/jaclang/lib.py')
    );
    if (self.jaclib_imports and not is_jaclib_module) {
        self.preamble.append(
            self.nod(
                'ImportFrom',
                ['module', 'names', 'level'],
                [
                    'jaclang.jac0core.jaclib',
                    [
                        self.nod(
                            'alias',
                            ['name', 'asname'],
                            [name, None],
                            jac_node=self.ir_out
                        ) for name in sorted(list(self.jaclib_imports))
                    ],
                    0
                ],
                jac_node=self.ir_out
            )
        );
    }
    merged_body = self._merge_module_bodies(nd);
    body_items: list[CgItem] = [];
    if nd.doc {
        body_items.append(
            self.nod('Expr', ['value'], [self.val(nd.doc)], jac_node=nd.doc)
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
    self.set_out(nd, [module]);
    self._module_root = module;
    self._module_path = nd.loc.mod_path;
    nd.gen.jcir = module_container_bytes(self._module_path, module);
}

impl JcirGenPass.exit_type_param(nd: TypeParam) -> None {
    bound_ast = self.val(nd.bound) if nd.bound else None;
    self.set_out(
        nd, [self.nod('TypeVar', ['name', 'bound'], [nd.name.value, bound_ast])]
    );
}

impl JcirGenPass.exit_type_alias(nd: TypeAlias) -> None {
    type_param_asts: list[CgNode] = [];
    for tp in nd.type_params {
        if self.outs(tp) {
            type_param_asts.append(self.val(tp));
        }
    }
    value_ast = self.val(nd.value);
    if nd.is_distinct {
        assign = self.nod(
            'Assign',
            ['targets', 'value'],
            [
                [
                    self.nod(
                        'Name',
                        ['id', 'ctx'],
                        [nd.name.sym_name, self.nod('Store', [], [])]
                    )
                ],
                value_ast
            ]
        );
        self.set_out(nd, [assign]);
        return;
    }
    type_alias = self.nod(
        'TypeAlias',
        ['name', 'type_params', 'value'],
        [
            self.nod(
                'Name', ['id', 'ctx'], [nd.name.sym_name, self.nod('Store', [], [])]
            ),
            type_param_asts,
            value_ast
        ]
    );
    self.set_out(nd, [type_alias]);
}

impl JcirGenPass.exit_global_vars(nd: GlobalVars) -> None {
    assigns_ast = self._flatten_ast_list([self.outs(a) for a in nd.assignments]);
    if nd.doc {
        doc = self.nod('Expr', ['value'], [self.val(nd.doc)], jac_node=nd.doc);
        self.set_out(nd, [doc] + assigns_ast);
    } else {
        self.set_out(nd, assigns_ast);
    }
}

impl JcirGenPass.enter_test(nd: Test) -> None {
    self._push_hoist_frame();
}

impl JcirGenPass.exit_test(nd: Test) -> None {
    test_name = nd.name.sym_name;
    if nd.code_context == CodeContext.NATIVE {
        body_stmts = self._native_test_shim_stmts(nd);
    } else {
        body_stmts = self.resolve_stmt_block(nd.body, doc=nd.doc);
    }
    test_directives = self.scope_directive_stmts([nd]);
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
    if nd.decorators {
        for d in nd.decorators {
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
            [self.val(i) for i in nd.decorators] if nd.decorators else [],
            self.const_of(None),
            None,
            []
        ]
    );
    jac_test_keywords: list[CgNode] = [];
    if nd.description {
        jac_test_keywords.append(
            self.nod(
                'keyword',
                ['arg', 'value'],
                ['description', self.const_of(nd.description.lit_value)]
            )
        );
    }
    func.get('decorator_list').append(
        self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [self.jaclib_obj('jac_test'), [], jac_test_keywords]
        )
    );
    if jcir_is_test_path(nd.loc.mod_path) {
        func.get('decorator_list').append(
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.jaclib_obj('impl_patch_filename'),
                    [],
                    [
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            ['file_loc', self.const_of(nd.loc.mod_path)]
                        )
                    ]
                ]
            )
        );
    }
    self.set_out(nd, [func]);
}

impl JcirGenPass.exit_module_code(nd: ModuleCode) -> None {
    stmts = self.resolve_stmt_block(nd.body, doc=nd.doc);
    if nd.name {
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
                            [self.const_of(nd.name.sym_name)]
                        ]
                    ),
                    stmts,
                    []
                ]
            )
        ];
    }
    self.set_out(nd, stmts);
}

impl JcirGenPass.exit_py_inline_code(nd: PyInlineCode) -> None {
    if nd.doc {
        doc = self.nod('Expr', ['value'], [self.val(nd.doc)], jac_node=nd.doc);
        shift = nd.loc.first_line;
        inner = doc.get('value');
        doc.l1 = doc.l1 + shift;
        doc.l2 = doc.l2 + shift;
        if isinstance(inner, CgNode) {
            inner.l1 = inner.l1 + shift;
            inner.l2 = inner.l2 + shift;
        }
        self.set_out(nd, [doc, CgSplice(src=nd.code.value, offset=shift)]);
    } else {
        self.set_out(
            nd, [CgSplice(src=textwrap.dedent(nd.code.value), offset=nd.loc.first_line)]
        );
    }
}

impl JcirGenPass.exit_import(nd: Import) -> None {
    import from jaclang.jac0core.compiler { import_binds_client_native }
    if (
        import_binds_client_native(nd, self.ir_in.gen.interop_manifest)
        or nd.native_only_drop
    ) {
        self.set_out(nd, []);
        return;
    }
    if (nd.from_loc and nd.from_loc.path) {
        module_parts = [
            p.value
            for p in nd.from_loc.path
            if p?.value
        ];
        if (module_parts == ['__future__']) {
            self.set_out(nd, []);
            return;
        }
    }
    if (
        nd.from_loc
        and nd.items
        and nd.is_service_import
        and nd.code_context != CodeContext.CLIENT
        and self._generate_sv_to_sv_stubs(nd)
    ) {
        return;
    }
    py_nodes: list[CgNode] = [];
    if nd.doc {
        py_nodes.append(
            self.nod('Expr', ['value'], [self.val(nd.doc)], jac_node=nd.doc)
        );
    }
    if nd.is_absorb {
        source = nd.items[0];
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
                    [self.nod('alias', ['name'], ['*'], jac_node=nd)],
                    source.level
                ],
                jac_node=nd
            )
        );
    } elif not nd.from_loc {
        mod_paths = [
            k
            for k in nd.kid
            if isinstance(k, ModulePath)
        ];
        names_list = [x for p in mod_paths for x in self.outs(p)]
            if mod_paths
            else [x for item in nd.items for x in self.outs(item)];
        py_nodes.append(self.nod('Import', ['names'], [names_list]));
    } else {
        module_name_parts = [p.value for p in nd.from_loc.path]
            if nd.from_loc.path
            else [];
        module_name = '.'.join(module_name_parts) if module_name_parts else None;
        py_nodes.append(
            self.nod(
                'ImportFrom',
                ['module', 'names', 'level'],
                [
                    module_name,
                    [i for item in nd.items for i in self.outs(item)],
                    nd.from_loc.level
                ]
            )
        );
    }
    if nd.is_typed {
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
            py_nodes = [wrapped];
        }
    }
    self.set_out(nd, py_nodes);
}

impl JcirGenPass.exit_module_path(nd: ModulePath) -> None {
    if nd.string_path_value is not None {
        import_node = nd.parent_of_type(Import);
        if (import_node and (import_node.code_context != CodeContext.CLIENT)) {
            self.emit(E5001, node_override=nd, path=str(nd.string_path_value));
        }
    }
    self.set_out(
        nd,
        [
            self.nod(
                'alias',
                ['name', 'asname'],
                [str(nd.dot_path_str), nd.alias.sym_name if nd.alias else None]
            )
        ]
    );
}

impl JcirGenPass.exit_module_item(nd: ModuleItem) -> None {
    if (isinstance(nd.name, Token) and (nd.name.value in ['default', '*'])) {
        import_node = nd.from_parent;
        if (import_node.code_context != CodeContext.CLIENT) {
            import_type = 'Default' if (nd.name.value == 'default') else 'Namespace';
            self.emit(
                E5002,
                node_override=nd,
                import_type=import_type,
                name=str(nd.name.value)
            );
            self.set_out(nd, []);
            return;
        }
    }
    self.set_out(
        nd,
        [
            self.nod(
                'alias',
                ['name', 'asname'],
                [
                    (nd.name.sym_name if isinstance(nd.name, Name) else nd.name.value),
                    nd.alias.sym_name if nd.alias else None
                ]
            )
        ]
    );
}

impl JcirGenPass.enter_archetype(nd: Archetype) -> None {
    if isinstance(nd.body, ImplDef) {
        self.traverse(nd.body);
    }
}

impl JcirGenPass.exit_archetype(nd: Archetype) -> None {
    inner:
        (
            Sequence[UniNode] | Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | None
        ) = None;
    if isinstance(nd.body, ImplDef) {
        inner = nd.body.body if not isinstance(nd.body.body, Expr) else None;
    } elif isinstance(nd.body, list) {
        inner = nd.body;
    }
    decorators = [self.val(i) for i in nd.decorators] if nd.decorators else [];
    body: list = self.resolve_stmt_block(inner, doc=nd.doc);
    if (not body and not isinstance(nd.body, Expr)) {
        self.emit(E5003, node_override=nd);
        body = [self.nod('Pass', [], [], jac_node=nd)];
    }
    if nd.is_async {
        body.insert(
            0,
            self.nod(
                'Assign',
                ['targets', 'value'],
                [
                    [
                        self.nod(
                            'Name',
                            ['id', 'ctx'],
                            ['__jac_async__', self.nod('Store', [], [])]
                        )
                    ],
                    self.const_of(nd.is_async)
                ]
            )
        );
    }
    if (sem_decorator := self._get_sem_decorator(nd)) {
        decorators.append(sem_decorator);
    }
    base_classes = [self.val(i) for i in nd.base_classes];
    if (nd.arch_type.name != Tok.KW_CLASS) {
        base_classes.append(self.jaclib_obj(nd.arch_type.value.capitalize()));
    }
    type_param_asts: list[CgNode] = [];
    if nd.type_params {
        for tp in nd.type_params {
            if self.outs(tp) {
                type_param_asts.append(self.val(tp));
            }
        }
    }
    keywords = [self.val(k) for k in nd.keywords] if nd.keywords else [];
    class_def = self.nod(
        'ClassDef',
        ['name', 'bases', 'keywords', 'body', 'decorator_list', 'type_params'],
        [nd.name.sym_name, base_classes, keywords, body, decorators, type_param_asts]
    );
    self.set_out(nd, [class_def]);
}

impl JcirGenPass.enter_enum(nd: Enum) -> None {
    if isinstance(nd.body, ImplDef) {
        self.traverse(nd.body);
    }
}

impl JcirGenPass.exit_enum(nd: Enum) -> None {
    inner:
        (
            Sequence[UniNode] | Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | None
        ) = None;
    if isinstance(nd.body, ImplDef) {
        inner = nd.body.body if not isinstance(nd.body.body, Expr) else None;
    } elif isinstance(nd.body, list) {
        inner = nd.body;
    }
    decorators = [self.val(i) for i in nd.decorators] if nd.decorators else [];
    body = self.resolve_stmt_block(inner, doc=nd.doc);
    if (sem_decorator := self._get_sem_decorator(nd)) {
        decorators.append(sem_decorator);
    }
    trailing_kind: str = "Enum";
    extra_bases: list[CgNode] = [];
    if nd.value_type {
        if (isinstance(nd.value_type, Name) and nd.value_type.value == "int") {
            trailing_kind = "IntEnum";
        } elif (isinstance(nd.value_type, Name) and nd.value_type.value == "str") {
            trailing_kind = "StrEnum";
        } else {
            extra_bases.append(self.val(nd.value_type));
        }
    }
    self.needs_enum_kind(trailing_kind);
    base_classes = extra_bases + [self.val(i) for i in nd.base_classes];
    base_classes.append(self.builtin_name(trailing_kind));
    class_def = self.nod(
        'ClassDef',
        ['name', 'bases', 'keywords', 'body', 'decorator_list', 'type_params'],
        [nd.name.sym_name, base_classes, [], body, decorators, []]
    );
    self.set_out(nd, [class_def]);
}

impl JcirGenPass.enter_ability(nd: Ability) -> None {
    self._push_hoist_frame();
    if isinstance(nd.body, ImplDef) {
        self.traverse(nd.body);
    }
}

impl JcirGenPass.exit_ability(nd: Ability) -> None {
    func_type = 'AsyncFunctionDef' if nd.is_async else 'FunctionDef';
    has_by_in_return = (
        isinstance(nd.signature, FuncSignature)
        and nd.signature.return_type
        and isinstance(nd.signature.return_type, BinaryExpr)
        and isinstance(nd.signature.return_type.op, Token)
        and (nd.signature.return_type.op.name == Tok.KW_BY)
    );
    scope_frame = self._hoist_frames.pop() if self._hoist_frames else [];
    if not self._hoist_frames {
        self._hoist_frames = [[]];
    }
    sig_roots: list[UniNode] = [];
    if nd.signature {
        sig_roots.append(nd.signature);
    }
    if nd.decorators {
        for d in nd.decorators {
            if d {
                sig_roots.append(d);
            }
        }
    }
    (body_hoists, enclosing_hoists) = self._split_scope_hoists(scope_frame, sig_roots);
    if enclosing_hoists {
        self._hoist_frames[-1].extend(enclosing_hoists);
    }
    is_prop_acc = nd.accessor_kind != "";
    prop_owner_name: str | None = None;
    if is_prop_acc {
        hv = nd.find_parent_of_type(HasVar);
        if (hv and isinstance(hv.name, Name)) {
            prop_owner_name = hv.name.value;
        }
    }
    body_loc_node: (UniNode | None) = nd.body if isinstance(nd.body, UniNode) else None;
    stmt_body:
        (
            Sequence[UniNode] | Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | None
        ) = None;
    if isinstance(nd.body, ImplDef) and not isinstance(nd.body.body, Expr) {
        stmt_body = nd.body.body;
    } elif isinstance(nd.body, list) {
        stmt_body = nd.body;
    }
    body = self.gen_llm_body(nd)
        if (
            isinstance(nd.body, Expr)
            or (isinstance(nd.body, ImplDef) and isinstance(nd.body.body, Expr))
            or has_by_in_return
        )
        else [
            self.nod('Expr', ['value'], [self.val(nd.doc)], jac_node=nd.doc),
            self.nod('Pass', [], [], jac_node=body_loc_node)
        ]
            if (nd.doc and nd.is_abstract)
            else [self.nod('Pass', [], [], jac_node=body_loc_node)]
                if nd.is_abstract
                else self.resolve_stmt_block(stmt_body, doc=nd.doc);
    if (nd.is_abstract and nd.body) {
        self.emit(E5004, node_override=nd, name=str(nd.sym_name));
    }
    decorator_list = [self.val(i) for i in nd.decorators] if nd.decorators else [];
    if (sem_decorator := self._get_sem_decorator(nd)) {
        decorator_list.append(sem_decorator);
    }
    if isinstance(nd.signature, EventSignature) {
        event_sig = nd.signature;
        decorator_list.append(
            self.jaclib_obj(
                'on_entry' if (event_sig.event.name == Tok.KW_ENTRY) else 'on_exit'
            )
        );
        trigger_arg: CgNode = self.const_of(None);
        if event_sig.arch_tag_info {
            tinfo = self.val(event_sig.arch_tag_info);
            if (
                tinfo.cls == 'Tuple' and isinstance(event_sig.arch_tag_info, TupleVal)
            ) {
                telts = tinfo.get('elts');
                if (len(telts) > 1) {
                    trigger_arg = telts[0];
                    for elem in telts[1:] {
                        trigger_arg = self.nod(
                            'BinOp',
                            ['left', 'op', 'right'],
                            [trigger_arg, self.nod('BitOr', [], []), elem]
                        );
                    }
                } elif (len(telts) == 1) {
                    trigger_arg = telts[0];
                }
            } else {
                trigger_arg = tinfo;
            }
        }
        trigger_thunk = self.nod(
            'Lambda',
            ['args', 'body'],
            [
                self.nod(
                    'arguments',
                    ['posonlyargs', 'args', 'kwonlyargs', 'kw_defaults', 'defaults'],
                    [[], [], [], [], []]
                ),
                trigger_arg
            ]
        );
        decorator_list.append(
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [self.jaclib_obj('set_trigger'), [trigger_thunk], []]
            )
        );
    }
    if isinstance(nd.body, ImplDef) {
        decorator_list.append(
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.jaclib_obj('impl_patch_filename'),
                    [self.const_of(nd.body.loc.mod_path)],
                    []
                ]
            )
        );
    }
    if nd.is_abstract {
        decorator_list.append(self.builtin_name('abstractmethod'));
    }
    if nd.is_override {
        decorator_list.append(self.builtin_name('override'));
    }
    if nd.is_static {
        decorator_list.insert(0, self.name_load('staticmethod'));
    }
    if nd.is_classmethod {
        decorator_list.insert(0, self.name_load('classmethod'));
    }
    if (is_prop_acc and (prop_owner_name is not None)) {
        if nd.accessor_kind == "property" {
            decorator_list.insert(0, self.name_load('property'));
        } elif nd.accessor_kind == "setter" {
            decorator_list.insert(
                0,
                self.nod(
                    'Attribute',
                    ['value', 'attr', 'ctx'],
                    [
                        self.name_load(prop_owner_name),
                        'setter',
                        self.nod('Load', [], [])
                    ]
                )
            );
        } elif nd.accessor_kind == "deleter" {
            decorator_list.insert(
                0,
                self.nod(
                    'Attribute',
                    ['value', 'attr', 'ctx'],
                    [
                        self.name_load(prop_owner_name),
                        'deleter',
                        self.nod('Load', [], [])
                    ]
                )
            );
        }
    }
    if (not body and not isinstance(nd.body, Expr)) {
        self.emit(E5005, node_override=nd);
        body = [self.nod('Pass', [], [], jac_node=nd)];
    }
    if body_hoists {
        body = [*body_hoists, *body];
    }
    directive_stmts = self.scope_directive_stmts(
        [nd, nd.body if isinstance(nd.body, ImplDef) else None]
    );
    if directive_stmts {
        insert_at = self._docstring_offset(body);
        body = [*body[:insert_at], *directive_stmts, *body[insert_at:]];
    }
    ast_returns: CgNode = self.const_of(None);
    if (isinstance(nd.signature, FuncSignature) and nd.signature.return_type) {
        if (
            isinstance(nd.signature.return_type, BinaryExpr)
            and isinstance(nd.signature.return_type.op, Token)
            and (nd.signature.return_type.op.name == Tok.KW_BY)
        ) {
            ast_returns = self.val(nd.signature.return_type.left);
        } else {
            ast_returns = self.val(nd.signature.return_type);
        }
    }
    if (
        is_prop_acc
        and (nd.accessor_kind == "property")
        and (nd.signature is None)
        and (prop_owner_name is not None)
    ) {
        hv2 = nd.find_parent_of_type(HasVar);
        if (hv2 and hv2.type_tag) {
            ast_returns = self.val(hv2.type_tag);
        }
    }
    name_ref_node = nd.name_ref;
    func_name_out = (
        prop_owner_name
            if (is_prop_acc and (prop_owner_name is not None))
            else self._py_name(name_ref_node) if name_ref_node is not None else ""
    );
    func_args_out: CgNode;
    if (is_prop_acc and (nd.signature is None)) {
        acc_args = [self.nod('arg', ['arg', 'annotation'], ['self', None])];
        if nd.accessor_kind == "setter" {
            acc_args.append(self.nod('arg', ['arg', 'annotation'], ['value', None]));
        }
        func_args_out = self.nod(
            'arguments',
            [
                'posonlyargs',
                'args',
                'vararg',
                'kwonlyargs',
                'kw_defaults',
                'kwarg',
                'defaults'
            ],
            [[], acc_args, None, [], [], None, []]
        );
    } elif nd.signature {
        func_args_out = self.val(nd.signature);
    } else {
        func_args_out = self.nod(
            'arguments',
            [
                'posonlyargs',
                'args',
                'vararg',
                'kwonlyargs',
                'kw_defaults',
                'kwarg',
                'defaults'
            ],
            [
                [],
                [self.nod('arg', ['arg', 'annotation'], ['self', None])]
                    if nd.is_method and not nd.is_static and not nd.is_classmethod
                    else [],
                None,
                [],
                [],
                None,
                []
            ]
        );
    }
    func_def = self.nod(
        func_type,
        ['name', 'args', 'body', 'decorator_list', 'returns', 'type_params'],
        [func_name_out, func_args_out, body, decorator_list, ast_returns, []]
    );
    self.set_out(nd, [func_def]);
}

impl JcirGenPass.exit_impl_def(nd: ImplDef) -> None {
    ;
}

impl JcirGenPass.exit_sem_def(nd: SemDef) -> None {
    ;
}

impl JcirGenPass.exit_func_signature(nd: FuncSignature) -> None {
    posonlyargs = [self.val(i) for i in nd.posonly_params];
    vararg = self.val(nd.varargs) if nd.varargs else None;
    kwarg = self.val(nd.kwargs) if nd.kwargs else None;
    params = [self.nod('arg', ['arg', 'annotation'], ['cls', None])]
        if (
            (abl := nd.parent)
            and isinstance(abl, Ability)
            and abl.is_method
            and abl.is_classmethod
            and not nd.is_in_py_class
        )
        else [self.nod('arg', ['arg', 'annotation'], ['self', None])]
            if (
                (abl := nd.parent)
                and isinstance(abl, Ability)
                and abl.is_method
                and not nd.is_static
                and not abl.is_cls_method
                and not nd.is_in_py_class
            )
            else [];
    if posonlyargs {
        posonlyargs = params + posonlyargs;
        params = [self.val(i) for i in nd.params];
    } else {
        params = params + [self.val(i) for i in nd.params];
    }
    defaults: list[CgNode] = [];
    all_params: list[UniNode] = list(nd.posonly_params) + list(nd.params);
    for i in all_params {
        if (isinstance(i, ParamVar) and i.value) {
            defaults.append(self.val(i.value));
        }
    }
    kwonly_args = [self.val(i) for i in nd.kwonlyargs];
    kw_defaults: list[CgNode | None] = [];
    for i in nd.kwonlyargs {
        if isinstance(i, ParamVar) and i.value {
            kw_defaults.append(self.val(i.value));
        } else {
            kw_defaults.append(None);
        }
    }
    self.set_out(
        nd,
        [
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
                [posonlyargs, params, kwonly_args, vararg, kwarg, kw_defaults, defaults]
            )
        ]
    );
}

impl JcirGenPass.exit_event_signature(nd: EventSignature) -> None {
    arch_kw = Con.HERE.value if nd.from_walker else Con.VISITOR.value;
    annotation: (CgNode | None) = None;
    if nd.arch_tag_info {
        tag_recipe = self.val(nd.arch_tag_info);
        if (tag_recipe.cls == 'Tuple' and isinstance(nd.arch_tag_info, TupleVal)) {
            telts = tag_recipe.get('elts');
            if (len(telts) > 1) {
                annotation = telts[0];
                for elem in telts[1:] {
                    annotation = self.nod(
                        'BinOp',
                        ['left', 'op', 'right'],
                        [annotation, self.nod('BitOr', [], []), elem]
                    );
                }
            } elif (len(telts) == 1) {
                annotation = telts[0];
            }
        } else {
            annotation = tag_recipe;
        }
    }
    if (annotation is not None and self._recipe_contains_root(annotation)) {
        self.jaclib_imports.add('Root');
    }
    arch_arg = self.nod(
        'arg',
        ['arg', 'annotation'],
        [f"{arch_kw}", annotation],
        jac_node=nd.arch_tag_info or nd
    );
    self.set_out(
        nd,
        [
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
                [
                    [],
                    [self.nod('arg', ['arg', 'annotation'], ['self', None]), arch_arg]
                        if ((abl := nd.find_parent_of_type(Ability)) and abl.is_method)
                        else [arch_arg],
                    [],
                    None,
                    None,
                    [],
                    []
                ]
            )
        ]
    );
}

impl JcirGenPass._recipe_contains_root(v: any) -> bool {
    if isinstance(v, CgNode) {
        if (v.cls == 'Name' and v.hasf('id') and v.get('id') == 'Root') {
            return True;
        }
        for item in v.vals {
            if self._recipe_contains_root(item) {
                return True;
            }
        }
        return False;
    }
    if isinstance(v, list) {
        for item in v {
            if self._recipe_contains_root(item) {
                return True;
            }
        }
    }
    return False;
}

impl JcirGenPass.exit_param_var(nd: ParamVar) -> None {
    if self.val(nd.name).cls == 'Name' {
        name = self.val(nd.name).get('id');
        self.set_out(
            nd,
            [
                self.nod(
                    'arg',
                    ['arg', 'annotation'],
                    [name, self.val(nd.type_tag) if nd.type_tag else None]
                )
            ]
        );
    }
}

impl JcirGenPass.exit_arch_has(nd: ArchHas) -> None {
    vars_py = self._flatten_ast_list([self.outs(v) for v in nd.vars]);
    if nd.doc {
        doc = self.nod('Expr', ['value'], [self.val(nd.doc)], jac_node=nd.doc);
        self.set_out(nd, [doc] + vars_py);
    } else {
        self.set_out(nd, vars_py);
    }
}

impl JcirGenPass.exit_has_var(nd: HasVar) -> None {
    annotation = self.val(nd.type_tag) if nd.type_tag else None;
    if ((nd.accessors is not None) and (len(nd.accessors) > 0)) {
        result_stmts: list[CgItem] = [];
        for acc in nd.accessors {
            for stmt in self.outs(acc) {
                result_stmts.append(stmt);
            }
        }
        self.set_out(nd, result_stmts);
        return;
    }
    is_static_var = (
        (haspar := nd.find_parent_of_type(ArchHas)) and haspar and haspar.is_static
    );
    is_in_class = (
        (archpar := nd.find_parent_of_type(Archetype))
        and archpar
        and (archpar.arch_type.name == Tok.KW_CLASS)
    );
    value = None;
    if is_in_class {
        value = self.val(nd.value) if nd.value else None;
    } elif is_static_var {
        annotation = self.nod(
            'Subscript',
            ['value', 'slice', 'ctx'],
            [self.builtin_name('ClassVar'), annotation, self.nod('Load', [], [])]
        );
        value = self.val(nd.value) if nd.value else None;
    } elif nd.defer {
        value = self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [
                self.jaclib_obj('field'),
                [],
                [self.nod('keyword', ['arg', 'value'], ['init', self.const_of(False)])]
            ]
        );
    } elif nd.value {
        value_expr = self.val(nd.value);
        if value_expr.cls == 'Constant' {
            value = value_expr;
        } else {
            value = self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.jaclib_obj('field'),
                    [],
                    [
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            [
                                'factory',
                                self.nod(
                                    'Lambda',
                                    ['args', 'body'],
                                    [
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
                                        value_expr
                                    ]
                                )
                            ]
                        )
                    ]
                ]
            );
        }
    }
    ann_assign = self.nod(
        'AnnAssign',
        ['target', 'annotation', 'value', 'simple'],
        [
            self.val(nd.name),
            annotation or self.const_of(None),
            value,
            int(isinstance(nd.name, Name))
        ]
    );
    self.set_out(nd, [ann_assign]);
}

impl JcirGenPass.exit_typed_ctx_block(nd: TypedCtxBlock) -> None {
    loc = self.name_load(Con.HERE.value if nd.from_walker else Con.VISITOR.value);
    self.set_out(
        nd,
        [
            self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [
                    self.nod(
                        'Call',
                        ['func', 'args', 'keywords'],
                        [self.name_load('isinstance'), [loc, self.val(nd.type_ctx)], []]
                    ),
                    self.resolve_stmt_block(nd.body),
                    []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_open_stmt(nd: OpenStmt) -> None {
    self.builtin_imports.add("_jac_region_open");
    self.builtin_imports.add("_jac_region_close");
    _tmp = f"_jac_region_{nd.loc.first_line}_{nd.loc.col_start}";
    assign_stmt = self.nod(
        'Assign',
        ['targets', 'value'],
        [
            [
                self.nod(
                    'Name',
                    ['id', 'ctx'],
                    [_tmp, self.nod('Store', [], [], jac_node=nd)],
                    jac_node=nd
                )
            ],
            self.val(nd.target)
        ],
        jac_node=nd.target
    );
    open_stmt = self.nod(
        'Expr',
        ['value'],
        [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.name_load('_jac_region_open', jac_node=nd),
                    [self.name_load(_tmp, jac_node=nd)],
                    []
                ],
                jac_node=nd
            )
        ],
        jac_node=nd
    );
    close_stmt = self.nod(
        'Expr',
        ['value'],
        [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.name_load('_jac_region_close', jac_node=nd),
                    [self.name_load(_tmp, jac_node=nd)],
                    []
                ],
                jac_node=nd
            )
        ],
        jac_node=nd
    );
    clear_stmt = self.nod(
        'Assign',
        ['targets', 'value'],
        [
            [
                self.nod(
                    'Name',
                    ['id', 'ctx'],
                    [_tmp, self.nod('Store', [], [], jac_node=nd)],
                    jac_node=nd
                )
            ],
            self.const_of(None, jac_node=nd)
        ],
        jac_node=nd
    );
    body_stmts: list = self._flatten_ast_list([self.outs(item) for item in nd.body]);
    if not body_stmts {
        body_stmts = [self.nod('Pass', [], [], jac_node=nd)];
    }
    try_stmt = self.nod(
        'Try',
        ['body', 'handlers', 'orelse', 'finalbody'],
        [body_stmts, [], [], [close_stmt, clear_stmt]],
        jac_node=nd
    );
    self.set_out(nd, [assign_stmt, open_stmt, try_stmt]);
}

impl JcirGenPass.exit_if_stmt(nd: IfStmt) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [
                    self.val(nd.condition),
                    self.resolve_stmt_block(nd.body),
                    self.outs(nd.else_body) if nd.else_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_else_if(nd: ElseIf) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [
                    self.val(nd.condition),
                    self.resolve_stmt_block(nd.body),
                    self.outs(nd.else_body) if nd.else_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_else_stmt(nd: ElseStmt) -> None {
    self.set_out(nd, self.resolve_stmt_block(nd.body));
}

impl JcirGenPass.exit_expr_stmt(nd: ExprStmt) -> None {
    expr_stmt = self.nod('Expr', ['value'], [self.val(nd.expr)])
        if not nd.in_fstring
        else self.nod(
            'FormattedValue',
            ['value', 'conversion', 'format_spec'],
            [self.val(nd.expr), -1, None]
        );
    self.set_out(nd, [expr_stmt]);
}

impl JcirGenPass.exit_concurrent_expr(nd: ConcurrentExpr) -> None {
    func = '';
    if nd.tok {
        if nd.tok.value == 'flow' {
            func = 'thread_run';
        } elif nd.tok.value == 'wait' {
            func = 'thread_wait';
        }
    }
    if func {
        lambda_ex = [
            self.nod(
                'Lambda',
                ['args', 'body'],
                [
                    self.nod(
                        'arguments',
                        [
                            'posonlyargs',
                            'args',
                            'kwonlyargs',
                            'kw_defaults',
                            'defaults'
                        ],
                        [[], [], [], [], []]
                    ),
                    self.val(nd.target)
                ]
            )
        ];
        self.set_out(
            nd,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [
                        self.jaclib_obj(func),
                        lambda_ex if (func == 'thread_run') else [self.val(nd.target)],
                        []
                    ]
                )
            ]
        );
    }
}

impl JcirGenPass.exit_try_stmt(nd: TryStmt) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'Try',
                ['body', 'handlers', 'orelse', 'finalbody'],
                [
                    self.resolve_stmt_block(nd.body),
                    [self.val(i) for i in nd.excepts],
                    self.outs(nd.else_body) if nd.else_body else [],
                    self.outs(nd.finally_body) if nd.finally_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_except(nd: Except) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'ExceptHandler',
                ['type', 'name', 'body'],
                [
                    self.val(nd.ex_type) if nd.ex_type else None,
                    nd.name.sym_name if nd.name else None,
                    self.resolve_stmt_block(nd.body)
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_finally_stmt(nd: FinallyStmt) -> None {
    self.set_out(nd, self.resolve_stmt_block(nd.body));
}

impl JcirGenPass.exit_iter_for_stmt(nd: IterForStmt) -> None {
    py_nodes: list[CgNode] = [];
    body = self.resolve_stmt_block(nd.body);
    body = body + [self.val(nd.count_by)];
    py_nodes.append(self.val(nd.iter));
    py_nodes.append(
        self.nod(
            'While',
            ['test', 'body', 'orelse'],
            [
                self.val(nd.condition),
                body,
                self.outs(nd.else_body) if nd.else_body else []
            ]
        )
    );
    self.set_out(nd, py_nodes);
}

impl JcirGenPass.exit_in_for_stmt(nd: InForStmt) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'AsyncFor' if nd.is_async else 'For',
                ['target', 'iter', 'body', 'orelse'],
                [
                    self.val(nd.target),
                    self.val(nd.collection),
                    self.resolve_stmt_block(nd.body),
                    self.outs(nd.else_body) if nd.else_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_while_stmt(nd: WhileStmt) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'While',
                ['test', 'body', 'orelse'],
                [
                    self.val(nd.condition),
                    self.resolve_stmt_block(nd.body),
                    self.outs(nd.else_body) if nd.else_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_forever_stmt(nd: ForeverStmt) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'While',
                ['test', 'body', 'orelse'],
                [self.const_of(True), self.resolve_stmt_block(nd.body), []]
            )
        ]
    );
}

impl JcirGenPass.exit_with_stmt(nd: WithStmt) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'AsyncWith' if nd.is_async else 'With',
                ['items', 'body'],
                [
                    [self.val(item) for item in nd.exprs],
                    self.resolve_stmt_block(nd.body)
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_expr_as_item(nd: ExprAsItem) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'withitem',
                ['context_expr', 'optional_vars'],
                [self.val(nd.expr), self.val(nd.alias) if nd.alias else None]
            )
        ]
    );
}

impl JcirGenPass.exit_raise_stmt(nd: RaiseStmt) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'Raise',
                ['exc', 'cause'],
                [
                    self.val(nd.cause) if nd.cause else None,
                    self.val(nd.from_target) if nd.from_target else None
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_assert_stmt(nd: AssertStmt) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'Assert',
                ['test', 'msg'],
                [
                    self.val(nd.condition),
                    self.val(nd.error_msg) if nd.error_msg else None
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_ctrl_stmt(nd: CtrlStmt) -> None {
    if (nd.ctrl.name == Tok.KW_BREAK) {
        self.set_out(nd, [self.nod('Break', [], [])]);
    } elif (nd.ctrl.name == Tok.KW_CONTINUE) {
        if (iter_for_parent := nd.find_parent_of_type(IterForStmt)) {
            count_by = iter_for_parent.count_by;
            self.set_out(nd, [self.val(count_by), self.nod('Continue', [], [])]);
        } else {
            self.set_out(nd, [self.nod('Continue', [], [])]);
        }
    } elif (nd.ctrl.name == Tok.KW_SKIP) {
        self.set_out(nd, [self.nod('Return', ['value'], [None])]);
    }
}

impl JcirGenPass._delete_targets(nd: DeleteStmt) -> list[CgNode] {
    if (isinstance(nd.target, TupleVal) and nd.target.values) {
        return [self.val(i) for i in nd.target.values];
    }
    return [
        i
        for i in self.outs(nd.target)
        if isinstance(i, CgNode)
    ];
}

impl JcirGenPass._delete_ctx_targets(
    targets: list[CgNode], ctx_cls: str
) -> list[CgNode] {
    items: list[CgNode] = targets;
    head = items[0] if items else None;
    if (head is not None and head.cls in ('List', 'Tuple')) {
        items = [
            i
            for i in head.get('elts')
            if isinstance(i, CgNode)
        ];
    }
    result: list[CgNode] = [];
    for target in items {
        result.append(
            self._with_ctx(target, ctx_cls) if target.hasf('ctx') else target
        );
    }
    return result;
}

impl JcirGenPass.exit_delete_stmt(nd: DeleteStmt) -> None {
    destroy_expr = self.nod(
        'Expr',
        ['value'],
        [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.jaclib_obj('destroy'),
                    [
                        self.nod(
                            'List',
                            ['elts', 'ctx'],
                            [
                                self._delete_ctx_targets(
                                    self._delete_targets(nd), 'Load'
                                ),
                                self.nod('Load', [], [])
                            ]
                        )
                    ],
                    []
                ]
            )
        ]
    );
    delete_stmt = self.nod(
        'Delete',
        ['targets'],
        [self._delete_ctx_targets(self._delete_targets(nd), 'Del')]
    );
    self.set_out(nd, [destroy_expr, delete_stmt]);
}

impl JcirGenPass.exit_report_stmt(nd: ReportStmt) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'Expr',
                ['value'],
                [
                    self.nod(
                        'Call',
                        ['func', 'args', 'keywords'],
                        [self.jaclib_obj('log_report'), self.outs(nd.expr), []]
                    )
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_return_stmt(nd: ReturnStmt) -> None {
    self.set_out(
        nd, [self.nod('Return', ['value'], [self.val(nd.expr) if nd.expr else None])]
    );
}

impl JcirGenPass.exit_yield_expr(nd: YieldExpr) -> None {
    if not nd.with_from {
        self.set_out(
            nd, [self.nod('Yield', ['value'], [self.val(nd.expr) if nd.expr else None])]
        );
    } else {
        self.set_out(
            nd,
            [
                self.nod(
                    'YieldFrom',
                    ['value'],
                    [self.val(nd.expr) if nd.expr else self.const_of(None)]
                )
            ]
        );
    }
}

impl JcirGenPass.exit_visit_stmt(nd: VisitStmt) -> None {
    loc = self.name_load('self' if nd.from_walker else Con.VISITOR.value);
    visit_call = self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [self.jaclib_obj('visit'), [loc, self.val(nd.target)], []]
    );
    if (nd.insert_loc is not None) {
        visit_call.get('keywords').append(
            self.nod(
                'keyword', ['arg', 'value'], ['insert_loc', self.val(nd.insert_loc)]
            )
        );
    }
    self.set_out(
        nd,
        [
            self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [
                    self.nod(
                        'UnaryOp',
                        ['op', 'operand'],
                        [self.nod('Not', [], []), visit_call]
                    ),
                    self.outs(nd.else_body),
                    []
                ]
            )
        ]
            if nd.else_body
            else [self.nod('Expr', ['value'], [visit_call])]
    );
}

impl JcirGenPass.exit_disengage_stmt(nd: DisengageStmt) -> None {
    loc = self.name_load('self' if nd.from_walker else Con.VISITOR.value);
    self.set_out(
        nd,
        [
            self.nod(
                'Expr',
                ['value'],
                [
                    self.nod(
                        'Call',
                        ['func', 'args', 'keywords'],
                        [self.jaclib_obj('disengage'), [loc], []]
                    )
                ]
            ),
            self.nod('Return', [], [])
        ]
    );
}

impl JcirGenPass.exit_await_expr(nd: AwaitExpr) -> None {
    self.set_out(nd, [self.nod('Await', ['value'], [self.val(nd.target)])]);
}

impl JcirGenPass.exit_cast_expr(nd: CastExpr) -> None {
    self.set_out(nd, self.outs(nd.value));
}

impl JcirGenPass.exit_assignment(nd: Assignment) -> None {
    value: (CgNode | None) = None;
    if nd.value {
        value = self.val(nd.value);
    } elif nd.is_enum_stmt {
        value = self.nod(
            'Call', ['func', 'args', 'keywords'], [self.name_load('auto'), [], []]
        );
    } elif not nd.type_tag {
        raise RuntimeError(
            self.ice('assignment has no value, no enum default and no type tag')
        );
    }
    targets_ast = [self.val(t) for t in nd.target];
    if nd.type_tag {
        assignment_stmt = self.nod(
            'AnnAssign',
            ['target', 'annotation', 'value', 'simple'],
            [
                targets_ast[0],
                self.val(nd.type_tag),
                self.val(nd.value) if nd.value else None,
                int(isinstance(targets_ast[0], CgNode) and targets_ast[0].cls == 'Name')
            ]
        );
    } elif nd.aug_op {
        assignment_stmt = self.nod(
            'AugAssign',
            ['target', 'op', 'value'],
            [
                targets_ast[0],
                self.val(nd.aug_op),
                value if isinstance(value, CgNode) else self.const_of(None)
            ]
        );
    } else {
        assignment_stmt = self.nod(
            'Assign',
            ['targets', 'value'],
            [targets_ast, value if isinstance(value, CgNode) else self.const_of(None)]
        );
    }
    self.set_out(nd, [assignment_stmt]);
}

impl JcirGenPass.exit_binary_expr(nd: BinaryExpr) -> None {
    if isinstance(nd.op, ConnectOp) {
        left = self.val(nd.right)
            if (nd.op.edge_dir == EdgeDir.IN)
            else self.val(nd.left);
        right = self.val(nd.left)
            if (nd.op.edge_dir == EdgeDir.IN)
            else self.val(nd.right);
        keywords = [
            self.nod('keyword', ['arg', 'value'], ['left', left]),
            self.nod('keyword', ['arg', 'value'], ['right', right])
        ];
        if nd.op.conn_type {
            keywords.append(
                self.nod(
                    'keyword', ['arg', 'value'], ['edge', self.val(nd.op.conn_type)]
                )
            );
        }
        if (nd.op.edge_dir == EdgeDir.ANY) {
            keywords.append(
                self.nod('keyword', ['arg', 'value'], ['undir', self.const_of(True)])
            );
        }
        if nd.op.conn_assign {
            keywords.append(
                self.nod(
                    'keyword',
                    ['arg', 'value'],
                    ['conn_assign', self.val(nd.op.conn_assign)]
                )
            );
        }
        self.set_out(
            nd,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [self.jaclib_obj('connect'), [], keywords]
                )
            ]
        );
    } elif isinstance(nd.op, DisconnectOp) {
        keywords = [
            self.nod('keyword', ['arg', 'value'], ['left', self.val(nd.left)]),
            self.nod('keyword', ['arg', 'value'], ['right', self.val(nd.right)])
        ];
        if (nd.op.edge_spec.edge_dir != EdgeDir.OUT) {
            keywords.append(
                self.nod(
                    'keyword',
                    ['arg', 'value'],
                    [
                        'dir',
                        self.nod(
                            'Attribute',
                            ['value', 'attr', 'ctx'],
                            [
                                self.jaclib_obj('EdgeDir'),
                                EDGE_DIR_NAMES[int(nd.op.edge_spec.edge_dir)],
                                self.nod('Load', [], [])
                            ]
                        )
                    ]
                )
            );
        }
        if nd.op.edge_spec.filter_cond {
            keywords.append(
                self.nod(
                    'keyword',
                    ['arg', 'value'],
                    ['filter', self.val(nd.op.edge_spec.filter_cond)]
                )
            );
        }
        self.set_out(
            nd,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [self.jaclib_obj('disconnect'), [], keywords]
                )
            ]
        );
    } elif (nd.op.name in [Tok.KW_AND.value, Tok.KW_OR.value]) {
        self.set_out(
            nd,
            [
                self.nod(
                    'BoolOp',
                    ['op', 'values'],
                    [self.val(nd.op), [self.val(nd.left), self.val(nd.right)]]
                )
            ]
        );
    } elif ((nd.op.name in [Tok.WALRUS_EQ]) and self.val(nd.left).cls == 'Name') {
        self.val(nd.left).setf('ctx', self.nod('Store', [], []));
        self.set_out(
            nd,
            [
                self.nod(
                    'NamedExpr',
                    ['target', 'value'],
                    [self.val(nd.left), self.val(nd.right)]
                )
            ]
        );
    } elif ((nd.op.name in [Tok.WALRUS_EQ]) and not isinstance(nd.left, Name)) {
        self.set_out(nd, [self.val(nd.right)]);
    } elif self.outs(nd.op) {
        self.set_out(
            nd,
            [
                self.nod(
                    'BinOp',
                    ['left', 'op', 'right'],
                    [self.val(nd.left), self.val(nd.op), self.val(nd.right)]
                )
            ]
        );
    } else {
        self.set_out(nd, self.translate_jac_bin_op(nd));
    }
}

impl JcirGenPass.translate_jac_bin_op(nd: BinaryExpr) -> list {
    if not isinstance(nd.op, Token) {
        raise RuntimeError(
            self.ice('translate_jac_bin_op reached a non-token operator')
        );
    }
    if (nd.op.name in [Tok.PIPE_FWD, Tok.A_PIPE_FWD]) {
        func_node = FuncCall(
            target=nd.right,
            params=list(nd.left.values)
                if (isinstance(nd.left, TupleVal) and nd.left.values)
                else [nd.left],
            genai_call=None,
            kid=nd.kid
        );
        func_node.parent = nd.parent;
        self.exit_func_call(func_node);
        return self.outs(func_node);
    } elif (nd.op.name in [Tok.KW_SPAWN]) {
        return [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [self.jaclib_obj('spawn'), [self.val(nd.left), self.val(nd.right)], []]
            )
        ];
    } elif (nd.op.name in [Tok.PIPE_BKWD, Tok.A_PIPE_BKWD]) {
        func_node = FuncCall(
            target=nd.left,
            params=list(nd.right.values)
                if (isinstance(nd.right, TupleVal) and nd.right.values)
                else [nd.right],
            genai_call=None,
            kid=nd.kid
        );
        func_node.parent = nd.parent;
        self.exit_func_call(func_node);
        return self.outs(func_node);
    } elif (nd.op.name in [Tok.KW_BY]) {
        return [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.jaclib_obj('by_operator'),
                    [self.val(nd.left), self.val(nd.right)],
                    []
                ]
            )
        ];
    } elif ((nd.op.name == Tok.PIPE_FWD) and isinstance(nd.right, TupleVal)) {
        self.emit(E5006);
    } else {
        self.emit(E5007, op=str(nd.op.value));
    }
    return [];
}

impl JcirGenPass.exit_compare_expr(nd: CompareExpr) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'Compare',
                ['left', 'ops', 'comparators'],
                [
                    self.val(nd.left),
                    [self.val(i) for i in nd.ops],
                    [self.val(i) for i in nd.rights]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_cfg_expr(nd: CfgExpr) -> None {
    self.set_out(nd, self.outs(nd.expr));
}

impl JcirGenPass.exit_bool_expr(nd: BoolExpr) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'BoolOp',
                ['op', 'values'],
                [self.val(nd.op), [self.val(i) for i in nd.values]]
            )
        ]
    );
}

impl JcirGenPass.exit_lambda_expr(nd: LambdaExpr) -> None {
    if isinstance(nd.body, list) {
        tail = nd.tail_return_expr();
        if tail is not None {
            self._emit_lambda_expr_body(nd, tail);
            return;
        }
        if (nd.signature and self.outs(nd.signature)) {
            arguments = self.val(nd.signature);
        } else {
            arguments = self.nod(
                'arguments',
                ['posonlyargs', 'args', 'kwonlyargs', 'kw_defaults', 'defaults'],
                [[], [], [], [], []],
                jac_node=nd
            );
        }
        body_stmts = self.resolve_stmt_block(nd.body, doc=None);
        directive_stmts = self.scope_directive_stmts([nd]);
        if directive_stmts {
            body_stmts = [*directive_stmts, *body_stmts];
        }
        if not body_stmts {
            body_stmts = [self.nod('Pass', [], [], jac_node=nd)];
        }
        func_name = self._next_lambda_name();
        returns = self.val(nd.signature.return_type)
            if (
                nd.signature
                and nd.signature.return_type
                and self.outs(nd.signature.return_type)
            )
            else None;
        func_def = self.nod(
            'FunctionDef',
            ['name', 'args', 'body', 'decorator_list', 'returns', 'type_params'],
            [func_name, arguments, body_stmts, [], returns, []],
            jac_node=nd
        );
        self.set_out(nd, [self._function_expr_from_def(func_def, nd)]);
        return;
    }
    if not isinstance(nd.body, Expr) {
        raise RuntimeError(
            self.ice('lambda statement body fell past the FunctionDef path')
        );
    }
    self._emit_lambda_expr_body(nd, nd.body);
}

impl JcirGenPass._emit_lambda_expr_body(nd: LambdaExpr, body_node: Expr) -> None {
    if nd.signature {
        self._remove_lambda_param_annotations(nd.signature);
    }
    if (nd.signature and self.outs(nd.signature)) {
        arguments = self.val(nd.signature);
    } else {
        arguments = self.nod(
            'arguments',
            ['posonlyargs', 'args', 'kwonlyargs', 'kw_defaults', 'defaults'],
            [[], [], [], [], []],
            jac_node=nd
        );
    }
    self.set_out(
        nd,
        [
            self.nod(
                'Lambda',
                ['args', 'body'],
                [arguments, self.val(body_node)],
                jac_node=nd
            )
        ]
    );
}

impl JcirGenPass._remove_lambda_param_annotations(signature: FuncSignature) -> None {
    for param in signature.params {
        if (self.outs(param) and self.val(param).cls == 'arg') {
            self.val(param).setf('annotation', None);
        }
    }
}

impl JcirGenPass._emit_jobj_ref(nd: UnaryExpr) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.builtin_name('jobj'),
                    [],
                    [
                        self.nod(
                            'keyword', ['arg', 'value'], ['id', self.val(nd.operand)]
                        )
                    ]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_unary_expr(nd: UnaryExpr) -> None {
    if nd.ownership in (OwnershipKind.OWN, OwnershipKind.IMM) {
        self.set_out(nd, [self.val(nd.operand)]);
        return;
    }
    if nd.op.name == Tok.BW_AND {
        if is_borrow_kind(nd.ownership) {
            self.set_out(
                nd,
                [
                    self.nod(
                        'Call',
                        ['func', 'args', 'keywords'],
                        [self.builtin_name('jref'), [self.val(nd.operand)], []]
                    )
                ]
            );
        } else {
            self._emit_jobj_ref(nd);
        }
        return;
    }
    op_name = nd.op.name;
    op_cls = UNARY_CLS_BY_NAME[op_name] if op_name in UNARY_CLS_BY_NAME else '';
    if op_cls {
        self.set_out(
            nd,
            [
                self.nod(
                    'UnaryOp',
                    ['op', 'operand'],
                    [self.nod(op_cls, [], []), self.val(nd.operand)]
                )
            ]
        );
        return;
    } elif (nd.op.name in [Tok.PIPE_FWD, Tok.KW_SPAWN, Tok.A_PIPE_FWD]) {
        self.set_out(
            nd,
            [
                self.nod(
                    'Call', ['func', 'args', 'keywords'], [self.val(nd.operand), [], []]
                )
            ]
        );
    } elif (nd.op.name in [Tok.STAR_MUL]) {
        ctx_val = self.py_ctx(nd.operand)
            if isinstance(nd.operand, AstSymbolNode)
            else self.nod('Load', [], []);
        self.set_out(
            nd, [self.nod('Starred', ['value', 'ctx'], [self.val(nd.operand), ctx_val])]
        );
    } elif (nd.op.name in [Tok.STAR_POW]) {
        self.set_out(nd, self.outs(nd.operand));
    } else {
        raise RuntimeError(self.ice("Unknown Unary operator " + nd.op.value));
    }
}

impl JcirGenPass.exit_if_else_expr(nd: IfElseExpr) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'IfExp',
                ['test', 'body', 'orelse'],
                [self.val(nd.condition), self.val(nd.value), self.val(nd.else_value)]
            )
        ]
    );
}

impl JcirGenPass._multi_string_pieces(str_seq: Sequence[UniNode]) -> list {
    pieces: list[any] = [];
    for i in str_seq {
        if isinstance(i, String) {
            pieces.append(i.lit_value);
        } elif isinstance(i, (FString, ExprStmt)) {
            py_val = self.val(i);
            if py_val.cls == 'JoinedStr' {
                for v in py_val.get('values') {
                    pieces.append(v);
                }
            } else {
                pieces.append(py_val);
            }
        } elif (isinstance(i, Token) and (i.name in [Tok.LBRACE, Tok.RBRACE])) {
            continue;
        } else {
            raise RuntimeError(self.ice('Multi string made of something weird.'));
        }
    }
    return pieces;
}

impl JcirGenPass.exit_multi_string(nd: MultiString) -> None {
    lone = nd.strings[0] if (len(nd.strings) == 1) else None;
    if (isinstance(lone, FString) and self.outs(lone)) {
        self.set_out(nd, self.outs(lone));
        return;
    }
    combined_multi: list = [];
    for item in self._multi_string_pieces(nd.strings) {
        if (
            combined_multi
            and isinstance(item, str)
            and isinstance((tail_str := combined_multi[-1]), str)
        ) {
            combined_multi[-1] = tail_str + item;
        } elif (
            combined_multi
            and isinstance(item, bytes)
            and isinstance((tail_bytes := combined_multi[-1]), bytes)
        ) {
            combined_multi[-1] = tail_bytes + item;
        } else {
            combined_multi.append(item);
        }
    }
    for (i, v) in enumerate(combined_multi) {
        if isinstance(v, (str, bytes)) {
            combined_multi[i] = self.const_of(v);
        }
    }
    merged: list[CgNode] = [];
    for v in combined_multi {
        prev: (CgNode | None) = merged[-1] if merged else None;
        folded = False;
        if (prev is not None and isinstance(v, CgNode) and v.cls == 'Constant') {
            next_const = v.get('value');
            prev_const = prev.get('value') if prev.cls == 'Constant' else None;
            if (isinstance(next_const, str) and isinstance(prev_const, str)) {
                merged[-1] = self.const_of(prev_const + next_const);
                folded = True;
            }
        }
        if not folded {
            merged.append(v);
        }
    }
    if not merged {
        self.set_out(nd, [self.const_of('')]);
    } elif (len(merged) == 1 and merged[0].cls == 'Constant') {
        self.set_out(nd, [merged[0]]);
    } else {
        self.set_out(nd, [self.nod('JoinedStr', ['values'], [merged])]);
    }
}

impl JcirGenPass.exit_f_string(nd: FString) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'JoinedStr',
                ['values'],
                [
                    [
                        self.val(part)
                        for part in nd.parts
                        if self.outs(part)
                    ]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_formatted_value(nd: FormattedValue) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'FormattedValue',
                ['value', 'conversion', 'format_spec'],
                [
                    self.val(nd.format_part),
                    nd.conversion,
                    self.val(nd.format_spec) if nd.format_spec else None
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_list_val(nd: ListVal) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'List',
                ['elts', 'ctx'],
                [[self.val(v) for v in nd.values], self.py_ctx(nd)]
            )
        ]
    );
}

impl JcirGenPass.exit_set_val(nd: SetVal) -> None {
    self.set_out(nd, [self.nod('Set', ['elts'], [[self.val(i) for i in nd.values]])]);
}

impl JcirGenPass.exit_tuple_val(nd: TupleVal) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'Tuple',
                ['elts', 'ctx'],
                [[self.val(i) for i in nd.values], self.py_ctx(nd)]
            )
        ]
    );
}

impl JcirGenPass.exit_dict_val(nd: DictVal) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'Dict',
                ['keys', 'values'],
                [
                    [self.val(x.key) if x.key else None for x in nd.kv_pairs],
                    [self.val(x.value) for x in nd.kv_pairs]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_k_v_pair(nd: KVPair) -> None {
    ;
}

impl JcirGenPass.exit_k_w_pair(nd: KWPair) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'keyword',
                ['arg', 'value'],
                [
                    nd.key.sym_name
                        if (nd.key and self.val(nd.key).cls == 'Name')
                        else None,
                    self.val(nd.value)
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_inner_compr(nd: InnerCompr) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'comprehension',
                ['target', 'iter', 'ifs', 'is_async'],
                [
                    self.val(nd.target),
                    self.val(nd.collection),
                    [self.val(x) for x in nd.conditional] if nd.conditional else [],
                    0
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_list_compr(nd: ListCompr) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'ListComp',
                ['elt', 'generators'],
                [self.val(nd.out_expr), [self.val(i) for i in nd.compr]]
            )
        ]
    );
}

impl JcirGenPass.exit_gen_compr(nd: GenCompr) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'GeneratorExp',
                ['elt', 'generators'],
                [self.val(nd.out_expr), [self.val(i) for i in nd.compr]]
            )
        ]
    );
}

impl JcirGenPass.exit_set_compr(nd: SetCompr) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'SetComp',
                ['elt', 'generators'],
                [self.val(nd.out_expr), [self.val(i) for i in nd.compr]]
            )
        ]
    );
}

impl JcirGenPass.exit_dict_compr(nd: DictCompr) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'DictComp',
                ['key', 'value', 'generators'],
                [
                    self.val(nd.kv_pair.key) if nd.kv_pair.key else self.const_of(None),
                    self.val(nd.kv_pair.value),
                    [self.val(i) for i in nd.compr]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_atom_trailer(nd: AtomTrailer) -> None {
    if nd.is_genai {
        self.set_out(nd, []);
    }
    if nd.is_attr {
        if isinstance(nd.right, AstSymbolNode) {
            self.set_out(
                nd,
                [
                    self.nod(
                        'Attribute',
                        ['value', 'attr', 'ctx'],
                        [
                            self.val(nd.target),
                            self._py_name(nd.right),
                            self.py_ctx(nd.right)
                        ]
                    )
                ]
            );
        } else {
            self.emit(E5008);
        }
    } elif isinstance(nd.right, FilterCompr) {
        if self._is_edge_ref_target(nd.target) {
            target_py = self.val(nd.target);
            narrow_kws = self._query_filter_kws(nd.right, 'nd', 'preds');
            target_py.get('args')[0] = self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.nod(
                        'Attribute',
                        ['value', 'attr', 'ctx'],
                        [target_py.get('args')[0], 'narrow', self.nod('Load', [], [])]
                    ),
                    [],
                    narrow_kws
                ]
            );
            self.set_out(nd, [target_py]);
        } else {
            self.set_out(
                nd,
                [
                    self.nod(
                        'Call',
                        ['func', 'args', 'keywords'],
                        [
                            self.jaclib_obj('filter_on'),
                            [],
                            [
                                self.nod(
                                    'keyword',
                                    ['arg', 'value'],
                                    ['items', self.val(nd.target)]
                                ),
                                self.nod(
                                    'keyword',
                                    ['arg', 'value'],
                                    ['func', self.val(nd.right)]
                                )
                            ]
                        ]
                    )
                ]
            );
        }
    } elif isinstance(nd.right, AssignCompr) {
        self.set_out(
            nd,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [
                        self.jaclib_obj('assign_all'),
                        [self.val(nd.target), self.val(nd.right)],
                        []
                    ]
                )
            ]
        );
    } elif (
        isinstance(nd.right, IndexSlice)
        and nd.right.is_range
        and len(nd.right.slices) == 1
        and self._is_edge_ref_target(nd.target)
    ) {
        target_py = self.val(nd.target);
        slc = nd.right.slices[0];
        start_ast = self.val(slc.start) if slc.start else self.const_of(None);
        stop_ast = self.val(slc.stop) if slc.stop else self.const_of(None);
        step_ast = self.val(slc.step) if slc.step else self.const_of(None);
        slice_call = self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [self.name_load('slice'), [start_ast, stop_ast, step_ast], []]
        );
        target_py.get('keywords').append(
            self.nod('keyword', ['arg', 'value'], ['slc', slice_call])
        );
        self.set_out(nd, [target_py]);
    } else {
        self.set_out(
            nd,
            [
                self.nod(
                    'Subscript',
                    ['value', 'slice', 'ctx'],
                    [
                        self.val(nd.target),
                        self.val(nd.right),
                        self.py_ctx(nd.right)
                            if isinstance(nd.right, AstSymbolNode)
                            else self.nod('Load', [], [])
                    ]
                )
            ]
        );
        if self.val(nd.right).hasf('ctx') {
            self.val(nd.right).setf('ctx', self.nod('Load', [], []));
        }
    }
    if nd.is_null_ok {
        walrus_assign = self.nod(
            'NamedExpr',
            ['target', 'value'],
            [
                self.nod(
                    'Name', ['id', 'ctx'], ['__jac_tmp', self.nod('Store', [], [])]
                ),
                self.val(nd.target)
            ]
        );
        tmp_ref = self.name_load('__jac_tmp');
        none_const = self.const_of(None);
        cur = self.val(nd);
        body_expr: CgNode;
        if cur.cls == 'Attribute' {
            body_expr = self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.name_load('getattr'),
                    [tmp_ref, self.const_of(cur.get('attr')), none_const],
                    []
                ]
            );
        } elif cur.cls == 'Call' {
            cfunc = cur.get('func');
            if (
                isinstance(cfunc, CgNode)
                and (
                    cfunc.cls == 'Attribute'
                    or (cfunc.cls == 'Name' and cfunc.get('id') == 'filter_on')
                )
            ) {
                for kw in cur.get('keywords') {
                    if (isinstance(kw, CgNode) and kw.get('arg') == 'items') {
                        kw.setf('value', tmp_ref);
                    }
                }
            }
            if (
                isinstance(cfunc, CgNode)
                and (
                    cfunc.cls == 'Attribute'
                    or (cfunc.cls == 'Name' and cfunc.get('id') == 'assign_all')
                )
                and cur.get('args')
            ) {
                cur.get('args')[0] = tmp_ref;
            }
            body_expr = cur;
        } elif cur.cls == 'Subscript' {
            body_expr = self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [self.jaclib_obj('safe_subscript'), [tmp_ref, cur.get('slice')], []]
            );
        } else {
            cur.setf('value', tmp_ref);
            body_expr = cur;
        }
        self.set_out(
            nd,
            [
                self.nod(
                    'IfExp',
                    ['test', 'body', 'orelse'],
                    [
                        self.nod(
                            'Compare',
                            ['left', 'ops', 'comparators'],
                            [walrus_assign, [self.nod('IsNot', [], [])], [none_const]]
                        ),
                        body_expr,
                        none_const
                    ]
                )
            ]
        );
    }
}

impl JcirGenPass.exit_atom_unit(nd: AtomUnit) -> None {
    if (
        isinstance(nd.value, Ability)
        and self.outs(nd.value)
        and self.val(nd.value).cls in ('FunctionDef', 'AsyncFunctionDef')
    ) {
        self.set_out(nd, [self._function_expr_from_def(self.val(nd.value), nd)]);
        return;
    }
    self.set_out(nd, self.outs(nd.value));
}

impl JcirGenPass.gen_call_args(nd: FuncCall) -> tuple[(list, list)] {
    args: list[CgNode] = [];
    keywords: list[CgNode] = [];
    if nd.params {
        for x in nd.params {
            if (isinstance(x, UnaryExpr) and (x.op.name == Tok.STAR_POW)) {
                keywords.append(
                    self.nod('keyword', ['value'], [self.val(x.operand)], jac_node=x)
                );
            } elif isinstance(x, Expr) {
                args.append(self.val(x));
            } elif (isinstance(x, KWPair) and self.val(x).cls == 'keyword') {
                keywords.append(self.val(x));
            } else {
                raise RuntimeError(self.ice('Invalid Parameter'));
            }
        }
    }
    return (args, keywords);
}

impl JcirGenPass.exit_func_call(nd: FuncCall) -> None {
    if nd.genai_call {
        self._refuse(nd, 'genai call expression');
    }
    if (
        isinstance(nd.target, SpecialVarRef)
        and nd.target.name == Tok.KW_ROOT
        and (nd.params is None or len(nd.params) == 0)
    ) {
        self.set_out(nd, self.outs(nd.target));
        return;
    }
    if (
        isinstance(nd.target, AtomTrailer)
        and nd.target.is_attr
        and isinstance(nd.target.right, Name)
        and nd.target.right.sym_name == "chunks"
        and nd.params is not None
        and len(nd.params) == 1
    ) {
        _ck_m = nd.chunks_recv_type if nd.chunks_recv_type is not None else "";
        if (
            _ck_m == "list"
            or _ck_m.startswith("list[")
            or (_ck_m in ("", "Unknown", "None") and nd.target.right.sym is None)
        ) {
            self.set_out(
                nd,
                [
                    self.nod(
                        'Call',
                        ['func', 'args', 'keywords'],
                        [
                            self.builtin_name('_jac_chunks'),
                            [self.val(nd.target.target), self.val(nd.params[0])],
                            []
                        ]
                    )
                ]
            );
            return;
        }
    }
    func = self.val(nd.target);
    (args, keywords) = self.gen_call_args(nd);
    self.set_out(
        nd, [self.nod('Call', ['func', 'args', 'keywords'], [func, args, keywords])]
    );
}

impl JcirGenPass.exit_index_slice(nd: IndexSlice) -> None {
    if nd.is_range {
        if (len(nd.slices) > 1) {
            self.set_out(
                nd,
                [
                    self.nod(
                        'Tuple',
                        ['elts', 'ctx'],
                        [
                            [
                                self.nod(
                                    'Slice',
                                    ['lower', 'upper', 'step'],
                                    [
                                        self.val(slc.start) if slc.start else None,
                                        self.val(slc.stop) if slc.stop else None,
                                        self.val(slc.step) if slc.step else None
                                    ]
                                ) for slc in nd.slices
                            ],
                            self.nod('Load', [], [])
                        ]
                    )
                ]
            );
        } elif (len(nd.slices) == 1) {
            slc = nd.slices[0];
            self.set_out(
                nd,
                [
                    self.nod(
                        'Slice',
                        ['lower', 'upper', 'step'],
                        [
                            self.val(slc.start) if slc.start else None,
                            self.val(slc.stop) if slc.stop else None,
                            self.val(slc.step) if slc.step else None
                        ]
                    )
                ]
            );
        }
    } elif ((len(nd.slices) > 0) and (nd.slices[0].start is not None)) {
        self.set_out(nd, self.outs(nd.slices[0].start));
    } else {
        self.set_out(nd, []);
    }
}

impl JcirGenPass.exit_special_var_ref(nd: SpecialVarRef) -> None {
    if (nd.name == Tok.KW_SUPER) {
        self.set_out(
            nd,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [
                        self.nod('Name', ['id', 'ctx'], ['super', self.py_ctx(nd)]),
                        [],
                        []
                    ]
                )
            ]
        );
    } elif (nd.name == Tok.KW_ROOT) {
        self.set_out(
            nd,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [self.jaclib_obj('root'), [], []]
                )
            ]
        );
    } else {
        self.set_out(
            nd, [self.nod('Name', ['id', 'ctx'], [self._py_name(nd), self.py_ctx(nd)])]
        );
    }
}

impl JcirGenPass._is_edge_ref_target(target: UniNode) -> bool {
    if isinstance(target, EdgeRefTrailer) {
        return not target.edges_only and not target.is_async;
    }
    if (isinstance(target, AtomTrailer) and isinstance(target.right, FilterCompr)) {
        return self._is_edge_ref_target(target.target);
    }
    return False;
}

impl JcirGenPass._cmp_op_str(op: CgNode) -> (str | None) {
    if op.cls == 'Eq' {
        return '==';
    }
    if op.cls == 'NotEq' {
        return '!=';
    }
    if op.cls == 'Lt' {
        return '<';
    }
    if op.cls == 'LtE' {
        return '<=';
    }
    if op.cls == 'Gt' {
        return '>';
    }
    if op.cls == 'GtE' {
        return '>=';
    }
    if op.cls == 'In' {
        return 'in';
    }
    return None;
}

impl JcirGenPass._query_filter_kws(
    fc: FilterCompr, type_arg: str, preds_arg: str
) -> list {
    kws: list[CgNode] = [];
    if fc.f_type {
        kws.append(
            self.nod('keyword', ['arg', 'value'], [type_arg, self.val(fc.f_type)])
        );
    }
    preds: list[CgNode] = [];
    for x in fc.compares {
        cmp_ast = self.val(x);
        reason: str = '';
        field_name: str = '';
        op_str: str = '';
        if cmp_ast.cls != 'Compare' {
            reason = 'not a comparison';
        } else {
            ops = cmp_ast.get('ops');
            left = cmp_ast.get('left');
            if len(ops) != 1 {
                reason = 'chained comparisons are not admitted';
            } elif (not isinstance(left, CgNode)) or (left.cls != 'Name') {
                reason = 'left side must be a declared field name';
            } else {
                op_node = ops[0];
                op_label = '?';
                if isinstance(op_node, CgNode) {
                    op_label = op_node.cls;
                    resolved = self._cmp_op_str(op_node);
                    if resolved is not None {
                        op_str = resolved;
                    }
                }
                if not op_str {
                    reason = f"operator '{op_label}' is not admitted";
                } else {
                    field_id = left.get('id');
                    if isinstance(field_id, str) {
                        field_name = field_id;
                    }
                }
            }
        }
        if reason {
            self.emit(E5094, node_override=x, reason=reason);
        } else {
            preds.append(
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [
                        self.jaclib_obj('QPred'),
                        [],
                        [
                            self.nod(
                                'keyword',
                                ['arg', 'value'],
                                ['field', self.const_of(field_name)]
                            ),
                            self.nod(
                                'keyword',
                                ['arg', 'value'],
                                ['op', self.const_of(op_str)]
                            ),
                            self.nod(
                                'keyword',
                                ['arg', 'value'],
                                ['value', cmp_ast.get('comparators')[0]]
                            )
                        ]
                    ]
                )
            );
        }
    }
    if preds {
        kws.append(
            self.nod(
                'keyword',
                ['arg', 'value'],
                [
                    preds_arg,
                    self.nod('List', ['elts', 'ctx'], [preds, self.nod('Load', [], [])])
                ]
            )
        );
    }
    return kws;
}

impl JcirGenPass.exit_edge_ref_trailer(nd: EdgeRefTrailer) -> None {
    origin: (CgNode | None) = None;
    cur = nd.chain[0];
    chomp = [*nd.chain[1:]];
    from_visit = bool(isinstance(nd.parent, VisitStmt));
    if not isinstance(cur, EdgeOpRef) {
        origin = self.val(cur);
        cur = chomp.pop(0);
    }
    origin_ast = origin if origin is not None else self.val(cur);
    hops: list[CgNode] = [];
    while True {
        if not isinstance(cur, EdgeOpRef) {
            raise RuntimeError(self.ice('edge ref chain hop is not an EdgeOpRef'));
        }
        keywords = [
            self.nod(
                'keyword', ['arg', 'value'], ['dir', self.const_of(cur.edge_dir.value)]
            )
        ];
        if cur.filter_cond {
            keywords.extend(self._query_filter_kws(cur.filter_cond, 'edge', 'epreds'));
        }
        if (chomp and not isinstance(chomp[0], EdgeOpRef)) {
            filt = chomp.pop(0);
            if isinstance(filt, FilterCompr) {
                keywords.extend(self._query_filter_kws(filt, 'nd', 'preds'));
            } else {
                keywords.append(
                    self.nod('keyword', ['arg', 'value'], ['only', self.val(filt)])
                );
            }
        }
        hops.append(
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [self.jaclib_obj('QHop'), [], keywords]
            )
        );
        if chomp {
            cur = chomp.pop(0);
        } else {
            break;
        }
    }
    gq_kws = [
        self.nod(
            'keyword',
            ['arg', 'value'],
            [
                'hops',
                self.nod('List', ['elts', 'ctx'], [hops, self.nod('Load', [], [])])
            ]
        )
    ];
    if nd.edges_only {
        gq_kws.append(
            self.nod('keyword', ['arg', 'value'], ['edges_only', self.const_of(True)])
        );
    }
    pynode = self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [self.jaclib_obj('GraphQuery'), [origin_ast], gq_kws]
    );
    if from_visit {
        pynode = self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [
                self.nod(
                    'Attribute',
                    ['value', 'attr', 'ctx'],
                    [pynode, 'visit', self.nod('Load', [], [])]
                ),
                [],
                []
            ]
        );
    }
    if nd.is_async {
        pynode = self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [self.jaclib_obj('arefs'), [pynode], []]
        );
    } else {
        pynode = self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [self.jaclib_obj('refs'), [pynode], []]
        );
    }
    self.set_out(nd, [pynode]);
}

impl JcirGenPass.exit_edge_op_ref(nd: EdgeOpRef) -> None {
    self.set_out(nd, [self.name_load(Con.HERE.value if nd.from_walker else 'self')]);
}

impl JcirGenPass.exit_disconnect_op(nd: DisconnectOp) -> None {
    self.set_out(nd, self.outs(nd.edge_spec));
}

impl JcirGenPass.exit_connect_op(nd: ConnectOp) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.jaclib_obj('build_edge'),
                    [],
                    [
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            ['is_undirected', self.const_of(nd.edge_dir == EdgeDir.ANY)]
                        ),
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            [
                                'conn_type',
                                self.val(nd.conn_type)
                                    if nd.conn_type
                                    else self.const_of(None)
                            ]
                        ),
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            [
                                'conn_assign',
                                self.val(nd.conn_assign)
                                    if nd.conn_assign
                                    else self.const_of(None)
                            ]
                        )
                    ]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_filter_compr(nd: FilterCompr) -> None {
    iter_name = 'i';
    comprs: list[CgNode] = [];
    if nd.f_type {
        f_type_recipe = self.val(nd.f_type);
        cur_loc = self.nod('Pass', [], []);
        f_type_recipe.l1 = cur_loc.l1;
        f_type_recipe.c1 = cur_loc.c1;
        f_type_recipe.l2 = cur_loc.l2;
        f_type_recipe.c2 = cur_loc.c2;
        comprs.append(
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.name_load('isinstance'),
                    [self.name_load(iter_name), f_type_recipe],
                    []
                ]
            )
        );
    }
    for x in nd.compares {
        x_recipe = self.val(x);
        if x_recipe.cls != 'Compare' {
            continue;
        }
        left = x_recipe.get('left');
        if (not isinstance(left, CgNode)) or (left.cls != 'Name') {
            continue;
        }
        comprs.append(
            self.nod(
                'Compare',
                ['left', 'ops', 'comparators'],
                [
                    self.nod(
                        'Attribute',
                        ['value', 'attr', 'ctx'],
                        [
                            self.name_load(iter_name, jac_node=x),
                            left.get('id'),
                            self.nod('Load', [], [], jac_node=x)
                        ],
                        jac_node=x
                    ),
                    x_recipe.get('ops'),
                    x_recipe.get('comparators')
                ],
                jac_node=x
            )
        );
    }
    body: (CgNode | None) = None;
    if (len(comprs) > 1) {
        body = self.nod('BoolOp', ['op', 'values'], [self.nod('And', [], []), comprs]);
    } elif comprs {
        body = comprs[0];
    }
    if body {
        self.set_out(
            nd,
            [
                self.nod(
                    'Lambda',
                    ['args', 'body'],
                    [
                        self.nod(
                            'arguments',
                            [
                                'posonlyargs',
                                'args',
                                'kwonlyargs',
                                'kw_defaults',
                                'defaults'
                            ],
                            [[], [self.nod('arg', ['arg'], [iter_name])], [], [], []]
                        ),
                        body
                    ]
                )
            ]
        );
    }
}

impl JcirGenPass.exit_assign_compr(nd: AssignCompr) -> None {
    keys: list[CgNode] = [];
    values: list[CgNode] = [];
    for i in nd.assigns {
        if i.key {
            keys.append(self.const_of(i.key.sym_name));
            values.append(self.val(i.value));
        }
    }
    key_tup = self.nod('Tuple', ['elts', 'ctx'], [keys, self.nod('Load', [], [])]);
    val_tup = self.nod('Tuple', ['elts', 'ctx'], [values, self.nod('Load', [], [])]);
    self.set_out(
        nd,
        [
            self.nod(
                'Tuple', ['elts', 'ctx'], [[key_tup, val_tup], self.nod('Load', [], [])]
            )
        ]
    );
}

impl JcirGenPass.exit_match_stmt(nd: MatchStmt) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'Match',
                ['subject', 'cases'],
                [self.val(nd.target), [self.val(x) for x in nd.cases]]
            )
        ]
    );
}

impl JcirGenPass.exit_match_case(nd: MatchCase) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'match_case',
                ['pattern', 'guard', 'body'],
                [
                    self.val(nd.pattern),
                    self.val(nd.guard) if nd.guard else None,
                    self.resolve_stmt_block(nd.body)
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_match_or(nd: MatchOr) -> None {
    self.set_out(
        nd, [self.nod('MatchOr', ['patterns'], [[self.val(x) for x in nd.patterns]])]
    );
}

impl JcirGenPass.exit_match_as(nd: MatchAs) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'MatchAs',
                ['name', 'pattern'],
                [nd.name.sym_name, self.val(nd.pattern) if nd.pattern else None]
            )
        ]
    );
}

impl JcirGenPass.exit_match_wild(nd: MatchWild) -> None {
    self.set_out(nd, [self.nod('MatchAs', [], [])]);
}

impl JcirGenPass.exit_match_value(nd: MatchValue) -> None {
    self.set_out(nd, [self.nod('MatchValue', ['value'], [self.val(nd.value)])]);
}

impl JcirGenPass.exit_match_singleton(nd: MatchSingleton) -> None {
    self.set_out(nd, [self.nod('MatchSingleton', ['value'], [nd.value.lit_value])]);
}

impl JcirGenPass.exit_match_sequence(nd: MatchSequence) -> None {
    self.set_out(
        nd,
        [self.nod('MatchSequence', ['patterns'], [[self.val(x) for x in nd.values]])]
    );
}

impl JcirGenPass.exit_match_mapping(nd: MatchMapping) -> None {
    map_keys: list[CgNode] = [];
    map_patterns: list[CgNode] = [];
    rest: (str | None) = None;
    for i in nd.values {
        if (
            isinstance(i, MatchKVPair)
            and isinstance(i.key, MatchValue)
            and self.outs(i.key.value)
            and self.outs(i.value)
        ) {
            map_keys.append(self.val(i.key.value));
            map_patterns.append(self.val(i.value));
        } elif isinstance(i, MatchStar) {
            rest = i.name.sym_name;
        }
    }
    self.set_out(
        nd,
        [
            self.nod(
                'MatchMapping',
                ['keys', 'patterns', 'rest'],
                [map_keys, map_patterns, rest]
            )
        ]
    );
}

impl JcirGenPass.exit_match_k_v_pair(nd: MatchKVPair) -> None {
    ;
}

impl JcirGenPass.exit_match_star(nd: MatchStar) -> None {
    self.set_out(nd, [self.nod('MatchStar', ['name'], [nd.name.sym_name])]);
}

impl JcirGenPass.exit_match_arch(nd: MatchArch) -> None {
    self.set_out(
        nd,
        [
            self.nod(
                'MatchClass',
                ['cls', 'patterns', 'kwd_attrs', 'kwd_patterns'],
                [
                    self.val(nd.name),
                    [self.val(x) for x in (nd.arg_patterns or [])],
                    [
                        x.key.sym_name
                        for x in (nd.kw_patterns or [])
                        if isinstance(x.key, NameAtom)
                    ],
                    [self.val(x.value) for x in (nd.kw_patterns or [])]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_token(nd: Token) -> None {
    if nd.name in TOKEN_CLS_BY_NAME {
        self.set_out(nd, [self.nod(TOKEN_CLS_BY_NAME[nd.name], [], [])]);
    }
}

impl JcirGenPass.exit_name(nd: Name) -> None {
    name = nd.sym_name;
    if name == "Self" {
        resolved = self._resolve_self_type(nd);
        if resolved is not None {
            self.set_out(nd, [resolved]);
            return;
        }
    }
    if not is_identifier_slot(nd) {
        if (name in self._get_builtin_names()) {
            self.builtin_imports.add(name);
        }
        if (name in self._get_ambient_typing_names()) {
            self.typing_imports.add(name);
        }
    }
    self.set_out(nd, [self.nod('Name', ['id', 'ctx'], [name, self.py_ctx(nd)])]);
}

impl JcirGenPass._resolve_self_type(nd: Name) -> (CgNode | None) {
    arch = nd.find_parent_of_type(Archetype);
    enum_parent = nd.find_parent_of_type(Enum) if not arch else None;
    enclosing = arch or enum_parent;
    enclosing_name: str | None = None;
    if enclosing {
        enclosing_name = enclosing.name.sym_name if enclosing.name else None;
    }
    if not enclosing_name {
        impl_def = nd.find_parent_of_type(ImplDef);
        if (impl_def and impl_def.target and len(impl_def.target) > 0) {
            enclosing_name = impl_def.target[0].sym_name
                if isinstance(impl_def.target[0], NameAtom)
                else None;
        }
    }
    if not enclosing_name {
        return None;
    }
    if self._is_in_type_annotation(nd) {
        return self.name_load(enclosing_name);
    }
    ability = nd.find_parent_of_type(Ability);
    impl_def = nd.find_parent_of_type(ImplDef);
    is_in_classmethod = False;
    is_in_method = False;
    if ability {
        is_in_classmethod = ability.is_cls_method;
        is_in_method = ability.is_method
            and not ability.is_static
            and not ability.is_cls_method;
    } elif (
        impl_def and impl_def.decl_link and isinstance(impl_def.decl_link, Ability)
    ) {
        is_in_classmethod = impl_def.decl_link.is_cls_method;
        is_in_method = (
            impl_def.decl_link.is_method
            and not impl_def.decl_link.is_static
            and not impl_def.decl_link.is_cls_method
        );
    }
    if is_in_classmethod {
        return self.nod('Name', ['id', 'ctx'], ['cls', self.py_ctx(nd)]);
    }
    if is_in_method {
        return self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [self.name_load('type'), [self.name_load('self')], []]
        );
    }
    return self.nod('Name', ['id', 'ctx'], [enclosing_name, self.py_ctx(nd)]);
}

impl JcirGenPass._is_in_type_annotation(nd: UniNode) -> bool {
    parent = nd.parent;
    while parent {
        if isinstance(parent, FuncSignature) {
            if parent.return_type {
                return self._is_descendant_of(nd, parent.return_type);
            }
        }
        if isinstance(parent, ParamVar) {
            if parent.type_tag {
                return True;
            }
        }
        if isinstance(parent, HasVar) {
            if parent.type_tag {
                return True;
            }
        }
        if isinstance(parent, SubTag) {
            return True;
        }
        parent = parent.parent;
    }
    return False;
}

impl JcirGenPass._is_descendant_of(nd: UniNode, ancestor: UniNode) -> bool {
    if nd is ancestor {
        return True;
    }
    current = nd.parent;
    while current {
        if current is ancestor {
            return True;
        }
        current = current.parent;
    }
    return False;
}

impl JcirGenPass.exit_float(nd: Float) -> None {
    self.set_out(nd, [self.const_of(float(nd.value))]);
}

impl JcirGenPass.exit_int(nd: Int) -> None {
    self.set_out(nd, [self.const_of(int(nd.value, 0))]);
}

impl JcirGenPass.exit_string(nd: String) -> None {
    self.set_out(nd, [self.const_of(nd.lit_value)]);
}

impl JcirGenPass.exit_bool(nd: Bool) -> None {
    self.set_out(nd, [self.const_of(nd.value == 'True')]);
}

impl JcirGenPass.exit_builtin_type(nd: BuiltinType) -> None {
    if nd.sym_name == "any" {
        parent = nd.parent;
        is_call_func = (
            parent is not None and isinstance(parent, FuncCall) and parent.target is nd
        );
        if not is_call_func {
            self.typing_imports.add("Any");
            self.set_out(
                nd, [self.nod('Name', ['id', 'ctx'], ["Any", self.py_ctx(nd)])]
            );
            return;
        }
    }
    self.set_out(nd, [self.nod('Name', ['id', 'ctx'], [nd.sym_name, self.py_ctx(nd)])]);
}

impl JcirGenPass.exit_null(nd: Null) -> None {
    self.set_out(nd, [self.const_of(None)]);
}

impl JcirGenPass.exit_ellipsis(nd: Ellipsis) -> None {
    self.set_out(nd, [self.const_of(CgEllipsis())]);
}

impl JcirGenPass.exit_jsx_element(nd: JsxElement) -> None {
    tag_arg: CgNode;
    if nd.dynamic_tag is not None {
        tag_arg = self.val(nd.dynamic_tag);
    } elif (nd.is_fragment or not nd.name) {
        tag_arg = self.const_of(None, jac_node=nd);
    } else {
        tag_arg = self.val(nd.name);
    }
    attrs_expr: CgNode;
    if not nd.attributes {
        attrs_expr = self.nod('Dict', ['keys', 'values'], [[], []], jac_node=nd);
    } elif any(isinstance(attr, JsxSpreadAttribute) for attr in nd.attributes) {
        attrs_expr = self.nod('Dict', ['keys', 'values'], [[], []], jac_node=nd);
        for attr in nd.attributes {
            if isinstance(attr, JsxSpreadAttribute) {
                attrs_expr = self.nod(
                    'Dict',
                    ['keys', 'values'],
                    [[None, None], [attrs_expr, self.val(attr)]],
                    jac_node=attr
                );
            } elif isinstance(attr, JsxNormalAttribute) {
                attr_tuple = self.val(attr);
                attrs_expr = self.nod(
                    'Dict',
                    ['keys', 'values'],
                    [
                        [None, attr_tuple.get('elts')[0]],
                        [attrs_expr, attr_tuple.get('elts')[1]]
                    ],
                    jac_node=attr
                );
            }
        }
    } else {
        dkeys: list = [];
        dvalues: list = [];
        for attr in nd.attributes {
            if isinstance(attr, JsxNormalAttribute) {
                attr_tuple = self.val(attr);
                dkeys.append(attr_tuple.get('elts')[0]);
                dvalues.append(attr_tuple.get('elts')[1]);
            }
        }
        attrs_expr = self.nod(
            'Dict', ['keys', 'values'], [dkeys, dvalues], jac_node=nd
        );
    }
    children_arg: CgNode;
    if nd.children {
        kept_children = [
            c
            for c in nd.children
            if not isinstance(c, JsxComment)
                and not (isinstance(c, JsxText) and not c.get_normalized_text())
        ];
        children_arg = self.nod(
            'List',
            ['elts', 'ctx'],
            [
                [self.val(c) for c in kept_children],
                self.nod('Load', [], [], jac_node=nd)
            ],
            jac_node=nd
        );
    } else {
        children_arg = self.nod(
            'List',
            ['elts', 'ctx'],
            [[], self.nod('Load', [], [], jac_node=nd)],
            jac_node=nd
        );
    }
    self.set_out(
        nd,
        [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [self.jaclib_obj('jsx'), [tag_arg, attrs_expr, children_arg], []],
                jac_node=nd
            )
        ]
    );
}

impl JcirGenPass.exit_jsx_element_name(nd: JsxElementName) -> None {
    name_str = '.'.join(part.value for part in nd.parts);
    if (nd.parts and nd.parts[0].value[0].isupper()) {
        self.set_out(nd, [self.name_load(name_str, jac_node=nd)]);
    } else {
        self.set_out(nd, [self.const_of(name_str, jac_node=nd)]);
    }
}

impl JcirGenPass.exit_jsx_spread_attribute(nd: JsxSpreadAttribute) -> None {
    self.set_out(nd, [self.val(nd.expr)]);
}

impl JcirGenPass.exit_jsx_normal_attribute(nd: JsxNormalAttribute) -> None {
    if not nd.name {
        self.set_out(nd, []);
        return;
    }
    key_ast = self.const_of(nd.name.value, jac_node=nd.name);
    value_ast: CgNode;
    if (nd.value and isinstance(nd.value, String)) {
        import from html { unescape }
        value_ast = self.const_of(unescape(nd.value.lit_value), jac_node=nd.value);
    } elif (nd.value and self.outs(nd.value)) {
        value_ast = self.val(nd.value);
    } else {
        value_ast = self.const_of(True, jac_node=nd);
    }
    self.set_out(
        nd,
        [
            self.nod(
                'Tuple',
                ['elts', 'ctx'],
                [[key_ast, value_ast], self.nod('Load', [], [], jac_node=nd)],
                jac_node=nd
            )
        ]
    );
}

impl JcirGenPass.exit_jsx_text(nd: JsxText) -> None {
    import from html { unescape }
    self.set_out(nd, [self.const_of(unescape(nd.get_normalized_text()), jac_node=nd)]);
}

impl JcirGenPass.exit_jsx_expression(nd: JsxExpression) -> None {
    self.set_out(nd, [self.val(nd.expr)]);
}

impl JcirGenPass.exit_jsx_slot(nd: JsxSlot) -> None {
    self.set_out(nd, [self.const_of(None, jac_node=nd)]);
}

impl JcirGenPass.exit_jsx_comment(nd: JsxComment) -> None {
    self.set_out(nd, []);
}

impl JcirGenPass.exit_semi(nd: Semi) -> None {
    ;
}

impl JcirGenPass.exit_comment_token(nd: CommentToken) -> None {
    ;
}

impl JcirGenPass._gen_native_interop_stubs(nd: UniNode) -> None {
    manifest = self.ir_in.gen.interop_manifest;
    parts: list[str] = [];
    names: list[str] = [];
    if (manifest and manifest.bindings) {
        import from jaclang.jac0core.interop_bridge { JAC_TO_CTYPES_STR }
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
    import from jaclang.jac0core.codeinfo { native_test_symbol, native_glob_init_name }
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
        "from jaclang.runtimelib.test import invoke_native_test as _jac_invoke",
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
    if not sv_to_sv_names {
        return False;
    }
    boundary_types = manifest.boundary_types;
    parts: list = [
        "from jaclang.runtimelib import sv_client as __jac_sv_client",
        "__jac_sv_client._declare_consumer_provider(__name__, '" + module_name + "')"
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
                    local_name, item_name, module_name, binding, boundary_types
                )
            );
            names.append(local_name);
            continue;
        }
        parts.append(
            self._gen_py_sv_func_stub(
                local_name, item_name, module_name, binding, boundary_types
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

impl JcirGenPass._gen_py_sv_func_stub(
    local_name: str,
    func_name: str,
    module_name: str,
    binding: InteropBinding,
    boundary_types: dict[(str, BoundaryTypeInfo)]
) -> str {
    params = ', '.join(binding.param_names) if binding.param_names else '';
    args_kvs: list[str] = [];
    for i in range(len(binding.param_names)) {
        pname = binding.param_names[i];
        ptype = binding.param_types[i] if i < len(binding.param_types) else '';
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
    args_dict = '{' + ', '.join(args_kvs) + '}';
    ret_type = binding.ret_type;
    raw_call = (
        "__jac_sv_client.call('"
        + module_name
        + "', '"
        + func_name
        + "', "
        + args_dict
        + ")"
    );
    if (ret_type in boundary_types and boundary_types[ret_type].kind != "enum") {
        ret_expr = ret_type + '._from_wire(' + raw_call + ')';
    } else {
        ret_expr = raw_call;
    }
    return 'def ' + local_name + '(' + params + '):\n    return ' + ret_expr;
}

impl JcirGenPass._gen_py_sv_walker_stub(
    local_name: str,
    walker_name: str,
    module_name: str,
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
    args_kvs: list[str] = [];
    for i in range(len(field_names)) {
        pname = field_names[i];
        ptype = field_types[i] if i < len(field_types) else '';
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
    args_dict = '{' + ', '.join(args_kvs) + '}';
    init_params = ', '.join(
        ['cls'] + [field_names[i] + '=None' for i in range(len(field_names))]
    );
    lines: list[str] = [];
    lines.append('class ' + local_name + ':');
    lines.append('    __jac_fields__ = ' + fields_repr);
    lines.append('    __jac_walker_name__ = ' + "'" + walker_name + "'");
    lines.append('    __jac_provider_module__ = ' + "'" + module_name + "'");
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
            + module_name
            + "', '"
            + walker_name
            + "', kwargs, cls)"
    );
    lines.append('    def __init__(self, *args, **kwargs):');
    lines.append('        pass');
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

impl JcirGenPass._invoke_llm_call(
    model: CgNode, caller: CgNode, args: CgNode, is_async: bool = False
) -> CgNode {
    mtir_ast = self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [
            self.jaclib_obj('get_mtir'),
            [],
            [
                self.nod('keyword', ['arg', 'value'], ['caller', caller]),
                self.nod('keyword', ['arg', 'value'], ['args', args]),
                self.nod(
                    'keyword',
                    ['arg', 'value'],
                    [
                        'call_params',
                        self.nod(
                            'Attribute',
                            ['value', 'attr', 'ctx'],
                            [model, 'call_params', self.nod('Load', [], [])]
                        )
                    ]
                )
            ]
        ]
    );
    hook_name = 'acall_llm' if is_async else 'call_llm';
    call = self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [
            self.jaclib_obj(hook_name),
            [],
            [
                self.nod('keyword', ['arg', 'value'], ['model', model]),
                self.nod('keyword', ['arg', 'value'], ['mt_run', mtir_ast])
            ]
        ]
    );
    if is_async {
        return self.nod('Await', ['value'], [call]);
    }
    return call;
}

impl JcirGenPass.gen_llm_body(nd: Ability) -> list {
    assert isinstance(nd.signature, FuncSignature);
    model_expr: CgNode;
    if (
        nd.signature.return_type
        and isinstance(nd.signature.return_type, BinaryExpr)
        and isinstance(nd.signature.return_type.op, Token)
        and (nd.signature.return_type.op.name == Tok.KW_BY)
    ) {
        model_expr = self.val(nd.signature.return_type.right);
    } elif isinstance(nd.body, Expr) {
        model_expr = self.val(nd.body);
    } else {
        raise RuntimeError(self.ice('gen_llm_body called without model expression'));
    }
    llm_name_ref = nd.name_ref;
    caller: CgNode;
    if nd.method_owner {
        owner = self.nod(
            'Name',
            ['id', 'ctx'],
            [
                'self' if not nd.is_static else nd.method_owner.sym_name,
                self.nod('Load', [], [], jac_node=nd.method_owner)
            ],
            jac_node=nd.method_owner
        );
        caller = self.nod(
            'Attribute',
            ['value', 'attr', 'ctx'],
            [
                owner,
                self._py_name(llm_name_ref) if llm_name_ref is not None else "",
                self.nod('Load', [], [], jac_node=nd.method_owner)
            ],
            jac_node=nd.method_owner
        );
    } else {
        caller = self.name_load(
            self._py_name(llm_name_ref) if llm_name_ref is not None else ""
        );
    }
    args = self.nod(
        'Dict',
        ['keys', 'values'],
        [
            [
                self.const_of(param.name.sym_name)
                for param in nd.signature.params
                if isinstance(param, ParamVar)
            ],
            [
                self.name_load(param.name.sym_name)
                for param in nd.signature.params
                if isinstance(param, ParamVar)
            ]
        ]
    );
    llm_call = self._invoke_llm_call(
        model=model_expr, caller=caller, args=args, is_async=nd.is_async
    );
    statements: list[CgNode] = [];
    if nd.doc {
        statements.append(
            self.nod(
                'Expr',
                ['value'],
                [self.nod('Constant', ['value'], [nd.doc.lit_value], jac_node=nd.doc)]
            )
        );
    }
    statements.append(self.nod('Return', ['value'], [llm_call]));
    return statements;
}
