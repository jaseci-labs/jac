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

impl JcirGenPass._apply_coercion(nd: Expr) -> None {
    target = nd.coerce_to;
    got = self.outs(nd);
    if target is None or len(got) != 1 or not isinstance(got[0], CgNode) {
        return;
    }
    parent = nd.parent;
    if (
        isinstance(parent, FuncCall)
        and isinstance(parent.target, Name)
        and parent.target.sym_name == target
        and parent.params is not None
        and len(parent.params) == 1
    ) {
        return;
    }
    row = shape_of(target);
    if row is None or not row.is_float {
        return;
    }
    if target == "f32" {
        self._fw_wrap_call(nd, "_fw_r_f32", [got[0]]);
        return;
    }
    src = shape_of(nd.fw) if nd.fw is not None else None;
    if src is not None and src.is_float {
        return;
    }
    self.set_out(
        nd,
        [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [self.name_load('float'), [got[0]], []],
                jac_node=nd
            )
        ]
    );
}

impl JcirGenPass._fw_helper(name: str) -> CgNode {
    self.sized_imports.add(name);
    return self.name_load(name);
}

impl JcirGenPass._fw_call_node(helper: str, args: list, jac_node: UniNode) -> CgNode {
    return self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [self._fw_helper(helper), args, []],
        jac_node=jac_node
    );
}

impl JcirGenPass._fw_wrap_call(nd: Expr, helper: str, args: list) -> None {
    self.set_out(nd, [self._fw_call_node(helper, args, nd)]);
}

impl JcirGenPass._apply_fw(nd: Expr) -> None {
    if isinstance(nd, FuncCall) {
        self._fw_call(nd);
        return;
    }
    name = nd.fw;
    if name is None {
        return;
    }
    if isinstance(nd, BinaryExpr) {
        self._fw_binary(nd, name);
    } elif isinstance(nd, UnaryExpr) {
        self._fw_unary(nd, name);
    }
}

impl JcirGenPass._fw_binary(nd: BinaryExpr, name: str) -> None {
    if not isinstance(nd.op, Token) {
        return;
    }
    got = self.outs(nd);
    if len(got) != 1 or not isinstance(got[0], CgNode) or got[0].cls != 'BinOp' {
        return;
    }
    row = shape_of(name);
    if row is None {
        return;
    }
    out = self._fw_checked(
        name, nd.op.name, self.val(nd.left), self.val(nd.right), got[0], nd
    );
    if out is not None {
        self.set_out(nd, [out]);
    }
}

impl JcirGenPass._fw_checked(
    name: str, op: str, left: CgNode, right: CgNode, op_node: any, jac_node: UniNode
) -> (CgNode | None) {
    row = shape_of(name);
    if row is None or not row.sized {
        return None;
    }
    if isinstance(jac_node, Expr) and jac_node.fw_safe and op in FW_ELIDABLE_OPS {
        return None;
    }
    if row.is_float {
        if row.width != 32 {
            return None;
        }
        return self._fw_call_node("_fw_r_f32", [op_node], jac_node);
    }
    if op in (Tok.PLUS, Tok.MINUS, Tok.STAR_MUL, Tok.FLOOR_DIV) {
        return self._fw_call_node(f"_fw_ck_{name}", [op_node], jac_node);
    }
    if op == Tok.STAR_POW {
        return self._fw_call_node(f"_fw_pow_{name}", [left, right], jac_node);
    }
    if op == Tok.LSHIFT {
        return self._fw_call_node(f"_fw_shl_{name}", [left, right], jac_node);
    }
    if op == Tok.RSHIFT {
        return self._fw_call_node(f"_fw_shr_{name}", [left, right], jac_node);
    }
    return None;
}

impl JcirGenPass._fw_as_load(item: any) -> any {
    if isinstance(item, list) {
        return [self._fw_as_load(x) for x in item];
    }
    if not isinstance(item, CgNode) {
        return item;
    }
    copy = self.nod(item.cls, list(item.keys), [], jac_node=item.jac_src);
    copy.vals = [
        self.nod('Load', [], [], jac_node=item.jac_src)
            if (item.keys[i] == 'ctx')
            else self._fw_as_load(item.vals[i]) for i in range(len(item.keys))
    ];
    return copy;
}

impl JcirGenPass._fw_aug_assign(
    nd: Assignment, target: any, value: any
) -> (CgNode | None) {
    tgt = nd.target[0] if nd.target else None;
    if (
        not isinstance(tgt, Expr)
        or tgt.fw is None
        or nd.aug_op is None
        or not isinstance(target, CgNode)
        or not isinstance(value, CgNode)
    ) {
        return None;
    }
    base = FW_AUG_TO_BIN.get(nd.aug_op.name, None);
    if base is None {
        return None;
    }
    load = self._fw_as_load(target);
    binop = self.nod(
        'BinOp',
        ['left', 'op', 'right'],
        [load, self.val(nd.aug_op), value],
        jac_node=nd
    );
    checked = self._fw_checked(tgt.fw, base, load, value, binop, nd);
    if checked is None {
        return None;
    }
    return self.nod('Assign', ['targets', 'value'], [[target], checked], jac_node=nd);
}

impl JcirGenPass._fw_unary(nd: UnaryExpr, name: str) -> None {
    if not isinstance(nd.op, Token) {
        return;
    }
    got = self.outs(nd);
    if len(got) != 1 or not isinstance(got[0], CgNode) {
        return;
    }
    row = shape_of(name);
    if row is None or not row.sized {
        return;
    }
    op = nd.op.name;
    if row.is_float {
        if row.width == 32 and op == Tok.MINUS {
            self._fw_wrap_call(nd, "_fw_r_f32", [got[0]]);
        }
        return;
    }
    if op == Tok.MINUS {
        if not nd.fw_safe {
            self._fw_wrap_call(nd, f"_fw_ck_{name}", [got[0]]);
        }
    } elif op == Tok.BW_NOT and not row.signed {
        self._fw_wrap_call(nd, f"_fw_inv_{name}", [self.val(nd.operand)]);
    }
}

impl JcirGenPass._fw_call(nd: FuncCall) -> None {
    callee = nd.target;
    if not isinstance(callee, Name) {
        return;
    }
    args = [
        a
        for a in (nd.params or [])
        if isinstance(a, Expr)
    ];
    if len(args) != len(nd.params or []) {
        return;
    }
    if callee.sym_name == "abs" and len(args) == 1 {
        name = nd.fw or args[0].fw;
        row = shape_of(name) if name is not None else None;
        if row is None or not row.sized or row.is_float or name is None {
            return;
        }
        got = self.outs(nd);
        if len(got) == 1 and isinstance(got[0], CgNode) {
            self._fw_wrap_call(nd, f"_fw_ck_{name}", [got[0]]);
        }
        return;
    }
    op = FW_WRAPPING_OPS.get(callee.sym_name, None);
    if op is None {
        return;
    }
    name = nd.fw or (args[0].fw if args else None);
    row = shape_of(name) if name is not None else None;
    if row is None or not row.sized or row.is_float or name is None {
        return;
    }
    call_args: list = [
        self.const_of(name, jac_node=nd),
        self.const_of(op, jac_node=nd)
    ];
    for a in args {
        call_args.append(self.val(a));
    }
    self._fw_wrap_call(nd, "_fw_wrapping", call_args);
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

impl JcirGenPass._ct_kind(v: any) -> str {
    if v is None or isinstance(v, (bool, int, float, str, bytes)) {
        return "scalar";
    }
    kind = type(v).__name__;
    if kind in ("CtEnumMember", "CtType", "CtFunc", "CtRecord") {
        return kind;
    }
    if isinstance(v, (list, tuple, set, frozenset, dict)) {
        return "container";
    }
    if isinstance(v, type) and v.__module__ == "builtins" {
        return "pytype";
    }
    return "";
}

impl JcirGenPass._ct_materializable(v: any) -> bool {
    kind = self._ct_kind(v);
    if not kind {
        return False;
    }
    if kind == "container" {
        items = v.values() if isinstance(v, dict) else v;
        for item in items {
            if not self._ct_materializable(item) {
                return False;
            }
        }
        if isinstance(v, dict) {
            for k in v.keys() {
                if not self._ct_materializable(k) {
                    return False;
                }
            }
        }
        return True;
    }
    if kind == "CtRecord" {
        for item in v.fields.values() {
            if not self._ct_materializable(item) {
                return False;
            }
        }
    }
    return True;
}

impl JcirGenPass._ct_concrete(nd: Expr) -> bool {
    cv = nd.ct_value;
    return cv is not None and not cv.is_deferred and self._ct_materializable(cv.v);
}

impl JcirGenPass._comptime_only_names -> set[str] {
    cached = self._ct_only_names;
    if cached is not None {
        return cached;
    }
    names: set[str] = set();
    for imp in self.ir_in.get_all_sub_nodes(Import) {
        if not imp.is_comptime {
            continue;
        }
        for item in imp.items {
            bound: (Name | None) = item.alias;
            if bound is None
                and isinstance(item, ModuleItem)
                and isinstance(item.name, Name) {
                bound = item.name;
            }
            if bound is None and isinstance(item, ModulePath) and item.path {
                last = item.path[-1];
                bound = last if isinstance(last, Name) else None;
            }
            if bound is not None {
                names.add(bound.sym_name);
            }
        }
    }
    for ab in self.ir_in.get_all_sub_nodes(Ability) {
        if ab.is_comptime and ab.name_ref is not None {
            names.add(ab.name_ref.sym_name);
        }
    }
    self._ct_only_names = names;
    return names;
}

impl JcirGenPass._is_comptime_only_name(nd: Name) -> bool {
    if nd.sym_name in self._comptime_only_names() {
        return True;
    }
    for sym in (nd.sym, ) {
        if sym is None {
            continue;
        }
        decl = sym.decl;
        imp = decl.find_parent_of_type(Import) if isinstance(decl, Name) else None;
        if imp is not None and imp.is_comptime {
            return True;
        }
        owner = decl.name_of;
        if isinstance(owner, Ability) and owner.is_comptime {
            return True;
        }
        par = decl.parent if isinstance(decl, Name) else None;
        if isinstance(par, Assignment) and isinstance(par.parent, GlobalVars) {
            home = par.find_parent_of_type(Module);
            if home is not None and home is not self.ir_in {
                hp = (home.loc.mod_path if home.loc else "").replace("\\", "/");
                if hp.endswith("jaclang/comptime.jac") {
                    return True;
                }
            }
        }
    }
    return False;
}

impl JcirGenPass._import_ref(module: str, name: str, jac_node: UniNode) -> CgNode {
    imported = self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [
            self.name_load('__import__', jac_node),
            [self.const_of(module, jac_node)],
            [
                self.nod(
                    'keyword',
                    ['arg', 'value'],
                    [
                        'fromlist',
                        self.nod(
                            'List',
                            ['elts', 'ctx'],
                            [[self.const_of(name, jac_node)], self.nod('Load', [], [])]
                        )
                    ]
                )
            ]
        ],
        jac_node=jac_node
    );
    return self.nod(
        'Attribute',
        ['value', 'attr', 'ctx'],
        [imported, name, self.nod('Load', [], [])],
        jac_node=jac_node
    );
}

