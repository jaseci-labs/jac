"""Implementation for pyast_gen_pass constructs."""

"""Get the set of builtin names, cached after first successful access."""
@ classmethod
impl PyastGenPass._get_builtin_names(cls: Any) -> set[str] {
    if (cls._builtin_names is None) {
        try {
            import jaclang.runtimelib.builtin as builtin_mod;
            cls._builtin_names = `set(builtin_mod.__all__);
        } except (ImportError, AttributeError) {
            return `set();
        }
    }
    return cls._builtin_names;
}

impl PyastGenPass.before_pass(self: PyastGenPass) -> None {
    self.child_passes: list[PyastGenPass] = self._init_child_passes(PyastGenPass);
    self.debuginfo: dict[(str, list[str])] = {'jac_mods': []};
    self.already_added: list[str] = [];
    self.jaclib_imports: set[str] = `set();
    self.builtin_imports: set[str] = `set();
    self._temp_name_counter: int = 0;
    self._hoisted_funcs: list[(ast3.FunctionDef | ast3.AsyncFunctionDef)] = [];
    self.preamble: list[ast3.AST] = [
        self.sync(
            ast3.ImportFrom(
                module='__future__',
                names=[self.sync(ast3.alias(name='annotations', asname=None))],
                level=0
            ),
            jac_node=self.ir_out
        )
    ];
    self.jsx_processor = PyJsxProcessor(self);
}

"""Enter node."""
impl PyastGenPass.enter_node(self: PyastGenPass, nd: uni.UniNode) -> None {
    if isinstance(nd, uni.NativeBlock) {
        self._gen_native_interop_stubs(nd);
        self.prune();
        return;
    }
    if (
        isinstance(nd, uni.ClientBlock)
        or (
            isinstance(nd, uni.ContextAwareNode)
            and (nd.code_context in (CodeContext.CLIENT, CodeContext.NATIVE))
            and ((nd.parent is None) or isinstance(nd.parent, uni.Module))
        )
    ) {
        self.prune();
        return;
    }
    if nd.gen.py_ast {
        self.prune();
        return;
    }
    super.enter_node(nd);
}

"""Exit node."""
impl PyastGenPass.exit_node(self: PyastGenPass, nd: uni.UniNode) -> None {
    if isinstance(nd, (uni.ClientBlock, uni.NativeBlock)) {
        return;
    }
    if (
        isinstance(nd, uni.ContextAwareNode)
        and (nd.code_context in (CodeContext.CLIENT, CodeContext.NATIVE))
        and ((nd.parent is None) or isinstance(nd.parent, uni.Module))
    ) {
        return;
    }
    super.exit_node(nd);
}

"""Generate Python stubs for native interop at the NativeBlock position.

        For native_exports (native functions called from Python):
          Generates a Python stub function that calls the native function via
ctypes.
        For native_imports (Python functions called from native):
          Generates a registration statement that stores the Python function
          in the interop callback table.
        """
impl PyastGenPass._gen_native_interop_stubs(
    self: PyastGenPass, nd: uni.NativeBlock
) -> None {
    manifest = self.ir_in.gen.interop_manifest;
    if (not manifest or not manifest.bindings) {
        return;
    }
    import from jaclang.jac0core.interop_bridge { JAC_TO_CTYPES_STR }
    parts: list[str] = [];
    for binding in manifest.native_exports {
        params = ', '.join(binding.param_names);
        ret_ct = JAC_TO_CTYPES_STR.get(binding.ret_type, 'ctypes.c_int64');
        arg_cts = ', '.join(
            JAC_TO_CTYPES_STR.get(pt, 'ctypes.c_int64') for pt in binding.param_types
        );
        parts.append(
            f"def {binding.name}({params}):\n" + f"    import ctypes\n" + f"    _addr = __jac_native_engine__" + f".get_function_address('{binding.name}')\n" + f"    _fn = ctypes.CFUNCTYPE({ret_ct}, {arg_cts})(_addr)\n" + f"    return _fn({params})"
        );
    }
    for binding in manifest.native_imports {
        parts.append(f"__jac_interop_py_funcs__['{binding.name}'] = {binding.name}");
    }
    if parts {
        src = '\n'.join(parts);
        parsed = ast3.parse(src);
        nd.gen.py_ast = `list(parsed.body);
    }
}

"""Return the object from jaclib as ast node based on the import config."""
impl PyastGenPass.jaclib_obj(self: PyastGenPass, obj_name: str) -> ast3.Name {
    self.jaclib_imports.add(obj_name);
    return self.sync(ast3.Name(id=obj_name, ctx=ast3.Load()));
}

"""Return a builtin name and track it for importing.

        Note: Some names like 'Enum' are provided by other imports (e.g.,
needs_enum)
        and should not be added to builtin_imports.
        """
impl PyastGenPass.builtin_name(self: PyastGenPass, name: str) -> ast3.Name {
    if (name not in ['Enum']) {
        self.builtin_imports.add(name);
    }
    return self.sync(ast3.Name(id=name, ctx=ast3.Load()));
}

"""Append an import statement to the preamble once."""
impl PyastGenPass._add_preamble_once(
    self: PyastGenPass, key: str, nd: ast3.AST
) -> None {
    if (key in self.already_added) {
        return;
    }
    self.preamble.append(self.sync(nd, jac_node=self.ir_out));
    self.already_added.append(key);
}

"""Ensure typing is imported only once."""
impl PyastGenPass.needs_typing(self: PyastGenPass) -> None {
    self._add_preamble_once(
        self.needs_typing.__name__,
        ast3.Import(names=[self.sync(ast3.alias(name='typing'), jac_node=self.ir_out)])
    );
}

"""Ensure Enum utilities are imported only once."""
impl PyastGenPass.needs_enum(self: PyastGenPass) -> None {
    self._add_preamble_once(
        self.needs_enum.__name__,
        ast3.ImportFrom(
            module='enum',
            names=[
                self.sync(ast3.alias(name='Enum', asname=None)),
                self.sync(ast3.alias(name='auto', asname=None))
            ],
            level=0
        )
    );
}

"""Ensure concurrent Future is imported only once."""
impl PyastGenPass.needs_future(self: PyastGenPass) -> None {
    self._add_preamble_once(
        self.needs_future.__name__,
        ast3.ImportFrom(
            module='concurrent.futures',
            names=[self.sync(ast3.alias(name='Future', asname=None))],
            level=0
        )
    );
}

"""Generate a deterministic temporary name for synthesized definitions."""
impl PyastGenPass._next_temp_name(self: PyastGenPass, prefix: str) -> str {
    self._temp_name_counter += 1;
    return f"__jac_{prefix}_{self._temp_name_counter}";
}

"""Convert Jac identifiers to Python runtime identifiers."""
impl PyastGenPass._py_name(self: PyastGenPass, nd: uni.AstSymbolNode) -> str {
    if (isinstance(nd, uni.SpecialVarRef) and (nd.name == Tok.KW_INIT)) {
        return '__init__';
    }
    return nd.sym_name;
}

"""Convert a synthesized function definition into an executable expression.

        Instead of using make_block_lambda at runtime, we hoist the function
        definition to be emitted before the current statement, then return
        a reference to the function name.
        """
impl PyastGenPass._function_expr_from_def(
    self: PyastGenPass,
    func_def: (ast3.FunctionDef | ast3.AsyncFunctionDef),
    jac_node: uni.UniNode,
    filename_hint: str
) -> ast3.Name {
    ast3.fix_missing_locations(func_def);
    self._hoisted_funcs.append(func_def);
    return self.sync(ast3.Name(id=func_def.name, ctx=ast3.Load()), jac_node=jac_node);
}

impl PyastGenPass.get_weather(city: str) { }

"""Create a semstring decorator for the given semantic strings.

        Example:
            @_.sem(
                "Returns the weather for a given city.", {
                    "city" : "Name of the city to get the weather for.",
                }
            )
            def get_weather(city: str) {}

        This the second parameter (dict) will also used in the class `has`
variables
        enum values etc.
        """
impl PyastGenPass._get_sem_decorator(
    self: PyastGenPass, nd: uni.UniNode
) -> (ast3.Call | None) {
    semstr: str = '';
    inner_semstr: dict[(str, str)] = {};
    if isinstance(nd, uni.Archetype) {
        semstr = nd.semstr;
        arch_ast_body: list[uni.UniNode] = [];
        if isinstance(nd.body, `list) {
            arch_ast_body = nd.body;
        } elif (isinstance(nd.body, uni.ImplDef) and isinstance(nd.body.body, `list)) {
            arch_ast_body = nd.body.body;
        }
        for stmt in arch_ast_body {
            if isinstance(stmt, uni.ArchHas) {
                for has_var in stmt.vars {
                    if has_var.semstr {
                        inner_semstr[has_var.sym_name] = has_var.semstr;
                    }
                }
            }
        }
    } elif isinstance(nd, uni.Enum) {
        semstr = nd.semstr;
        enum_ast_body: list[uni.UniNode] = [];
        if isinstance(nd.body, `list) {
            enum_ast_body = nd.body;
        } elif (isinstance(nd.body, uni.ImplDef) and isinstance(nd.body.body, `list)) {
            enum_ast_body = nd.body.body;
        }
        for stmt in enum_ast_body {
            if (
                isinstance(stmt, uni.Assignment)
                and isinstance(stmt.target[0], uni.AstSymbolNode)
            ) {
                name = stmt.target[0].sym_name;
                val_semstr = stmt.target[0].semstr;
                inner_semstr[name] = val_semstr;
            }
        }
    } elif isinstance(nd, uni.Ability) {
        semstr = nd.semstr;
        inner_semstr = {
            param.sym_name: param.semstr
            for param in nd.signature.params
            if param.semstr
        }
        if isinstance(nd.signature, uni.FuncSignature)
        else {};
    }
    if (not semstr and (not inner_semstr or all(not v for v in inner_semstr.values()))) {
        return None;
    }
    return self.sync(
        ast3.Call(
            func=self.jaclib_obj('sem'),
            args=[
                self.sync(ast3.Constant(value=semstr)),
                self.sync(
                    ast3.Dict(
                        keys=[self.sync(ast3.Constant(value=k)) for k in inner_semstr],
                        values=[
                            self.sync(ast3.Constant(value=v))
                            for v in inner_semstr.values()
                        ]
                    )
                )
            ],
            keywords=[]
        )
    );
}

"""Sync ast locations."""
impl PyastGenPass.sync(
    self: PyastGenPass,
    py_node: T,
    jac_node: (uni.UniNode | None) = None,
    deep: bool = False
) -> T {
    if not jac_node {
        jac_node = self.cur_node;
    }
    for i in ast3.walk(py_node) if deep else [py_node] {
        if isinstance(i, ast3.AST) {
            i.lineno = jac_node.loc.first_line;
            i.col_offset = jac_node.loc.col_start;
            i.end_lineno = jac_node.loc.last_line
            if (
                jac_node.loc.last_line
                and (jac_node.loc.last_line > jac_node.loc.first_line)
            )
            else jac_node.loc.first_line;
            i.end_col_offset = jac_node.loc.col_end
            if (
                jac_node.loc.col_end
                and (jac_node.loc.col_end > jac_node.loc.col_start)
            )
            else jac_node.loc.col_start;
            i.jac_link: list[ast3.AST] = [jac_node];
        }
    }
    return py_node;
}

"""Sync ast locations."""
impl PyastGenPass.pyinline_sync(
    self: PyastGenPass, py_nodes: list[ast3.AST]
) -> list[ast3.AST] {
    for nd in py_nodes {
        for i in ast3.walk(nd) {
            if isinstance(i, ast3.AST) {
                if (i?.lineno and (i.lineno is not None)) {
                    i.lineno += self.cur_node.loc.first_line;
                }
                if (i?.end_lineno and (i.end_lineno is not None)) {
                    i.end_lineno += self.cur_node.loc.first_line;
                }
                i.jac_link: ast3.AST = [self.cur_node];
            }
        }
    }
    return py_nodes;
}

"""Resolve switch case pattern."""
impl PyastGenPass.resolve_switch_pattern(
    self: PyastGenPass, pattern: uni.MatchPattern, target: uni.Expr
) -> ast3.expr {
    if isinstance(pattern, uni.MatchValue) {
        return self.sync(
            ast3.Compare(
                left=cast(ast3.expr, target.gen.py_ast[0]),
                ops=[self.sync(ast3.Eq())],
                comparators=[cast(ast3.expr, pattern.value.gen.py_ast[0])]
            )
        );
    } elif isinstance(pattern, uni.MatchOr) {
        return self.sync(
            ast3.BoolOp(
                op=self.sync(ast3.Or()),
                values=[
                    self.resolve_switch_pattern(pat, target)
                    for pat in pattern.patterns
                ]
            )
        );
    } elif isinstance(pattern, uni.MatchSingleton) {
        return self.sync(
            ast3.Compare(
                left=cast(ast3.expr, target.gen.py_ast[0]),
                ops=[self.sync(ast3.Is())],
                comparators=[cast(ast3.expr, pattern.value.gen.py_ast[0])]
            )
        );
    } else {
        raise self.ice('Unsupported switch pattern type') ;
    }
}

"""Resolve switch statement."""
impl PyastGenPass.resolve_switch_stmt(
    self: PyastGenPass, nd: uni.SwitchStmt
) -> list[ast3.AST] {
    var_executed = self.sync(ast3.Name(id='__executed', ctx=ast3.Store()));
    assign_var = self.sync(
        ast3.Assign(
            targets=[var_executed], value=self.sync(ast3.Constant(value=False))
        )
    );
    ast_nodes: list[ast3.AST] = [];
    test_expr: ast3.expr;
    executed_assign = self.sync(
        ast3.Assign(targets=[var_executed], value=self.sync(ast3.Constant(value=True)))
    );
    for `case in nd.cases {
        if (`case.pattern is None) {
            ast_nodes.extend((self.resolve_stmt_block(`case.body) + [executed_assign]));
        } else {
            test_expr = self.sync(
                ast3.BoolOp(
                    op=self.sync(ast3.Or()),
                    values=[
                        self.resolve_switch_pattern(`case.pattern, nd.target),
                        self.sync(ast3.Name(id='__executed', ctx=ast3.Load()))
                    ]
                )
            );
            if_stmt = self.sync(
                ast3.If(
                    `test=test_expr,
                    body=cast(
                        `list[ast3.stmt],
                        (self.resolve_stmt_block(`case.body) + [executed_assign])
                    ),
                    orelse=[]
                )
            );
            ast_nodes.append(if_stmt);
        }
    }
    while_cond = self.sync(
        ast3.UnaryOp(
            op=self.sync(ast3.Not()),
            operand=self.sync(ast3.Name(id='__executed', ctx=ast3.Load()))
        )
    );
    return [
        assign_var,
        self.sync(
            ast3.While(
                `test=while_cond, body=cast(`list[ast3.stmt], ast_nodes), orelse=[]
            )
        )
    ];
}

