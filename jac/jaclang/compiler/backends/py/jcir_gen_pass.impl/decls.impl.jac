impl JcirGenPass._get_sem_decorator(nd: UniNode) -> (CgNode | None) {
    semstr: str = '';
    inner_semstr: dict[(str, str)] = {};
    if isinstance(nd, Archetype) {
        semstr = nd.semstr;
        arch_ast_body: list[UniNode] = list(ModuleFacts.unwrap_body(nd) or []);
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
        enum_ast_body: list[UniNode] = list(ModuleFacts.unwrap_body(nd) or []);
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
    return self.call_node(
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
    );
}

impl JcirGenPass.enter_archetype with Archetype entry {
    if isinstance(here.body, ImplDef) {
        self.traverse(here.body);
    }
}

impl JcirGenPass.exit_archetype with Archetype exit {
    inner = ModuleFacts.unwrap_body(here);
    decorators = [self.val(i) for i in here.decorators] if here.decorators else [];
    body: list = self.resolve_stmt_block(inner, doc=here.doc);
    if here.arch_type.name != Tok.KW_CLASS {
        import from jaclang.compiler.frontend.codeinfo { endpoint_key }
        type_id = endpoint_key(self.ir_in, 'type', here.sym_name);
        body.append(
            self.nod(
                'Assign',
                ['targets', 'value'],
                [
                    [
                        self.nod(
                            'Name',
                            ['id', 'ctx'],
                            ['__jac_type_id__', self.nod('Store', [], [])]
                        )
                    ],
                    self.const_of(type_id)
                ]
            )
        );
    }
    if (not body and not isinstance(here.body, Expr)) {
        self.emit(E5003, node_override=here);
        body = [self.nod('Pass', [], [], jac_node=here)];
    }
    ct_fields = self._ct_param_fields(here);
    if ct_fields {
        insert_at = 1 if here.doc else 0;
        body[insert_at:insert_at] = ct_fields;
    }
    async_walker = here.arch_kind == 'walker'
        and any(
            isinstance(stmt, Ability)
                and stmt.is_async
                and isinstance(stmt.signature, EventSignature) for stmt in (inner or [])
        );
    if here.is_async or async_walker {
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
                    self.const_of(True)
                ]
            )
        );
    }
    if (sem_decorator := self._get_sem_decorator(here)) {
        decorators.append(sem_decorator);
    }
    base_classes = [self.val(i) for i in here.base_classes];
    if (here.arch_type.name != Tok.KW_CLASS) {
        base_classes.append(self.jaclib_obj(here.arch_type.value.capitalize()));
    }
    type_param_asts: list[CgNode] = [];
    if here.type_params {
        for tp in here.type_params {
            if self.outs(tp) {
                type_param_asts.append(self.val(tp));
            }
        }
    }
    keywords = [self.val(k) for k in here.keywords] if here.keywords else [];
    class_def = self.nod(
        'ClassDef',
        ['name', 'bases', 'keywords', 'body', 'decorator_list', 'type_params'],
        [here.name.sym_name, base_classes, keywords, body, decorators, type_param_asts]
    );
    self.set_out(here, [class_def]);
}

impl JcirGenPass.enter_enum with Enum entry {
    if isinstance(here.body, ImplDef) {
        self.traverse(here.body);
    }
}

impl JcirGenPass.exit_enum with Enum exit {
    inner = ModuleFacts.unwrap_body(here);
    decorators = [self.val(i) for i in here.decorators] if here.decorators else [];
    body = self.resolve_stmt_block(inner, doc=here.doc);
    if (sem_decorator := self._get_sem_decorator(here)) {
        decorators.append(sem_decorator);
    }
    trailing_kind: str = "Enum";
    extra_bases: list[CgNode] = [];
    if here.value_type {
        if (isinstance(here.value_type, Name) and here.value_type.value == "int") {
            trailing_kind = "IntEnum";
        } elif (isinstance(here.value_type, Name) and here.value_type.value == "str") {
            trailing_kind = "StrEnum";
        } else {
            extra_bases.append(self.val(here.value_type));
        }
    }
    self.needs_enum_kind(trailing_kind);
    base_classes = extra_bases + [self.val(i) for i in here.base_classes];
    base_classes.append(self.builtin_name(trailing_kind));
    class_def = self.nod(
        'ClassDef',
        ['name', 'bases', 'keywords', 'body', 'decorator_list', 'type_params'],
        [here.name.sym_name, base_classes, [], body, decorators, []]
    );
    self.set_out(here, [class_def]);
}