impl JcirGenPass._class_ref(module: str, name: str, jac_node: UniNode) -> CgNode {
    import from jaclang.compiler.frontend.codeinfo { module_dotted_name }
    if module == "builtins" or not module {
        return self.name_load(name, jac_node);
    }
    if module
        == module_dotted_name(
            self.ir_in.loc.mod_path if self.ir_in.loc else "", self.ir_in.name
        ) {
        return self.name_load(name, jac_node);
    }
    local_sym = self.ir_in.sym_tab.lookup(name, deep=False);
    if local_sym is not None {
        return self.name_load(name, jac_node);
    }
    return self._import_ref(module, name, jac_node);
}

impl JcirGenPass._ct_order_key(v: any) -> str {
    if v is None {
        return "0";
    }
    if isinstance(v, bool) {
        return "1" + ("1" if v else "0");
    }
    if isinstance(v, (int, float)) {
        return "2" + repr(v);
    }
    if isinstance(v, str) {
        return "3" + v;
    }
    if isinstance(v, bytes) {
        return "4" + v.hex();
    }
    if isinstance(v, frozenset) {
        return "5" + "\x00".join(sorted([self._ct_order_key(x) for x in v]));
    }
    if isinstance(v, tuple) {
        return "6" + "\x00".join([self._ct_order_key(x) for x in v]);
    }
    return "7"
        + self._ct_kind(v)
        + ":"
        + str(getattr(v, "enum_name", ""))
        + ":"
        + str(getattr(v, "member", ""))
        + ":"
        + str(
            getattr(v, "qualname", "")
                or getattr(v, "name", "")
                or getattr(v, "__name__", "")
        );
}

impl JcirGenPass._materialize(v: any, jac_node: UniNode) -> (CgNode | None) {
    import from jaclang.compiler.frontend.codeinfo { module_dotted_name }
    load = self.nod('Load', [], []);
    kind = self._ct_kind(v);
    if kind == "scalar" {
        return self.const_of(v, jac_node);
    }
    if kind == "pytype" {
        return self.name_load(v.__name__, jac_node);
    }
    if isinstance(v, (list, tuple)) {
        elts: list = [];
        for item in v {
            m = self._materialize(item, jac_node);
            if m is None {
                return None;
            }
            elts.append(m);
        }
        return self.nod(
            'List' if isinstance(v, list) else 'Tuple', ['elts', 'ctx'], [elts, load]
        );
    }
    if isinstance(v, (set, frozenset)) {
        elts2: list = [];
        for item in sorted(v, key=self._ct_order_key) {
            m = self._materialize(item, jac_node);
            if m is None {
                return None;
            }
            elts2.append(m);
        }
        ctor = 'frozenset' if isinstance(v, frozenset) else 'set';
        return self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [
                self.name_load(ctor, jac_node),
                [self.nod('List', ['elts', 'ctx'], [elts2, load])],
                []
            ]
        );
    }
    if isinstance(v, dict) {
        keys: list = [];
        vals: list = [];
        for (k, item) in v.items() {
            mk = self._materialize(k, jac_node);
            mv = self._materialize(item, jac_node);
            if mk is None or mv is None {
                return None;
            }
            keys.append(mk);
            vals.append(mv);
        }
        return self.nod('Dict', ['keys', 'values'], [keys, vals]);
    }
    if kind == "CtEnumMember" {
        return self.nod(
            'Attribute',
            ['value', 'attr', 'ctx'],
            [self._class_ref(v.module, v.enum_name, jac_node), v.member, load],
            jac_node=jac_node
        );
    }
    if kind == "CtType" {
        cls_ref = self._class_ref(v.module, v.name, jac_node);
        ct_args = v?.ct_args or {};
        if not ct_args {
            return cls_ref;
        }
        ct_kws: list = [];
        for (ck, cvv) in ct_args.items() {
            mv = self._materialize(cvv, jac_node);
            if mv is None {
                return None;
            }
            ct_kws.append(self.nod('keyword', ['arg', 'value'], [ck, mv]));
        }
        return self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [
                self._import_ref("jaclang.comptime", "specialize", jac_node),
                [cls_ref],
                ct_kws
            ],
            jac_node=jac_node
        );
    }
    if kind == "CtFunc" {
        same_module = v.module
            == module_dotted_name(
                self.ir_in.loc.mod_path if self.ir_in.loc else "", self.ir_in.name
            );
        ct_only = v.ability is not None and v.ability.is_comptime;
        if same_module and not ct_only {
            parts = v.qualname.split(".");
            cur: CgNode = self.name_load(parts[0], jac_node);
            for part in parts[1:] {
                cur = self.nod(
                    'Attribute', ['value', 'attr', 'ctx'], [cur, part, load]
                );
            }
            return cur;
        }
        return self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [
                self._import_ref("jaclang.comptime", "__ct_lazy", jac_node),
                [
                    self.const_of(v.module, jac_node),
                    self.const_of(v.qualname, jac_node)
                ],
                []
            ],
            jac_node=jac_node
        );
    }
    if kind == "CtRecord" {
        kws: list = [];
        for (k, item) in v.fields.items() {
            mv = self._materialize(item, jac_node);
            if mv is None {
                return None;
            }
            kws.append(self.nod('keyword', ['arg', 'value'], [k, mv]));
        }
        cls_ref = self._class_ref(v.module, v.class_name, jac_node);
        if self._record_bypasses_init(v) {
            return self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self._import_ref("jaclang.comptime", "record", jac_node),
                    [cls_ref],
                    kws
                ],
                jac_node=jac_node
            );
        }
        return self.nod(
            'Call', ['func', 'args', 'keywords'], [cls_ref, [], kws], jac_node=jac_node
        );
    }
    return None;
}

impl JcirGenPass._is_ct_type_param(nd: Name) -> bool {
    sym = nd.sym;
    if sym is None {
        return False;
    }
    owner = sym.decl.name_of;
    return isinstance(owner, TypeParam) and owner.is_comptime;
}

impl JcirGenPass._ct_param_decls(cls_expr: Expr) -> (list[TypeParam] | None) {
    t: any = cls_expr.type;
    shared: any = t?.shared;
    if shared is None or not shared?.ct_params {
        return None;
    }
    arch = shared.symbol_table;
    if not isinstance(arch, Archetype) {
        return None;
    }
    return `list(arch.type_params or []);
}

impl JcirGenPass._ct_ctor_slots(nd: AtomTrailer) -> (list[tuple] | None) {
    if nd.is_attr or not isinstance(nd.right, IndexSlice) or nd.right.is_range {
        return None;
    }
    tps = self._ct_param_decls(nd.target);
    if tps is None {
        return None;
    }
    s0 = nd.right.slices[0] if nd.right.slices else None;
    head = s0.start if s0 is not None else None;
    vals: list = `list(head.values)
        if isinstance(head, TupleVal)
        else ([head] if head else []);
    out: list[tuple] = [];
    for (i, tp) in enumerate(tps) {
        if tp.is_comptime and i < len(vals) {
            out.append((tp.name.value, vals[i], ));
        }
    }
    return out;
}

impl JcirGenPass._trailer_reaches_ct_class(nd: AtomTrailer) -> bool {
    cur: any = nd.target;
    while isinstance(cur, AtomTrailer) {
        if self._ct_ctor_slots(cur) is not None {
            return True;
        }
        cur = cur.target;
    }
    return False;
}

impl JcirGenPass._ct_param_fields(nd: Archetype) -> list[CgNode] {
    out: list[CgNode] = [];
    for tp in (nd.type_params or []) {
        if not tp.is_comptime {
            continue;
        }
        bnd = tp.bound;
        ann = self.val(bnd) if bnd is not None else self.name_load('object', tp);
        out.append(
            self.nod(
                'AnnAssign',
                ['target', 'annotation', 'value', 'simple'],
                [
                    self.nod(
                        'Name',
                        ['id', 'ctx'],
                        [tp.name.value, self.nod('Store', [], [])]
                    ),
                    ann,
                    self.nod(
                        'Call',
                        ['func', 'args', 'keywords'],
                        [
                            self._import_ref("dataclasses", "field", tp),
                            [],
                            [
                                self.nod(
                                    'keyword',
                                    ['arg', 'value'],
                                    ['kw_only', self.const_of(True)]
                                )
                            ]
                        ]
                    ),
                    1
                ],
                jac_node=tp
            )
        );
    }
    return out;
}

impl JcirGenPass._record_bypasses_init(v: any) -> bool {
    ct = v?.class_type;
    shared = ct?.shared;
    if shared is None {
        return False;
    }
    for cls in (shared.mro or []) {
        arch = cls.shared.symbol_table;
        if not isinstance(arch, Archetype) {
            continue;
        }
        for m in arch.get_methods() {
            nm = m.name_ref.sym_name if m.name_ref else "";
            if nm in ("init", "__init__", "postinit", "__post_init__") {
                return True;
            }
        }
        for hv in arch.get_has_vars() {
            if hv.defer {
                return True;
            }
        }
    }
    return False;
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
    if (self.jaclib_imports and not is_jaclib_module) {
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
        self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [self.jaclib_obj('jac_test'), [], jac_test_keywords]
        )
    );
    if jcir_is_test_path(here.loc.mod_path) {
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
                            ['file_loc', self.const_of(here.loc.mod_path)]
                        )
                    ]
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
    py_nodes: list[CgNode] = [];
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
            py_nodes = [wrapped];
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

impl JcirGenPass.enter_archetype with Archetype entry {
    if isinstance(here.body, ImplDef) {
        self.traverse(here.body);
    }
}

impl JcirGenPass.exit_archetype with Archetype exit {
    inner:
        (
            Sequence[UniNode] | Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | None
        ) = None;
    if isinstance(here.body, ImplDef) {
        inner = here.body.body if not isinstance(here.body.body, Expr) else None;
    } elif isinstance(here.body, list) {
        inner = here.body;
    }
    decorators = [self.val(i) for i in here.decorators] if here.decorators else [];
    body: list = self.resolve_stmt_block(inner, doc=here.doc);
    if (not body and not isinstance(here.body, Expr)) {
        self.emit(E5003, node_override=here);
        body = [self.nod('Pass', [], [], jac_node=here)];
    }
    ct_fields = self._ct_param_fields(here);
    if ct_fields {
        insert_at = 1 if here.doc else 0;
        body[insert_at:insert_at] = ct_fields;
    }
    if here.is_async {
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
                    self.const_of(here.is_async)
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
    inner:
        (
            Sequence[UniNode] | Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | None
        ) = None;
    if isinstance(here.body, ImplDef) {
        inner = here.body.body if not isinstance(here.body.body, Expr) else None;
    } elif isinstance(here.body, list) {
        inner = here.body;
    }
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
    stmt_body:
        (
            Sequence[UniNode] | Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | None
        ) = None;
    if isinstance(here.body, ImplDef) and not isinstance(here.body.body, Expr) {
        stmt_body = here.body.body;
    } elif isinstance(here.body, list) {
        stmt_body = here.body;
    }
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
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [self.jaclib_obj('set_trigger'), [trigger_thunk], []]
            )
        );
    }
    if isinstance(here.body, ImplDef) {
        decorator_list.append(
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.jaclib_obj('impl_patch_filename'),
                    [self.const_of(here.body.loc.mod_path)],
                    []
                ]
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
        value = self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [
                self.jaclib_obj('field'),
                [],
                [self.nod('keyword', ['arg', 'value'], ['init', self.const_of(False)])]
            ]
        );
    } elif here.value {
        value_expr = self.val(here.value);
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
            self.val(here.name),
            annotation or self.const_of(None),
            value,
            int(isinstance(here.name, Name))
        ]
    );
    self.set_out(here, [ann_assign]);
}