"""Unwind codeblock."""
impl PyastGenPass.resolve_stmt_block(
    self: PyastGenPass,
    nd: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None,
    doc: (uni.String | None) = None
) -> list[ast3.AST] {
    items = `list(nd) if nd else [];
    valid_stmts = [
        i
        for i in items
        if not isinstance(i, uni.Semi)
    ];
    ret: list[ast3.AST] = [self.sync(ast3.Pass())]
    if (isinstance(nd, Sequence) and not valid_stmts)
    else self._flatten_ast_list(
        [
            x.gen.py_ast
            if not isinstance(x, uni.SwitchStmt)
            else self.resolve_switch_stmt(x)
            for x in valid_stmts
            if not isinstance(x, uni.ImplDef)
        ]
    )
    if (nd is not None)
    else [self.sync(ast3.Pass())];
    if doc {
        ret = [
            self.sync(
                ast3.Expr(value=cast(ast3.expr, doc.gen.py_ast[0])), jac_node=doc
            ),
            *ret
        ];
    }
    return ret;
}

"""Sync ast locations."""
impl PyastGenPass.sync_many(
    self: PyastGenPass, py_nodes: list[T], jac_node: uni.UniNode
) -> list[T] {
    for py_node in py_nodes {
        self.sync(py_node, jac_node);
    }
    return py_nodes;
}

"""Convert list to attribute."""
impl PyastGenPass.list_to_attrib(
    self: PyastGenPass,
    attribute_list: list[str],
    sync_node_list: Sequence[uni.UniNode]
) -> ast3.AST {
    attr_node: (ast3.Name | ast3.Attribute) = self.sync(
        ast3.Name(id=attribute_list[0], ctx=ast3.Load()), sync_node_list[0]
    );
    for (attr, sync_node) in zip(attribute_list[1:], sync_node_list[1:], strict=False) {
        attr_node = self.sync(
            ast3.Attribute(value=attr_node, attr=attr, ctx=ast3.Load()), sync_node
        );
    }
    return attr_node;
}

impl PyastGenPass.exit_sub_tag(self: PyastGenPass, nd: uni.SubTag[uni.T]) -> None {
    nd.gen.py_ast = nd.tag.gen.py_ast;
}

impl PyastGenPass.exit_module(self: PyastGenPass, nd: uni.Module) -> None {
    for child_pass in self.child_passes {
        self.jaclib_imports.update(child_pass.jaclib_imports);
        self.builtin_imports.update(child_pass.builtin_imports);
    }
    is_builtin_module = (
        nd.loc.mod_path.endswith(('builtin.jac', 'builtin.py'))
        and ('runtimelib' in nd.loc.mod_path)
    );
    if (self.builtin_imports and not is_builtin_module) {
        self.preamble.append(
            self.sync(
                ast3.ImportFrom(
                    module='jaclang.runtimelib.builtin',
                    names=[
                        self.sync(ast3.alias(name=name, asname=None))
                        for name in sorted(self.builtin_imports)
                    ],
                    level=0
                ),
                jac_node=self.ir_out
            )
        );
    }
    mod_path_norm = nd.loc.mod_path.replace('\\', '/');
    is_jaclib_module = mod_path_norm.endswith(('/jaclang/lib.jac', '/jaclang/lib.py'));
    if (self.jaclib_imports and not is_jaclib_module) {
        self.preamble.append(
            self.sync(
                ast3.ImportFrom(
                    module='jaclang.jac0core.jaclib',
                    names=[
                        self.sync(ast3.alias(name=name, asname=None))
                        for name in sorted(self.jaclib_imports)
                    ],
                    level=0
                ),
                jac_node=self.ir_out
            )
        );
    }
    merged_body = self._merge_module_bodies(nd);
    body_items: list[ast3.AST | list[ast3.AST] | None] = [];
    if nd.doc {
        doc_stmt = self.sync(
            ast3.Expr(value=cast(ast3.expr, nd.doc.gen.py_ast[0])), jac_node=nd.doc
        );
        body_items.append(doc_stmt);
    }
    body_items.extend(self.preamble);
    body_items.extend(item.gen.py_ast for item in merged_body);
    new_body = self._flatten_ast_list(body_items);
    nd.gen.py_ast = [
        self.sync(
            ast3.Module(body=[cast(ast3.stmt, s) for s in new_body], type_ignores=[])
        )
    ];
    nd.gen.py = ast3.unparse(nd.gen.py_ast[0]);
}

impl PyastGenPass.exit_type_param(self: PyastGenPass, nd: uni.TypeParam) -> None {
    bound_ast = cast(ast3.expr, nd.bound.gen.py_ast[0]) if nd.bound else None;
    type_var = self.sync(ast3.TypeVar(name=nd.name.value, bound=bound_ast));
    nd.gen.py_ast = [type_var];
}

impl PyastGenPass.exit_type_alias(self: PyastGenPass, nd: uni.TypeAlias) -> None {
    type_param_asts: list[ast3.type_param] = [];
    for tp in nd.type_params {
        if tp.gen.py_ast {
            type_param_asts.append(cast(ast3.type_param, tp.gen.py_ast[0]));
        }
    }
    value_ast = cast(ast3.expr, nd.value.gen.py_ast[0]);
    type_alias = self.sync(
        ast3.TypeAlias(
            name=self.sync(ast3.Name(id=nd.name.sym_name, ctx=ast3.Store())),
            type_params=type_param_asts,
            value=value_ast
        )
    );
    nd.gen.py_ast = [type_alias];
}

impl PyastGenPass.exit_global_vars(self: PyastGenPass, nd: uni.GlobalVars) -> None {
    if nd.doc {
        doc = self.sync(
            ast3.Expr(value=cast(ast3.expr, nd.doc.gen.py_ast[0])), jac_node=nd.doc
        );
        assigns_ast: list[ast3.AST] = self._flatten_ast_list(
            [a.gen.py_ast for a in nd.assignments]
        );
        if isinstance(doc, ast3.AST) {
            nd.gen.py_ast = [doc] + assigns_ast;
        } else {
            raise self.ice() ;
        }
    } else {
        nd.gen.py_ast = self._flatten_ast_list([a.gen.py_ast for a in nd.assignments]);
    }
}

impl PyastGenPass.exit_test(self: PyastGenPass, nd: uni.Test) -> None {
    test_name = nd.name.sym_name;
    func = self.sync(
        ast3.FunctionDef(
            name=test_name,
            args=self.sync(
                ast3.arguments(
                    posonlyargs=[],
                    args=[
                        self.sync(ast3.arg(arg=Con.JAC_CHECK.value, annotation=None))
                    ],
                    kwonlyargs=[],
                    vararg=None,
                    kwarg=None,
                    kw_defaults=[],
                    defaults=[]
                )
            ),
            body=[
                cast(ast3.stmt, stmt)
                for stmt in self.resolve_stmt_block(nd.body, doc=nd.doc)
            ],
            decorator_list=[],
            returns=self.sync(ast3.Constant(value=None)),
            type_comment=None,
            type_params=[]
        )
    );
    # Build jac_test decorator, passing description if available
    jac_test_keywords: list = [];
    if nd.description {
        jac_test_keywords.append(
            self.sync(
                ast3.keyword(
                    arg='description',
                    value=self.sync(ast3.Constant(value=nd.description.lit_value))
                )
            )
        );
    }
    func.decorator_list.append(
        self.sync(
            ast3.Call(
                func=self.jaclib_obj('jac_test'), args=[], keywords=jac_test_keywords
            )
        )
    );
    if nd.loc.mod_path.endswith('.test.jac') {
        func.decorator_list.append(
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('impl_patch_filename'),
                    args=[],
                    keywords=[
                        self.sync(
                            ast3.keyword(
                                arg='file_loc',
                                value=self.sync(ast3.Constant(value=nd.loc.mod_path))
                            )
                        )
                    ]
                )
            )
        );
    }
    nd.gen.py_ast = [func];
}

impl PyastGenPass.exit_module_code(self: PyastGenPass, nd: uni.ModuleCode) -> None {
    nd.gen.py_ast = self.resolve_stmt_block(nd.body, doc=nd.doc);
    if nd.name {
        nd.gen.py_ast = [
            self.sync(
                ast3.If(
                    `test=self.sync(
                        ast3.Compare(
                            left=self.sync(ast3.Name(id='__name__', ctx=ast3.Load())),
                            ops=[self.sync(ast3.Eq())],
                            comparators=[
                                self.sync(ast3.Constant(value=nd.name.sym_name))
                            ]
                        )
                    ),
                    body=[cast(ast3.stmt, i) for i in nd.gen.py_ast],
                    orelse=[]
                )
            )
        ];
    }
}

"""Handle ClientBlock - already set to empty in enter_node."""
impl PyastGenPass.exit_client_block(self: PyastGenPass, nd: uni.ClientBlock) -> None {
    ;
}

"""Handle ServerBlock - unwrap its children to module level."""
impl PyastGenPass.exit_server_block(self: PyastGenPass, nd: uni.ServerBlock) -> None {
    nd.gen.py_ast = self._flatten_ast_list([item.gen.py_ast for item in nd.body]);
}

"""Handle NativeBlock - already pruned in enter_node."""
impl PyastGenPass.exit_native_block(self: PyastGenPass, nd: uni.NativeBlock) -> None {
    ;
}

impl PyastGenPass.exit_py_inline_code(self: PyastGenPass, nd: uni.PyInlineCode) -> None {
    if nd.doc {
        doc = self.sync(
            ast3.Expr(value=cast(ast3.expr, nd.doc.gen.py_ast[0])), jac_node=nd.doc
        );
        if isinstance(doc, ast3.AST) {
            nd.gen.py_ast = self.pyinline_sync([doc, *ast3.parse(nd.code.value).body]);
        } else {
            raise self.ice() ;
        }
    } else {
        nd.gen.py_ast = self.pyinline_sync(
            [*ast3.parse(textwrap.dedent(nd.code.value)).body]
        );
    }
}

"""Exit import node."""
impl PyastGenPass.exit_import(self: PyastGenPass, nd: uni.Import) -> None {
    if (nd.from_loc and nd.from_loc.path) {
        module_parts = [
            p.value
            for p in nd.from_loc.path
            if p?.value
        ];
        if (module_parts == ['__future__']) {
            nd.gen.py_ast = [];
            return;
        }
    }
    py_nodes: list[ast3.AST] = [];
    if nd.doc {
        py_nodes.append(
            self.sync(
                ast3.Expr(value=cast(ast3.expr, nd.doc.gen.py_ast[0])), jac_node=nd.doc
            )
        );
    }
    if nd.is_absorb {
        source = nd.items[0];
        if not isinstance(source, uni.ModulePath) {
            raise self.ice() ;
        }
        module_name_parts = [p.value for p in source.path] if source.path else [];
        module_name = '.'.join(module_name_parts) if module_name_parts else None;
        py_nodes.append(
            self.sync(
                py_node=ast3.ImportFrom(
                    module=module_name,
                    names=[self.sync(ast3.alias(name='*'), nd)],
                    level=source.level
                ),
                jac_node=nd
            )
        );
    } elif not nd.from_loc {
        # For plain imports (import X as Y), ModuleItem may not be in the
        # traversed kid list, so collect from ModulePath nodes directly.
        mod_paths = [
            k
            for k in nd.kid
            if isinstance(k, uni.ModulePath)
        ];
        names_list = [cast(ast3.alias, x) for p in mod_paths for x in p.gen.py_ast]
        if mod_paths
        else [cast(ast3.alias, x) for item in nd.items for x in item.gen.py_ast];
        py_nodes.append(self.sync(ast3.Import(names=names_list)));
    } else {
        module_name_parts = [p.value for p in nd.from_loc.path]
        if nd.from_loc.path
        else [];
        module_name = '.'.join(module_name_parts) if module_name_parts else None;
        py_nodes.append(
            self.sync(
                ast3.ImportFrom(
                    module=module_name,
                    names=[
                        cast(ast3.alias, i) for item in nd.items
                        for i in item.gen.py_ast
                    ],
                    level=nd.from_loc.level
                )
            )
        );
    }
    nd.gen.py_ast = py_nodes;
}

impl PyastGenPass.exit_module_path(self: PyastGenPass, nd: uni.ModulePath) -> None {
    if (nd.path and (len(nd.path) == 1) and isinstance(nd.path[0], uni.String)) {
        import_node = nd.parent_of_type(uni.Import);
        if (import_node and (import_node.code_context != CodeContext.CLIENT)) {
            self.log_error(
                'String literal imports (e.g., from "' + str(nd.path[0].lit_value) + '") are only supported in client (cl) imports, not Python imports. ' + "Use 'cl import from \"" + str(
                    nd.path[0].lit_value
                ) + "\" { ... }' instead.",
                nd
            );
        }
    }
    nd.gen.py_ast = [
        self.sync(
            ast3.alias(
                name=str(nd.dot_path_str),
                asname=nd.alias.sym_name if nd.alias else None
            )
        )
    ];
}