impl JcirGenPass.enter_ability with Ability entry {
    self._push_hoist_frame();
    if isinstance(here.body, ImplDef) {
        self.traverse(here.body);
    }
}

impl JcirGenPass.exit_ability with Ability exit {
    func_type = 'AsyncFunctionDef' if here.is_async else 'FunctionDef';
    has_by_in_return = (
        isinstance(here.signature, FuncSignature)
        and here.signature.return_type
        and isinstance(here.signature.return_type, BinaryExpr)
        and isinstance(here.signature.return_type.op, Token)
        and (here.signature.return_type.op.name == Tok.KW_BY)
    );
    scope_frame = self._hoist_frames.pop() if self._hoist_frames else [];
    if not self._hoist_frames {
        self._hoist_frames = [[]];
    }
    sig_roots: list[UniNode] = [];
    if here.signature {
        sig_roots.append(here.signature);
    }
    if here.decorators {
        for d in here.decorators {
            if d {
                sig_roots.append(d);
            }
        }
    }
    (body_hoists, enclosing_hoists) = self._split_scope_hoists(scope_frame, sig_roots);
    if enclosing_hoists {
        self._hoist_frames[-1].extend(enclosing_hoists);
    }
    is_prop_acc = here.accessor_kind != "";
    prop_owner_name: str | None = None;
    if is_prop_acc {
        hv = here.find_parent_of_type(HasVar);
        if (hv and isinstance(hv.name, Name)) {
            prop_owner_name = hv.name.value;
        }
    }
    body_loc_node: (UniNode | None) = here.body
        if isinstance(here.body, UniNode)
        else None;
    stmt_body = ModuleFacts.unwrap_body(here);
    body = self.gen_llm_body(here)
        if (
            isinstance(here.body, Expr)
            or (isinstance(here.body, ImplDef) and isinstance(here.body.body, Expr))
            or has_by_in_return
        )
        else [
            self.nod('Expr', ['value'], [self.val(here.doc)], jac_node=here.doc),
            self.nod('Pass', [], [], jac_node=body_loc_node)
        ]
            if (here.doc and here.is_abstract)
            else [self.nod('Pass', [], [], jac_node=body_loc_node)]
                if here.is_abstract
                else self.resolve_stmt_block(stmt_body, doc=here.doc);
    if (here.is_abstract and here.body) {
        self.emit(E5004, node_override=here, name=str(here.sym_name));
    }
    decorator_list = [self.val(i) for i in here.decorators] if here.decorators else [];
    if (sem_decorator := self._get_sem_decorator(here)) {
        decorator_list.append(sem_decorator);
    }
    if isinstance(here.signature, EventSignature) {
        event_sig = here.signature;
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
            self.call_node(self.jaclib_obj('set_trigger'), [trigger_thunk], [])
        );
    }
    if isinstance(here.body, ImplDef) {
        decorator_list.append(
            self.call_node(
                self.jaclib_obj('impl_patch_filename'),
                [self.const_of(here.body.loc.mod_path)],
                []
            )
        );
    }
    if here.is_abstract {
        decorator_list.append(self.builtin_name('abstractmethod'));
    }
    if here.is_override {
        decorator_list.append(self.builtin_name('override'));
    }
    if here.is_static {
        decorator_list.insert(0, self.name_load('staticmethod'));
    }
    if here.is_classmethod {
        decorator_list.insert(0, self.name_load('classmethod'));
    }
    if (is_prop_acc and (prop_owner_name is not None)) {
        if here.accessor_kind == "property" {
            decorator_list.insert(0, self.name_load('property'));
        } elif here.accessor_kind == "setter" {
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
        } elif here.accessor_kind == "deleter" {
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
    if (not body and not isinstance(here.body, Expr)) {
        self.emit(E5005, node_override=here);
        body = [self.nod('Pass', [], [], jac_node=here)];
    }
    if body_hoists {
        body = [*body_hoists, *body];
    }
    body = self._scope_cleanup_body(here, body);
    directive_stmts = self.scope_directive_stmts(
        [here, here.body if isinstance(here.body, ImplDef) else None]
    );
    if directive_stmts {
        insert_at = self._docstring_offset(body);
        body = [*body[:insert_at], *directive_stmts, *body[insert_at:]];
    }
    ast_returns: CgNode = self.const_of(None);
    if (isinstance(here.signature, FuncSignature) and here.signature.return_type) {
        if (
            isinstance(here.signature.return_type, BinaryExpr)
            and isinstance(here.signature.return_type.op, Token)
            and (here.signature.return_type.op.name == Tok.KW_BY)
        ) {
            ast_returns = self.val(here.signature.return_type.left);
        } else {
            ast_returns = self.val(here.signature.return_type);
        }
    }
    if (
        is_prop_acc
        and (here.accessor_kind == "property")
        and (here.signature is None)
        and (prop_owner_name is not None)
    ) {
        hv2 = here.find_parent_of_type(HasVar);
        if (hv2 and hv2.type_tag) {
            ast_returns = self.val(hv2.type_tag);
        }
    }
    name_ref_node = here.name_ref;
    func_name_out = (
        prop_owner_name
            if (is_prop_acc and (prop_owner_name is not None))
            else self._py_name(name_ref_node) if name_ref_node is not None else ""
    );
    func_args_out: CgNode;
    if (is_prop_acc and (here.signature is None)) {
        acc_args = [self.nod('arg', ['arg', 'annotation'], ['self', None])];
        if here.accessor_kind == "setter" {
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
    } elif here.signature {
        func_args_out = self.val(here.signature);
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
                    if here.is_method and not here.is_static and not here.is_classmethod
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
    self.set_out(here, [func_def]);
}

impl JcirGenPass.exit_impl_def with ImplDef exit {}

impl JcirGenPass.exit_sem_def with SemDef exit {}

impl JcirGenPass.exit_func_signature with FuncSignature exit {
    posonlyargs = [self.val(i) for i in here.posonly_params];
    vararg = self.val(here.varargs) if here.varargs else None;
    kwarg = self.val(here.kwargs) if here.kwargs else None;
    _first = list(here.posonly_params) + list(here.params);
    _explicit_self = (
        bool(_first)
        and isinstance(_first[0], ParamVar)
        and _first[0].name is not None
        and _first[0].name.sym_name == "self"
    );
    params = [self.nod('arg', ['arg', 'annotation'], ['cls', None])]
        if (
            (abl := here.parent)
            and isinstance(abl, Ability)
            and abl.is_method
            and abl.is_classmethod
            and not here.is_in_py_class
        )
        else [self.nod('arg', ['arg', 'annotation'], ['self', None])]
            if (
                (abl := here.parent)
                and isinstance(abl, Ability)
                and abl.is_method
                and not here.is_static
                and not abl.is_cls_method
                and not here.is_in_py_class
                and not _explicit_self
            )
            else [];
    if posonlyargs {
        posonlyargs = params + posonlyargs;
        params = [self.val(i) for i in here.params];
    } else {
        params = params + [self.val(i) for i in here.params];
    }
    defaults: list[CgNode] = [];
    all_params: list[UniNode] = list(here.posonly_params) + list(here.params);
    for i in all_params {
        if (isinstance(i, ParamVar) and i.value) {
            defaults.append(self.val(i.value));
        }
    }
    kwonly_args = [self.val(i) for i in here.kwonlyargs];
    kw_defaults: list[CgNode | None] = [];
    for i in here.kwonlyargs {
        if isinstance(i, ParamVar) and i.value {
            kw_defaults.append(self.val(i.value));
        } else {
            kw_defaults.append(None);
        }
    }
    self.set_out(
        here,
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

impl JcirGenPass.exit_event_signature with EventSignature exit {
    arch_kw = Con.HERE.value if here.from_walker else Con.VISITOR.value;
    annotation: (CgNode | None) = None;
    if here.arch_tag_info {
        tag_recipe = self.val(here.arch_tag_info);
        if (tag_recipe.cls == 'Tuple' and isinstance(here.arch_tag_info, TupleVal)) {
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
        jac_node=here.arch_tag_info or here
    );
    self.set_out(
        here,
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
                        if (
                            (abl := here.find_parent_of_type(Ability)) and abl.is_method
                        )
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

impl JcirGenPass.exit_param_var with ParamVar exit {
    if self.val(here.name).cls == 'Name' {
        name = self.val(here.name).get('id');
        self.set_out(
            here,
            [
                self.nod(
                    'arg',
                    ['arg', 'annotation'],
                    [name, self.val(here.type_tag) if here.type_tag else None]
                )
            ]
        );
    }
}

impl JcirGenPass.exit_arch_has with ArchHas exit {
    vars_py = self._flatten_ast_list([self.outs(v) for v in here.vars]);
    if here.doc {
        doc = self.nod('Expr', ['value'], [self.val(here.doc)], jac_node=here.doc);
        self.set_out(here, [doc] + vars_py);
    } else {
        self.set_out(here, vars_py);
    }
}

impl JcirGenPass.exit_has_var with HasVar exit {
    import from jaclang.compiler.field_semantics { is_field_marker }
    annotation = self.val(here.type_tag) if here.type_tag else None;
    if ((here.accessors is not None) and (len(here.accessors) > 0)) {
        result_stmts: list[CgItem] = [];
        for acc in here.accessors {
            for stmt in self.outs(acc) {
                result_stmts.append(stmt);
            }
        }
        self.set_out(here, result_stmts);
        return;
    }
    is_static_var = (
        (haspar := here.find_parent_of_type(ArchHas)) and haspar and haspar.is_static
    );
    is_in_class = (
        (archpar := here.find_parent_of_type(Archetype))
        and archpar
        and (archpar.arch_type.name == Tok.KW_CLASS)
    );
    value = None;
    if is_in_class {
        value = self.val(here.value) if here.value else None;
    } elif is_static_var {
        annotation = self.nod(
            'Subscript',
            ['value', 'slice', 'ctx'],
            [self.builtin_name('ClassVar'), annotation, self.nod('Load', [], [])]
        );
        value = self.val(here.value) if here.value else None;
    } elif here.defer {
        value = self.call_node(
            self.jaclib_obj('field'),
            [],
            [self.nod('keyword', ['arg', 'value'], ['init', self.const_of(False)])]
        );
    } elif here.value {
        value_expr = self.val(here.value);
        if value_expr.cls == 'Constant'
            or (isinstance(here.value, FuncCall) and is_field_marker(here.value)) {
            value = value_expr;
        } else {
            value = self.call_node(
                self.jaclib_obj('field'),
                [],
                [
                    self.nod(
                        'keyword',
                        ['arg', 'value'],
                        [
                            'default_factory',
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
            );
        }
    }
    ann_assign = self.nod(
        'AnnAssign',
        ['target', 'annotation', 'value', 'simple'],
        [
            self.val(here.name),
            annotation or self.const_of(None),
            value,
            int(isinstance(here.name, Name))
        ]
    );
    self.set_out(here, [ann_assign]);
}

impl JcirGenPass._invoke_llm_call(
    model: CgNode, caller: CgNode, args: CgNode, is_async: bool = False
) -> CgNode {
    mtir_ast = self.call_node(
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
    );
    hook_name = 'acall_llm' if is_async else 'call_llm';
    call = self.call_node(
        self.jaclib_obj(hook_name),
        [],
        [
            self.nod('keyword', ['arg', 'value'], ['model', model]),
            self.nod('keyword', ['arg', 'value'], ['mt_run', mtir_ast])
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