impl JcirGenPass.exit_typed_ctx_block with TypedCtxBlock exit {
    loc = self.name_load(Con.HERE.value if here.from_walker else Con.VISITOR.value);
    self.set_out(
        here,
        [
            self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [
                    self.nod(
                        'Call',
                        ['func', 'args', 'keywords'],
                        [
                            self.name_load('isinstance'),
                            [loc, self.val(here.type_ctx)],
                            []
                        ]
                    ),
                    self.resolve_stmt_block(here.body),
                    []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_open_stmt with OpenStmt exit {
    self.builtin_imports.add("_jac_region_open");
    self.builtin_imports.add("_jac_region_close");
    _tmp = f"_jac_region_{here.loc.first_line}_{here.loc.col_start}";
    assign_stmt = self.nod(
        'Assign',
        ['targets', 'value'],
        [
            [
                self.nod(
                    'Name',
                    ['id', 'ctx'],
                    [_tmp, self.nod('Store', [], [], jac_node=here)],
                    jac_node=here
                )
            ],
            self.val(here.target)
        ],
        jac_node=here.target
    );
    open_stmt = self.nod(
        'Expr',
        ['value'],
        [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.name_load('_jac_region_open', jac_node=here),
                    [self.name_load(_tmp, jac_node=here)],
                    []
                ],
                jac_node=here
            )
        ],
        jac_node=here
    );
    close_stmt = self.nod(
        'Expr',
        ['value'],
        [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.name_load('_jac_region_close', jac_node=here),
                    [self.name_load(_tmp, jac_node=here)],
                    []
                ],
                jac_node=here
            )
        ],
        jac_node=here
    );
    clear_stmt = self.nod(
        'Assign',
        ['targets', 'value'],
        [
            [
                self.nod(
                    'Name',
                    ['id', 'ctx'],
                    [_tmp, self.nod('Store', [], [], jac_node=here)],
                    jac_node=here
                )
            ],
            self.const_of(None, jac_node=here)
        ],
        jac_node=here
    );
    body_stmts: list = self._flatten_ast_list([self.outs(item) for item in here.body]);
    if not body_stmts {
        body_stmts = [self.nod('Pass', [], [], jac_node=here)];
    }
    try_stmt = self.nod(
        'Try',
        ['body', 'handlers', 'orelse', 'finalbody'],
        [body_stmts, [], [], [close_stmt, clear_stmt]],
        jac_node=here
    );
    self.set_out(here, [assign_stmt, open_stmt, try_stmt]);
}

impl JcirGenPass._comptime_if_out(nd: IfStmt) -> bool {
    if nd.ct_taken is None {
        return False;
    }
    if nd.ct_taken {
        self.set_out(nd, self.resolve_stmt_block(nd.body));
    } else {
        self.set_out(nd, self.outs(nd.else_body) if nd.else_body else []);
    }
    return True;
}