impl PyastGenPass.exit_module_item(self: PyastGenPass, nd: uni.ModuleItem) -> None {
    if (isinstance(nd.name, uni.Token) and (nd.name.value in ['default', '*'])) {
        import_node = nd.from_parent;
        if (import_node.code_context != CodeContext.CLIENT) {
            import_type = 'Default' if (nd.name.value == 'default') else 'Namespace';
            self.log_error(
                import_type + " imports (using '" + str(nd.name.value) + "') are only supported in client (cl) imports, not Python imports",
                nd
            );
            nd.gen.py_ast = [];
            return;
        }
    }
    nd.gen.py_ast = [
        self.sync(
            ast3.alias(
                name=(
                    nd.name.sym_name
                    if isinstance(nd.name, uni.Name)
                    else nd.name.value
                ),
                asname=nd.alias.sym_name if nd.alias else None
            )
        )
    ];
}

impl PyastGenPass.enter_archetype(self: PyastGenPass, nd: uni.Archetype) -> None {
    if isinstance(nd.body, uni.ImplDef) {
        self.traverse(nd.body);
    }
}

impl PyastGenPass.exit_archetype(self: PyastGenPass, nd: uni.Archetype) -> None {
    inner: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None = None;
    if isinstance(nd.body, uni.ImplDef) {
        inner = nd.body.body if not isinstance(nd.body.body, uni.Expr) else None;
    } elif not isinstance(nd.body, uni.Expr) {
        inner = nd.body;
    }
    body: list[ast3.AST] = self.resolve_stmt_block(inner, doc=nd.doc);
    if (not body and not isinstance(nd.body, uni.Expr)) {
        self.log_error('Archetype has no body. Perhaps an impl must be imported.', nd);
        body = [self.sync(ast3.Pass(), nd)];
    }
    if nd.is_async {
        body.insert(
            0,
            self.sync(
                ast3.Assign(
                    targets=[
                        self.sync(ast3.Name(id='__jac_async__', ctx=ast3.Store()))
                    ],
                    value=self.sync(ast3.Constant(value=nd.is_async))
                )
            )
        );
    }
    decorators = [cast(ast3.expr, i.gen.py_ast[0]) for i in nd.decorators]
    if nd.decorators
    else [];
    if (sem_decorator := self._get_sem_decorator(nd)) {
        decorators.append(sem_decorator);
    }
    base_classes = [cast(ast3.expr, i.gen.py_ast[0]) for i in nd.base_classes];
    if (nd.arch_type.name != Tok.KW_CLASS) {
        base_classes.append(self.jaclib_obj(nd.arch_type.value.capitalize()));
    }
    type_param_asts: list[ast3.type_param] = [];
    if nd.type_params {
        for tp in nd.type_params {
            if tp.gen.py_ast {
                type_param_asts.append(cast(ast3.type_param, tp.gen.py_ast[0]));
            }
        }
    }
    class_def = self.sync(
        ast3.ClassDef(
            name=nd.name.sym_name,
            bases=[cast(ast3.expr, i) for i in base_classes],
            keywords=[],
            body=[cast(ast3.stmt, i) for i in body],
            decorator_list=[cast(ast3.expr, i) for i in decorators],
            type_params=type_param_asts
        )
    );
    nd.gen.py_ast = [class_def];
}

impl PyastGenPass.enter_enum(self: PyastGenPass, nd: uni.Enum) -> None {
    if isinstance(nd.body, uni.ImplDef) {
        self.traverse(nd.body);
    }
}

impl PyastGenPass.exit_enum(self: PyastGenPass, nd: uni.Enum) -> None {
    self.needs_enum();
    inner: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None = None;
    if isinstance(nd.body, uni.ImplDef) {
        inner = nd.body.body if not isinstance(nd.body.body, uni.Expr) else None;
    } elif not isinstance(nd.body, uni.Expr) {
        inner = nd.body;
    }
    body = self.resolve_stmt_block(inner, doc=nd.doc);
    decorators = [cast(ast3.expr, i.gen.py_ast[0]) for i in nd.decorators]
    if nd.decorators
    else [];
    if (sem_decorator := self._get_sem_decorator(nd)) {
        decorators.append(sem_decorator);
    }
    base_classes = [cast(ast3.expr, i.gen.py_ast[0]) for i in nd.base_classes];
    base_classes.append(self.builtin_name('Enum'));
    class_def = self.sync(
        ast3.ClassDef(
            name=nd.name.sym_name,
            bases=[cast(ast3.expr, i) for i in base_classes],
            keywords=[],
            body=[cast(ast3.stmt, i) for i in body],
            decorator_list=[cast(ast3.expr, i) for i in decorators],
            type_params=[]
        )
    );
    nd.gen.py_ast = [class_def];
}

impl PyastGenPass.enter_ability(self: PyastGenPass, nd: uni.Ability) -> None {
    if isinstance(nd.body, uni.ImplDef) {
        self.traverse(nd.body);
    }
}

"""Reusable method to codegen call_llm(model, caller, args)."""
impl PyastGenPass._invoke_llm_call(
    self: PyastGenPass, model: ast3.expr, caller: ast3.expr, args: ast3.Dict
) -> ast3.Call {
    mtir_ast = self.sync(
        ast3.Call(
            func=self.jaclib_obj('get_mtir'),
            args=[],
            keywords=[
                self.sync(ast3.keyword(arg='caller', value=caller)),
                self.sync(ast3.keyword(arg='args', value=args)),
                self.sync(
                    ast3.keyword(
                        arg='call_params',
                        value=self.sync(
                            ast3.Attribute(
                                value=model, attr='call_params', ctx=ast3.Load()
                            )
                        )
                    )
                )
            ]
        )
    );
    return self.sync(
        ast3.Call(
            func=self.jaclib_obj('call_llm'),
            args=[],
            keywords=[
                self.sync(ast3.keyword(arg='model', value=model)),
                self.sync(ast3.keyword(arg='mt_run', value=mtir_ast))
            ]
        )
    );
}

"""Generate the by LLM body."""
impl PyastGenPass.gen_llm_body(self: PyastGenPass, nd: uni.Ability) -> list[ast3.stmt] {
    assert isinstance(nd.signature, uni.FuncSignature);
    model_expr: ast3.expr;
    if (
        nd.signature.return_type
        and isinstance(nd.signature.return_type, uni.BinaryExpr)
        and isinstance(nd.signature.return_type.op, uni.Token)
        and (nd.signature.return_type.op.name == Tok.KW_BY)
    ) {
        model_expr = cast(ast3.expr, nd.signature.return_type.right.gen.py_ast[0]);
    } elif isinstance(nd.body, uni.Expr) {
        model_expr = cast(ast3.expr, nd.body.gen.py_ast[0]);
    } else {
        raise self.ice('gen_llm_body called without model expression') ;
    }
    caller: ast3.expr;
    if nd.method_owner {
        owner = self.sync(
            ast3.Name(
                id='self' if not nd.is_static else nd.method_owner.sym_name,
                ctx=ast3.Load()
            ),
            jac_node=nd.method_owner
        );
        caller = self.sync(
            ast3.Attribute(
                value=owner, attr=self._py_name(nd.name_ref), ctx=ast3.Load()
            ),
            jac_node=nd.method_owner
        );
    } else {
        caller = self.sync(ast3.Name(self._py_name(nd.name_ref), ctx=ast3.Load()));
    }
    args = self.sync(
        ast3.Dict(
            keys=[
                self.sync(ast3.Constant(value=param.name.sym_name))
                for param in nd.signature.params
            ],
            values=[
                self.sync(ast3.Name(param.name.sym_name, ctx=ast3.Load()))
                for param in nd.signature.params
            ]
        )
    );
    llm_call = self._invoke_llm_call(model=model_expr, caller=caller, args=args);
    statements: list[ast3.stmt] = [];
    if nd.doc {
        statements.append(
            self.sync(
                ast3.Expr(
                    value=self.sync(
                        ast3.Constant(value=nd.doc.lit_value), jac_node=nd.doc
                    )
                )
            )
        );
    }
    statements.append(self.sync(ast3.Return(value=llm_call)));
    return statements;
}

impl PyastGenPass.exit_ability(self: PyastGenPass, nd: uni.Ability) -> None {
    func_type = ast3.AsyncFunctionDef if nd.is_async else ast3.FunctionDef;
    has_by_in_return = (
        isinstance(nd.signature, uni.FuncSignature)
        and nd.signature.return_type
        and isinstance(nd.signature.return_type, uni.BinaryExpr)
        and isinstance(nd.signature.return_type.op, uni.Token)
        and (nd.signature.return_type.op.name == Tok.KW_BY)
    );
    body = self.gen_llm_body(nd)
    if (
        isinstance(nd.body, uni.Expr)
        or (isinstance(nd.body, uni.ImplDef) and isinstance(nd.body.body, uni.Expr))
        or has_by_in_return
    )
    else [
        self.sync(
            ast3.Expr(value=cast(ast3.expr, nd.doc.gen.py_ast[0])), jac_node=nd.doc
        ),
        self.sync(ast3.Pass(), nd.body)
    ]
    if (nd.doc and nd.is_abstract)
    else [self.sync(ast3.Pass(), nd.body)]
    if nd.is_abstract
    else self.resolve_stmt_block(
        nd.body.body
        if (
            isinstance(nd.body, uni.ImplDef) and not isinstance(nd.body.body, uni.Expr)
        )
        else nd.body if not isinstance(nd.body, uni.Expr) else None,
        doc=nd.doc
    );
    if (nd.is_abstract and nd.body) {
        self.log_error(
            "Abstract ability " + str(nd.sym_name) + " should not have a body.", nd
        );
    }
    decorator_list = [cast(ast3.expr, i.gen.py_ast[0]) for i in nd.decorators]
    if nd.decorators
    else [];
    if (sem_decorator := self._get_sem_decorator(nd)) {
        decorator_list.append(sem_decorator);
    }
    if isinstance(nd.signature, uni.EventSignature) {
        decorator_list.append(
            self.jaclib_obj(
                'on_entry' if (nd.signature.event.name == Tok.KW_ENTRY) else 'on_exit'
            )
        );
    }
    if isinstance(nd.body, uni.ImplDef) {
        decorator_list.append(
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('impl_patch_filename'),
                    args=[self.sync(ast3.Constant(value=nd.body.loc.mod_path))],
                    keywords=[]
                )
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
        decorator_list.insert(
            0, self.sync(ast3.Name(id='staticmethod', ctx=ast3.Load()))
        );
    }
    if (not body and not isinstance(nd.body, uni.Expr)) {
        self.log_error('Ability has no body. Perhaps an impl must be imported.', nd);
        body = [self.sync(ast3.Pass(), nd)];
    }
    ast_returns: ast3.expr = self.sync(ast3.Constant(value=None));
    if (isinstance(nd.signature, uni.FuncSignature) and nd.signature.return_type) {
        if (
            isinstance(nd.signature.return_type, uni.BinaryExpr)
            and isinstance(nd.signature.return_type.op, uni.Token)
            and (nd.signature.return_type.op.name == Tok.KW_BY)
        ) {
            ast_returns = cast(ast3.expr, nd.signature.return_type.left.gen.py_ast[0]);
        } else {
            ast_returns = cast(ast3.expr, nd.signature.return_type.gen.py_ast[0]);
        }
    }
    func_def = self.sync(
        func_type(
            name=self._py_name(nd.name_ref),
            args=cast(ast3.arguments, nd.signature.gen.py_ast[0])
            if nd.signature
            else self.sync(
                ast3.arguments(
                    posonlyargs=[],
                    args=[self.sync(ast3.arg(arg='self', annotation=None))]
                    if nd.is_method
                    else [],
                    vararg=None,
                    kwonlyargs=[],
                    kw_defaults=[],
                    kwarg=None,
                    defaults=[]
                )
            ),
            body=[cast(ast3.stmt, i) for i in body],
            decorator_list=[cast(ast3.expr, i) for i in decorator_list],
            returns=ast_returns,
            type_params=[]
        )
    );
    nd.gen.py_ast = [func_def];
}

impl PyastGenPass.exit_impl_def(self: PyastGenPass, nd: uni.ImplDef) -> None {
    ;
}

impl PyastGenPass.exit_sem_def(self: PyastGenPass, nd: uni.SemDef) -> None {
    ;
}

