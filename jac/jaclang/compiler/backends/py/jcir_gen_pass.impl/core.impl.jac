impl JcirGenPass._get_builtin_names -> set[str] {
    return set(JCIR_BUILTIN_NAMES);
}

impl JcirGenPass._get_ambient_typing_names -> set[str] {
    return set(JCIR_AMBIENT_TYPING_NAMES);
}

impl JcirGenPass.postinit -> None {
    _jaclib: set[str] = set();
    _builtins: set[str] = set();
    _sized: set[str] = set();
    _typing: set[str] = set();
    self.jaclib_imports = _jaclib;
    self._runtime_aliases = {};
    self._reserved_names = {nd.sym_name for nd in self.ir_in.get_all_sub_nodes(Name)};
    self.builtin_imports = _builtins;
    self.sized_imports = _sized;
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

impl JcirGenPass.enter_walk with UniNode entry {
    if self.is_canceled() or here.ct_pruned {
        osp_skip_rest();
        return;
    }
    self.cur_node = here;
    if (isinstance(here, Module) and (here is not self.ir_in)) {
        osp_skip_rest();
        return;
    }
    if isinstance(here, (Ability, Import)) and here.is_comptime {
        osp_skip_rest();
        return;
    }
    if (
        isinstance(here, ContextAwareNode)
        and (here.code_context == CodeContext.NATIVE)
        and ((here.parent is None) or isinstance(here.parent, Module))
        and not isinstance(here, (Import, Test))
        and not self._is_native_ext_module()
    ) {
        first_native = True;
        for sib in self.ir_in.body {
            if sib is here {
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
            self._interop_stub_node = here;
        }
        osp_skip_rest();
        return;
    }
    if (
        isinstance(here, ContextAwareNode)
        and (here.code_context == CodeContext.CLIENT)
        and not here.codespace_dual
        and ((here.parent is None) or isinstance(here.parent, Module))
    ) {
        osp_skip_rest();
        return;
    }
    if (
        isinstance(here, Import)
        and here.code_context == CodeContext.NATIVE
        and (not here.items)
    ) {
        osp_skip_rest();
        return;
    }
}

impl JcirGenPass.exit_walk with UniNode exit {
    if here.ct_pruned {
        osp_skip_rest();
        return;
    }
    self.cur_node = here;
    if self.is_canceled() {
        osp_skip_rest();
        return;
    }
    if (isinstance(here, Module) and (here is not self.ir_in)) {
        osp_skip_rest();
        return;
    }
    if isinstance(here, (Ability, Import)) and here.is_comptime {
        self.set_out(here, []);
        osp_skip_rest();
        return;
    }
    if (
        isinstance(here, ContextAwareNode)
        and (here.code_context == CodeContext.CLIENT)
        and not here.codespace_dual
        and ((here.parent is None) or isinstance(here.parent, Module))
    ) {
        osp_skip_rest();
        return;
    }
    if (
        isinstance(here, ContextAwareNode)
        and (here.code_context == CodeContext.NATIVE)
        and ((here.parent is None) or isinstance(here.parent, Module))
        and not isinstance(here, (Import, Test))
        and not self._is_native_ext_module()
    ) {
        osp_skip_rest();
        return;
    }
    if (
        isinstance(here, Import)
        and here.code_context == CodeContext.NATIVE
        and (not here.items)
    ) {
        osp_skip_rest();
        return;
    }
}

impl JcirGenPass.finish_expr with Expr exit {
    if here.fw is not None or isinstance(here, FuncCall) {
        self._apply_fw(here);
    }
    if here.coerce_to is not None {
        self._apply_coercion(here);
    }
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

impl JcirGenPass.call_node(
    func: CgNode, args: list, keywords: list, jac_node: (UniNode | None) = None
) -> CgNode {
    return self.nod(
        'Call', ['func', 'args', 'keywords'], [func, args, keywords], jac_node=jac_node
    );
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
    cached = self._runtime_aliases.get(obj_name);
    if cached is not None {
        return self.name_load(cached);
    }
    alias = "_jac_runtime_" + obj_name;
    while alias in self._reserved_names {
        alias += "_";
    }
    self._reserved_names.add(alias);
    self._runtime_aliases[obj_name] = alias;
    return self.name_load(alias);
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

impl JcirGenPass.exit_token with Token exit {
    if here.__class__ is not Token {
        return;
    }
    if here.name in TOKEN_CLS_BY_NAME {
        self.set_out(here, [self.nod(TOKEN_CLS_BY_NAME[here.name], [], [])]);
    }
}

impl JcirGenPass.exit_semi with Semi exit {}

impl JcirGenPass.exit_comment_token with CommentToken exit {}