impl JcirGenPass.exit_if_stmt with IfStmt exit {
    if here.__class__ is not IfStmt {
        return;
    }
    if self._comptime_if_out(here) {
        return;
    }
    self.set_out(
        here,
        [
            self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [
                    self.val(here.condition),
                    self.resolve_stmt_block(here.body),
                    self.outs(here.else_body) if here.else_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_else_if with ElseIf exit {
    if self._comptime_if_out(here) {
        return;
    }
    self.set_out(
        here,
        [
            self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [
                    self.val(here.condition),
                    self.resolve_stmt_block(here.body),
                    self.outs(here.else_body) if here.else_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_else_stmt with ElseStmt exit {
    self.set_out(here, self.resolve_stmt_block(here.body));
}

impl JcirGenPass.exit_expr_stmt with ExprStmt exit {
    if not here.in_fstring {
        stub_call = self._sv_bridge_walker_call(here.expr);
        if stub_call is not None {
            stub_name = (
                stub_call.target.sym_name if isinstance(stub_call.target, Name) else ''
            );
            (args, keywords) = self.gen_call_args(stub_call);
            deferred = self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.nod(
                        'Attribute',
                        ['value', 'attr', 'ctx'],
                        [
                            self.nod(
                                'Name',
                                ['id', 'ctx'],
                                [stub_name, self.nod('Load', [], [])]
                            ),
                            '_deferred',
                            self.nod('Load', [], [])
                        ]
                    ),
                    args,
                    keywords
                ],
                jac_node=here.expr
            );
            self.set_out(here, [self.nod('Expr', ['value'], [deferred])]);
            return;
        }
    }
    expr_stmt = self.nod('Expr', ['value'], [self.val(here.expr)])
        if not here.in_fstring
        else self.nod(
            'FormattedValue',
            ['value', 'conversion', 'format_spec'],
            [self.val(here.expr), -1, None]
        );
    self.set_out(here, [expr_stmt]);
}

impl JcirGenPass.exit_concurrent_expr with ConcurrentExpr exit {
    func = '';
    if here.tok {
        if here.tok.value == 'flow' {
            func = 'thread_run';
        } elif here.tok.value == 'wait' {
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
                    self.val(here.target)
                ]
            )
        ];
        self.set_out(
            here,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [
                        self.jaclib_obj(func),
                        lambda_ex
                            if (func == 'thread_run')
                            else [self.val(here.target)],
                        []
                    ]
                )
            ]
        );
    }
}

impl JcirGenPass.exit_try_stmt with TryStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'Try',
                ['body', 'handlers', 'orelse', 'finalbody'],
                [
                    self.resolve_stmt_block(here.body),
                    [self.val(i) for i in here.excepts],
                    self.outs(here.else_body) if here.else_body else [],
                    self.outs(here.finally_body) if here.finally_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_except with Except exit {
    self.set_out(
        here,
        [
            self.nod(
                'ExceptHandler',
                ['type', 'name', 'body'],
                [
                    self.val(here.ex_type) if here.ex_type else None,
                    here.name.sym_name if here.name else None,
                    self.resolve_stmt_block(here.body)
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_finally_stmt with FinallyStmt exit {
    self.set_out(here, self.resolve_stmt_block(here.body));
}

impl JcirGenPass.exit_iter_for_stmt with IterForStmt exit {
    py_nodes: list[CgNode] = [];
    body = self.resolve_stmt_block(here.body);
    body = body + [self.val(here.count_by)];
    py_nodes.append(self.val(here.iter));
    py_nodes.append(
        self.nod(
            'While',
            ['test', 'body', 'orelse'],
            [
                self.val(here.condition),
                body,
                self.outs(here.else_body) if here.else_body else []
            ]
        )
    );
    self.set_out(here, py_nodes);
}

impl JcirGenPass.exit_in_for_stmt with InForStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'AsyncFor' if here.is_async else 'For',
                ['target', 'iter', 'body', 'orelse'],
                [
                    self.val(here.target),
                    self.val(here.collection),
                    self.resolve_stmt_block(here.body),
                    self.outs(here.else_body) if here.else_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_while_stmt with WhileStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'While',
                ['test', 'body', 'orelse'],
                [
                    self.val(here.condition),
                    self.resolve_stmt_block(here.body),
                    self.outs(here.else_body) if here.else_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_forever_stmt with ForeverStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'While',
                ['test', 'body', 'orelse'],
                [self.const_of(True), self.resolve_stmt_block(here.body), []]
            )
        ]
    );
}

impl JcirGenPass.exit_with_stmt with WithStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'AsyncWith' if here.is_async else 'With',
                ['items', 'body'],
                [
                    [self.val(item) for item in here.exprs],
                    self.resolve_stmt_block(here.body)
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_expr_as_item with ExprAsItem exit {
    self.set_out(
        here,
        [
            self.nod(
                'withitem',
                ['context_expr', 'optional_vars'],
                [self.val(here.expr), self.val(here.alias) if here.alias else None]
            )
        ]
    );
}

impl JcirGenPass.exit_raise_stmt with RaiseStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'Raise',
                ['exc', 'cause'],
                [
                    self.val(here.cause) if here.cause else None,
                    self.val(here.from_target) if here.from_target else None
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_assert_stmt with AssertStmt exit {
    if here.is_comptime {
        self.set_out(here, []);
        return;
    }
    self.set_out(
        here,
        [
            self.nod(
                'Assert',
                ['test', 'msg'],
                [
                    self.val(here.condition),
                    self.val(here.error_msg) if here.error_msg else None
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_ctrl_stmt with CtrlStmt exit {
    if (here.ctrl.name == Tok.KW_BREAK) {
        self.set_out(here, [self.nod('Break', [], [])]);
    } elif (here.ctrl.name == Tok.KW_CONTINUE) {
        if (iter_for_parent := here.find_parent_of_type(IterForStmt)) {
            count_by = iter_for_parent.count_by;
            self.set_out(here, [self.val(count_by), self.nod('Continue', [], [])]);
        } else {
            self.set_out(here, [self.nod('Continue', [], [])]);
        }
    } elif (here.ctrl.name == Tok.KW_SKIP) {
        self.set_out(here, [self.nod('Return', ['value'], [None])]);
    }
}

impl JcirGenPass._del_ctx_target(target: Expr, ctx_cls: str) -> CgNode {
    cgn = self.val(target);
    return self._with_ctx(cgn, ctx_cls) if cgn.hasf('ctx') else cgn;
}

impl JcirGenPass._destroy_call(value: CgNode, strict: bool) -> CgNode {
    keywords: list[CgNode] = [];
    if strict {
        keywords.append(
            self.nod('keyword', ['arg', 'value'], ['strict', self.const_of(True)])
        );
    }
    return self.nod(
        'Expr',
        ['value'],
        [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [self.jaclib_obj('destroy'), [value], keywords]
            )
        ]
    );
}

impl JcirGenPass._del_is_trivial(cgn: CgNode) -> bool {
    if cgn.cls in ('Name', 'Constant') {
        return True;
    }
    if cgn.cls == 'Slice' {
        return all(
            (part is None) or (isinstance(part, CgNode) and self._del_is_trivial(part))
            for part in (cgn.get('lower'), cgn.get('upper'), cgn.get('step'))
        );
    }
    return False;
}

impl JcirGenPass._del_slice_value(value: CgNode, nd: DeleteStmt) -> CgNode {
    if value.cls != 'Slice' {
        return value;
    }
    return self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [
            self.name_load('slice', jac_node=nd),
            [
                part if isinstance(part, CgNode) else self.const_of(None)
                for part in (value.get('lower'), value.get('upper'), value.get('step'))
            ],
            []
        ]
    );
}

impl JcirGenPass._del_bind_temp(
    value: CgNode, name: str, stmts: list[CgItem], nd: DeleteStmt
) -> CgNode {
    bound = self._del_slice_value(value, nd);
    stmts.append(
        self.nod(
            'Assign',
            ['targets', 'value'],
            [
                [self.nod('Name', ['id', 'ctx'], [name, self.nod('Store', [], [])])],
                bound
            ],
            jac_node=nd
        )
    );
    return self.name_load(name, jac_node=nd);
}

impl JcirGenPass._del_location(
    target: Expr, nd: DeleteStmt, ordinal: int
) -> list[CgItem] {
    stmts: list[CgItem] = [];
    if isinstance(target, Name) {
        stmts.append(self._destroy_call(self._del_ctx_target(target, 'Load'), False));
        stmts.append(
            self.nod('Delete', ['targets'], [[self._del_ctx_target(target, 'Del')]])
        );
        return stmts;
    }
    loaded = self._del_ctx_target(target, 'Load');
    prefix = f"_jac_del_{nd.loc.first_line}_{nd.loc.col_start}_{ordinal}";
    container = loaded.get('value');
    if not self._del_is_trivial(container) {
        container = self._del_bind_temp(container, prefix + "_c", stmts, nd);
    }
    del_ctx = self.nod('Del', [], []);
    if loaded.cls == 'Attribute' {
        attr = loaded.get('attr');
        peek_call = self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [self.jaclib_obj('peek_attr'), [container, self.const_of(attr)], []]
        );
        del_target = self.nod(
            'Attribute', ['value', 'attr', 'ctx'], [container, attr, del_ctx]
        );
    } else {
        key = loaded.get('slice');
        if not self._del_is_trivial(key) {
            key = self._del_bind_temp(key, prefix + "_k", stmts, nd);
        }
        peek_call = self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [
                self.jaclib_obj('peek_item'),
                [container, self._del_slice_value(key, nd)],
                []
            ]
        );
        del_target = self.nod(
            'Subscript', ['value', 'slice', 'ctx'], [container, key, del_ctx]
        );
    }
    stmts.append(self._destroy_call(peek_call, False));
    stmts.append(self.nod('Delete', ['targets'], [[del_target]]));
    return stmts;
}

impl JcirGenPass.exit_delete_stmt with DeleteStmt exit {
    stmts: list[CgItem] = [];
    ordinal = 0;
    for target in here.leaf_targets() {
        if DeleteStmt.is_location(target) {
            stmts.extend(self._del_location(target, here, ordinal));
        } else {
            simple = None;
            if isinstance(target, EdgeRefTrailer) and target.edges_only {
                simple = self._simple_hop(target);
            }
            if simple is not None {
                stmts.append(
                    self.nod(
                        'Expr',
                        ['value'],
                        [
                            self.nod(
                                'Call',
                                ['func', 'args', 'keywords'],
                                [self.jaclib_obj('clear_edges'), simple, []]
                            )
                        ]
                    )
                );
            } else {
                stmts.append(
                    self._destroy_call(self._del_ctx_target(target, 'Load'), True)
                );
            }
        }
        ordinal += 1;
    }
    self.set_out(here, stmts);
}

impl JcirGenPass.exit_report_stmt with ReportStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'Expr',
                ['value'],
                [
                    self.nod(
                        'Call',
                        ['func', 'args', 'keywords'],
                        [self.jaclib_obj('log_report'), self.outs(here.expr), []]
                    )
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_return_stmt with ReturnStmt exit {
    self.set_out(
        here,
        [self.nod('Return', ['value'], [self.val(here.expr) if here.expr else None])]
    );
}

impl JcirGenPass.exit_yield_expr with YieldExpr exit {
    if not here.with_from {
        self.set_out(
            here,
            [self.nod('Yield', ['value'], [self.val(here.expr) if here.expr else None])]
        );
    } else {
        self.set_out(
            here,
            [
                self.nod(
                    'YieldFrom',
                    ['value'],
                    [self.val(here.expr) if here.expr else self.const_of(None)]
                )
            ]
        );
    }
}

impl JcirGenPass.exit_visit_stmt with VisitStmt exit {
    loc = self.name_load('self' if here.from_walker else Con.VISITOR.value);
    visit_call = self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [self.jaclib_obj('visit'), [loc, self.val(here.target)], []]
    );
    if (here.insert_loc is not None) {
        visit_call.get('keywords').append(
            self.nod(
                'keyword', ['arg', 'value'], ['insert_loc', self.val(here.insert_loc)]
            )
        );
    }
    self.set_out(
        here,
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
                    self.outs(here.else_body),
                    []
                ]
            )
        ]
            if here.else_body
            else [self.nod('Expr', ['value'], [visit_call])]
    );
}

impl JcirGenPass.exit_disengage_stmt with DisengageStmt exit {
    loc = self.name_load('self' if here.from_walker else Con.VISITOR.value);
    self.set_out(
        here,
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

impl JcirGenPass.exit_await_expr with AwaitExpr exit {
    self.set_out(here, [self.nod('Await', ['value'], [self.val(here.target)])]);
}

impl JcirGenPass.exit_cast_expr with CastExpr exit {
    self.set_out(here, self.outs(here.value));
}

impl JcirGenPass.exit_assignment with Assignment exit {
    value: (CgNode | None) = None;
    init_cv = here.value.ct_value if here.value else None;
    if here.value
        and here.is_comptime
        and init_cv is not None
        and self._ct_concrete(here.value) {
        value = self._materialize(init_cv.v, here.value);
        if value is None {
            value = self.val(here.value);
        }
    } elif here.value {
        value = self.val(here.value);
    } elif here.is_enum_stmt {
        value = self.nod(
            'Call', ['func', 'args', 'keywords'], [self.name_load('auto'), [], []]
        );
    } elif not here.type_tag {
        raise RuntimeError(
            self.ice('assignment has no value, no enum default and no type tag')
        );
    }
    targets_ast = [self.val(t) for t in here.target];
    class_body_ct = (
        here.is_comptime
        and isinstance(here.parent, GlobalVars)
        and isinstance(here.parent.parent, Archetype)
    );
    ct_val0 = here.value;
    if class_body_ct and ct_val0 is not None and not self._ct_concrete(ct_val0) {
        tgt0 = here.target[0] if here.target else None;
        if isinstance(tgt0, Name) {
            self.set_out(
                here,
                [
                    self.nod(
                        'FunctionDef',
                        ['name', 'args', 'body', 'decorator_list', 'returns'],
                        [
                            tgt0.sym_name,
                            self.nod(
                                'arguments',
                                [
                                    'posonlyargs',
                                    'args',
                                    'kwonlyargs',
                                    'kw_defaults',
                                    'defaults'
                                ],
                                [
                                    [],
                                    [
                                        self.nod(
                                            'arg', ['arg', 'annotation'], ['self', None]
                                        )
                                    ],
                                    [],
                                    [],
                                    []
                                ]
                            ),
                            [
                                self.nod(
                                    'Return',
                                    ['value'],
                                    [self.val(ct_val0)],
                                    jac_node=here
                                )
                            ],
                            [self.name_load('property', here)],
                            None
                        ],
                        jac_node=here
                    )
                ]
            );
            return;
        }
    }
    if here.type_tag and not class_body_ct {
        assignment_stmt = self.nod(
            'AnnAssign',
            ['target', 'annotation', 'value', 'simple'],
            [
                targets_ast[0],
                self.val(here.type_tag),
                value if here.value else None,
                int(isinstance(targets_ast[0], CgNode) and targets_ast[0].cls == 'Name')
            ]
        );
    } elif here.aug_op {
        _fw_aug = self._fw_aug_assign(
            here, targets_ast[0], value if isinstance(value, CgNode) else None
        );
        assignment_stmt = _fw_aug
            if _fw_aug is not None
            else self.nod(
                'AugAssign',
                ['target', 'op', 'value'],
                [
                    targets_ast[0],
                    self.val(here.aug_op),
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
    self.set_out(here, [assignment_stmt]);
}

impl JcirGenPass.exit_binary_expr with BinaryExpr exit {
    if isinstance(here.op, ConnectOp) {
        left = self.val(here.right)
            if (here.op.edge_dir == EdgeDir.IN)
            else self.val(here.left);
        right = self.val(here.left)
            if (here.op.edge_dir == EdgeDir.IN)
            else self.val(here.right);
        keywords = [
            self.nod('keyword', ['arg', 'value'], ['left', left]),
            self.nod('keyword', ['arg', 'value'], ['right', right])
        ];
        if here.op.conn_type {
            keywords.append(
                self.nod(
                    'keyword', ['arg', 'value'], ['edge', self.val(here.op.conn_type)]
                )
            );
        }
        if (here.op.edge_dir == EdgeDir.ANY) {
            keywords.append(
                self.nod('keyword', ['arg', 'value'], ['undir', self.const_of(True)])
            );
        }
        if here.op.conn_assign {
            keywords.append(
                self.nod(
                    'keyword',
                    ['arg', 'value'],
                    ['conn_assign', self.val(here.op.conn_assign)]
                )
            );
        }
        self.set_out(
            here,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [self.jaclib_obj('connect'), [], keywords]
                )
            ]
        );
    } elif isinstance(here.op, DisconnectOp) {
        keywords = [
            self.nod('keyword', ['arg', 'value'], ['left', self.val(here.left)]),
            self.nod('keyword', ['arg', 'value'], ['right', self.val(here.right)])
        ];
        if (here.op.edge_spec.edge_dir != EdgeDir.OUT) {
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
                                EDGE_DIR_NAMES[int(here.op.edge_spec.edge_dir)],
                                self.nod('Load', [], [])
                            ]
                        )
                    ]
                )
            );
        }
        if here.op.edge_spec.filter_cond {
            keywords.append(
                self.nod(
                    'keyword',
                    ['arg', 'value'],
                    ['filter', self.val(here.op.edge_spec.filter_cond)]
                )
            );
        }
        self.set_out(
            here,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [self.jaclib_obj('disconnect'), [], keywords]
                )
            ]
        );
    } elif (here.op.name in [Tok.KW_AND.value, Tok.KW_OR.value]) {
        self.set_out(
            here,
            [
                self.nod(
                    'BoolOp',
                    ['op', 'values'],
                    [self.val(here.op), [self.val(here.left), self.val(here.right)]]
                )
            ]
        );
    } elif ((here.op.name in [Tok.WALRUS_EQ]) and self.val(here.left).cls == 'Name') {
        self.val(here.left).setf('ctx', self.nod('Store', [], []));
        self.set_out(
            here,
            [
                self.nod(
                    'NamedExpr',
                    ['target', 'value'],
                    [self.val(here.left), self.val(here.right)]
                )
            ]
        );
    } elif ((here.op.name in [Tok.WALRUS_EQ]) and not isinstance(here.left, Name)) {
        self.set_out(here, [self.val(here.right)]);
    } elif self.outs(here.op) {
        self.set_out(
            here,
            [
                self.nod(
                    'BinOp',
                    ['left', 'op', 'right'],
                    [self.val(here.left), self.val(here.op), self.val(here.right)]
                )
            ]
        );
    } else {
        self.set_out(here, self.translate_jac_bin_op(here));
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
        if nd.parent is not None {
            func_node.set_parent(nd.parent);
        }
        self._exit_func_call_impl(func_node);
        return self.outs(func_node);
    } elif (nd.op.name in [Tok.KW_SPAWN]) {
        for side in (nd.right, nd.left) {
            if self._sv_bridge_walker_call(side) is not None {
                return [self.val(side)];
            }
        }
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
        if nd.parent is not None {
            func_node.set_parent(nd.parent);
        }
        self._exit_func_call_impl(func_node);
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

impl JcirGenPass.exit_compare_expr with CompareExpr exit {
    self.set_out(
        here,
        [
            self.nod(
                'Compare',
                ['left', 'ops', 'comparators'],
                [
                    self.val(here.left),
                    [self.val(i) for i in here.ops],
                    [self.val(i) for i in here.rights]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_cfg_expr with CfgExpr exit {
    self.set_out(here, self.outs(here.expr));
}

impl JcirGenPass.exit_bool_expr with BoolExpr exit {
    self.set_out(
        here,
        [
            self.nod(
                'BoolOp',
                ['op', 'values'],
                [self.val(here.op), [self.val(i) for i in here.values]]
            )
        ]
    );
}

impl JcirGenPass.exit_lambda_expr with LambdaExpr exit {
    if isinstance(here.body, list) {
        tail = here.tail_return_expr();
        if tail is not None {
            self._emit_lambda_expr_body(here, tail);
            return;
        }
        if (here.signature and self.outs(here.signature)) {
            arguments = self.val(here.signature);
        } else {
            arguments = self.nod(
                'arguments',
                ['posonlyargs', 'args', 'kwonlyargs', 'kw_defaults', 'defaults'],
                [[], [], [], [], []],
                jac_node=here
            );
        }
        body_stmts = self.resolve_stmt_block(here.body, doc=None);
        directive_stmts = self.scope_directive_stmts([here]);
        if directive_stmts {
            body_stmts = [*directive_stmts, *body_stmts];
        }
        if not body_stmts {
            body_stmts = [self.nod('Pass', [], [], jac_node=here)];
        }
        func_name = self._next_lambda_name();
        returns = self.val(here.signature.return_type)
            if (
                here.signature
                and here.signature.return_type
                and self.outs(here.signature.return_type)
            )
            else None;
        func_def = self.nod(
            'FunctionDef',
            ['name', 'args', 'body', 'decorator_list', 'returns', 'type_params'],
            [func_name, arguments, body_stmts, [], returns, []],
            jac_node=here
        );
        self.set_out(here, [self._function_expr_from_def(func_def, here)]);
        return;
    }
    if not isinstance(here.body, Expr) {
        raise RuntimeError(
            self.ice('lambda statement body fell past the FunctionDef path')
        );
    }
    self._emit_lambda_expr_body(here, here.body);
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

impl JcirGenPass.exit_unary_expr with UnaryExpr exit {
    if here.ownership in (OwnershipKind.OWN, OwnershipKind.IMM) {
        self.set_out(here, [self.val(here.operand)]);
        return;
    }
    if here.op.name == Tok.BW_AND {
        if is_borrow_kind(here.ownership) {
            self.set_out(
                here,
                [
                    self.nod(
                        'Call',
                        ['func', 'args', 'keywords'],
                        [self.builtin_name('jref'), [self.val(here.operand)], []]
                    )
                ]
            );
        } else {
            self._emit_jobj_ref(here);
        }
        return;
    }
    op_name = here.op.name;
    op_cls = UNARY_CLS_BY_NAME[op_name] if op_name in UNARY_CLS_BY_NAME else '';
    if op_cls {
        self.set_out(
            here,
            [
                self.nod(
                    'UnaryOp',
                    ['op', 'operand'],
                    [self.nod(op_cls, [], []), self.val(here.operand)]
                )
            ]
        );
        return;
    } elif (here.op.name in [Tok.PIPE_FWD, Tok.KW_SPAWN, Tok.A_PIPE_FWD]) {
        self.set_out(
            here,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [self.val(here.operand), [], []]
                )
            ]
        );
    } elif (here.op.name in [Tok.STAR_MUL]) {
        ctx_val = self.py_ctx(here.operand)
            if isinstance(here.operand, AstSymbolNode)
            else self.nod('Load', [], []);
        self.set_out(
            here,
            [self.nod('Starred', ['value', 'ctx'], [self.val(here.operand), ctx_val])]
        );
    } elif (here.op.name in [Tok.STAR_POW]) {
        self.set_out(here, self.outs(here.operand));
    } else {
        raise RuntimeError(self.ice("Unknown Unary operator " + here.op.value));
    }
}

impl JcirGenPass.exit_if_else_expr with IfElseExpr exit {
    self.set_out(
        here,
        [
            self.nod(
                'IfExp',
                ['test', 'body', 'orelse'],
                [
                    self.val(here.condition),
                    self.val(here.value),
                    self.val(here.else_value)
                ]
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

impl JcirGenPass.exit_multi_string with MultiString exit {
    lone = here.strings[0] if (len(here.strings) == 1) else None;
    if (isinstance(lone, FString) and self.outs(lone)) {
        self.set_out(here, self.outs(lone));
        return;
    }
    combined_multi: list = [];
    for item in self._multi_string_pieces(here.strings) {
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
        self.set_out(here, [self.const_of('')]);
    } elif (len(merged) == 1 and merged[0].cls == 'Constant') {
        self.set_out(here, [merged[0]]);
    } else {
        self.set_out(here, [self.nod('JoinedStr', ['values'], [merged])]);
    }
}

impl JcirGenPass.exit_f_string with FString exit {
    self.set_out(
        here,
        [
            self.nod(
                'JoinedStr',
                ['values'],
                [
                    [
                        self.val(part)
                        for part in here.parts
                        if self.outs(part)
                    ]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_formatted_value with FormattedValue exit {
    self.set_out(
        here,
        [
            self.nod(
                'FormattedValue',
                ['value', 'conversion', 'format_spec'],
                [
                    self.val(here.format_part),
                    here.conversion,
                    self.val(here.format_spec) if here.format_spec else None
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_list_val with ListVal exit {
    self.set_out(
        here,
        [
            self.nod(
                'List',
                ['elts', 'ctx'],
                [[self.val(v) for v in here.values], self.py_ctx(here)]
            )
        ]
    );
}

impl JcirGenPass.exit_set_val with SetVal exit {
    self.set_out(
        here, [self.nod('Set', ['elts'], [[self.val(i) for i in here.values]])]
    );
}

impl JcirGenPass.exit_tuple_val with TupleVal exit {
    self.set_out(
        here,
        [
            self.nod(
                'Tuple',
                ['elts', 'ctx'],
                [[self.val(i) for i in here.values], self.py_ctx(here)]
            )
        ]
    );
}

impl JcirGenPass.exit_dict_val with DictVal exit {
    self.set_out(
        here,
        [
            self.nod(
                'Dict',
                ['keys', 'values'],
                [
                    [self.val(x.key) if x.key else None for x in here.kv_pairs],
                    [self.val(x.value) for x in here.kv_pairs]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_k_v_pair with KVPair exit {}

impl JcirGenPass.exit_k_w_pair with KWPair exit {
    self.set_out(
        here,
        [
            self.nod(
                'keyword',
                ['arg', 'value'],
                [
                    here.key.sym_name
                        if (here.key and self.val(here.key).cls == 'Name')
                        else None,
                    self.val(here.value)
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_inner_compr with InnerCompr exit {
    self.set_out(
        here,
        [
            self.nod(
                'comprehension',
                ['target', 'iter', 'ifs', 'is_async'],
                [
                    self.val(here.target),
                    self.val(here.collection),
                    [self.val(x) for x in here.conditional] if here.conditional else [],
                    0
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_list_compr with ListCompr exit {
    if here.__class__ is not ListCompr {
        return;
    }
    self.set_out(
        here,
        [
            self.nod(
                'ListComp',
                ['elt', 'generators'],
                [self.val(here.out_expr), [self.val(i) for i in here.compr]]
            )
        ]
    );
}

impl JcirGenPass.exit_gen_compr with GenCompr exit {
    self.set_out(
        here,
        [
            self.nod(
                'GeneratorExp',
                ['elt', 'generators'],
                [self.val(here.out_expr), [self.val(i) for i in here.compr]]
            )
        ]
    );
}

impl JcirGenPass.exit_set_compr with SetCompr exit {
    self.set_out(
        here,
        [
            self.nod(
                'SetComp',
                ['elt', 'generators'],
                [self.val(here.out_expr), [self.val(i) for i in here.compr]]
            )
        ]
    );
}

impl JcirGenPass.exit_dict_compr with DictCompr exit {
    self.set_out(
        here,
        [
            self.nod(
                'DictComp',
                ['key', 'value', 'generators'],
                [
                    self.val(here.kv_pair.key)
                        if here.kv_pair.key
                        else self.const_of(None),
                    self.val(here.kv_pair.value),
                    [self.val(i) for i in here.compr]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_atom_trailer with AtomTrailer exit {
    if here.is_genai {
        self.set_out(here, []);
    }
    trailer_cv = here.ct_value;
    if (
        here.is_attr
        and trailer_cv is not None
        and self._ct_concrete(here)
        and self._ct_kind(trailer_cv.v) in ("scalar", "CtEnumMember")
        and self._trailer_reaches_ct_class(here)
    ) {
        folded = self._materialize(trailer_cv.v, here);
        if folded is not None {
            self.set_out(here, [folded]);
            return;
        }
    }
    ct_slots = self._ct_ctor_slots(here);
    if ct_slots is not None {
        kws: list = [];
        for pair in ct_slots {
            pname: str = pair[0];
            pexpr: UniNode = pair[1];
            kws.append(self.nod('keyword', ['arg', 'value'], [pname, self.val(pexpr)]));
        }
        self.set_out(
            here,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [
                        self._import_ref("jaclang.comptime", "specialize", here),
                        [self.val(here.target)],
                        kws
                    ],
                    jac_node=here
                )
            ]
        );
        return;
    }
    if here.is_attr {
        if isinstance(here.right, AstSymbolNode) {
            self.set_out(
                here,
                [
                    self.nod(
                        'Attribute',
                        ['value', 'attr', 'ctx'],
                        [
                            self.val(here.target),
                            self._py_name(here.right),
                            self.py_ctx(here.right)
                        ]
                    )
                ]
            );
        } else {
            self.emit(E5008);
        }
    } elif isinstance(here.right, FilterCompr) {
        if self._is_edge_ref_target(here.target) {
            target_py = self.val(here.target);
            narrow_kws = self._query_filter_kws(here.right, 'nd', 'preds');
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
            self.set_out(here, [target_py]);
        } else {
            self.set_out(
                here,
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
                                    ['items', self.val(here.target)]
                                ),
                                self.nod(
                                    'keyword',
                                    ['arg', 'value'],
                                    ['func', self.val(here.right)]
                                )
                            ]
                        ]
                    )
                ]
            );
        }
    } elif isinstance(here.right, AssignCompr) {
        self.set_out(
            here,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [
                        self.jaclib_obj('assign_all'),
                        [self.val(here.target), self.val(here.right)],
                        []
                    ]
                )
            ]
        );
    } elif (
        isinstance(here.right, IndexSlice)
        and here.right.is_range
        and len(here.right.slices) == 1
        and self._is_edge_ref_target(here.target)
    ) {
        target_py = self.val(here.target);
        slc = here.right.slices[0];
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
        self.set_out(here, [target_py]);
    } else {
        self.set_out(
            here,
            [
                self.nod(
                    'Subscript',
                    ['value', 'slice', 'ctx'],
                    [
                        self.val(here.target),
                        self.val(here.right),
                        self.py_ctx(here.right)
                            if isinstance(here.right, AstSymbolNode)
                            else self.nod('Load', [], [])
                    ]
                )
            ]
        );
        if self.val(here.right).hasf('ctx') {
            self.val(here.right).setf('ctx', self.nod('Load', [], []));
        }
    }
    if here.is_null_ok {
        walrus_assign = self.nod(
            'NamedExpr',
            ['target', 'value'],
            [
                self.nod(
                    'Name', ['id', 'ctx'], ['__jac_tmp', self.nod('Store', [], [])]
                ),
                self.val(here.target)
            ]
        );
        tmp_ref = self.name_load('__jac_tmp');
        none_const = self.const_of(None);
        cur = self.val(here);
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
            here,
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

impl JcirGenPass.exit_atom_unit with AtomUnit exit {
    if (
        isinstance(here.value, Ability)
        and self.outs(here.value)
        and self.val(here.value).cls in ('FunctionDef', 'AsyncFunctionDef')
    ) {
        self.set_out(here, [self._function_expr_from_def(self.val(here.value), here)]);
        return;
    }
    self.set_out(here, self.outs(here.value));
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

impl JcirGenPass._fold_sorted_traversal(nd: FuncCall) -> bool {
    if (not isinstance(nd.target, Name)) or nd.target.sym_name != 'sorted' {
        return False;
    }
    params = nd.params;
    if params is None or len(params) < 1 {
        return False;
    }
    trav = params[0];
    if not isinstance(trav, EdgeRefTrailer) {
        return False;
    }
    key_expr: (Expr | None) = None;
    reverse = False;
    for extra in params[1:] {
        if not isinstance(extra, KWPair) or extra.key is None {
            return False;
        }
        kname = extra.key.sym_name;
        if kname == 'key' {
            key_expr = extra.value;
        } elif kname == 'reverse' {
            rv = extra.value;
            if isinstance(rv, Bool) and rv.lit_value {
                reverse = True;
            } elif isinstance(rv, Bool) {
                reverse = False;
            } else {
                return False;
            }
        } else {
            return False;
        }
    }
    if key_expr is None {
        return False;
    }
    (node_ty, edge_ty) = self._final_hop_types(trav);
    specs = self._sort_order_specs(key_expr, node_ty, edge_ty);
    if specs is None {
        self.emit(
            W5096,
            node_override=key_expr,
            reason='sort key is not a field access, so it has no ORDER BY form'
        );
        return False;
    }
    outs = self.outs(trav);
    if len(outs) != 1 {
        return False;
    }
    call = outs[0];
    if (not isinstance(call, CgNode)) or call.cls != 'Call' {
        return False;
    }
    gq = call.get('args')[0] if call.get('args') else None;
    if (not isinstance(gq, CgNode)) or gq.cls != 'Call' {
        return False;
    }
    terms: list[CgNode] = [];
    for (fname, desc, on_edge) in specs {
        flip = (not desc) if reverse else desc;
        terms.append(
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [
                    self.jaclib_obj('QOrder'),
                    [],
                    [
                        self.nod(
                            'keyword', ['arg', 'value'], ['field', self.const_of(fname)]
                        ),
                        self.nod(
                            'keyword', ['arg', 'value'], ['desc', self.const_of(flip)]
                        ),
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            ['on_edge', self.const_of(on_edge)]
                        )
                    ]
                ]
            )
        );
    }
    gq.get('keywords').append(
        self.nod(
            'keyword',
            ['arg', 'value'],
            [
                'order',
                self.nod('List', ['elts', 'ctx'], [terms, self.nod('Load', [], [])])
            ]
        )
    );
    self.set_out(nd, [call]);
    return True;
}


impl JcirGenPass._order_term(
    expr: Expr, param: str, node_ty: str, edge_ty: str
) -> (tuple[str, bool, bool] | None) {
    desc = False;
    inner = expr;
    if isinstance(inner, UnaryExpr) and inner.op.name == Tok.MINUS {
        desc = True;
        inner = inner.operand;
    }
    if not isinstance(inner, AtomTrailer) or not inner.is_attr {
        return None;
    }
    base = inner.target;
    right = inner.right;
    if (not isinstance(base, Name))
        or base.sym_name != param
        or not isinstance(right, Name) {
        return None;
    }
    return (right.sym_name, desc, False);
}


impl JcirGenPass._sort_order_specs(
    key: Expr, node_ty: str, edge_ty: str
) -> (list[tuple[str, bool, bool]] | None) {
    if not isinstance(key, LambdaExpr) {
        return None;
    }
    sig = key.signature;
    if sig is None or sig.params is None or len(sig.params) != 1 {
        return None;
    }
    pv = sig.params[0];
    pname = pv.name.sym_name;
    ann = '';
    if pv.type_tag is not None and isinstance(pv.type_tag.tag, Name) {
        ann = pv.type_tag.tag.sym_name;
    }
    if ann and node_ty and ann != node_ty {
        return None;
    }
    body = key.tail_return_expr();
    if body is None {
        return None;
    }
    parts: list = list(body.values) if isinstance(body, TupleVal) else [body];
    out: list[tuple[str, bool, bool]] = [];
    for part in parts {
        if not isinstance(part, Expr) {
            return None;
        }
        term = self._order_term(part, pname, node_ty, edge_ty);
        if term is None {
            return None;
        }
        out.append((term[0], term[1], False));
    }
    return out;
}


impl JcirGenPass._final_hop_types(nd: EdgeRefTrailer) -> tuple[str, str] {
    node_ty = '';
    edge_ty = '';
    for item in nd.chain {
        if isinstance(item, FilterCompr) and isinstance(item.f_type, Name) {
            node_ty = item.f_type.sym_name;
        } elif isinstance(item, EdgeOpRef) {
            fc = item.filter_cond;
            if fc is not None and isinstance(fc.f_type, Name) {
                edge_ty = fc.f_type.sym_name;
            }
        }
    }
    return (node_ty, edge_ty);
}


impl JcirGenPass.exit_func_call with FuncCall exit {
    self._exit_func_call_impl(here);
}

impl JcirGenPass._place_parts(arg: UniNode) -> (tuple | None) {
    place = arg;
    if isinstance(arg, UnaryExpr) and is_borrow_kind(arg.ownership) {
        place = arg.operand;
    }
    cg = self.val(place);
    if cg.cls == 'Attribute' {
        return ('attr', cg.get('value'), self.const_of(cg.get('attr')));
    }
    if cg.cls == 'Subscript' {
        return ('item', cg.get('value'), cg.get('slice'));
    }
    if cg.cls == 'Name' {
        return ('name', cg.get('id'), None);
    }
    return None;
}

impl JcirGenPass._name_swap_expr(store_id: str, value: CgNode) -> CgNode {
    return self.nod(
        'NamedExpr',
        ['target', 'value'],
        [self.nod('Name', ['id', 'ctx'], [store_id, self.nod('Store', [], [])]), value]
    );
}

impl JcirGenPass._lower_take(nd: FuncCall) -> (CgNode | None) {
    params = list(nd.params or []);
    if len(params) != 1 or isinstance(params[0], KWPair) {
        return None;
    }
    parts = self._place_parts(params[0]);
    if parts is None {
        return None;
    }
    (kind, owner, key) = parts;
    if kind == 'name' {
        moved = self.nod(
            'Tuple',
            ['elts', 'ctx'],
            [
                [
                    self.name_load(owner),
                    self._name_swap_expr(owner, self.const_of(None))
                ],
                self.nod('Load', [], [])
            ]
        );
        return self.nod(
            'Subscript',
            ['value', 'slice', 'ctx'],
            [moved, self.const_of(0), self.nod('Load', [], [])]
        );
    }
    helper = '_jac_take_attr' if kind == 'attr' else '_jac_take_item';
    return self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [self.builtin_name(helper), [owner, key], []]
    );
}

impl JcirGenPass._lower_swap(nd: FuncCall) -> (CgNode | None) {
    params = list(nd.params or []);
    if len(params) != 2 or any([isinstance(p, KWPair) for p in params]) {
        return None;
    }
    pa = self._place_parts(params[0]);
    pb = self._place_parts(params[1]);
    if pa is None or pb is None {
        return None;
    }
    (ka, oa, keya) = pa;
    (kb, ob, keyb) = pb;
    if ka == 'name' and kb == 'name' {
        inner = self.nod(
            'Tuple',
            ['elts', 'ctx'],
            [
                [self.name_load(ob), self._name_swap_expr(ob, self.name_load(oa))],
                self.nod('Load', [], [])
            ]
        );
        old_b = self.nod(
            'Subscript',
            ['value', 'slice', 'ctx'],
            [inner, self.const_of(0), self.nod('Load', [], [])]
        );
        return self._name_swap_expr(oa, old_b);
    }
    if ka == 'name' or kb == 'name' {
        (name_id, pk, pobj, pkey) = (oa, kb, ob, keyb)
            if ka == 'name'
            else (ob, ka, oa, keya);
        helper = '_jac_replace_attr' if pk == 'attr' else '_jac_replace_item';
        replaced = self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [self.builtin_name(helper), [pobj, pkey, self.name_load(name_id)], []]
        );
        return self._name_swap_expr(name_id, replaced);
    }
    return self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [
            self.builtin_name('_jac_swap_places'),
            [
                oa,
                keya,
                self.const_of(ka == 'attr'),
                ob,
                keyb,
                self.const_of(kb == 'attr')
            ],
            []
        ]
    );
}

impl JcirGenPass._exit_func_call_impl(nd: FuncCall) -> None {
    if isinstance(nd.target, Name) and nd.target.sym_name in ('take', 'swap') {
        import from jaclang.compiler.symbol_utils { CallKind, classify_call }
        lowered = (
            (
                self._lower_take(nd)
                    if nd.target.sym_name == 'take'
                    else self._lower_swap(nd)
            )
                if classify_call(nd) == CallKind.BUILTIN
                else None
        );
        if lowered is not None {
            self.set_out(nd, [lowered]);
            return;
        }
    }
    call_cv = nd.ct_value;
    if (
        nd.callee_decl is not None
        and nd.callee_decl.is_comptime
        and call_cv is not None
        and self._ct_concrete(nd)
    ) {
        folded = self._materialize(call_cv.v, nd);
        if folded is not None {
            self.set_out(nd, [folded]);
            return;
        }
    }
    if self._fold_sorted_traversal(nd) {
        return;
    }
    self._warn_inplace_sort(nd);
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

impl JcirGenPass.exit_index_slice with IndexSlice exit {
    if here.is_range {
        if (len(here.slices) > 1) {
            self.set_out(
                here,
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
                                ) for slc in here.slices
                            ],
                            self.nod('Load', [], [])
                        ]
                    )
                ]
            );
        } elif (len(here.slices) == 1) {
            slc = here.slices[0];
            self.set_out(
                here,
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
    } elif ((len(here.slices) > 0) and (here.slices[0].start is not None)) {
        self.set_out(here, self.outs(here.slices[0].start));
    } else {
        self.set_out(here, []);
    }
}

impl JcirGenPass.exit_special_var_ref with SpecialVarRef exit {
    if (here.name == Tok.KW_SUPER) {
        self.set_out(
            here,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [
                        self.nod('Name', ['id', 'ctx'], ['super', self.py_ctx(here)]),
                        [],
                        []
                    ]
                )
            ]
        );
    } elif (here.name == Tok.KW_ROOT) {
        self.set_out(
            here,
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
            here,
            [self.nod('Name', ['id', 'ctx'], [self._py_name(here), self.py_ctx(here)])]
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
    if isinstance(target, FuncCall)
        and isinstance(target.target, Name)
        and target.target.sym_name == 'sorted'
        and target.params is not None
        and len(target.params) >= 1 {
        return self._is_edge_ref_target(target.params[0]);
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
    return self._query_filter_kws_ord(fc, type_arg, preds_arg, False, [])[0];
}


impl JcirGenPass._order_name_of(x: Expr) -> (tuple[str, bool] | None) {
    inner = x;
    desc = False;
    if isinstance(inner, UnaryExpr) {
        if inner.op.name != Tok.MINUS {
            return None;
        }
        desc = True;
        inner = inner.operand;
    }
    if not isinstance(inner, Name) {
        return None;
    }
    return (inner.sym_name, desc);
}


impl JcirGenPass._query_filter_kws_ord(
    fc: FilterCompr,
    type_arg: str,
    preds_arg: str,
    on_edge: bool,
    order_out: list[CgNode]
) -> tuple[list[CgNode], bool] {
    kws: list[CgNode] = [];
    if fc.f_type {
        kws.append(
            self.nod('keyword', ['arg', 'value'], [type_arg, self.val(fc.f_type)])
        );
    }
    preds: list[CgNode] = [];
    saw_order = False;
    for x in fc.compares {
        term = self._order_name_of(x);
        if term is not None {
            saw_order = True;
            order_out.append(
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [
                        self.jaclib_obj('QOrder'),
                        [],
                        [
                            self.nod(
                                'keyword',
                                ['arg', 'value'],
                                ['field', self.const_of(term[0])]
                            ),
                            self.nod(
                                'keyword',
                                ['arg', 'value'],
                                ['desc', self.const_of(term[1])]
                            ),
                            self.nod(
                                'keyword',
                                ['arg', 'value'],
                                ['on_edge', self.const_of(on_edge)]
                            )
                        ]
                    ]
                )
            );
            continue;
        }
        if saw_order {
            self.emit(
                E5094,
                node_override=x,
                reason='ordering terms must come after every predicate'
            );
            continue;
        }
        cmp_ast = self.val(x);
        reason: str = '';
        field_name: str = '';
        op_str: str = '';
        composite_names: list[str] = [];
        if cmp_ast.cls != 'Compare' {
            reason = 'not a comparison';
        } else {
            ops = cmp_ast.get('ops');
            left = cmp_ast.get('left');
            if len(ops) != 1 {
                reason = 'chained comparisons are not admitted';
            } elif isinstance(left, CgNode) and left.cls == 'Tuple' {
                op_node = ops[0];
                resolved = self._cmp_op_str(op_node)
                    if isinstance(op_node, CgNode)
                    else None;
                names: list[str] = [];
                for elt in left.get('elts') {
                    if isinstance(elt, CgNode) and elt.cls == 'Name' {
                        eid = elt.get('id');
                        if isinstance(eid, str) {
                            names.append(eid);
                        }
                    }
                }
                right = cmp_ast.get('comparators')[0];
                if resolved is None or resolved == 'in' {
                    reason = 'a composite key has no ordering for this operator';
                } elif (not names) or len(names) != len(left.get('elts')) {
                    reason = 'a composite key must be a tuple of declared field names';
                } elif (
                    (not isinstance(right, CgNode))
                    or right.cls != 'Tuple'
                    or len(right.get('elts')) != len(names)
                ) {
                    reason = f"a composite key of arity {len(
                        names
                    )} needs a tuple value of the same arity";
                } else {
                    composite_names = names;
                    op_str = resolved;
                }
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
                                [
                                    'field',
                                    self.nod(
                                        'Tuple',
                                        ['elts', 'ctx'],
                                        [
                                            [
                                                self.const_of(nm)
                                                for nm in composite_names
                                            ],
                                            self.nod('Load', [], [])
                                        ]
                                    )
                                        if composite_names
                                        else self.const_of(field_name)
                                ]
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
    return (kws, saw_order);
}

impl JcirGenPass._warn_inplace_sort(nd: FuncCall) -> None {
    tgt = nd.target;
    if (not isinstance(tgt, AtomTrailer))
        or not tgt.is_attr
        or not isinstance(tgt.right, Name)
        or tgt.right.sym_name != 'sort' {
        return;
    }
    base = tgt.target;
    if not isinstance(base, Name) {
        return;
    }
    sym = base.sym;
    if sym is None {
        return;
    }
    for defn in sym.defn {
        assign = defn.parent;
        if isinstance(assign, Assignment)
            and assign.value is not None
            and isinstance(assign.value, EdgeRefTrailer) {
            self.emit(
                W5096,
                node_override=nd,
                reason=(
                    f"'{base.sym_name}' holds a traversal and .sort() cannot "
                    f"fold; use sorted(), or order inside the reference"
                )
            );
            return;
        }
    }
}


impl JcirGenPass._traversal_consumed_now(nd: EdgeRefTrailer) -> bool {
    parent = nd.parent;
    if parent is None {
        return False;
    }
    if isinstance(parent, (IfStmt, WhileStmt, AssertStmt)) {
        return parent.condition is nd;
    }
    if isinstance(parent, BoolExpr) {
        return True;
    }
    if isinstance(parent, UnaryExpr) {
        return parent.op.name == Tok.NOT and parent.operand is nd;
    }
    if isinstance(parent, FuncCall) {
        tgt = parent.target;
        return isinstance(tgt, Name)
            and tgt.sym_name == 'len'
            and parent.params is not None
            and len(parent.params) == 1
            and parent.params[0] is nd;
    }
    return False;
}


impl JcirGenPass._simple_hop(nd: EdgeRefTrailer) -> (list[CgNode] | None) {
    if nd.is_async {
        return None;
    }
    parent = nd.parent;
    if isinstance(parent, VisitStmt) {
        return None;
    }
    if isinstance(parent, AtomTrailer)
        and parent.target is nd
        and isinstance(parent.right, (FilterCompr, IndexSlice)) {
        return None;
    }
    if isinstance(parent, FuncCall)
        and isinstance(parent.target, Name)
        and parent.target.sym_name == 'sorted'
        and parent.params is not None
        and len(parent.params) >= 1
        and parent.params[0] is nd {
        return None;
    }
    chain = nd.chain;
    if len(chain) == 2
        and not isinstance(chain[0], EdgeOpRef)
        and isinstance(chain[1], EdgeOpRef) {
        origin_ast = self.val(chain[0]);
        hop = chain[1];
    } elif len(chain) == 1 and isinstance(chain[0], EdgeOpRef) {
        hop = chain[0];
        origin_ast = self.val(hop);
    } else {
        return None;
    }
    type_ast = self.const_of(None);
    fc = hop.filter_cond;
    if fc is not None {
        if fc.compares or fc.f_type is None {
            return None;
        }
        type_ast = self.val(fc.f_type);
    }
    return [origin_ast, self.const_of(hop.edge_dir.value), type_ast];
}

impl JcirGenPass.exit_edge_ref_trailer with EdgeRefTrailer exit {
    simple = self._simple_hop(here);
    if simple is not None {
        self.set_out(
            here,
            [
                self.nod(
                    'Call',
                    ['func', 'args', 'keywords'],
                    [
                        self.jaclib_obj('hop'),
                        [*simple, self.const_of(here.edges_only)],
                        []
                    ]
                )
            ]
        );
        return;
    }
    origin: (CgNode | None) = None;
    cur = here.chain[0];
    chomp = [*here.chain[1:]];
    from_visit = bool(isinstance(here.parent, VisitStmt));
    if not isinstance(cur, EdgeOpRef) {
        origin = self.val(cur);
        cur = chomp.pop(0);
    }
    origin_ast = origin if origin is not None else self.val(cur);
    hops: list[CgNode] = [];
    order_terms: list[CgNode] = [];
    while True {
        if not isinstance(cur, EdgeOpRef) {
            raise RuntimeError(self.ice('edge ref chain hop is not an EdgeOpRef'));
        }
        keywords = [
            self.nod(
                'keyword', ['arg', 'value'], ['dir', self.const_of(cur.edge_dir.value)]
            )
        ];
        hop_order: list[CgNode] = [];
        if cur.filter_cond {
            (ekws, _eord) = self._query_filter_kws_ord(
                cur.filter_cond, 'edge', 'epreds', True, hop_order
            );
            keywords.extend(ekws);
        }
        if (chomp and not isinstance(chomp[0], EdgeOpRef)) {
            filt = chomp.pop(0);
            if isinstance(filt, FilterCompr) {
                (nkws, _nord) = self._query_filter_kws_ord(
                    filt, 'nd', 'preds', False, hop_order
                );
                keywords.extend(nkws);
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
        if hop_order and chomp {
            self.emit(
                E5094,
                node_override=here,
                reason='ordering applies to the final hop of a traversal'
            );
            hop_order = [];
        }
        order_terms = hop_order;
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
    if order_terms {
        gq_kws.append(
            self.nod(
                'keyword',
                ['arg', 'value'],
                [
                    'order',
                    self.nod(
                        'List', ['elts', 'ctx'], [order_terms, self.nod('Load', [], [])]
                    )
                ]
            )
        );
    }
    if here.edges_only {
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
    if here.is_async {
        pynode = self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [self.jaclib_obj('arefs'), [pynode], []]
        );
    } else {
        ref_kws: list[CgNode] = [];
        if self._traversal_consumed_now(here) {
            ref_kws.append(
                self.nod('keyword', ['arg', 'value'], ['lazy', self.const_of(True)])
            );
        }
        pynode = self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [self.jaclib_obj('refs'), [pynode], ref_kws]
        );
    }
    self.set_out(here, [pynode]);
}

impl JcirGenPass.exit_edge_op_ref with EdgeOpRef exit {
    self.set_out(
        here, [self.name_load(Con.HERE.value if here.from_walker else 'self')]
    );
}

impl JcirGenPass.exit_disconnect_op with DisconnectOp exit {
    self.set_out(here, self.outs(here.edge_spec));
}

impl JcirGenPass.exit_connect_op with ConnectOp exit {
    self.set_out(
        here,
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
                            [
                                'is_undirected',
                                self.const_of(here.edge_dir == EdgeDir.ANY)
                            ]
                        ),
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            [
                                'conn_type',
                                self.val(here.conn_type)
                                    if here.conn_type
                                    else self.const_of(None)
                            ]
                        ),
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            [
                                'conn_assign',
                                self.val(here.conn_assign)
                                    if here.conn_assign
                                    else self.const_of(None)
                            ]
                        )
                    ]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_filter_compr with FilterCompr exit {
    iter_name = 'i';
    comprs: list[CgNode] = [];
    if here.f_type {
        f_type_recipe = self.val(here.f_type);
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
    for x in here.compares {
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
            here,
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

impl JcirGenPass.exit_assign_compr with AssignCompr exit {
    keys: list[CgNode] = [];
    values: list[CgNode] = [];
    for i in here.assigns {
        if i.key {
            keys.append(self.const_of(i.key.sym_name));
            values.append(self.val(i.value));
        }
    }
    key_tup = self.nod('Tuple', ['elts', 'ctx'], [keys, self.nod('Load', [], [])]);
    val_tup = self.nod('Tuple', ['elts', 'ctx'], [values, self.nod('Load', [], [])]);
    self.set_out(
        here,
        [
            self.nod(
                'Tuple', ['elts', 'ctx'], [[key_tup, val_tup], self.nod('Load', [], [])]
            )
        ]
    );
}

impl JcirGenPass.exit_match_stmt with MatchStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'Match',
                ['subject', 'cases'],
                [self.val(here.target), [self.val(x) for x in here.cases]]
            )
        ]
    );
}

impl JcirGenPass.exit_match_case with MatchCase exit {
    self.set_out(
        here,
        [
            self.nod(
                'match_case',
                ['pattern', 'guard', 'body'],
                [
                    self.val(here.pattern),
                    self.val(here.guard) if here.guard else None,
                    self.resolve_stmt_block(here.body)
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_match_or with MatchOr exit {
    self.set_out(
        here,
        [self.nod('MatchOr', ['patterns'], [[self.val(x) for x in here.patterns]])]
    );
}

impl JcirGenPass.exit_match_as with MatchAs exit {
    self.set_out(
        here,
        [
            self.nod(
                'MatchAs',
                ['name', 'pattern'],
                [here.name.sym_name, self.val(here.pattern) if here.pattern else None]
            )
        ]
    );
}

impl JcirGenPass.exit_match_wild with MatchWild exit {
    self.set_out(here, [self.nod('MatchAs', [], [])]);
}

impl JcirGenPass.exit_match_value with MatchValue exit {
    self.set_out(here, [self.nod('MatchValue', ['value'], [self.val(here.value)])]);
}

impl JcirGenPass.exit_match_singleton with MatchSingleton exit {
    self.set_out(here, [self.nod('MatchSingleton', ['value'], [here.value.lit_value])]);
}

impl JcirGenPass.exit_match_sequence with MatchSequence exit {
    self.set_out(
        here,
        [self.nod('MatchSequence', ['patterns'], [[self.val(x) for x in here.values]])]
    );
}

impl JcirGenPass.exit_match_mapping with MatchMapping exit {
    map_keys: list[CgNode] = [];
    map_patterns: list[CgNode] = [];
    rest: (str | None) = None;
    for i in here.values {
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
        here,
        [
            self.nod(
                'MatchMapping',
                ['keys', 'patterns', 'rest'],
                [map_keys, map_patterns, rest]
            )
        ]
    );
}

impl JcirGenPass.exit_match_k_v_pair with MatchKVPair exit {}

impl JcirGenPass.exit_match_star with MatchStar exit {
    self.set_out(here, [self.nod('MatchStar', ['name'], [here.name.sym_name])]);
}

impl JcirGenPass.exit_match_arch with MatchArch exit {
    self.set_out(
        here,
        [
            self.nod(
                'MatchClass',
                ['cls', 'patterns', 'kwd_attrs', 'kwd_patterns'],
                [
                    self.val(here.name),
                    [self.val(x) for x in (here.arg_patterns or [])],
                    [
                        x.key.sym_name
                        for x in (here.kw_patterns or [])
                        if isinstance(x.key, NameAtom)
                    ],
                    [self.val(x.value) for x in (here.kw_patterns or [])]
                ]
            )
        ]
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

impl JcirGenPass.exit_name with Name exit {
    if here.__class__ is not Name {
        return;
    }
    name = here.sym_name;
    if self._is_ct_type_param(here) and here.expr_ctx == ExprCtx.LOAD {
        self.set_out(
            here,
            [
                self.nod(
                    'Attribute',
                    ['value', 'attr', 'ctx'],
                    [self.name_load('self', here), name, self.nod('Load', [], [])],
                    jac_node=here
                )
            ]
        );
        return;
    }
    if name == "Self" {
        resolved = self._resolve_self_type(here);
        if resolved is not None {
            self.set_out(here, [resolved]);
            return;
        }
    }
    name_cv = here.ct_value;
    if name_cv is not None
        and self._ct_concrete(here)
        and here.expr_ctx == ExprCtx.LOAD {
        cv = name_cv.v;
        if self._is_comptime_only_name(here)
            or self._ct_kind(cv) in ("scalar", "CtEnumMember") {
            folded = self._materialize(cv, here);
            if folded is not None {
                self.set_out(here, [folded]);
                return;
            }
        }
    }
    if not is_identifier_slot(here) {
        if (name in self._get_builtin_names()) {
            self.builtin_imports.add(name);
        }
        if (name in self._get_ambient_typing_names()) {
            self.typing_imports.add(name);
        }
    }
    self.set_out(here, [self.nod('Name', ['id', 'ctx'], [name, self.py_ctx(here)])]);
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

impl JcirGenPass.exit_float with Float exit {
    self.set_out(here, [self.const_of(float(here.value))]);
}

impl JcirGenPass.exit_int with Int exit {
    self.set_out(here, [self.const_of(int(here.value, 0))]);
}

impl JcirGenPass.exit_string with String exit {
    self.set_out(here, [self.const_of(here.lit_value)]);
}

impl JcirGenPass.exit_bool with Bool exit {
    self.set_out(here, [self.const_of(here.value == 'True')]);
}

impl JcirGenPass.exit_builtin_type with BuiltinType exit {
    if here.sym_name in self._get_builtin_names() {
        self.builtin_imports.add(here.sym_name);
    }
    if here.sym_name == "any" {
        parent = here.parent;
        is_call_func = (
            parent is not None
            and isinstance(parent, FuncCall)
            and parent.target is here
        );
        if not is_call_func {
            self.typing_imports.add("Any");
            self.set_out(
                here, [self.nod('Name', ['id', 'ctx'], ["Any", self.py_ctx(here)])]
            );
            return;
        }
    }
    self.set_out(
        here, [self.nod('Name', ['id', 'ctx'], [here.sym_name, self.py_ctx(here)])]
    );
}

impl JcirGenPass.exit_null with Null exit {
    self.set_out(here, [self.const_of(None)]);
}

impl JcirGenPass.exit_ellipsis with Ellipsis exit {
    self.set_out(here, [self.const_of(CgEllipsis())]);
}

impl JcirGenPass.exit_jsx_element with JsxElement exit {
    tag_arg: CgNode;
    if here.dynamic_tag is not None {
        tag_arg = self.val(here.dynamic_tag);
    } elif (here.is_fragment or not here.name) {
        tag_arg = self.const_of(None, jac_node=here);
    } else {
        tag_arg = self.val(here.name);
    }
    attrs_expr: CgNode;
    if not here.attributes {
        attrs_expr = self.nod('Dict', ['keys', 'values'], [[], []], jac_node=here);
    } elif any(isinstance(attr, JsxSpreadAttribute) for attr in here.attributes) {
        attrs_expr = self.nod('Dict', ['keys', 'values'], [[], []], jac_node=here);
        for attr in here.attributes {
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
        for attr in here.attributes {
            if isinstance(attr, JsxNormalAttribute) {
                attr_tuple = self.val(attr);
                dkeys.append(attr_tuple.get('elts')[0]);
                dvalues.append(attr_tuple.get('elts')[1]);
            }
        }
        attrs_expr = self.nod(
            'Dict', ['keys', 'values'], [dkeys, dvalues], jac_node=here
        );
    }
    children_arg: CgNode;
    if here.children {
        kept_children = [
            c
            for c in here.children
            if not isinstance(c, JsxComment)
                and not (isinstance(c, JsxText) and not c.get_normalized_text())
        ];
        children_arg = self.nod(
            'List',
            ['elts', 'ctx'],
            [
                [self.val(c) for c in kept_children],
                self.nod('Load', [], [], jac_node=here)
            ],
            jac_node=here
        );
    } else {
        children_arg = self.nod(
            'List',
            ['elts', 'ctx'],
            [[], self.nod('Load', [], [], jac_node=here)],
            jac_node=here
        );
    }
    self.set_out(
        here,
        [
            self.nod(
                'Call',
                ['func', 'args', 'keywords'],
                [self.jaclib_obj('jsx'), [tag_arg, attrs_expr, children_arg], []],
                jac_node=here
            )
        ]
    );
}

impl JcirGenPass.exit_jsx_element_name with JsxElementName exit {
    name_str = '.'.join(part.value for part in here.parts);
    if (here.parts and here.parts[0].value[0].isupper()) {
        self.set_out(here, [self.name_load(name_str, jac_node=here)]);
    } else {
        self.set_out(here, [self.const_of(name_str, jac_node=here)]);
    }
}

impl JcirGenPass.exit_jsx_spread_attribute with JsxSpreadAttribute exit {
    self.set_out(here, [self.val(here.expr)]);
}

impl JcirGenPass.exit_jsx_normal_attribute with JsxNormalAttribute exit {
    if not here.name {
        self.set_out(here, []);
        return;
    }
    key_ast = self.const_of(here.name.value, jac_node=here.name);
    value_ast: CgNode;
    if (here.value and isinstance(here.value, String)) {
        import from html { unescape }
        value_ast = self.const_of(unescape(here.value.lit_value), jac_node=here.value);
    } elif (here.value and self.outs(here.value)) {
        value_ast = self.val(here.value);
    } else {
        value_ast = self.const_of(True, jac_node=here);
    }
    self.set_out(
        here,
        [
            self.nod(
                'Tuple',
                ['elts', 'ctx'],
                [[key_ast, value_ast], self.nod('Load', [], [], jac_node=here)],
                jac_node=here
            )
        ]
    );
}

impl JcirGenPass.exit_jsx_text with JsxText exit {
    import from html { unescape }
    self.set_out(
        here, [self.const_of(unescape(here.get_normalized_text()), jac_node=here)]
    );
}

impl JcirGenPass.exit_jsx_expression with JsxExpression exit {
    self.set_out(here, [self.val(here.expr)]);
}

impl JcirGenPass.exit_jsx_slot with JsxSlot exit {
    self.set_out(here, [self.const_of(None, jac_node=here)]);
}

impl JcirGenPass.exit_jsx_comment with JsxComment exit {
    self.set_out(here, []);
}

impl JcirGenPass.exit_semi with Semi exit {}

impl JcirGenPass.exit_comment_token with CommentToken exit {}

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

impl JcirGenPass._gen_py_sv_func_stub(
    local_name: str,
    func_name: str,
    provider_app: str,
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
        return [];
    }
    effect = src_mod.gen.interop_manifest.endpoint_effects.get(key);
    if not isinstance(effect, dict) or not effect.get('is_writer') {
        return [];
    }
    return [str(t) for t in (effect.get('touches') or ['*'])];
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