impl PyastGenPass.exit_func_signature(
    self: PyastGenPass, nd: uni.FuncSignature
) -> None {
    posonlyargs = [i.gen.py_ast[0] for i in nd.posonly_params];
    vararg = nd.varargs.gen.py_ast[0] if nd.varargs else None;
    kwarg = nd.kwargs.gen.py_ast[0] if nd.kwargs else None;
    params = [self.sync(ast3.arg(arg='self', annotation=None))]
    if (
        (abl := nd.parent)
        and isinstance(abl, uni.Ability)
        and abl.is_method
        and not nd.is_static
        and not nd.is_in_py_class
    )
    else [];
    if posonlyargs {
        posonlyargs = params + posonlyargs;
        params = [cast(ast3.arg, i.gen.py_ast[0]) for i in nd.params];
    } else {
        params = params + [cast(ast3.arg, i.gen.py_ast[0]) for i in nd.params];
    }
    defaults = [];
    for i in [*nd.posonly_params, *nd.params] {
        if i.value {
            defaults.append(cast(ast3.expr, i.value.gen.py_ast[0]));
        }
    }
    kwonly_args = [cast(ast3.arg, i.gen.py_ast[0]) for i in nd.kwonlyargs];
    kw_defaults: list[(ast3.expr | None)] = [];
    for i in nd.kwonlyargs {
        if i.value {
            kw_defaults.append(cast(ast3.expr, i.value.gen.py_ast[0]));
        } else {
            kw_defaults.append(None);
        }
    }
    nd.gen.py_ast = [
        self.sync(
            ast3.arguments(
                posonlyargs=[cast(ast3.arg, param) for param in posonlyargs],
                args=[cast(ast3.arg, param) for param in params],
                kwonlyargs=kwonly_args,
                vararg=cast(ast3.arg, vararg) if vararg else None,
                kwarg=cast(ast3.arg, kwarg) if kwarg else None,
                kw_defaults=kw_defaults,
                defaults=[cast(ast3.expr, `default) for `default in defaults]
            )
        )
    ];
}

impl PyastGenPass.exit_event_signature(
    self: PyastGenPass, nd: uni.EventSignature
) -> None {
    arch_kw = Con.HERE.value if nd.from_walker else Con.VISITOR.value;
    annotation = None;
    if nd.arch_tag_info {
        py_ast = cast(ast3.expr, nd.arch_tag_info.gen.py_ast[0]);
        if (
            isinstance(py_ast, ast3.Tuple)
            and isinstance(nd.arch_tag_info, uni.TupleVal)
        ) {
            if (len(py_ast.elts) > 1) {
                annotation = py_ast.elts[0];
                for elem in py_ast.elts[1:] {
                    annotation = self.sync(
                        ast3.BinOp(
                            left=annotation, op=self.sync(ast3.BitOr()), right=elem
                        )
                    );
                }
            } elif (len(py_ast.elts) == 1) {
                annotation = py_ast.elts[0];
            }
        } else {
            annotation = py_ast;
        }
    }
    if annotation {
        for n in ast3.walk(annotation) {
            if (isinstance(n, ast3.Name) and (n.id == 'Root')) {
                self.jaclib_imports.add('Root');
            }
        }
    }
    arch_arg = self.sync(
        ast3.arg(arg=f"{arch_kw}", annotation=annotation),
        jac_node=nd.arch_tag_info or nd
    );
    nd.gen.py_ast = [
        self.sync(
            ast3.arguments(
                posonlyargs=[],
                args=[self.sync(ast3.arg(arg='self', annotation=None)), arch_arg]
                if ((abl := nd.find_parent_of_type(uni.Ability)) and abl.is_method)
                else [arch_arg],
                kwonlyargs=[],
                vararg=None,
                kwarg=None,
                kw_defaults=[],
                defaults=[]
            )
        )
    ];
}

impl PyastGenPass.exit_param_var(self: PyastGenPass, nd: uni.ParamVar) -> None {
    if isinstance(nd.name.gen.py_ast[0], ast3.Name) {
        name = nd.name.gen.py_ast[0].id;
        nd.gen.py_ast = [
            self.sync(
                ast3.arg(
                    arg=name,
                    annotation=cast(ast3.expr, nd.type_tag.gen.py_ast[0])
                    if nd.type_tag
                    else None
                )
            )
        ];
    }
}

impl PyastGenPass.exit_arch_has(self: PyastGenPass, nd: uni.ArchHas) -> None {
    vars_py: list[ast3.AST] = self._flatten_ast_list([v.gen.py_ast for v in nd.vars]);
    if nd.doc {
        doc = self.sync(
            ast3.Expr(value=cast(ast3.expr, nd.doc.gen.py_ast[0])), jac_node=nd.doc
        );
        if isinstance(doc, ast3.AST) {
            nd.gen.py_ast = [doc] + vars_py;
        } else {
            raise self.ice() ;
        }
    } else {
        nd.gen.py_ast = vars_py;
    }
}

impl PyastGenPass.exit_has_var(self: PyastGenPass, nd: uni.HasVar) -> None {
    annotation = nd.type_tag.gen.py_ast[0] if nd.type_tag else None;
    is_static_var = (
        (haspar := nd.find_parent_of_type(uni.ArchHas)) and haspar and haspar.is_static
    );
    is_in_class = (
        (archpar := nd.find_parent_of_type(uni.Archetype))
        and archpar
        and (archpar.arch_type.name == Tok.KW_CLASS)
    );
    value = None;
    if is_in_class {
        value = cast(ast3.expr, nd.value.gen.py_ast[0]) if nd.value else None;
    } elif is_static_var {
        annotation = self.sync(
            ast3.Subscript(
                value=self.builtin_name('ClassVar'),
                slice=cast(ast3.expr, annotation),
                ctx=ast3.Load()
            )
        );
        value = cast(ast3.expr, nd.value.gen.py_ast[0]) if nd.value else None;
    } elif nd.defer {
        value = self.sync(
            ast3.Call(
                func=self.jaclib_obj('field'),
                args=[],
                keywords=[
                    self.sync(
                        ast3.keyword(
                            arg='init', value=self.sync(ast3.Constant(value=False))
                        )
                    )
                ]
            )
        );
    } elif nd.value {
        if isinstance(nd.value.gen.py_ast[0], ast3.Constant) {
            value = cast(ast3.expr, nd.value.gen.py_ast[0]);
        } else {
            value = self.sync(
                ast3.Call(
                    func=self.jaclib_obj('field'),
                    args=[],
                    keywords=[
                        self.sync(
                            ast3.keyword(
                                arg='factory',
                                value=self.sync(
                                    ast3.Lambda(
                                        args=self.sync(
                                            ast3.arguments(
                                                posonlyargs=[],
                                                args=[],
                                                kwonlyargs=[],
                                                vararg=None,
                                                kwarg=None,
                                                kw_defaults=[],
                                                defaults=[]
                                            )
                                        ),
                                        body=cast(ast3.expr, nd.value.gen.py_ast[0])
                                    )
                                )
                            )
                        )
                    ]
                )
            );
        }
    }
    nd.gen.py_ast = [
        self.sync(
            ast3.AnnAssign(
                target=cast(
                    ast3.Name | ast3.Attribute | ast3.Subscript, nd.name.gen.py_ast[0]
                ),
                annotation=cast(ast3.expr, annotation)
                if annotation
                else ast3.Constant(value=None),
                value=value,
                simple=int(isinstance(nd.name, uni.Name))
            )
        )
    ];
}

impl PyastGenPass.exit_typed_ctx_block(
    self: PyastGenPass, nd: uni.TypedCtxBlock
) -> None {
    loc = self.sync(
        ast3.Name(id=Con.HERE.value, ctx=ast3.Load())
        if nd.from_walker
        else ast3.Name(id=Con.VISITOR.value, ctx=ast3.Load())
    );
    nd.gen.py_ast = [
        self.sync(
            ast3.If(
                `test=self.sync(
                    ast3.Call(
                        func=self.sync(ast3.Name(id='isinstance', ctx=ast3.Load())),
                        args=[loc, cast(ast3.expr, nd.type_ctx.gen.py_ast[0])],
                        keywords=[]
                    )
                ),
                body=cast(`list[ast3.stmt], self.resolve_stmt_block(nd.body)),
                orelse=[]
            )
        )
    ];
}

impl PyastGenPass.exit_if_stmt(self: PyastGenPass, nd: uni.IfStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.If(
                `test=cast(ast3.expr, nd.condition.gen.py_ast[0]),
                body=cast(`list[ast3.stmt], self.resolve_stmt_block(nd.body)),
                orelse=cast(`list[ast3.stmt], nd.else_body.gen.py_ast)
                if nd.else_body
                else []
            )
        )
    ];
}

impl PyastGenPass.exit_else_if(self: PyastGenPass, nd: uni.ElseIf) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.If(
                `test=cast(ast3.expr, nd.condition.gen.py_ast[0]),
                body=cast(`list[ast3.stmt], self.resolve_stmt_block(nd.body)),
                orelse=cast(`list[ast3.stmt], nd.else_body.gen.py_ast)
                if nd.else_body
                else []
            )
        )
    ];
}

impl PyastGenPass.exit_else_stmt(self: PyastGenPass, nd: uni.ElseStmt) -> None {
    nd.gen.py_ast = self.resolve_stmt_block(nd.body);
}

impl PyastGenPass.exit_expr_stmt(self: PyastGenPass, nd: uni.ExprStmt) -> None {
    hoisted = self._hoisted_funcs[:];
    self._hoisted_funcs.clear();
    expr_stmt = self.sync(ast3.Expr(value=cast(ast3.expr, nd.expr.gen.py_ast[0])))
    if not nd.in_fstring
    else self.sync(
        ast3.FormattedValue(
            value=cast(ast3.expr, nd.expr.gen.py_ast[0]),
            conversion=-1,
            format_spec=None
        )
    );
    nd.gen.py_ast = [*hoisted, expr_stmt];
}

impl PyastGenPass.exit_concurrent_expr(
    self: PyastGenPass, nd: uni.ConcurrentExpr
) -> None {
    func = '';
    if nd.tok {
        match nd.tok.value {
            case 'flow':
                func = 'thread_run';

            case 'wait':
                func = 'thread_wait';

        }
    }
    if func {
        lambda_ex = [
            self.sync(
                ast3.Lambda(
                    args=self.sync(
                        ast3.arguments(
                            posonlyargs=[],
                            args=[],
                            kwonlyargs=[],
                            kw_defaults=[],
                            defaults=[]
                        )
                    ),
                    body=cast(ast3.expr, nd.target.gen.py_ast[0])
                )
            )
        ];
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj(func),
                    args=cast(
                        `list[ast3.expr],
                        lambda_ex
                        if (func == 'thread_run')
                        else [nd.target.gen.py_ast[0]]
                    ),
                    keywords=[]
                )
            )
        ];
    }
}

impl PyastGenPass.exit_try_stmt(self: PyastGenPass, nd: uni.TryStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Try(
                body=cast(`list[ast3.stmt], self.resolve_stmt_block(nd.body)),
                handlers=[
                    cast(ast3.ExceptHandler, i.gen.py_ast[0]) for i in nd.excepts
                ],
                orelse=[cast(ast3.stmt, i) for i in nd.else_body.gen.py_ast]
                if nd.else_body
                else [],
                finalbody=[cast(ast3.stmt, i) for i in nd.finally_body.gen.py_ast]
                if nd.finally_body
                else []
            )
        )
    ];
}

impl PyastGenPass.exit_except(self: PyastGenPass, nd: uni.Except) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.ExceptHandler(
                `type=cast(ast3.expr, nd.ex_type.gen.py_ast[0]) if nd.ex_type else None,
                name=nd.name.sym_name if nd.name else None,
                body=[
                    cast(ast3.stmt, stmt) for stmt in self.resolve_stmt_block(nd.body)
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_finally_stmt(self: PyastGenPass, nd: uni.FinallyStmt) -> None {
    nd.gen.py_ast = self.resolve_stmt_block(nd.body);
}

impl PyastGenPass.exit_iter_for_stmt(self: PyastGenPass, nd: uni.IterForStmt) -> None {
    py_nodes: list[ast3.AST] = [];
    body = self.resolve_stmt_block(nd.body);
    if (
        isinstance(body, `list)
        and isinstance(nd.count_by.gen.py_ast[0], ast3.AST)
        and isinstance(nd.iter.gen.py_ast[0], ast3.AST)
    ) {
        body += [nd.count_by.gen.py_ast[0]];
    } else {
        raise self.ice() ;
    }
    py_nodes.append(nd.iter.gen.py_ast[0]);
    py_nodes.append(
        self.sync(
            ast3.While(
                `test=cast(ast3.expr, nd.condition.gen.py_ast[0]),
                body=[cast(ast3.stmt, stmt) for stmt in body],
                orelse=[cast(ast3.stmt, stmt) for stmt in nd.else_body.gen.py_ast]
                if nd.else_body
                else []
            )
        )
    );
    nd.gen.py_ast = py_nodes;
}

impl PyastGenPass.exit_in_for_stmt(self: PyastGenPass, nd: uni.InForStmt) -> None {
    for_node = ast3.AsyncFor if nd.is_async else ast3.For;
    nd.gen.py_ast = [
        self.sync(
            for_node(
                target=cast(ast3.expr, nd.target.gen.py_ast[0]),
                iter=cast(ast3.expr, nd.collection.gen.py_ast[0]),
                body=[
                    cast(ast3.stmt, stmt) for stmt in self.resolve_stmt_block(nd.body)
                ],
                orelse=[cast(ast3.stmt, stmt) for stmt in nd.else_body.gen.py_ast]
                if nd.else_body
                else []
            )
        )
    ];
}

impl PyastGenPass.exit_while_stmt(self: PyastGenPass, nd: uni.WhileStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.While(
                `test=cast(ast3.expr, nd.condition.gen.py_ast[0]),
                body=[
                    cast(ast3.stmt, stmt) for stmt in self.resolve_stmt_block(nd.body)
                ],
                orelse=[cast(ast3.stmt, stmt) for stmt in nd.else_body.gen.py_ast]
                if nd.else_body
                else []
            )
        )
    ];
}

impl PyastGenPass.exit_with_stmt(self: PyastGenPass, nd: uni.WithStmt) -> None {
    with_node = ast3.AsyncWith if nd.is_async else ast3.With;
    nd.gen.py_ast = [
        self.sync(
            with_node(
                items=[cast(ast3.withitem, item.gen.py_ast[0]) for item in nd.exprs],
                body=[
                    cast(ast3.stmt, stmt) for stmt in self.resolve_stmt_block(nd.body)
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_expr_as_item(self: PyastGenPass, nd: uni.ExprAsItem) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.withitem(
                context_expr=cast(ast3.expr, nd.expr.gen.py_ast[0]),
                optional_vars=cast(ast3.expr, nd.alias.gen.py_ast[0])
                if nd.alias
                else None
            )
        )
    ];
}

impl PyastGenPass.exit_raise_stmt(self: PyastGenPass, nd: uni.RaiseStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Raise(
                exc=cast(ast3.expr, nd.cause.gen.py_ast[0]) if nd.cause else None,
                cause=cast(ast3.expr, nd.from_target.gen.py_ast[0])
                if nd.from_target
                else None
            )
        )
    ];
}

impl PyastGenPass.exit_assert_stmt(self: PyastGenPass, nd: uni.AssertStmt) -> None {
    if isinstance(nd.parent, uni.Test) {
        self.assert_helper(nd);
    } else {
        nd.gen.py_ast = [
            self.sync(
                ast3.Assert(
                    `test=cast(ast3.expr, nd.condition.gen.py_ast[0]),
                    msg=cast(ast3.expr, nd.error_msg.gen.py_ast[0])
                    if nd.error_msg
                    else None
                )
            )
        ];
    }
}

"""Sub objects.

        target: ExprType,
        """
impl PyastGenPass.assert_helper(self: PyastGenPass, nd: uni.AssertStmt) -> None {
    @dataclass
    class CheckNodeIsinstanceCallResult {
        with entry {
            isit: bool = False;
            inst: (ast3.AST | None) = None;
            clss: (ast3.AST | None) = None;
        }
    }
    def check_node_isinstance_call(nd: uni.FuncCall) -> CheckNodeIsinstanceCallResult {
        if not (
            (len(nd.params) == 2)
            and isinstance(nd.params[0], uni.Expr)
            and isinstance(nd.params[1], uni.Expr)
        ) {
            return CheckNodeIsinstanceCallResult();
        }
        func = nd.target.gen.py_ast[0];
        if not (isinstance(func, ast3.Name) and (func.id == 'isinstance')) {
            return CheckNodeIsinstanceCallResult();
        }
        return CheckNodeIsinstanceCallResult(
            True, nd.params[0].gen.py_ast[0], nd.params[1].gen.py_ast[0]
        );
    }
    assert_func_name = 'assertTrue';
    assert_args_list = nd.condition.gen.py_ast;
    if (
        isinstance(nd.condition, uni.CompareExpr)
        and isinstance(nd.condition.gen.py_ast[0], ast3.Compare)
        and (len(nd.condition.ops) == 1)
    ) {
        expr: uni.CompareExpr = nd.condition;
        opty: uni.Token = expr.ops[0];
        optype2fn = {
            Tok.EE.name: 'assertEqual',
            Tok.NE.name: 'assertNotEqual',
            Tok.LT.name: 'assertLess',
            Tok.LTE.name: 'assertLessEqual',
            Tok.GT.name: 'assertGreater',
            Tok.GTE.name: 'assertGreaterEqual',
            Tok.KW_IN.name: 'assertIn',
            Tok.KW_NIN.name: 'assertNotIn',
            Tok.KW_IS.name: 'assertIs',
            Tok.KW_ISN.name: 'assertIsNot'
        };
        if (opty.name in optype2fn) {
            assert_func_name = optype2fn[opty.name];
            assert_args_list = [expr.left.gen.py_ast[0], expr.rights[0].gen.py_ast[0]];
            if ((opty.name == Tok.KW_IS) and isinstance(expr.rights[0], uni.Null)) {
                assert_func_name = 'assertIsNone';
                assert_args_list.pop();
            } elif ((opty.name == Tok.KW_ISN) and isinstance(expr.rights[0], uni.Null)) {
                assert_func_name = 'assertIsNotNone';
                assert_args_list.pop();
            }
        }
    } elif (
        isinstance(nd.condition, uni.FuncCall)
        and isinstance(nd.condition.gen.py_ast[0], ast3.Call)
    ) {
        res = check_node_isinstance_call(nd.condition);
        if res.isit {
            assert isinstance(res.inst, ast3.AST);
            assert isinstance(res.clss, ast3.AST);
            assert_func_name = 'assertIsInstance';
            assert_args_list = [res.inst, res.clss];
        }
    } elif (
        isinstance(nd.condition, uni.UnaryExpr)
        and isinstance(nd.condition, uni.UnaryExpr)
        and isinstance(nd.condition.operand, uni.FuncCall)
        and isinstance(nd.condition.operand, uni.UnaryExpr)
    ) {
        res = check_node_isinstance_call(nd.condition.operand);
        if res.isit {
            assert isinstance(res.inst, ast3.AST);
            assert isinstance(res.clss, ast3.AST);
            assert_func_name = 'assertIsNotInstance';
            assert_args_list = [res.inst, res.clss];
        }
    }
    if (
        isinstance(nd.condition, uni.FuncCall)
        and isinstance(nd.condition.gen.py_ast[0], ast3.Call)
    ) {
        func = nd.condition.target;
        if (isinstance(func, uni.Name) and (func.value == 'almostEqual')) {
            assert_func_name = 'assertAlmostEqual';
            assert_args_list = [];
            for param in nd.condition.params {
                assert_args_list.append(param.gen.py_ast[0]);
            }
        }
    }
    assert_func_expr: ast3.Attribute = self.sync(
        ast3.Attribute(
            value=self.sync(ast3.Name(id=Con.JAC_CHECK.value, ctx=ast3.Load())),
            attr=assert_func_name,
            ctx=ast3.Load()
        )
    );
    assert_call_expr: ast3.Call = self.sync(
        ast3.Call(
            func=assert_func_expr,
            args=[cast(ast3.expr, arg) for arg in assert_args_list],
            keywords=[]
        )
    );
    nd.gen.py_ast = [self.sync(ast3.Expr(assert_call_expr))];
}

impl PyastGenPass.exit_ctrl_stmt(self: PyastGenPass, nd: uni.CtrlStmt) -> None {
    if (nd.ctrl.name == Tok.KW_BREAK) {
        nd.gen.py_ast = [self.sync(ast3.Break())];
    } elif (nd.ctrl.name == Tok.KW_CONTINUE) {
        if (iter_for_parent := self.find_parent_of_type(nd, uni.IterForStmt)) {
            count_by = iter_for_parent.count_by;
            nd.gen.py_ast = [count_by.gen.py_ast[0], self.sync(ast3.Continue())];
        } else {
            nd.gen.py_ast = [self.sync(ast3.Continue())];
        }
    } elif (nd.ctrl.name == Tok.KW_SKIP) {
        nd.gen.py_ast = [self.sync(ast3.Return(value=None))];
    }
}

impl PyastGenPass.exit_delete_stmt(self: PyastGenPass, nd: uni.DeleteStmt) -> None {
    """Set the given ctx (Load, Del) to AST node(s).""";
    def set_ctx(targets: (ast3.AST | list[ast3.AST]), ctx: type) -> list[ast3.AST] {
        if not isinstance(targets, `list) {
            targets = [targets];
        } elif isinstance(targets[0], (ast3.List, ast3.Tuple)) {
            targets = [
                i
                for i in targets[0].elts
                if isinstance(i, ast3.AST)
            ];
        }
        result = [];
        for target in targets {
            if target?.ctx {
                target = copy.copy(target);
                target.ctx = ctx();
            }
            result.append(target);
        }
        return result;
    }
    destroy_expr = ast3.Expr(
        value=self.sync(
            ast3.Call(
                func=self.jaclib_obj('destroy'),
                args=[
                    self.sync(
                        ast3.List(
                            elts=cast(
                                `list[ast3.expr], set_ctx(nd.py_ast_targets, ast3.Load)
                            ),
                            ctx=ast3.Load()
                        )
                    )
                ],
                keywords=[]
            )
        )
    );
    delete_stmt = self.sync(
        ast3.Delete(
            targets=cast(`list[ast3.expr], set_ctx(nd.py_ast_targets, ast3.Del))
        )
    );
    nd.gen.py_ast = [self.sync(destroy_expr), self.sync(delete_stmt)];
}

impl PyastGenPass.exit_report_stmt(self: PyastGenPass, nd: uni.ReportStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Expr(
                value=self.sync(
                    self.sync(
                        ast3.Call(
                            func=self.jaclib_obj('log_report'),
                            args=cast(`list[ast3.expr], nd.expr.gen.py_ast),
                            keywords=[]
                        )
                    )
                )
            )
        )
    ];
}

impl PyastGenPass.exit_return_stmt(self: PyastGenPass, nd: uni.ReturnStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Return(
                value=cast(ast3.expr, nd.expr.gen.py_ast[0]) if nd.expr else None
            )
        )
    ];
}

impl PyastGenPass.exit_yield_expr(self: PyastGenPass, nd: uni.YieldExpr) -> None {
    if not nd.with_from {
        nd.gen.py_ast = [
            self.sync(
                ast3.Yield(
                    value=cast(ast3.expr, nd.expr.gen.py_ast[0]) if nd.expr else None
                )
            )
        ];
    } else {
        nd.gen.py_ast = [
            self.sync(
                ast3.YieldFrom(
                    value=cast(ast3.expr, nd.expr.gen.py_ast[0])
                    if nd.expr
                    else self.sync(ast3.Constant(value=None))
                )
            )
        ];
    }
}

impl PyastGenPass.exit_visit_stmt(self: PyastGenPass, nd: uni.VisitStmt) -> None {
    loc = self.sync(
        ast3.Name(id='self', ctx=ast3.Load())
        if nd.from_walker
        else ast3.Name(id=Con.VISITOR.value, ctx=ast3.Load())
    );
    visit_call = self.sync(
        ast3.Call(
            func=self.jaclib_obj('visit'),
            args=cast(`list[ast3.expr], [loc, nd.target.gen.py_ast[0]]),
            keywords=[]
        )
    );
    if (nd.insert_loc is not None) {
        visit_call.keywords.append(
            self.sync(
                ast3.keyword(
                    arg='insert_loc',
                    value=cast(ast3.expr, nd.insert_loc.gen.py_ast[0])
                )
            )
        );
    }
    nd.gen.py_ast = [
        self.sync(
            ast3.If(
                `test=self.sync(
                    ast3.UnaryOp(op=self.sync(ast3.Not()), operand=visit_call)
                ),
                body=cast(`list[ast3.stmt], nd.else_body.gen.py_ast),
                orelse=[]
            )
        )
        if nd.else_body
        else self.sync(ast3.Expr(value=visit_call))
    ];
}

impl PyastGenPass.exit_disengage_stmt(
    self: PyastGenPass, nd: uni.DisengageStmt
) -> None {
    loc = self.sync(
        ast3.Name(id='self', ctx=ast3.Load())
        if nd.from_walker
        else ast3.Name(id=Con.VISITOR.value, ctx=ast3.Load())
    );
    nd.gen.py_ast = [
        self.sync(
            ast3.Expr(
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj('disengage'), args=[loc], keywords=[]
                    )
                )
            )
        ),
        self.sync(ast3.Return())
    ];
}

impl PyastGenPass.exit_await_expr(self: PyastGenPass, nd: uni.AwaitExpr) -> None {
    nd.gen.py_ast = [
        self.sync(ast3.Await(value=cast(ast3.expr, nd.target.gen.py_ast[0])))
    ];
}

impl PyastGenPass.exit_global_stmt(self: PyastGenPass, nd: uni.GlobalStmt) -> None {
    py_nodes = [];
    for x in nd.target {
        py_nodes.append(self.sync(ast3.Global(names=[x.sym_name]), jac_node=x));
    }
    nd.gen.py_ast = [*py_nodes];
}

impl PyastGenPass.exit_non_local_stmt(self: PyastGenPass, nd: uni.NonLocalStmt) -> None {
    py_nodes = [];
    for x in nd.target {
        py_nodes.append(self.sync(ast3.Nonlocal(names=[x.sym_name]), jac_node=x));
    }
    nd.gen.py_ast = [*py_nodes];
}

impl PyastGenPass.exit_assignment(self: PyastGenPass, nd: uni.Assignment) -> None {
    value = nd.value.gen.py_ast[0]
    if nd.value
    else self.sync(
        ast3.Call(
            func=self.sync(ast3.Name(id='auto', ctx=ast3.Load())), args=[], keywords=[]
        )
    )
    if nd.is_enum_stmt
    else None if nd.type_tag else self.ice();
    targets_ast = [cast(ast3.expr, t.gen.py_ast[0]) for t in nd.target];
    hoisted = self._hoisted_funcs[:];
    self._hoisted_funcs.clear();
    if nd.type_tag {
        assignment_stmt: ast3.AnnAssign | ast3.Assign | ast3.AugAssign = self.sync(
            ast3.AnnAssign(
                target=cast(ast3.Name, targets_ast[0]),
                annotation=cast(ast3.expr, nd.type_tag.gen.py_ast[0]),
                value=cast(ast3.expr, nd.value.gen.py_ast[0]) if nd.value else None,
                simple=int(isinstance(targets_ast[0], ast3.Name))
            )
        );
    } elif nd.aug_op {
        assignment_stmt = self.sync(
            ast3.AugAssign(
                target=cast(ast3.Name, targets_ast[0]),
                op=cast(ast3.operator, nd.aug_op.gen.py_ast[0]),
                value=cast(ast3.expr, value)
                if isinstance(value, ast3.expr)
                else ast3.Constant(value=None)
            )
        );
    } else {
        assignment_stmt = self.sync(
            ast3.Assign(
                targets=cast(`list[ast3.expr], targets_ast),
                value=cast(ast3.expr, value)
                if isinstance(value, ast3.expr)
                else ast3.Constant(value=None)
            )
        );
    }
    nd.gen.py_ast = [*hoisted, assignment_stmt];
}

impl PyastGenPass.exit_binary_expr(self: PyastGenPass, nd: uni.BinaryExpr) -> None {
    if isinstance(nd.op, uni.ConnectOp) {
        left = nd.right.gen.py_ast[0]
        if (nd.op.edge_dir == EdgeDir.IN)
        else nd.left.gen.py_ast[0];
        right = nd.left.gen.py_ast[0]
        if (nd.op.edge_dir == EdgeDir.IN)
        else nd.right.gen.py_ast[0];
        keywords = [
            self.sync(ast3.keyword(arg='left', value=cast(ast3.expr, left))),
            self.sync(ast3.keyword(arg='right', value=cast(ast3.expr, right)))
        ];
        if nd.op.conn_type {
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='edge',
                        value=cast(ast3.expr, nd.op.conn_type.gen.py_ast[0])
                    )
                )
            );
        }
        if (nd.op.edge_dir == EdgeDir.ANY) {
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='undir', value=self.sync(ast3.Constant(value=True))
                    )
                )
            );
        }
        if nd.op.conn_assign {
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='conn_assign',
                        value=cast(ast3.expr, nd.op.conn_assign.gen.py_ast[0])
                    )
                )
            );
        }
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(func=self.jaclib_obj('connect'), args=[], keywords=keywords)
            )
        ];
    } elif isinstance(nd.op, uni.DisconnectOp) {
        keywords = [
            self.sync(
                ast3.keyword(arg='left', value=cast(ast3.expr, nd.left.gen.py_ast[0]))
            ),
            self.sync(
                ast3.keyword(
                    arg='right', value=cast(ast3.expr, nd.right.gen.py_ast[0])
                )
            )
        ];
        if (nd.op.edge_spec.edge_dir != EdgeDir.OUT) {
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='EdgeDir',
                        value=self.sync(
                            ast3.Attribute(
                                value=self.jaclib_obj('EdgeDir'),
                                attr=nd.op.edge_spec.edge_dir.name,
                                ctx=ast3.Load()
                            )
                        )
                    )
                )
            );
        }
        if nd.op.edge_spec.filter_cond {
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='filter_on',
                        value=cast(
                            ast3.expr, nd.op.edge_spec.filter_cond.gen.py_ast[0]
                        )
                    )
                )
            );
        }
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('disconnect'), args=[], keywords=keywords
                )
            )
        ];
    } elif (nd.op.name in [Tok.KW_AND.value, Tok.KW_OR.value]) {
        nd.gen.py_ast = [
            self.sync(
                ast3.BoolOp(
                    op=cast(ast3.boolop, nd.op.gen.py_ast[0]),
                    values=[
                        cast(ast3.expr, nd.left.gen.py_ast[0]),
                        cast(ast3.expr, nd.right.gen.py_ast[0])
                    ]
                )
            )
        ];
    } elif (
        (nd.op.name in [Tok.WALRUS_EQ])
        and isinstance(nd.left.gen.py_ast[0], ast3.Name)
    ) {
        nd.left.gen.py_ast[0].ctx = ast3.Store();
        nd.gen.py_ast = [
            self.sync(
                ast3.NamedExpr(
                    target=cast(ast3.Name, nd.left.gen.py_ast[0]),
                    value=cast(ast3.expr, nd.right.gen.py_ast[0])
                )
            )
        ];
    } elif (nd.op.gen.py_ast and isinstance(nd.op.gen.py_ast[0], ast3.AST)) {
        nd.gen.py_ast = [
            self.sync(
                ast3.BinOp(
                    left=cast(ast3.expr, nd.left.gen.py_ast[0]),
                    right=cast(ast3.expr, nd.right.gen.py_ast[0]),
                    op=cast(ast3.operator, nd.op.gen.py_ast[0])
                )
            )
        ];
    } else {
        nd.gen.py_ast = self.translate_jac_bin_op(nd);
    }
}

impl PyastGenPass.translate_jac_bin_op(
    self: PyastGenPass, nd: uni.BinaryExpr
) -> list[ast3.AST] {
    if isinstance(nd.op, (uni.DisconnectOp, uni.ConnectOp)) {
        raise self.ice() ;
    } elif (nd.op.name in [Tok.PIPE_FWD, Tok.A_PIPE_FWD]) {
        func_node = uni.FuncCall(
            target=nd.right,
            params=`list(nd.left.values)
            if (isinstance(nd.left, uni.TupleVal) and nd.left.values)
            else [nd.left],
            genai_call=None,
            kid=nd.kid
        );
        func_node.parent = nd.parent;
        self.exit_func_call(func_node);
        return func_node.gen.py_ast;
    } elif (nd.op.name in [Tok.KW_SPAWN]) {
        return [
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('spawn'),
                    args=cast(
                        `list[ast3.expr],
                        [nd.left.gen.py_ast[0], nd.right.gen.py_ast[0]]
                    ),
                    keywords=[]
                )
            )
        ];
    } elif (nd.op.name in [Tok.PIPE_BKWD, Tok.A_PIPE_BKWD]) {
        func_node = uni.FuncCall(
            target=nd.left,
            params=`list(nd.right.values)
            if (isinstance(nd.right, uni.TupleVal) and nd.right.values)
            else [nd.right],
            genai_call=None,
            kid=nd.kid
        );
        func_node.parent = nd.parent;
        self.exit_func_call(func_node);
        return func_node.gen.py_ast;
    } elif (nd.op.name in [Tok.KW_BY]) {
        return [
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('by_operator'),
                    args=cast(
                        `list[ast3.expr],
                        [nd.left.gen.py_ast[0], nd.right.gen.py_ast[0]]
                    ),
                    keywords=[]
                )
            )
        ];
    } elif ((nd.op.name == Tok.PIPE_FWD) and isinstance(nd.right, uni.TupleVal)) {
        self.log_error('Invalid pipe target.');
    } else {
        self.log_error(
            "Binary operator " + str(nd.op.value) + " not supported in bootstrap Jac"
        );
    }
    return [];
}

impl PyastGenPass.exit_compare_expr(self: PyastGenPass, nd: uni.CompareExpr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Compare(
                left=cast(ast3.expr, nd.left.gen.py_ast[0]),
                comparators=[cast(ast3.expr, i.gen.py_ast[0]) for i in nd.rights],
                ops=[cast(ast3.cmpop, i.gen.py_ast[0]) for i in nd.ops]
            )
        )
    ];
}

impl PyastGenPass.exit_bool_expr(self: PyastGenPass, nd: uni.BoolExpr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.BoolOp(
                op=cast(ast3.boolop, nd.op.gen.py_ast[0]),
                values=[cast(ast3.expr, i.gen.py_ast[0]) for i in nd.values]
            )
        )
    ];
}

impl PyastGenPass.exit_lambda_expr(self: PyastGenPass, nd: uni.LambdaExpr) -> None {
    if isinstance(nd.body, `list) {
        if (nd.signature and nd.signature.gen.py_ast) {
            arguments = cast(ast3.arguments, nd.signature.gen.py_ast[0]);
        } else {
            arguments = self.sync(
                ast3.arguments(
                    posonlyargs=[], args=[], kwonlyargs=[], kw_defaults=[], defaults=[]
                ),
                jac_node=nd
            );
        }
        body_stmts = [
            cast(ast3.stmt, stmt)
            for stmt in self.resolve_stmt_block(nd.body, doc=None)
        ];
        if not body_stmts {
            body_stmts = [self.sync(ast3.Pass(), jac_node=nd)];
        }
        func_name = self._next_temp_name('lambda');
        returns = cast(ast3.expr, nd.signature.return_type.gen.py_ast[0])
        if (
            nd.signature
            and nd.signature.return_type
            and nd.signature.return_type.gen.py_ast
        )
        else None;
        func_def = self.sync(
            ast3.FunctionDef(
                name=func_name,
                args=arguments,
                body=body_stmts,
                decorator_list=[],
                returns=returns,
                type_params=[]
            ),
            jac_node=nd
        );
        nd.gen.py_ast = [
            self._function_expr_from_def(
                func_def=func_def,
                jac_node=nd,
                filename_hint=f"<jac_lambda:{func_name}>"
            )
        ];
        return;
    }
    if nd.signature {
        self._remove_lambda_param_annotations(nd.signature);
    }
    if (nd.signature and nd.signature.gen.py_ast) {
        arguments = cast(ast3.arguments, nd.signature.gen.py_ast[0]);
    } else {
        arguments = self.sync(
            ast3.arguments(
                posonlyargs=[], args=[], kwonlyargs=[], kw_defaults=[], defaults=[]
            ),
            jac_node=nd
        );
    }
    body_node = cast(uni.Expr, nd.body);
    body_expr = cast(ast3.expr, body_node.gen.py_ast[0]);
    nd.gen.py_ast = [
        self.sync(ast3.Lambda(args=arguments, body=body_expr), jac_node=nd)
    ];
}

impl PyastGenPass._remove_lambda_param_annotations(
    self: PyastGenPass, signature: uni.FuncSignature
) -> None {
    for param in signature.params {
        if (param.gen.py_ast and isinstance(param.gen.py_ast[0], ast3.arg)) {
            param.gen.py_ast[0].annotation = None;
        }
    }
}

impl PyastGenPass.exit_unary_expr(self: PyastGenPass, nd: uni.UnaryExpr) -> None {
    op_tok = Tok(nd.op.name) if (nd.op.name in Tok.__members__) else None;
    op_cls = UNARY_OP_MAP.get(op_tok) if op_tok else None;
    if op_cls {
        nd.gen.py_ast = [
            self.sync(
                ast3.UnaryOp(
                    op=self.sync(op_cls()),
                    operand=cast(ast3.expr, nd.operand.gen.py_ast[0])
                )
            )
        ];
        return;
    } elif (nd.op.name in [Tok.PIPE_FWD, Tok.KW_SPAWN, Tok.A_PIPE_FWD]) {
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=cast(ast3.expr, nd.operand.gen.py_ast[0]),
                    args=[],
                    keywords=[]
                )
            )
        ];
    } elif (nd.op.name in [Tok.STAR_MUL]) {
        ctx_val = nd.operand.py_ctx_func()
        if isinstance(nd.operand, uni.AstSymbolNode)
        else ast3.Load();
        nd.gen.py_ast = [
            self.sync(
                ast3.Starred(
                    value=cast(ast3.expr, nd.operand.gen.py_ast[0]),
                    ctx=cast(ast3.expr_context, ctx_val)
                )
            )
        ];
    } elif (nd.op.name in [Tok.STAR_POW]) {
        nd.gen.py_ast = nd.operand.gen.py_ast;
    } elif (nd.op.name in [Tok.BW_AND]) {
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=self.builtin_name('jobj'),
                    args=[],
                    keywords=[
                        self.sync(
                            ast3.keyword(
                                arg='id',
                                value=cast(ast3.expr, nd.operand.gen.py_ast[0])
                            )
                        )
                    ]
                )
            )
        ];
    } else {
        self.ice("Unknown Unary operator " + str(nd.op.value));
    }
}

impl PyastGenPass.exit_if_else_expr(self: PyastGenPass, nd: uni.IfElseExpr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.IfExp(
                `test=cast(ast3.expr, nd.condition.gen.py_ast[0]),
                body=cast(ast3.expr, nd.value.gen.py_ast[0]),
                orelse=cast(ast3.expr, nd.else_value.gen.py_ast[0])
            )
        )
    ];
}

impl PyastGenPass.exit_multi_string(self: PyastGenPass, nd: uni.MultiString) -> None {
    def get_pieces(str_seq: Sequence) -> list[(str | ast3.AST)] {
        pieces: list[(str | ast3.AST)] = [];
        for i in str_seq {
            if isinstance(i, uni.String) {
                pieces.append(i.lit_value);
            } elif isinstance(i, (uni.FString, uni.ExprStmt)) {
                pieces.append(i.gen.py_ast[0]);
            } elif (isinstance(i, uni.Token) and (i.name in [Tok.LBRACE, Tok.RBRACE])) {
                continue;
            } else {
                raise self.ice('Multi string made of something weird.') ;
            }
        }
        return pieces;
    }
    combined_multi: list[str | bytes | ast3.AST] = [];
    for item in get_pieces(nd.strings) {
        if (
            combined_multi
            and isinstance(item, str)
            and isinstance(combined_multi[-1], str)
        ) {
            if isinstance(combined_multi[-1], str) {
                combined_multi[-1] += item;
            }
        } elif (
            combined_multi
            and isinstance(item, `bytes)
            and isinstance(combined_multi[-1], `bytes)
        ) {
            combined_multi[-1] += item;
        } else {
            combined_multi.append(item);
        }
    }
    for (i, val) in enumerate(combined_multi) {
        if isinstance(val, (str, `bytes)) {
            combined_multi[i] = self.sync(ast3.Constant(value=val));
        }
    }
    if ((len(combined_multi) > 1) or not isinstance(combined_multi[0], ast3.Constant)) {
        nd.gen.py_ast = [
            self.sync(
                ast3.JoinedStr(values=[cast(ast3.expr, nd) for nd in combined_multi])
            )
        ];
    } else {
        nd.gen.py_ast = [combined_multi[0]];
    }
}

impl PyastGenPass.exit_f_string(self: PyastGenPass, nd: uni.FString) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.JoinedStr(
                values=[
                    cast(ast3.expr, part.gen.py_ast[0])
                    for part in nd.parts
                    if part.gen.py_ast
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_formatted_value(
    self: PyastGenPass, nd: uni.FormattedValue
) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.FormattedValue(
                value=cast(ast3.expr, nd.format_part.gen.py_ast[0]),
                conversion=nd.conversion,
                format_spec=cast(ast3.expr, nd.format_spec.gen.py_ast[0])
                if nd.format_spec
                else None
            )
        )
    ];
}

impl PyastGenPass.exit_list_val(self: PyastGenPass, nd: uni.ListVal) -> None {
    elts = [cast(ast3.expr, v.gen.py_ast[0]) for v in nd.values];
    ctx = ast3.Load()
    if isinstance(nd.py_ctx_func(), ast3.Load)
    else cast(ast3.expr_context, nd.py_ctx_func());
    nd.gen.py_ast = [self.sync(ast3.List(elts=elts, ctx=ctx))];
}

impl PyastGenPass.exit_set_val(self: PyastGenPass, nd: uni.SetVal) -> None {
    elts = [cast(ast3.expr, i.gen.py_ast[0]) for i in nd.values];
    nd.gen.py_ast = [self.sync(ast3.Set(elts=elts))];
}

impl PyastGenPass.exit_tuple_val(self: PyastGenPass, nd: uni.TupleVal) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Tuple(
                elts=[cast(ast3.expr, i.gen.py_ast[0]) for i in nd.values],
                ctx=cast(ast3.expr_context, nd.py_ctx_func())
            )
        )
    ];
}

impl PyastGenPass.exit_dict_val(self: PyastGenPass, nd: uni.DictVal) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Dict(
                keys=[
                    cast(ast3.expr, x.key.gen.py_ast[0]) if x.key else None
                    for x in nd.kv_pairs
                ],
                values=[cast(ast3.expr, x.value.gen.py_ast[0]) for x in nd.kv_pairs]
            )
        )
    ];
}

impl PyastGenPass.exit_k_v_pair(self: PyastGenPass, nd: uni.KVPair) -> None {
    ;
}

impl PyastGenPass.exit_k_w_pair(self: PyastGenPass, nd: uni.KWPair) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.keyword(
                arg=nd.key.gen.py_ast[0].id
                if (nd.key and isinstance(nd.key.gen.py_ast[0], ast3.Name))
                else None,
                value=cast(ast3.expr, nd.value.gen.py_ast[0])
            )
        )
    ];
}

impl PyastGenPass.exit_inner_compr(self: PyastGenPass, nd: uni.InnerCompr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.comprehension(
                target=cast(ast3.expr, nd.target.gen.py_ast[0]),
                iter=cast(ast3.expr, nd.collection.gen.py_ast[0]),
                ifs=[cast(ast3.expr, x.gen.py_ast[0]) for x in nd.conditional]
                if nd.conditional
                else [],
                is_async=0
            )
        )
    ];
}

impl PyastGenPass.exit_list_compr(self: PyastGenPass, nd: uni.ListCompr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.ListComp(
                elt=cast(ast3.expr, nd.out_expr.gen.py_ast[0]),
                generators=cast(
                    `list[ast3.comprehension], [i.gen.py_ast[0] for i in nd.compr]
                )
            )
        )
    ];
}

impl PyastGenPass.exit_gen_compr(self: PyastGenPass, nd: uni.GenCompr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.GeneratorExp(
                elt=cast(ast3.expr, nd.out_expr.gen.py_ast[0]),
                generators=[
                    cast(ast3.comprehension, i.gen.py_ast[0]) for i in nd.compr
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_set_compr(self: PyastGenPass, nd: uni.SetCompr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.SetComp(
                elt=cast(ast3.expr, nd.out_expr.gen.py_ast[0]),
                generators=[
                    cast(ast3.comprehension, i.gen.py_ast[0]) for i in nd.compr
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_dict_compr(self: PyastGenPass, nd: uni.DictCompr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.DictComp(
                key=cast(ast3.expr, nd.kv_pair.key.gen.py_ast[0])
                if nd.kv_pair.key
                else cast(ast3.expr, ast3.Constant(value=None)),
                value=cast(ast3.expr, nd.kv_pair.value.gen.py_ast[0]),
                generators=[
                    cast(ast3.comprehension, i.gen.py_ast[0]) for i in nd.compr
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_atom_trailer(self: PyastGenPass, nd: uni.AtomTrailer) -> None {
    if nd.is_genai {
        nd.gen.py_ast = [];
    }
    if nd.is_attr {
        if isinstance(nd.right, uni.AstSymbolNode) {
            nd.gen.py_ast = [
                self.sync(
                    ast3.Attribute(
                        value=cast(ast3.expr, nd.target.gen.py_ast[0]),
                        attr=self._py_name(nd.right),
                        ctx=cast(ast3.expr_context, nd.right.py_ctx_func())
                    )
                )
            ];
        } else {
            self.log_error('Invalid attribute access');
        }
    } elif isinstance(nd.right, uni.FilterCompr) {
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('filter_on'),
                    args=[],
                    keywords=[
                        self.sync(
                            ast3.keyword(
                                arg='items',
                                value=cast(ast3.expr, nd.target.gen.py_ast[0])
                            )
                        ),
                        self.sync(
                            ast3.keyword(
                                arg='func',
                                value=cast(ast3.expr, nd.right.gen.py_ast[0])
                            )
                        )
                    ]
                )
            )
        ];
    } elif isinstance(nd.right, uni.AssignCompr) {
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj('assign_all'),
                    args=cast(
                        `list[ast3.expr],
                        [nd.target.gen.py_ast[0], nd.right.gen.py_ast[0]]
                    ),
                    keywords=[]
                )
            )
        ];
    } else {
        nd.gen.py_ast = [
            self.sync(
                ast3.Subscript(
                    value=cast(ast3.expr, nd.target.gen.py_ast[0]),
                    slice=cast(ast3.expr, nd.right.gen.py_ast[0]),
                    ctx=cast(ast3.expr_context, nd.right.py_ctx_func())
                    if isinstance(nd.right, uni.AstSymbolNode)
                    else ast3.Load()
                )
            )
        ];
        nd.right.gen.py_ast[0].ctx = ast3.Load();
    }
    if nd.is_null_ok {
        walrus_assign = self.sync(
            ast3.NamedExpr(
                target=self.sync(ast3.Name(id='__jac_tmp', ctx=ast3.Store())),
                value=cast(ast3.expr, nd.target.gen.py_ast[0])
            )
        );
        tmp_ref = self.sync(ast3.Name(id='__jac_tmp', ctx=ast3.Load()));
        none_const = self.sync(ast3.Constant(value=None));
        body_expr: ast3.expr;
        if isinstance(nd.gen.py_ast[0], ast3.Attribute) {
            body_expr = self.sync(
                ast3.Call(
                    func=self.sync(ast3.Name(id='getattr', ctx=ast3.Load())),
                    args=[
                        tmp_ref,
                        self.sync(ast3.Constant(value=nd.gen.py_ast[0].attr)),
                        none_const
                    ],
                    keywords=[]
                )
            );
        } elif isinstance(nd.gen.py_ast[0], ast3.Call) {
            call_node = nd.gen.py_ast[0];
            if (
                isinstance(call_node.func, ast3.Attribute)
                or (
                    isinstance(call_node.func, ast3.Name)
                    and (call_node.func.id == 'filter_on')
                )
            ) {
                for kw in call_node.keywords {
                    if (kw.arg == 'items') {
                        kw.value = tmp_ref;
                    }
                }
            }
            if (
                (
                    isinstance(call_node.func, ast3.Attribute)
                    or (
                        isinstance(call_node.func, ast3.Name)
                        and (call_node.func.id == 'assign_all')
                    )
                )
                and call_node.args
            ) {
                call_node.args[0] = tmp_ref;
            }
            body_expr = cast(ast3.expr, call_node);
        } else {
            if isinstance(nd.gen.py_ast[0], ast3.Subscript) {
                index_expr = nd.gen.py_ast[0].slice;
                body_expr = self.sync(
                    ast3.Call(
                        func=self.jaclib_obj('safe_subscript'),
                        args=[tmp_ref, index_expr],
                        keywords=[]
                    )
                );
            } else {
                nd.gen.py_ast[0].value = tmp_ref;
                body_expr = cast(ast3.expr, nd.gen.py_ast[0]);
            }
        }
        nd.gen.py_ast = [
            self.sync(
                ast3.IfExp(
                    `test=self.sync(
                        ast3.Compare(
                            left=walrus_assign,
                            ops=[self.sync(ast3.IsNot())],
                            comparators=[none_const]
                        )
                    ),
                    body=body_expr,
                    orelse=none_const
                )
            )
        ];
    }
}

impl PyastGenPass.exit_atom_unit(self: PyastGenPass, nd: uni.AtomUnit) -> None {
    if (
        isinstance(nd.value, uni.Ability)
        and nd.value.gen.py_ast
        and isinstance(
            nd.value.gen.py_ast[0], (ast3.FunctionDef, ast3.AsyncFunctionDef)
        )
    ) {
        func_ast = cast(
            (ast3.FunctionDef | ast3.AsyncFunctionDef), nd.value.gen.py_ast[0]
        );
        nd.gen.py_ast = [
            self._function_expr_from_def(
                func_def=func_ast,
                jac_node=nd,
                filename_hint=f"<jac_iife:{func_ast.name}>"
            )
        ];
        return;
    }
    nd.gen.py_ast = nd.value.gen.py_ast;
}

"""Generate the arguments for a function call."""
impl PyastGenPass.gen_call_args(
    self: PyastGenPass, nd: uni.FuncCall
) -> tuple[(list[ast3.expr], list[ast3.keyword])] {
    args = [];
    keywords = [];
    if nd.params {
        for x in nd.params {
            if (isinstance(x, uni.UnaryExpr) and (x.op.name == Tok.STAR_POW)) {
                keywords.append(
                    self.sync(
                        ast3.keyword(value=cast(ast3.expr, x.operand.gen.py_ast[0])), x
                    )
                );
            } elif isinstance(x, uni.Expr) {
                args.append(cast(ast3.expr, x.gen.py_ast[0]));
            } elif (
                isinstance(x, uni.KWPair) and isinstance(x.gen.py_ast[0], ast3.keyword)
            ) {
                keywords.append(x.gen.py_ast[0]);
            } else {
                self.ice('Invalid Parameter');
            }
        }
    }
    return (args, keywords);
}

impl PyastGenPass.exit_func_call(self: PyastGenPass, nd: uni.FuncCall) -> None {
    if nd.genai_call {
        self.ice('Type(by llm()) call feature is temporarily disabled.');
    } else {
        # TODO: Primitive emitter dispatch hook.
        # When type information is available, primitive method calls
        # (e.g., mylist.append(x), s.upper()) and builtin function calls
        # (e.g., len(x), print(x)) can be routed through the emitter
        # infrastructure at jaclang.jac0core.passes.primitives_py.
        # For the Python backend this is a pass-through (no behavior change),
        # but wiring it in validates the dispatch mechanism.
        # Integration point: check if nd.target is an AtomTrailer on a
        # primitive type, then call PyListEmitter/PyStrEmitter/etc.
        func = nd.target.gen.py_ast[0];
        (args, keywords) = self.gen_call_args(nd);
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=cast(ast3.expr, func),
                    args=[cast(ast3.expr, arg) for arg in args],
                    keywords=keywords
                )
            )
        ];
    }
}

impl PyastGenPass.exit_index_slice(self: PyastGenPass, nd: uni.IndexSlice) -> None {
    if nd.is_range {
        if (len(nd.slices) > 1) {
            nd.gen.py_ast = [
                self.sync(
                    ast3.Tuple(
                        elts=[
                            self.sync(
                                ast3.Slice(
                                    lower=cast(ast3.expr, slice.start.gen.py_ast[0])
                                    if slice.start
                                    else None,
                                    upper=cast(ast3.expr, slice.stop.gen.py_ast[0])
                                    if slice.stop
                                    else None,
                                    step=cast(ast3.expr, slice.step.gen.py_ast[0])
                                    if slice.step
                                    else None
                                )
                            ) for slice in nd.slices
                        ],
                        ctx=ast3.Load()
                    )
                )
            ];
        } elif (len(nd.slices) == 1) {
            slice = nd.slices[0];
            nd.gen.py_ast = [
                self.sync(
                    ast3.Slice(
                        lower=cast(ast3.expr, slice.start.gen.py_ast[0])
                        if slice.start
                        else None,
                        upper=cast(ast3.expr, slice.stop.gen.py_ast[0])
                        if slice.stop
                        else None,
                        step=cast(ast3.expr, slice.step.gen.py_ast[0])
                        if slice.step
                        else None
                    )
                )
            ];
        }
    } elif ((len(nd.slices) > 0) and (nd.slices[0].start is not None)) {
        nd.gen.py_ast = nd.slices[0].start.gen.py_ast;
    } else {
        nd.gen.py_ast = [];
    }
}

impl PyastGenPass.exit_special_var_ref(
    self: PyastGenPass, nd: uni.SpecialVarRef
) -> None {
    if (nd.name == Tok.KW_SUPER) {
        nd.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=self.sync(ast3.Name(id='super', ctx=nd.py_ctx_func())),
                    args=[],
                    keywords=[]
                )
            )
        ];
    } elif (nd.name == Tok.KW_ROOT) {
        nd.gen.py_ast = [
            self.sync(ast3.Call(func=self.jaclib_obj('root'), args=[], keywords=[]))
        ];
    } else {
        nd.gen.py_ast = [
            self.sync(ast3.Name(id=self._py_name(nd), ctx=nd.py_ctx_func()))
        ];
    }
}

impl PyastGenPass.exit_edge_ref_trailer(
    self: PyastGenPass, nd: uni.EdgeRefTrailer
) -> None {
    origin = None;
    cur = nd.chain[0];
    chomp = [*nd.chain[1:]];
    from_visit = bool(isinstance(nd.parent, uni.VisitStmt));
    if not isinstance(cur, uni.EdgeOpRef) {
        origin = cur.gen.py_ast[0];
        cur = cast(uni.EdgeOpRef, chomp.pop(0));
    }
    pynode = self.sync(
        ast3.Call(
            func=self.jaclib_obj('OPath'),
            args=[cast(ast3.expr, (origin or cur.gen.py_ast[0]))],
            keywords=[]
        )
    );
    while True {
        keywords = [];
        if cur.filter_cond {
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='edge',
                        value=cast(ast3.expr, self.sync(cur.filter_cond.gen.py_ast[0]))
                    )
                )
            );
        }
        if (chomp and not isinstance(chomp[0], uni.EdgeOpRef)) {
            filt = chomp.pop(0);
            keywords.append(
                self.sync(
                    ast3.keyword(
                        arg='nd', value=cast(ast3.expr, self.sync(filt.gen.py_ast[0]))
                    )
                )
            );
        }
        pynode = self.sync(
            ast3.Call(
                func=self.sync(
                    ast3.Attribute(
                        value=pynode,
                        attr=f"edge_{cur.edge_dir.name.lower()}",
                        ctx=ast3.Load()
                    )
                ),
                args=[],
                keywords=keywords
            )
        );
        if chomp {
            cur = cast(uni.EdgeOpRef, chomp.pop(0));
        } else {
            break;
        }
    }
    if nd.edges_only {
        pynode = self.sync(
            ast3.Call(
                func=self.sync(
                    ast3.Attribute(value=pynode, attr='edge', ctx=ast3.Load())
                ),
                args=[],
                keywords=[]
            )
        );
    }
    if from_visit {
        pynode = self.sync(
            ast3.Call(
                func=self.sync(
                    ast3.Attribute(value=pynode, attr='visit', ctx=ast3.Load())
                ),
                args=[],
                keywords=[]
            )
        );
    }
    if nd.is_async {
        pynode = self.sync(
            ast3.Call(func=self.jaclib_obj('arefs'), args=[pynode], keywords=[])
        );
    } else {
        pynode = self.sync(
            ast3.Call(func=self.jaclib_obj('refs'), args=[pynode], keywords=[])
        );
    }
    nd.gen.py_ast = [pynode];
}

impl PyastGenPass.exit_edge_op_ref(self: PyastGenPass, nd: uni.EdgeOpRef) -> None {
    loc = self.sync(
        ast3.Name(id=Con.HERE.value, ctx=ast3.Load())
        if nd.from_walker
        else ast3.Name(id='self', ctx=ast3.Load())
    );
    nd.gen.py_ast = [loc];
}

impl PyastGenPass.exit_disconnect_op(self: PyastGenPass, nd: uni.DisconnectOp) -> None {
    nd.gen.py_ast = nd.edge_spec.gen.py_ast;
}

impl PyastGenPass.exit_connect_op(self: PyastGenPass, nd: uni.ConnectOp) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Call(
                func=self.jaclib_obj('build_edge'),
                args=[],
                keywords=[
                    self.sync(
                        ast3.keyword(
                            arg='is_undirected',
                            value=self.sync(
                                ast3.Constant(value=(nd.edge_dir == EdgeDir.ANY))
                            )
                        )
                    ),
                    self.sync(
                        ast3.keyword(
                            arg='conn_type',
                            value=cast(ast3.expr, nd.conn_type.gen.py_ast[0])
                            if nd.conn_type
                            else self.sync(ast3.Constant(value=None))
                        )
                    ),
                    self.sync(
                        ast3.keyword(
                            arg='conn_assign',
                            value=cast(ast3.expr, nd.conn_assign.gen.py_ast[0])
                            if nd.conn_assign
                            else self.sync(ast3.Constant(value=None))
                        )
                    )
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_filter_compr(self: PyastGenPass, nd: uni.FilterCompr) -> None {
    iter_name = 'i';
    comprs: list[(ast3.Compare | ast3.Call)] = [
        self.sync(
            ast3.Call(
                func=self.sync(ast3.Name(id='isinstance', ctx=ast3.Load())),
                args=cast(
                    `list[ast3.expr],
                    [
                        self.sync(ast3.Name(id=iter_name, ctx=ast3.Load())),
                        self.sync(nd.f_type.gen.py_ast[0])
                    ]
                ),
                keywords=[]
            )
        )
    ]
    if nd.f_type
    else [];
    comprs.extend(
        self.sync(
            ast3.Compare(
                left=self.sync(
                    ast3.Attribute(
                        value=self.sync(
                            ast3.Name(id=iter_name, ctx=ast3.Load()), jac_node=x
                        ),
                        attr=x.gen.py_ast[0].left.id,
                        ctx=ast3.Load()
                    ),
                    jac_node=x
                ),
                ops=x.gen.py_ast[0].ops,
                comparators=x.gen.py_ast[0].comparators
            ),
            jac_node=x
        )
        for x in nd.compares
        if (
            isinstance(x.gen.py_ast[0], ast3.Compare)
            and isinstance(x.gen.py_ast[0].left, ast3.Name)
        )
    );
    if (
        body := (
            self.sync(
                ast3.BoolOp(
                    op=self.sync(ast3.And()),
                    values=[cast(ast3.expr, item) for item in comprs]
                )
            )
            if (len(comprs) > 1)
            else comprs[0] if comprs else None
        )
    ) {
        nd.gen.py_ast = [
            self.sync(
                ast3.Lambda(
                    args=self.sync(
                        ast3.arguments(
                            posonlyargs=[],
                            args=[self.sync(ast3.arg(arg=iter_name))],
                            kwonlyargs=[],
                            kw_defaults=[],
                            defaults=[]
                        )
                    ),
                    body=body
                )
            )
        ];
    }
}

impl PyastGenPass.exit_assign_compr(self: PyastGenPass, nd: uni.AssignCompr) -> None {
    keys = [];
    values = [];
    for i in nd.assigns {
        if i.key {
            keys.append(self.sync(ast3.Constant(i.key.sym_name)));
            values.append(i.value.gen.py_ast[0]);
        }
    }
    key_tup = self.sync(
        ast3.Tuple(
            elts=[
                key
                for key in keys
                if isinstance(key, ast3.expr)
            ],
            ctx=ast3.Load()
        )
    );
    val_tup = self.sync(
        ast3.Tuple(
            elts=[
                v
                for v in values
                if isinstance(v, ast3.expr)
            ],
            ctx=ast3.Load()
        )
    );
    nd.gen.py_ast = [self.sync(ast3.Tuple(elts=[key_tup, val_tup], ctx=ast3.Load()))];
}

impl PyastGenPass.exit_match_stmt(self: PyastGenPass, nd: uni.MatchStmt) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.Match(
                subject=cast(ast3.expr, nd.target.gen.py_ast[0]),
                cases=[cast(ast3.match_case, x.gen.py_ast[0]) for x in nd.cases]
            )
        )
    ];
}

impl PyastGenPass.exit_match_case(self: PyastGenPass, nd: uni.MatchCase) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.match_case(
                pattern=cast(ast3.pattern, nd.pattern.gen.py_ast[0]),
                guard=cast(ast3.expr, nd.guard.gen.py_ast[0]) if nd.guard else None,
                body=[cast(ast3.stmt, x.gen.py_ast[0]) for x in nd.body]
            )
        )
    ];
}

impl PyastGenPass.exit_match_or(self: PyastGenPass, nd: uni.MatchOr) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.MatchOr(
                patterns=[cast(ast3.pattern, x.gen.py_ast[0]) for x in nd.patterns]
            )
        )
    ];
}

impl PyastGenPass.exit_match_as(self: PyastGenPass, nd: uni.MatchAs) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.MatchAs(
                name=nd.name.sym_name,
                pattern=cast(ast3.pattern, nd.pattern.gen.py_ast[0])
                if nd.pattern
                else None
            )
        )
    ];
}

impl PyastGenPass.exit_match_wild(self: PyastGenPass, nd: uni.MatchWild) -> None {
    nd.gen.py_ast = [self.sync(ast3.MatchAs())];
}

impl PyastGenPass.exit_match_value(self: PyastGenPass, nd: uni.MatchValue) -> None {
    nd.gen.py_ast = [
        self.sync(ast3.MatchValue(value=cast(ast3.expr, nd.value.gen.py_ast[0])))
    ];
}

impl PyastGenPass.exit_match_singleton(
    self: PyastGenPass, nd: uni.MatchSingleton
) -> None {
    nd.gen.py_ast = [self.sync(ast3.MatchSingleton(value=nd.value.lit_value))];
}

impl PyastGenPass.exit_match_sequence(
    self: PyastGenPass, nd: uni.MatchSequence
) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.MatchSequence(
                patterns=[cast(ast3.pattern, x.gen.py_ast[0]) for x in nd.values]
            )
        )
    ];
}

impl PyastGenPass.exit_match_mapping(self: PyastGenPass, nd: uni.MatchMapping) -> None {
    mapping = self.sync(ast3.MatchMapping(keys=[], patterns=[], rest=None));
    for i in nd.values {
        if (
            isinstance(i, uni.MatchKVPair)
            and isinstance(i.key, uni.MatchValue)
            and isinstance(i.key.value.gen.py_ast[0], ast3.expr)
            and isinstance(i.value.gen.py_ast[0], ast3.pattern)
        ) {
            mapping.keys.append(i.key.value.gen.py_ast[0]);
            mapping.patterns.append(i.value.gen.py_ast[0]);
        } elif isinstance(i, uni.MatchStar) {
            mapping.rest = i.name.sym_name;
        }
    }
    nd.gen.py_ast = [mapping];
}

impl PyastGenPass.exit_match_k_v_pair(self: PyastGenPass, nd: uni.MatchKVPair) -> None {
    ;
}

impl PyastGenPass.exit_match_star(self: PyastGenPass, nd: uni.MatchStar) -> None {
    nd.gen.py_ast = [self.sync(ast3.MatchStar(name=nd.name.sym_name))];
}

impl PyastGenPass.exit_match_arch(self: PyastGenPass, nd: uni.MatchArch) -> None {
    nd.gen.py_ast = [
        self.sync(
            ast3.MatchClass(
                cls=cast(ast3.expr, nd.name.gen.py_ast[0]),
                patterns=[
                    cast(ast3.pattern, x.gen.py_ast[0])
                    for x in (nd.arg_patterns or [])
                ],
                kwd_attrs=[
                    x.key.sym_name
                    for x in (nd.kw_patterns or [])
                    if isinstance(x.key, uni.NameAtom)
                ],
                kwd_patterns=[
                    cast(ast3.pattern, x.value.gen.py_ast[0])
                    for x in (nd.kw_patterns or [])
                ]
            )
        )
    ];
}

impl PyastGenPass.exit_token(self: PyastGenPass, nd: uni.Token) -> None {
    tok = Tok(nd.name) if (nd.name in Tok.__members__) else None;
    op_cls = TOKEN_AST_MAP.get(tok) if tok else None;
    if op_cls {
        nd.gen.py_ast = [self.sync(op_cls())];
    }
}

impl PyastGenPass.exit_name(self: PyastGenPass, nd: uni.Name) -> None {
    name = nd.sym_name;
    if (name in self._get_builtin_names()) {
        self.builtin_imports.add(name);
    }
    nd.gen.py_ast = [self.sync(ast3.Name(id=name, ctx=nd.py_ctx_func()))];
}

impl PyastGenPass.exit_float(self: PyastGenPass, nd: uni.Float) -> None {
    nd.gen.py_ast = [self.sync(ast3.Constant(value=float(nd.value)))];
}

impl PyastGenPass.exit_int(self: PyastGenPass, nd: uni.Int) -> None {
    nd.gen.py_ast = [self.sync(ast3.Constant(value=int(nd.value, 0)))];
}

impl PyastGenPass.exit_string(self: PyastGenPass, nd: uni.String) -> None {
    nd.gen.py_ast = [self.sync(ast3.Constant(value=nd.lit_value))];
}

impl PyastGenPass.exit_bool(self: PyastGenPass, nd: uni.Bool) -> None {
    nd.gen.py_ast = [self.sync(ast3.Constant(value=(nd.value == 'True')))];
}

impl PyastGenPass.exit_builtin_type(self: PyastGenPass, nd: uni.BuiltinType) -> None {
    nd.gen.py_ast = [self.sync(ast3.Name(id=nd.sym_name, ctx=nd.py_ctx_func()))];
}

impl PyastGenPass.exit_null(self: PyastGenPass, nd: uni.Null) -> None {
    nd.gen.py_ast = [self.sync(ast3.Constant(value=None))];
}

impl PyastGenPass.exit_ellipsis(self: PyastGenPass, nd: uni.Ellipsis) -> None {
    nd.gen.py_ast = [self.sync(ast3.Constant(value=...))];
}

"""Generate Python AST for JSX elements."""
impl PyastGenPass.exit_jsx_element(self: PyastGenPass, nd: uni.JsxElement) -> None {
    self.jsx_processor.element(nd);
}

"""Generate Python AST for JSX element names."""
impl PyastGenPass.exit_jsx_element_name(
    self: PyastGenPass, nd: uni.JsxElementName
) -> None {
    self.jsx_processor.element_name(nd);
}

"""Bases class for JSX attributes - handled by subclasses."""
impl PyastGenPass.exit_jsx_attribute(self: PyastGenPass, nd: uni.JsxAttribute) -> None {
    ;
}

"""Generate Python AST for JSX spread attributes."""
impl PyastGenPass.exit_jsx_spread_attribute(
    self: PyastGenPass, nd: uni.JsxSpreadAttribute
) -> None {
    self.jsx_processor.spread_attribute(nd);
}

"""Generate Python AST for JSX normal attributes."""
impl PyastGenPass.exit_jsx_normal_attribute(
    self: PyastGenPass, nd: uni.JsxNormalAttribute
) -> None {
    self.jsx_processor.normal_attribute(nd);
}

"""Bases class for JSX children - handled by subclasses."""
impl PyastGenPass.exit_jsx_child(self: PyastGenPass, nd: uni.JsxChild) -> None {
    ;
}

"""Generate Python AST for JSX text nodes."""
impl PyastGenPass.exit_jsx_text(self: PyastGenPass, nd: uni.JsxText) -> None {
    self.jsx_processor.text(nd);
}

"""Generate Python AST for JSX expression children."""
impl PyastGenPass.exit_jsx_expression(
    self: PyastGenPass, nd: uni.JsxExpression
) -> None {
    self.jsx_processor.expression(nd);
}

impl PyastGenPass.exit_semi(self: PyastGenPass, nd: uni.Semi) -> None {
    ;
}

impl PyastGenPass.exit_comment_token(self: PyastGenPass, nd: uni.CommentToken) -> None {
    ;
}
